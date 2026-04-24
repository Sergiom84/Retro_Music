#if canImport(WatchConnectivity)
import Foundation
import WatchConnectivity

private struct TransferTrackMetadata: Codable {
    let id: UUID
    let title: String
    let artist: String?
    let album: String?
    let duration: TimeInterval
    let isPodcast: Bool
    let storedFileName: String
    let artworkData: Data?
}

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var receivedMessage: String = ""
    @Published var receivedFileCount: Int = 0
    @Published var receivedAudioTracks: [AudioTrack] = [] {
        didSet {
            saveAudioTracks()
            pushLibrarySyncStateToiOS()
        }
    }

    private static let syncEventKey = "event"
    private static let syncTrackIDKey = "trackId"
    private static let syncedTrackIDsKey = "syncedTrackIDs"
    private static let trackSyncedEvent = "trackSynced"
    private static let trackRemovedEvent = "trackRemoved"

    private static var tracksFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return docs.appendingPathComponent("retromusic_tracks.json")
    }

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
        loadAudioTracks()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("❌ WCSession activation failed: \(error.localizedDescription)")
            return
        }
        
        print("✅ WCSession activated with state: \(activationState.rawValue)")
        pushLibrarySyncStateToiOS()
        
        #if os(iOS)
        print("📱 iOS - isPaired: \(session.isPaired), isWatchAppInstalled: \(session.isWatchAppInstalled), isReachable: \(session.isReachable)")
        #else
        print("⌚️ watchOS - isReachable: \(session.isReachable)")
        #endif
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        print("WCSession reachability changed: \(session.isReachable)")
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated, reactivating...")
        WCSession.default.activate()
    }
    #endif

    // MARK: - Sending Data

    func sendMessageToiOS(message: String) {
        guard WCSession.default.isReachable else {
            print("iOS is not reachable.")
            return
        }
        WCSession.default.sendMessage(["message": message]) { reply in
            print("Reply from iOS: \(reply)")
        } errorHandler: { error in
            print("Error sending message to iOS: \(error.localizedDescription)")
        }
    }

    // MARK: - Receiving Data

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if let received = message["message"] as? String {
                self.receivedMessage = received
                replyHandler(["status": "Message received by Watch"])
            }
        }
    }

    // MARK: - Persistence (JSON file)

    private func saveAudioTracks() {
        do {
            let data = try JSONEncoder().encode(receivedAudioTracks)
            try data.write(to: Self.tracksFileURL, options: .atomic)
        } catch {
            print("Error saving audio tracks: \(error.localizedDescription)")
        }
    }

    private func loadAudioTracks() {
        // Try loading from JSON file first
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

        // Migrate from UserDefaults if exists
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
            deleteTrack(id: receivedAudioTracks[index].id)
        }
    }

    func renameTrack(id: UUID, newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              let index = receivedAudioTracks.firstIndex(where: { $0.id == id }) else {
            return
        }

        receivedAudioTracks[index].title = trimmedTitle
    }

    func deleteTrack(id: UUID) {
        guard let index = receivedAudioTracks.firstIndex(where: { $0.id == id }) else { return }

        let track = receivedAudioTracks[index]
        removeFileIfExists(at: track.filePath)
        receivedAudioTracks.remove(at: index)
        notifyiOSAboutTrackRemoval(track.id)
    }

    // MARK: - File Reception

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let sourceURL = file.fileURL
        let metadata = file.metadata
        let transferMetadata = decodeTransferMetadata(from: metadata)

        print("📥 Received file from iOS: \(sourceURL.lastPathComponent)")
        let destinationURL = resolveDestinationURL(for: sourceURL, transferMetadata: transferMetadata)

        guard let parsedTrack = parseReceivedTrack(
            transferMetadata: transferMetadata,
            metadata: metadata,
            destinationURL: destinationURL
        ) else {
            print("❌ No valid metadata for file: \(destinationURL.lastPathComponent)")
            DispatchQueue.main.async {
                self.receivedFileCount += 1
            }
            return
        }

        do {
            try ensureParentDirectoryExists(for: destinationURL)

            if FileManager.default.fileExists(atPath: destinationURL.path) {
                print("⚠️ File already exists at destination, removing: \(destinationURL.lastPathComponent)")
                try FileManager.default.removeItem(at: destinationURL)
            }

            try storeReceivedFile(from: sourceURL, to: destinationURL)

            DispatchQueue.main.async {
                self.receivedFileCount += 1
                self.upsertReceivedTrack(parsedTrack)
                self.notifyiOSAboutSyncedTrack(parsedTrack.id)
                print("✅ AudioTrack received: \(parsedTrack.title)")
            }
        } catch {
            print("❌ Error processing received file: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.receivedFileCount += 1
            }
        }
    }

    private func resolveDestinationURL(for sourceURL: URL, transferMetadata: TransferTrackMetadata?) -> URL {
        let defaultName = sourceURL.lastPathComponent
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        guard let transferMetadata, !transferMetadata.storedFileName.isEmpty else {
            return documentsDirectory.appendingPathComponent(defaultName)
        }

        return documentsDirectory.appendingPathComponent(transferMetadata.storedFileName)
    }

    private func parseReceivedTrack(
        transferMetadata: TransferTrackMetadata?,
        metadata: [String: Any]?,
        destinationURL: URL
    ) -> AudioTrack? {
        if let lightMeta = transferMetadata {
            return AudioTrack(
                id: lightMeta.id,
                title: lightMeta.title,
                artist: lightMeta.artist,
                album: lightMeta.album,
                artworkData: lightMeta.artworkData,
                filePath: destinationURL,
                duration: lightMeta.duration,
                isPodcast: lightMeta.isPodcast
            )
        }

        guard let encodedTrack = metadata?["audioTrack"] as? Data else { return nil }

        if var legacyTrack = try? JSONDecoder().decode(AudioTrack.self, from: encodedTrack) {
            legacyTrack.filePath = destinationURL
            return legacyTrack
        }

        return nil
    }

    private func storeReceivedFile(from sourceURL: URL, to destinationURL: URL) throws {
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            print("✅ File moved to: \(destinationURL.path)")
        } catch {
            print("⚠️ Move failed, falling back to copy: \(error.localizedDescription)")
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("✅ File copied to: \(destinationURL.path)")
            if FileManager.default.fileExists(atPath: sourceURL.path) {
                try? FileManager.default.removeItem(at: sourceURL)
            }
        }
    }

    private func decodeTransferMetadata(from metadata: [String: Any]?) -> TransferTrackMetadata? {
        guard let encodedTrack = metadata?["audioTrack"] as? Data else { return nil }
        return try? JSONDecoder().decode(TransferTrackMetadata.self, from: encodedTrack)
    }

    private func ensureParentDirectoryExists(for destinationURL: URL) throws {
        let directoryURL = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
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

    private func notifyiOSAboutSyncedTrack(_ trackID: UUID) {
        transferTrackStateEvent(Self.trackSyncedEvent, trackID: trackID)
    }

    private func notifyiOSAboutTrackRemoval(_ trackID: UUID) {
        transferTrackStateEvent(Self.trackRemovedEvent, trackID: trackID)
    }

    private func transferTrackStateEvent(_ event: String, trackID: UUID) {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else {
            print("⚠️ Unable to report track sync state, WCSession not activated yet")
            return
        }

        session.transferUserInfo([
            Self.syncEventKey: event,
            Self.syncTrackIDKey: trackID.uuidString
        ])
    }

    private func pushLibrarySyncStateToiOS() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        guard session.activationState == .activated else {
            return
        }

        let syncedTrackIDs = receivedAudioTracks.map(\.id.uuidString).sorted()

        do {
            try session.updateApplicationContext([
                Self.syncedTrackIDsKey: syncedTrackIDs
            ])
        } catch {
            print("⚠️ Failed to update watch library sync state: \(error.localizedDescription)")
        }
    }
}
#else
import Foundation

class WatchConnectivityManager: NSObject, ObservableObject {
    @Published var receivedMessage: String = ""
    @Published var receivedFileCount: Int = 0
    @Published var receivedAudioTracks: [AudioTrack] = [] {
        didSet { saveAudioTracks() }
    }

    override init() { super.init(); loadAudioTracks() }

    func sendMessageToiOS(message: String) {
        // WatchConnectivity not available on this platform
        print("WatchConnectivity not available: cannot send message \(message)")
    }

    // MARK: - Persistence (JSON file)
    private static var tracksFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return docs.appendingPathComponent("retromusic_tracks.json")
    }

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
        let legacyKey = "persistedAudioTracks"
        if let savedData = UserDefaults.standard.data(forKey: legacyKey),
           let decoded = try? JSONDecoder().decode([AudioTrack].self, from: savedData) {
            self.receivedAudioTracks = decoded
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }
    }

    func deleteTracks(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            guard receivedAudioTracks.indices.contains(index) else { continue }
            let track = receivedAudioTracks[index]
            removeFileIfExists(at: track.filePath)
            receivedAudioTracks.remove(at: index)
        }
    }

    private func removeFileIfExists(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
#endif
