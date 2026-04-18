import Foundation
import WatchConnectivity

enum TransferStatus: Equatable {
    case idle
    case queued
    case transferring
    case sent
    case error(String)
}

private struct TransferTrackMetadata: Codable {
    let id: UUID
    let title: String
    let artist: String?
    let album: String?
    let duration: TimeInterval
    let isPodcast: Bool
    let storedFileName: String
}

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var receivedMessage: String = ""
    @Published var transferStatusByTrackId: [UUID: TransferStatus] = [:]
    @Published var lastTransferError: String?

    static let maxFileSizeBytes: UInt64 = 50 * 1024 * 1024 // 50 MB

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
            return
        }
        print("WCSession activated with state: \(activationState.rawValue)")
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }
    #endif

    // MARK: - Sending Data

    func sendMessageToWatch(message: String) {
        guard WCSession.default.isReachable else {
            print("Watch is not reachable.")
            return
        }
        WCSession.default.sendMessage(["message": message]) { reply in
            print("Reply from Watch: \(reply)")
        } errorHandler: { error in
            print("Error sending message: \(error.localizedDescription)")
        }
    }

    func transferFileToWatch(fileURL: URL, audioTrack: AudioTrack) {
        let session = WCSession.default
        let trackId = audioTrack.id

        // Validate pairing
        #if os(iOS)
        guard session.isPaired else {
            setTransferStatus(.error("No hay Apple Watch emparejado"), for: trackId)
            return
        }
        guard session.isWatchAppInstalled else {
            setTransferStatus(.error("La app del Watch no esta instalada"), for: trackId)
            return
        }
        #endif
        guard session.activationState == .activated else {
            setTransferStatus(.error("Sesion no activada"), for: trackId)
            return
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            setTransferStatus(.error("Archivo no encontrado"), for: trackId)
            return
        }

        // File size check
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

        // Encode metadata
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

            // Monitor transfer progress
            monitorTransfer(transfer, trackId: trackId)
        } catch {
            setTransferStatus(.error("Error al codificar metadata"), for: trackId)
        }
    }

    private func monitorTransfer(_ transfer: WCSessionFileTransfer, trackId: UUID) {
        setTransferStatus(.transferring, for: trackId)

        DispatchQueue.global(qos: .utility).async { [weak self] in
            while transfer.isTransferring {
                Thread.sleep(forTimeInterval: 0.5)
            }
            DispatchQueue.main.async {
                self?.setTransferStatus(.sent, for: trackId)
                // Clear sent status after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if self?.transferStatusByTrackId[trackId] == .sent {
                        self?.transferStatusByTrackId.removeValue(forKey: trackId)
                    }
                }
            }
        }
    }

    private func setTransferStatus(_ status: TransferStatus, for trackId: UUID) {
        DispatchQueue.main.async {
            self.transferStatusByTrackId[trackId] = status
            if case .error(let msg) = status {
                self.lastTransferError = msg
            }
        }
    }

    // MARK: - Transfer error handling

    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        if let error = error {
            // Try to extract track ID from metadata
            if let metadata = fileTransfer.file.metadata,
               let encodedData = metadata["audioTrack"] as? Data,
               let trackMeta = try? JSONDecoder().decode(TransferTrackMetadata.self, from: encodedData) {
                setTransferStatus(.error(error.localizedDescription), for: trackMeta.id)
            }
            print("Transfer failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Receiving Data

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        DispatchQueue.main.async {
            if let received = message["message"] as? String {
                self.receivedMessage = received
                replyHandler(["status": "Message received"])
            }
        }
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("Received file: \(file.fileURL.lastPathComponent)")
        
        // Extraer metadata del archivo transferido
        guard let metadata = file.metadata,
              let encodedData = metadata["audioTrack"] as? Data,
              let trackMetadata = try? JSONDecoder().decode(TransferTrackMetadata.self, from: encodedData) else {
            print("Failed to decode track metadata")
            return
        }
        
        // Guardar el archivo en documentos del Watch
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Could not access documents directory")
            return
        }
        
        let destinationURL = documentsURL.appendingPathComponent(trackMetadata.storedFileName)
        
        do {
            // Remover archivo existente si existe
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copiar el archivo recibido
            try FileManager.default.copyItem(at: file.fileURL, to: destinationURL)
            
            // Crear AudioTrack y guardarlo en lista
            let track = AudioTrack(
                id: trackMetadata.id,
                title: trackMetadata.title,
                artist: trackMetadata.artist,
                album: trackMetadata.album,
                artworkData: nil, // No transferimos artwork por tamaño
                filePath: destinationURL,
                duration: trackMetadata.duration,
                isPodcast: trackMetadata.isPodcast
            )
            
            // Guardar la lista de tracks
            saveReceivedTrack(track)
            
            print("✅ File saved successfully: \(destinationURL.lastPathComponent)")
        } catch {
            print("❌ Error saving received file: \(error.localizedDescription)")
        }
    }
    
    private func saveReceivedTrack(_ track: AudioTrack) {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let metadataURL = documentsURL.appendingPathComponent("watch_tracks.json")
        
        // Cargar tracks existentes
        var tracks: [AudioTrack] = []
        if FileManager.default.fileExists(atPath: metadataURL.path),
           let data = try? Data(contentsOf: metadataURL),
           let existingTracks = try? JSONDecoder().decode([AudioTrack].self, from: data) {
            tracks = existingTracks
        }
        
        // Agregar nuevo track si no existe
        if !tracks.contains(where: { $0.id == track.id }) {
            tracks.append(track)
            
            // Guardar lista actualizada
            if let encoded = try? JSONEncoder().encode(tracks) {
                try? encoded.write(to: metadataURL, options: .atomic)
            }
        }
    }
}
