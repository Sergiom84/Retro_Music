import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var receivedMessage: String = ""
    @Published var receivedFileCount: Int = 0
    @Published var receivedAudioTracks: [AudioTrack] = [] {
        didSet {
            saveAudioTracks()
        }
    }

    private let processingQueue = DispatchQueue(label: "com.retromusic.watch.file-processing", qos: .userInitiated)

    private static var tracksFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return docs.appendingPathComponent("retromusic_tracks.json")
    }

    override init() {
        super.init()
        loadAudioTracks()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Sending

    func sendMessageToiOS(message: String) {
        guard WCSession.default.isReachable else { return }
        WCSession.default.sendMessage(["message": message]) { reply in
            print("Reply from iOS: \(reply)")
        } errorHandler: { error in
            print("Error sending message to iOS: \(error.localizedDescription)")
        }
    }

    // MARK: - Receiving

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            if let received = message["message"] as? String {
                self?.receivedMessage = received
                replyHandler(["status": "Message received by Watch"])
            }
        }
    }

    // MARK: - Persistence

    private func saveAudioTracks() {
        do {
            let data = try JSONEncoder().encode(receivedAudioTracks)
            try data.write(to: Self.tracksFileURL, options: .atomic)
        } catch {
            print("Error saving audio tracks: \(error.localizedDescription)")
        }
    }

    private func loadAudioTracks() {
        if FileManager.default.fileExists(atPath: Self.tracksFileURL.path) {
            do {
                let data = try Data(contentsOf: Self.tracksFileURL)
                let decoded = try JSONDecoder().decode([AudioTrack].self, from: data)
                self.receivedAudioTracks = decoded
                return
            } catch {
                print("Error loading tracks from JSON: \(error.localizedDescription)")
            }
        }

        // Migrate from UserDefaults
        let legacyKey = "persistedAudioTracks"
        if let savedData = UserDefaults.standard.data(forKey: legacyKey),
           let decoded = try? JSONDecoder().decode([AudioTrack].self, from: savedData) {
            self.receivedAudioTracks = decoded
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }

    // MARK: - Track Management

    func deleteTracks(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard receivedAudioTracks.indices.contains(index) else { continue }
            let track = receivedAudioTracks[index]
            removeFileIfExists(at: track.filePath)
            receivedAudioTracks.remove(at: index)
        }
    }

    func deleteTrack(_ track: AudioTrack) {
        removeFileIfExists(at: track.filePath)
        receivedAudioTracks.removeAll { $0.id == track.id }
    }

    // MARK: - File Reception

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let sourceURL = file.fileURL
        let metadata = file.metadata

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            let destinationURL = self.resolveDestinationURL(for: sourceURL, metadata: metadata)

            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)

                let parsedTrack = self.parseReceivedTrack(metadata: metadata, destinationURL: destinationURL)
                DispatchQueue.main.async {
                    self.receivedFileCount += 1
                    if let track = parsedTrack {
                        self.upsertReceivedTrack(track)
                    } else {
                        self.removeFileIfExists(at: destinationURL)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.receivedFileCount += 1
                    print("Error processing received file: \(error.localizedDescription)")
                }
            }
        }
    }

    private func resolveDestinationURL(for sourceURL: URL, metadata: [String: Any]?) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        guard let transferMetadata = decodeTransferMetadata(from: metadata),
              !transferMetadata.storedFileName.isEmpty else {
            return documentsDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        }

        return documentsDirectory.appendingPathComponent(transferMetadata.storedFileName)
    }

    private func parseReceivedTrack(metadata: [String: Any]?, destinationURL: URL) -> AudioTrack? {
        guard let encodedTrack = metadata?["audioTrack"] as? Data else { return nil }

        if let lightMeta = try? JSONDecoder().decode(TransferTrackMetadata.self, from: encodedTrack) {
            return AudioTrack(
                id: lightMeta.id,
                title: lightMeta.title,
                artist: lightMeta.artist,
                album: lightMeta.album,
                artworkData: nil,
                filePath: destinationURL,
                duration: lightMeta.duration,
                isPodcast: lightMeta.isPodcast
            )
        }

        if var legacyTrack = try? JSONDecoder().decode(AudioTrack.self, from: encodedTrack) {
            legacyTrack.filePath = destinationURL
            return legacyTrack
        }

        return nil
    }

    private func decodeTransferMetadata(from metadata: [String: Any]?) -> TransferTrackMetadata? {
        guard let encodedTrack = metadata?["audioTrack"] as? Data else { return nil }
        return try? JSONDecoder().decode(TransferTrackMetadata.self, from: encodedTrack)
    }

    private func upsertReceivedTrack(_ track: AudioTrack) {
        if let existingIndex = receivedAudioTracks.firstIndex(where: { $0.id == track.id || $0.storedFileName == track.storedFileName }) {
            let previousFileURL = receivedAudioTracks[existingIndex].filePath
            receivedAudioTracks[existingIndex] = track
            if previousFileURL != track.filePath {
                removeFileIfExists(at: previousFileURL)
            }
            return
        }
        receivedAudioTracks.append(track)
    }

    private func removeFileIfExists(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
