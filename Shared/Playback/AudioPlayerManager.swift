import Foundation
import AVFoundation
#if !os(watchOS)
import MediaPlayer
#endif

class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var isBuffering: Bool = false
    @Published var currentProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var totalDuration: TimeInterval = 0.0
    @Published var currentTrackTitle: String = ""
    @Published var currentTrackArtist: String = ""
    @Published var currentTrackArtwork: Data? = nil
    @Published var currentTrackIndex: Int = -1
    @Published var playbackErrorMessage: String?
    @Published var playbackErrorCode: Int?
    @Published var playbackErrorDomain: String?
    @Published private(set) var isLiveStreamPlayback: Bool = false
    @Published private(set) var playbackVolume: Double = 1.0

    private struct PlaybackRequest {
        let url: URL
        let title: String
        let artist: String
        let artworkData: Data?
        let isLiveStream: Bool
    }

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var currentTrackURL: URL?
    private var activePlaybackRequest: PlaybackRequest?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var playerItemLikelyToKeepUpObserver: NSKeyValueObservation?
    private var playerItemBufferEmptyObserver: NSKeyValueObservation?
    private var playbackStalledObserver: NSObjectProtocol?
    private var failedToPlayToEndObserver: NSObjectProtocol?
    private var liveStreamRetryWorkItem: DispatchWorkItem?
    private var liveStreamRetryAttempts = 0
    private let maxLiveStreamRetryAttempts = 3
    private let liveStreamRetryBaseDelay: TimeInterval = 1.5
    private static let playbackVolumeDefaultsKey = "retromusic_watch_playback_volume"

    var playlist: [AudioTrack] = []
    var onTrackChanged: ((Int) -> Void)?

    override init() {
        if UserDefaults.standard.object(forKey: Self.playbackVolumeDefaultsKey) != nil {
            playbackVolume = UserDefaults.standard.double(forKey: Self.playbackVolumeDefaultsKey)
        }
        super.init()
        setupAudioSession()
        #if !os(watchOS)
        setupRemoteCommandCenter()
        #endif
        #if !os(macOS)
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        #endif
        NotificationCenter.default.addObserver(self, selector: #selector(playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: nil)
    }

    private func setupAudioSession() {
        #if !os(macOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            #if os(watchOS)
            try audioSession.setCategory(
                .playback,
                mode: .default,
                options: []
            )
            #else
            try audioSession.setCategory(
                .playback,
                mode: .default,
                policy: .longFormAudio,
                options: []
            )
            #endif
        } catch {
            print("Failed to set audio session: \(error.localizedDescription)")
        }
        #endif
    }

    private func activateAudioSessionIfNeeded(then completion: @escaping (Bool) -> Void) {
        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            completion(true)
        } catch {
            handleAudioSessionActivationFailure(error)
            completion(false)
        }
        #else
        completion(true)
        #endif
    }

    private func deactivateAudioSessionIfNeeded() {
        #if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Failed to deactivate audio session: \(error.localizedDescription)")
        }
        #endif
    }

    private func handleAudioSessionActivationFailure(_ error: Error) {
        let nsError = error as NSError
        print("Failed to activate audio session: \(error.localizedDescription)")
        isPlaying = false
        isBuffering = false
        playbackErrorCode = nsError.code
        playbackErrorDomain = nsError.domain
        playbackErrorMessage = error.localizedDescription
    }

    private func applyPlaybackVolume() {
        player?.volume = Float(playbackVolume)
    }

    private func setupRemoteCommandCenter() {
        #if !os(watchOS)
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [unowned self] _ in
            if !self.isPlaying {
                self.resume()
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.addTarget { [unowned self] _ in
            if self.isPlaying {
                self.pause()
                return .success
            }
            return .commandFailed
        }

        commandCenter.togglePlayPauseCommand.addTarget { [unowned self] _ in
            self.playPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [unowned self] _ in
            self.playNextTrack()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [unowned self] _ in
            self.playPreviousTrack()
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [unowned self] _ in
            self.seekForward(by: 30)
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [30]
        commandCenter.skipBackwardCommand.addTarget { [unowned self] _ in
            self.seekBackward(by: 30)
            return .success
        }
        #endif
    }

    private func updateNowPlayingInfo() {
        #if !os(watchOS)
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrackTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = currentTrackArtist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = totalDuration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        #endif
    }

    // MARK: - Playlist management

    func setPlaylist(_ tracks: [AudioTrack], startAt index: Int) {
        playlist = tracks
        currentTrackIndex = index
    }

    func playTrack(at index: Int) {
        guard playlist.indices.contains(index) else { return }
        currentTrackIndex = index
        let track = playlist[index]
        playAudio(
            url: track.filePath,
            title: track.title,
            artist: track.artist ?? "",
            artworkData: track.artworkData
        )
        onTrackChanged?(index)
    }

    func playNextTrack() {
        let nextIndex = currentTrackIndex + 1
        guard playlist.indices.contains(nextIndex) else {
            stopAudio()
            return
        }
        playTrack(at: nextIndex)
    }

    func playPreviousTrack() {
        if currentTime > 3 {
            seek(toProgress: 0)
            return
        }
        let prevIndex = currentTrackIndex - 1
        guard playlist.indices.contains(prevIndex) else {
            seek(toProgress: 0)
            return
        }
        playTrack(at: prevIndex)
    }

    // MARK: - Playback

    func playAudio(url: URL, title: String, artist: String, artworkData: Data?, isLiveStream: Bool = false) {
        startPlayback(
            url: url,
            title: title,
            artist: artist,
            artworkData: artworkData,
            isLiveStream: isLiveStream,
            resetLiveStreamRetryAttempts: true
        )
    }

    private func startPlayback(
        url: URL,
        title: String,
        artist: String,
        artworkData: Data?,
        isLiveStream: Bool,
        resetLiveStreamRetryAttempts: Bool
    ) {
        if resetLiveStreamRetryAttempts {
            liveStreamRetryAttempts = 0
        }
        cancelLiveStreamRetry()

        let playbackRequest = PlaybackRequest(
            url: url,
            title: title,
            artist: artist,
            artworkData: artworkData,
            isLiveStream: isLiveStream
        )

        if currentTrackURL == url,
           let existingPlayer = player,
           existingPlayer.currentItem?.status != .failed,
           playbackErrorMessage == nil {
            activePlaybackRequest = playbackRequest
            currentTrackTitle = title
            currentTrackArtist = artist
            currentTrackArtwork = artworkData
            isLiveStreamPlayback = isLiveStream

            if !isPlaying {
                activateAudioSessionIfNeeded { [weak self] activated in
                    guard let self = self, activated, self.player === existingPlayer else { return }
                    existingPlayer.play()
                    self.isPlaying = true
                    self.isBuffering = isLiveStream
                    self.applyPlaybackVolume()
                    self.updateNowPlayingInfo()
                }
            }

            applyPlaybackVolume()
            updateNowPlayingInfo()
            return
        }

        stopAudio(clearPlaybackRequest: false)

        activePlaybackRequest = playbackRequest
        currentTrackURL = url
        currentTrackTitle = title
        currentTrackArtist = artist
        currentTrackArtwork = artworkData
        playbackErrorMessage = nil
        playbackErrorCode = nil
        playbackErrorDomain = nil
        isLiveStreamPlayback = isLiveStream
        isBuffering = isLiveStream

        let playerItem = AVPlayerItem(url: url)
        if isLiveStream {
            playerItem.preferredForwardBufferDuration = 6
            playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        }
        observePlayerItem(playerItem)
        let newPlayer = AVPlayer(playerItem: playerItem)
        newPlayer.automaticallyWaitsToMinimizeStalling = true
        player = newPlayer
        applyPlaybackVolume()

        if isLiveStream {
            totalDuration = 0
            currentProgress = 0
        } else {
            Task { [weak self, playerItem] in
                do {
                    let duration = try await playerItem.asset.load(.duration)
                    let seconds = CMTimeGetSeconds(duration)
                    let strongSelf = self
                    await MainActor.run {
                        guard let self = strongSelf, self.player?.currentItem === playerItem else { return }
                        self.totalDuration = seconds.isFinite ? max(0, seconds) : 0
                        print("✅ Track duration loaded: \(self.totalDuration)s for '\(title)'")
                        self.updateNowPlayingInfo()
                    }
                } catch {
                    print("❌ Failed to load duration for '\(title)': \(error.localizedDescription)")
                    let strongSelf = self
                    await MainActor.run {
                        guard let self = strongSelf, self.player?.currentItem === playerItem else { return }
                        self.totalDuration = 0
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }

        timeObserverToken = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = CMTimeGetSeconds(time)
            self.currentProgress = (self.totalDuration > 0 && !self.isLiveStreamPlayback) ? self.currentTime / self.totalDuration : 0.0
            self.updateNowPlayingInfo()
        }

        activateAudioSessionIfNeeded { [weak self] activated in
            guard let self = self, activated, self.player === newPlayer else { return }
            newPlayer.play()
            self.isPlaying = true
            self.isBuffering = isLiveStream
            self.updateNowPlayingInfo()
        }
        updateNowPlayingInfo()
    }

    func playPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            isBuffering = false
        } else {
            if playbackErrorMessage != nil {
                player.seek(to: .zero)
            }
            playbackErrorMessage = nil
            activateAudioSessionIfNeeded { [weak self] activated in
                guard let self = self, activated, self.player === player else { return }
                player.play()
                self.isPlaying = true
                self.isBuffering = self.isLiveStreamPlayback
                self.updateNowPlayingInfo()
            }
        }
        updateNowPlayingInfo()
    }

    func resume() {
        guard let player = player, !isPlaying else { return }
        if playbackErrorMessage != nil {
            player.seek(to: .zero)
            playbackErrorMessage = nil
            playbackErrorCode = nil
            playbackErrorDomain = nil
        }
        activateAudioSessionIfNeeded { [weak self] activated in
            guard let self = self, activated, self.player === player else { return }
            player.play()
            self.isPlaying = true
            self.isBuffering = self.isLiveStreamPlayback
            self.applyPlaybackVolume()
            self.updateNowPlayingInfo()
        }
    }

    func pause() {
        guard let player = player, isPlaying else { return }
        player.pause()
        isPlaying = false
        isBuffering = false
        updateNowPlayingInfo()
    }

    func seek(toProgress progress: Double) {
        guard let player = player, totalDuration > 0, !isLiveStreamPlayback else { return }
        let clampedProgress = min(max(progress, 0.0), 1.0)
        let targetTime = totalDuration * clampedProgress
        let time = CMTime(seconds: targetTime, preferredTimescale: 600)
        player.seek(to: time) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = targetTime
            self.currentProgress = clampedProgress
            self.updateNowPlayingInfo()
        }
    }

    func seekForward(by seconds: Double) {
        guard let player = player, !isLiveStreamPlayback else { return }
        let newTime = totalDuration > 0
            ? min(totalDuration, currentTime + seconds)
            : max(0, currentTime + seconds)
        let time = CMTime(seconds: newTime, preferredTimescale: 1)
        player.seek(to: time) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = newTime
            self.currentProgress = self.totalDuration > 0 ? self.currentTime / self.totalDuration : 0
            self.updateNowPlayingInfo()
        }
    }

    func seekBackward(by seconds: Double) {
        guard let player = player, !isLiveStreamPlayback else { return }
        let newTime = max(0, currentTime - seconds)
        let time = CMTime(seconds: newTime, preferredTimescale: 1)
        player.seek(to: time) { [weak self] _ in
            guard let self = self else { return }
            self.currentTime = newTime
            self.currentProgress = self.totalDuration > 0 ? self.currentTime / self.totalDuration : 0
            self.updateNowPlayingInfo()
        }
    }

    func isCurrentTrack(url: URL) -> Bool {
        currentTrackURL == url
    }

    func setPlaybackVolume(_ newValue: Double) {
        let clampedValue = min(max(newValue, 0.0), 1.0)
        guard abs(clampedValue - playbackVolume) > 0.001 else { return }

        playbackVolume = clampedValue
        UserDefaults.standard.set(clampedValue, forKey: Self.playbackVolumeDefaultsKey)
        applyPlaybackVolume()
    }

    func stopAudio() {
        stopAudio(clearPlaybackRequest: true)
    }

    private func stopAudio(clearPlaybackRequest: Bool) {
        cancelLiveStreamRetry()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        removePlayerItemObservers()
        player?.pause()
        player = nil
        deactivateAudioSessionIfNeeded()
        isPlaying = false
        isBuffering = false
        currentProgress = 0.0
        currentTime = 0.0
        totalDuration = 0.0
        currentTrackURL = nil
        isLiveStreamPlayback = false
        currentTrackTitle = ""
        currentTrackArtist = ""
        currentTrackArtwork = nil
        playbackErrorMessage = nil
        playbackErrorCode = nil
        playbackErrorDomain = nil
        if clearPlaybackRequest {
            activePlaybackRequest = nil
            liveStreamRetryAttempts = 0
        }
        #if !os(watchOS)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        #endif
    }

    private func observePlayerItem(_ item: AVPlayerItem) {
        removePlayerItemObservers()

        playerItemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    self.isBuffering = false
                    self.playbackErrorMessage = nil
                    self.playbackErrorCode = nil
                    self.playbackErrorDomain = nil
                case .failed:
                    self.handlePlaybackFailure(item.error as NSError?)
                case .unknown:
                    if self.isLiveStreamPlayback {
                        self.isBuffering = true
                    }
                @unknown default:
                    break
                }
            }
        }

        playerItemLikelyToKeepUpObserver = item.observe(\.isPlaybackLikelyToKeepUp, options: [.initial, .new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self, self.isLiveStreamPlayback else { return }
                self.isBuffering = !item.isPlaybackLikelyToKeepUp
            }
        }

        playerItemBufferEmptyObserver = item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self = self, self.isLiveStreamPlayback else { return }
                if item.isPlaybackBufferEmpty {
                    self.isBuffering = true
                }
            }
        }

        playbackStalledObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isLiveStreamPlayback else { return }
            self.isBuffering = true
        }

        failedToPlayToEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? NSError
            self?.handlePlaybackFailure(error)
        }
    }

    private func removePlayerItemObservers() {
        playerItemStatusObserver = nil
        playerItemLikelyToKeepUpObserver = nil
        playerItemBufferEmptyObserver = nil

        if let playbackStalledObserver = playbackStalledObserver {
            NotificationCenter.default.removeObserver(playbackStalledObserver)
            self.playbackStalledObserver = nil
        }

        if let failedToPlayToEndObserver = failedToPlayToEndObserver {
            NotificationCenter.default.removeObserver(failedToPlayToEndObserver)
            self.failedToPlayToEndObserver = nil
        }
    }

    private func handlePlaybackFailure(_ error: NSError?) {
        player?.pause()
        isPlaying = false
        isBuffering = false
        playbackErrorMessage = error?.localizedDescription ?? "No se pudo reproducir el stream."
        playbackErrorCode = error?.code
        playbackErrorDomain = error?.domain

        if isLiveStreamPlayback,
           !shouldDeferToCompatibilityFallback(error),
           scheduleLiveStreamRetryIfNeeded() {
            updateNowPlayingInfo()
            return
        }

        updateNowPlayingInfo()
    }

    private func cancelLiveStreamRetry() {
        liveStreamRetryWorkItem?.cancel()
        liveStreamRetryWorkItem = nil
    }

    @discardableResult
    private func scheduleLiveStreamRetryIfNeeded() -> Bool {
        guard let request = activePlaybackRequest, request.isLiveStream else {
            return false
        }

        guard liveStreamRetryWorkItem == nil else {
            return true
        }

        guard liveStreamRetryAttempts < maxLiveStreamRetryAttempts else {
            return false
        }

        liveStreamRetryAttempts += 1
        let retryDelay = liveStreamRetryBaseDelay * Double(liveStreamRetryAttempts)

        playbackErrorMessage = nil
        playbackErrorCode = nil
        playbackErrorDomain = nil
        isBuffering = true

        let retryWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.startPlayback(
                url: request.url,
                title: request.title,
                artist: request.artist,
                artworkData: request.artworkData,
                isLiveStream: request.isLiveStream,
                resetLiveStreamRetryAttempts: false
            )
        }

        liveStreamRetryWorkItem = retryWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay, execute: retryWorkItem)
        return true
    }

    private func shouldDeferToCompatibilityFallback(_ error: NSError?) -> Bool {
        guard error?.domain == NSURLErrorDomain, let code = error?.code else {
            return false
        }

        let compatibilityFallbackCodes: Set<Int> = [
            NSURLErrorSecureConnectionFailed,
            NSURLErrorServerCertificateUntrusted,
            NSURLErrorServerCertificateHasBadDate,
            NSURLErrorServerCertificateNotYetValid,
            NSURLErrorServerCertificateHasUnknownRoot,
            NSURLErrorClientCertificateRejected,
            NSURLErrorAppTransportSecurityRequiresSecureConnection
        ]

        return compatibilityFallbackCodes.contains(code)
    }

    // MARK: - Interruptions

    #if !os(macOS)
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .began {
            if isPlaying {
                player?.pause()
                isPlaying = false
                isBuffering = false
                updateNowPlayingInfo()
            }
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume), !isPlaying, currentTrackURL != nil {
                    guard let player else { return }
                    activateAudioSessionIfNeeded { [weak self] activated in
                        guard let self = self, activated, self.player === player else { return }
                        player.play()
                        self.isPlaying = true
                        self.isBuffering = self.isLiveStreamPlayback
                        self.applyPlaybackVolume()
                        self.updateNowPlayingInfo()
                    }
                }
            }
        }
    }
    #endif

    @objc func playerDidFinishPlaying(note: Notification) {
        if isLiveStreamPlayback {
            player?.pause()
            isPlaying = false
            isBuffering = true
            playbackErrorMessage = "La emisora se interrumpio."
            playbackErrorCode = nil
            playbackErrorDomain = nil
            _ = scheduleLiveStreamRetryIfNeeded()
            updateNowPlayingInfo()
            return
        }
        playNextTrack()
    }

    deinit {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        removePlayerItemObservers()
        NotificationCenter.default.removeObserver(self)
    }
}
