import Foundation
import WatchConnectivity
#if os(iOS)
import UIKit
#endif

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
    let artworkData: Data?
}

private struct ArtworkTransferBudget {
    let maxDimension: CGFloat
    let maxBytes: Int
    let compressionQualities: [CGFloat]
}

struct TransferProgressSnapshot: Equatable {
    let fractionCompleted: Double
    let completedBytes: Int64
    let totalBytes: Int64
    let estimatedTimeRemaining: TimeInterval?
}

struct WatchSessionStatus: Equatable {
    let isSupported: Bool
    let activationState: WCSessionActivationState
    let isPaired: Bool
    let isWatchAppInstalled: Bool
    let isReachable: Bool
    let activationErrorMessage: String?

    static let unsupported = WatchSessionStatus(
        isSupported: false,
        activationState: .notActivated,
        isPaired: false,
        isWatchAppInstalled: false,
        isReachable: false,
        activationErrorMessage: nil
    )

    var activationLabel: String {
        switch activationState {
        case .activated:
            return "activa"
        case .inactive:
            return "inactiva"
        case .notActivated:
            return "pendiente"
        @unknown default:
            return "desconocida"
        }
    }

    var helpText: String {
        if !isSupported {
            return "WatchConnectivity no esta disponible en este dispositivo."
        }

        if let activationErrorMessage {
            return "Error activando WatchConnectivity: \(activationErrorMessage)"
        }

        if activationState != .activated {
            return "Activando WatchConnectivity..."
        }

        if !isPaired {
            return "No hay Apple Watch emparejado con este iPhone."
        }

        if !isWatchAppInstalled {
            return "RetroMusicWatch no aparece instalado en el reloj."
        }

        if !isReachable {
            return "Instalada. Reachable solo se pone verde con RetroMusic abierta en el reloj."
        }

        return "Watch conectado en tiempo real."
    }
}

