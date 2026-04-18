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

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var currentTrackURL: URL?
    private var playerItemStatusObserver: NSKeyValueObservation?
    private var playerItemLikelyToKeepUpObserver: NSKeyValueObservation?
    private var playerItemBufferEmptyObserver: NSKeyValueObservation?
    private var playbackStalledObserver: NSObjectProtocol?
    private var failedToPlayToEndObserver: NSObjectProtocol?

    var playlist: [AudioTrack] = []
    var onTrackChanged: ((Int) -> Void)?

    override init() {
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
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set audio session: \(error.localizedDescription)")
        }
        #endif
    }

    private func setupRemoteCommandCenter() {
        #if !os(watchOS)
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [unowned self] _ in
            if !self.isPlaying {
                self.playPause()
                return .success
            }
            return .commandFailed
        }

        commandCenter.pauseCommand.addTarget { [unowned self] _ in
            if self.isPlaying {
                self.playPause()
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

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [unowned self] _ in
            self.seekBackward(by: 15)
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
        if currentTrackURL == url,
           let existingPlayer = player,
           existingPlayer.currentItem?.status != .failed,
           playbackErrorMessage == nil {
            currentTrackTitle = title
            currentTrackArtist = artist
            currentTrackArtwork = artworkData
            isLiveStreamPlayback = isLiveStream

            if !isPlaying {
                existingPlayer.play()
                isPlaying = true
                isBuffering = isLiveStream
            }

            updateNowPlayingInfo()
            return
        }

        stopAudio()

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
        observePlayerItem(playerItem)
        player = AVPlayer(playerItem: playerItem)

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

        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func playPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
            isBuffering = false
        } else {
            if playbackErrorMessage != nil {
                player.seek(to: .zero)
            }
            playbackErrorMessage = nil
            player.play()
            isBuffering = isLiveStreamPlayback
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
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

    func stopAudio() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        removePlayerItemObservers()
        player?.pause()
        player = nil
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
        updateNowPlayingInfo()
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
                    player?.play()
                    isPlaying = true
                    isBuffering = isLiveStreamPlayback
                    updateNowPlayingInfo()
                }
            }
        }
    }
    #endif

    @objc func playerDidFinishPlaying(note: Notification) {
        if isLiveStreamPlayback {
            stopAudio()
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
