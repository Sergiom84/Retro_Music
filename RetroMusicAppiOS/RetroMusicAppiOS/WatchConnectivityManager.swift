import Foundation
import WatchConnectivity

enum TransferStatus: Equatable {
    case idle
    case queued
    case transferring
    case sent
    case error(String)
}

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var receivedMessage: String = ""
    @Published var transferStatusByTrackId: [UUID: TransferStatus] = [:]
    @Published var lastTransferError: String?

    static let maxFileSizeBytes: UInt64 = 50 * 1024 * 1024

    // Track active transfers to map WCSessionFileTransfer → trackId
    private var activeTransfers: [WCSessionFileTransfer: UUID] = [:]
    private let transferLock = NSLock()

    override init() {
        super.init()
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

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    // MARK: - Transfer File

    func transferFileToWatch(fileURL: URL, audioTrack: AudioTrack) {
        let session = WCSession.default
        let trackId = audioTrack.id

        guard session.isPaired else {
            setTransferStatus(.error("No hay Apple Watch emparejado"), for: trackId)
            return
        }
        guard session.isWatchAppInstalled else {
            setTransferStatus(.error("La app del Watch no esta instalada"), for: trackId)
            return
        }
        guard session.activationState == .activated else {
            setTransferStatus(.error("Sesion no activada"), for: trackId)
            return
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            setTransferStatus(.error("Archivo no encontrado"), for: trackId)
            return
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let fileSize = attrs[.size] as? UInt64 ?? 0
            if fileSize > Self.maxFileSizeBytes {
                let sizeMB = fileSize / (1024 * 1024)
                setTransferStatus(.error("Archivo demasiado grande (\(sizeMB) MB, max 50 MB)"), for: trackId)
                return
            }
        } catch {
            setTransferStatus(.error("No se pudo leer el archivo"), for: trackId)
            return
        }

        do {
            let transferMetadata = TransferTrackMetadata(
                id: audioTrack.id,
                title: audioTrack.title,
                artist: audioTrack.artist,
                album: audioTrack.album,
                duration: audioTrack.duration,
                isPodcast: audioTrack.isPodcast,
                storedFileName: audioTrack.storedFileName
            )
            let encodedMetadata = try JSONEncoder().encode(transferMetadata)

            setTransferStatus(.queued, for: trackId)
            let transfer = session.transferFile(fileURL, metadata: ["audioTrack": encodedMetadata])

            transferLock.lock()
            activeTransfers[transfer] = trackId
            transferLock.unlock()

            setTransferStatus(.transferring, for: trackId)
        } catch {
            setTransferStatus(.error("Error al codificar metadata"), for: trackId)
        }
    }

    // MARK: - Transfer Delegate (replaces polling)

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        transferLock.lock()
        let trackId = activeTransfers.removeValue(forKey: fileTransfer)
        transferLock.unlock()

        // Fallback: try to extract trackId from metadata
        let resolvedTrackId: UUID? = trackId ?? {
            guard let metadata = fileTransfer.file.metadata,
                  let encodedData = metadata["audioTrack"] as? Data,
                  let trackMeta = try? JSONDecoder().decode(TransferTrackMetadata.self, from: encodedData) else {
                return nil
            }
            return trackMeta.id
        }()

        guard let finalTrackId = resolvedTrackId else { return }

        if let error = error {
            setTransferStatus(.error(error.localizedDescription), for: finalTrackId)
        } else {
            setTransferStatus(.sent, for: finalTrackId)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if self?.transferStatusByTrackId[finalTrackId] == .sent {
                    self?.transferStatusByTrackId.removeValue(forKey: finalTrackId)
                }
            }
        }
    }

    private func setTransferStatus(_ status: TransferStatus, for trackId: UUID) {
        DispatchQueue.main.async { [weak self] in
            self?.transferStatusByTrackId[trackId] = status
            if case .error(let msg) = status {
                self?.lastTransferError = msg
            }
        }
    }

    // MARK: - Receiving

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async { [weak self] in
            if let received = message["message"] as? String {
                self?.receivedMessage = received
                replyHandler(["status": "Message received by iOS"])
            }
        }
    }

    func session(_ session: WCSession, didReceiveFile file: WCSessionFile) {
        print("Received file from Watch: \(file.fileURL.lastPathComponent)")
    }
}