class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var receivedMessage: String = ""
    @Published private(set) var sessionStatus: WatchSessionStatus = .unsupported
    @Published var transferStatusByTrackId: [UUID: TransferStatus] = [:]
    @Published var transferProgressByTrackId: [UUID: TransferProgressSnapshot] = [:]
    @Published var radioTransferStatusByStationId: [String: TransferStatus] = [:]
    @Published var lastTransferError: String?
    @Published private(set) var syncedTrackIDs: Set<UUID> = [] {
        didSet {
            saveSyncedTrackIDs()
        }
    }

    static let maxFileSizeBytes: UInt64 = 200 * 1024 * 1024 // 200 MB
    private static let fastArtworkTransferThresholdBytes: UInt64 = 40 * 1024 * 1024
    private static let skipArtworkTransferThresholdBytes: UInt64 = 150 * 1024 * 1024
    private static let standardArtworkBudget = ArtworkTransferBudget(
        maxDimension: 180,
        maxBytes: 140 * 1024,
        compressionQualities: [0.72, 0.58, 0.45]
    )
    private static let fastArtworkBudget = ArtworkTransferBudget(
        maxDimension: 96,
        maxBytes: 32 * 1024,
        compressionQualities: [0.55, 0.4, 0.28]
    )
    private static let syncEventKey = "event"
    private static let syncTrackIDKey = "trackId"
    private static let syncedTrackIDsKey = "syncedTrackIDs"
    private static let trackSyncedEvent = "trackSynced"
    private static let trackRemovedEvent = "trackRemoved"
    private static let radioStationAddedEvent = "radioStationAdded"
    private static let radioStationSyncedEvent = "radioStationSynced"
    private static let radioStationKey = "radioStation"
    private static let radioStationIDKey = "radioStationId"

    private static var syncedTracksFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return docs.appendingPathComponent("retromusic_watch_sync_state.json")
    }

    override init() {
        super.init()
        loadSyncedTrackIDs()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            refreshSessionStatus()
        }
    }

    func refreshSessionStatus() {
        guard WCSession.isSupported() else {
            DispatchQueue.main.async {
                self.sessionStatus = .unsupported
            }
            return
        }

        publishSessionStatus(from: WCSession.default)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        publishSessionStatus(from: session, activationError: error)

        if let error = error {
            print("WCSession activation failed: \(error.localizedDescription)")
            return
        }
        print("WCSession activated with state: \(activationState.rawValue)")
        applySyncedTrackIDs(from: session.receivedApplicationContext)
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        publishSessionStatus(from: session)
    }

    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) {
        publishSessionStatus(from: session)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        publishSessionStatus(from: session)
    }

    func sessionDidDeactivate(_ session: WCSession) {
        publishSessionStatus(from: session)
        WCSession.default.activate()
    }
    #endif

    private func publishSessionStatus(from session: WCSession, activationError: Error? = nil) {
        let nextStatus = WatchSessionStatus(
            isSupported: WCSession.isSupported(),
            activationState: session.activationState,
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            isReachable: session.isReachable,
            activationErrorMessage: activationError?.localizedDescription
        )

        DispatchQueue.main.async {
            self.sessionStatus = nextStatus
        }
    }

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

        if isTrackSyncedToWatch(trackId) {
            print("Track already synced to watch: \(audioTrack.title)")
            return
        }

        // Validate pairing
        #if os(iOS)
        guard session.isPaired else {
            setTransferStatus(.error("No hay Apple Watch emparejado"), for: trackId)
            return
        }
        guard session.isWatchAppInstalled else {
            setTransferStatus(.error("La app del Watch no esta instalada. Ejecuta RetroMusicWatch en el reloj o instalala desde la app Watch."), for: trackId)
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

        if hasOutstandingTransfer(for: trackId, session: session) {
            setTransferStatus(.queued, for: trackId)
            return
        }

        let fileSize: UInt64

        // File size check
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileSize = attrs[.size] as? UInt64 ?? 0
            if fileSize > Self.maxFileSizeBytes {
                let sizeMB = Self.formatSizeInMB(fileSize)
                let maxSizeMB = Self.formatSizeInMB(Self.maxFileSizeBytes)
                setTransferStatus(.error("Archivo demasiado grande (\(sizeMB) MB, max \(maxSizeMB) MB)"), for: trackId)
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
                storedFileName: audioTrack.storedFileName,
                artworkData: prepareArtworkForTransfer(audioTrack.artworkData, fileSize: fileSize)
            )
            let encodedMetadata = try JSONEncoder().encode(transferMetadata)

            setTransferStatus(.queued, for: trackId)
            let transfer = session.transferFile(fileURL, metadata: ["audioTrack": encodedMetadata])

            // Monitor transfer progress
            monitorTransfer(transfer, trackId: trackId, expectedBytes: Int64(fileSize))
        } catch {
            setTransferStatus(.error("Error al codificar metadata"), for: trackId)
        }
    }

    func transferRadioStationToWatch(_ station: RadioStation) {
        let session = WCSession.default

        #if os(iOS)
        guard session.isPaired else {
            setRadioTransferStatus(.error("No hay Apple Watch emparejado"), for: station.id)
            return
        }

        guard session.isWatchAppInstalled else {
            setRadioTransferStatus(.error("La app del Watch no esta instalada"), for: station.id)
            return
        }
        #endif

        guard session.activationState == .activated else {
            setRadioTransferStatus(.error("Sesion no activada"), for: station.id)
            return
        }

        do {
            let encodedStation = try JSONEncoder().encode(station)
            setRadioTransferStatus(.queued, for: station.id)
            session.transferUserInfo([
                Self.syncEventKey: Self.radioStationAddedEvent,
                Self.radioStationIDKey: station.id,
                Self.radioStationKey: encodedStation
            ])
        } catch {
            setRadioTransferStatus(.error("Error al codificar emisora"), for: station.id)
        }
    }

    private func monitorTransfer(_ transfer: WCSessionFileTransfer, trackId: UUID, expectedBytes: Int64) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            var lastObservedStatus: TransferStatus = .queued
            var startedTransferringAt: Date?

            self?.updateTransferProgress(
                TransferProgressSnapshot(
                    fractionCompleted: 0,
                    completedBytes: 0,
                    totalBytes: max(expectedBytes, 1),
                    estimatedTimeRemaining: nil
                ),
                for: trackId
            )

            while self?.hasOutstandingTransfer(for: trackId, session: WCSession.default) == true {
                let nextStatus: TransferStatus = transfer.isTransferring ? .transferring : .queued
                if nextStatus != lastObservedStatus {
                    self?.setTransferStatus(nextStatus, for: trackId)
                    lastObservedStatus = nextStatus
                }

                if transfer.isTransferring, startedTransferringAt == nil {
                    startedTransferringAt = Date()
                }

                let snapshot = self?.makeTransferProgressSnapshot(
                    from: transfer.progress,
                    expectedBytes: expectedBytes,
                    startedAt: startedTransferringAt,
                    isTransferring: transfer.isTransferring
                ) ?? TransferProgressSnapshot(
                    fractionCompleted: 0,
                    completedBytes: 0,
                    totalBytes: max(expectedBytes, 1),
                    estimatedTimeRemaining: nil
                )
                self?.updateTransferProgress(snapshot, for: trackId)
                Thread.sleep(forTimeInterval: 0.5)
            }

            self?.finalizeTransferProgress(for: trackId, totalBytes: expectedBytes)
        }
    }

    private func setTransferStatus(_ status: TransferStatus, for trackId: UUID) {
        DispatchQueue.main.async {
            self.transferStatusByTrackId[trackId] = status
            if case .error(let msg) = status {
                self.lastTransferError = msg
                self.transferProgressByTrackId.removeValue(forKey: trackId)
            } else if case .sent = status {
                self.transferProgressByTrackId.removeValue(forKey: trackId)
            }
        }
    }

    private func setRadioTransferStatus(_ status: TransferStatus, for stationId: String) {
        DispatchQueue.main.async {
            self.radioTransferStatusByStationId[stationId] = status
            if case .error(let msg) = status {
                self.lastTransferError = msg
            }
        }
    }

    private func updateTransferProgress(_ progress: TransferProgressSnapshot, for trackId: UUID) {
        DispatchQueue.main.async {
            self.transferProgressByTrackId[trackId] = progress
        }
    }

    private func finalizeTransferProgress(for trackId: UUID, totalBytes: Int64) {
        DispatchQueue.main.async {
            if case .error = self.transferStatusByTrackId[trackId] {
                return
            }

            if case .sent = self.transferStatusByTrackId[trackId] {
                self.transferProgressByTrackId.removeValue(forKey: trackId)
                return
            }

            self.transferStatusByTrackId[trackId] = .transferring
            self.transferProgressByTrackId[trackId] = TransferProgressSnapshot(
                fractionCompleted: 1,
                completedBytes: max(totalBytes, 1),
                totalBytes: max(totalBytes, 1),
                estimatedTimeRemaining: 0
            )
        }
    }

    private func makeTransferProgressSnapshot(
        from progress: Progress,
        expectedBytes: Int64,
        startedAt: Date?,
        isTransferring: Bool
    ) -> TransferProgressSnapshot {
        let totalBytes = max(progress.totalUnitCount, expectedBytes, 1)
        let completedBytes = min(max(progress.completedUnitCount, 0), totalBytes)
        let fractionCompleted = min(max(Double(completedBytes) / Double(totalBytes), 0), 1)

        return TransferProgressSnapshot(
            fractionCompleted: fractionCompleted,
            completedBytes: completedBytes,
            totalBytes: totalBytes,
            estimatedTimeRemaining: estimatedTimeRemaining(
                for: progress,
                totalBytes: totalBytes,
                startedAt: startedAt,
                isTransferring: isTransferring
            )
        )
    }

    private func estimatedTimeRemaining(
        for progress: Progress,
        totalBytes: Int64,
        startedAt: Date?,
        isTransferring: Bool
    ) -> TimeInterval? {
        guard isTransferring else { return nil }

        if let systemEstimate = progress.estimatedTimeRemaining,
           systemEstimate.isFinite,
           systemEstimate >= 0 {
            return systemEstimate
        }

        guard let startedAt else { return nil }

        let completedBytes = max(progress.completedUnitCount, 0)
        guard completedBytes > 0 else { return nil }

        let elapsed = Date().timeIntervalSince(startedAt)
        guard elapsed > 0 else { return nil }

        let bytesPerSecond = Double(completedBytes) / elapsed
        guard bytesPerSecond > 0 else { return nil }

        let remainingBytes = max(totalBytes - completedBytes, 0)
        return Double(remainingBytes) / bytesPerSecond
    }

    private func prepareArtworkForTransfer(_ artworkData: Data?, fileSize: UInt64) -> Data? {
        guard let artworkData else { return nil }
        guard let artworkBudget = artworkBudget(for: fileSize) else { return nil }

        #if os(iOS)
        guard let image = UIImage(data: artworkData) else {
            return artworkData.count <= artworkBudget.maxBytes ? artworkData : nil
        }

        let targetSize = resizedArtworkSize(for: image.size, maxDimension: artworkBudget.maxDimension)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        for quality in artworkBudget.compressionQualities {
            if let jpegData = resizedImage.jpegData(compressionQuality: quality),
               jpegData.count <= artworkBudget.maxBytes {
                return jpegData
            }
        }

        if let pngData = resizedImage.pngData(), pngData.count <= artworkBudget.maxBytes {
            return pngData
        }
        #endif

        return artworkData.count <= artworkBudget.maxBytes ? artworkData : nil
    }

    private func artworkBudget(for fileSize: UInt64) -> ArtworkTransferBudget? {
        if fileSize >= Self.skipArtworkTransferThresholdBytes {
            return nil
        }

        if fileSize >= Self.fastArtworkTransferThresholdBytes {
            return Self.fastArtworkBudget
        }

        return Self.standardArtworkBudget
    }

    private func resizedArtworkSize(for originalSize: CGSize, maxDimension: CGFloat) -> CGSize {
        guard originalSize.width > 0, originalSize.height > 0 else {
            return CGSize(width: maxDimension, height: maxDimension)
        }

        let currentMaxDimension = max(originalSize.width, originalSize.height)
        guard currentMaxDimension > maxDimension else { return originalSize }

        let scale = maxDimension / currentMaxDimension
        return CGSize(width: max(1, originalSize.width * scale), height: max(1, originalSize.height * scale))
    }

    private static func formatSizeInMB(_ bytes: UInt64) -> String {
        String(format: "%.1f", Double(bytes) / (1024 * 1024))
    }

    private func hasOutstandingTransfer(for trackId: UUID, session: WCSession) -> Bool {
        session.outstandingFileTransfers.contains { transfer in
            guard let metadata = transfer.file.metadata,
                  let encodedData = metadata["audioTrack"] as? Data,
                  let trackMeta = try? JSONDecoder().decode(TransferTrackMetadata.self, from: encodedData) else {
                return false
            }
            return trackMeta.id == trackId
        }
    }

    private func loadSyncedTrackIDs() {
        guard FileManager.default.fileExists(atPath: Self.syncedTracksFileURL.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: Self.syncedTracksFileURL)
            let decodedIDs = try JSONDecoder().decode([UUID].self, from: data)
            syncedTrackIDs = Set(decodedIDs)
        } catch {
            print("Failed to load synced watch tracks: \(error.localizedDescription)")
        }
    }

    private func applySyncedTrackIDs(_ newIDs: Set<UUID>) {
        DispatchQueue.main.async {
            self.syncedTrackIDs = newIDs

            let sentTrackIDs = self.transferStatusByTrackId.compactMap { entry in
                if case .sent = entry.value {
                    return entry.key
                }
                return nil
            }

            for trackID in sentTrackIDs where !newIDs.contains(trackID) {
                self.transferStatusByTrackId.removeValue(forKey: trackID)
            }
        }
    }

    private func applySyncedTrackIDs(from applicationContext: [String: Any]) {
        guard let trackIDStrings = applicationContext[Self.syncedTrackIDsKey] as? [String] else {
            return
        }

        let trackIDs = Set(trackIDStrings.compactMap(UUID.init(uuidString:)))
        applySyncedTrackIDs(trackIDs)
    }

    private func saveSyncedTrackIDs() {
        do {
            let sortedIDs = syncedTrackIDs.map(\.uuidString).sorted().compactMap(UUID.init(uuidString:))
            let data = try JSONEncoder().encode(sortedIDs)
            try data.write(to: Self.syncedTracksFileURL, options: .atomic)
        } catch {
            print("Failed to save synced watch tracks: \(error.localizedDescription)")
        }
    }

    private func markTrackAsSynced(_ trackId: UUID) {
        DispatchQueue.main.async {
            self.syncedTrackIDs.insert(trackId)
            self.transferStatusByTrackId[trackId] = .sent
            self.transferProgressByTrackId.removeValue(forKey: trackId)
        }
    }

    private func markTrackAsRemovedFromWatch(_ trackId: UUID) {
        DispatchQueue.main.async {
            self.syncedTrackIDs.remove(trackId)
            self.transferStatusByTrackId.removeValue(forKey: trackId)
            self.transferProgressByTrackId.removeValue(forKey: trackId)
        }
    }

    func isTrackSyncedToWatch(_ trackId: UUID) -> Bool {
        syncedTrackIDs.contains(trackId)
    }

    func markTrackNeedsResync(_ trackId: UUID) {
        DispatchQueue.main.async {
            self.syncedTrackIDs.remove(trackId)
            self.transferStatusByTrackId.removeValue(forKey: trackId)
            self.transferProgressByTrackId.removeValue(forKey: trackId)
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
            return
        }

        if let metadata = fileTransfer.file.metadata,
           let encodedData = metadata["audioTrack"] as? Data,
           let trackMeta = try? JSONDecoder().decode(TransferTrackMetadata.self, from: encodedData) {
            print("Transfer delivered to watch queue for track: \(trackMeta.title)")
        }
    }

    func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: Error?) {
        guard let event = userInfoTransfer.userInfo[Self.syncEventKey] as? String,
              event == Self.radioStationAddedEvent,
              let stationID = userInfoTransfer.userInfo[Self.radioStationIDKey] as? String else {
            return
        }

        if let error {
            setRadioTransferStatus(.error(error.localizedDescription), for: stationID)
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

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let event = userInfo[Self.syncEventKey] as? String else {
            return
        }

        switch event {
        case Self.trackSyncedEvent:
            guard let trackID = trackID(from: userInfo) else { return }
            print("Watch confirmed synced track: \(trackID.uuidString)")
            markTrackAsSynced(trackID)
        case Self.trackRemovedEvent:
            guard let trackID = trackID(from: userInfo) else { return }
            print("Watch confirmed removed track: \(trackID.uuidString)")
            markTrackAsRemovedFromWatch(trackID)
        case Self.radioStationSyncedEvent:
            guard let stationID = userInfo[Self.radioStationIDKey] as? String else { return }
            print("Watch confirmed synced radio station: \(stationID)")
            setRadioTransferStatus(.sent, for: stationID)
        default:
            break
        }
    }

    private func trackID(from userInfo: [String: Any]) -> UUID? {
        guard let trackIDString = userInfo[Self.syncTrackIDKey] as? String else {
            return nil
        }
        return UUID(uuidString: trackIDString)
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        applySyncedTrackIDs(from: applicationContext)
    }

}
