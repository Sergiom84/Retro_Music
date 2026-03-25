import Foundation
import AVFoundation
import MediaPlayer

#if os(watchOS)
import WatchKit
#else
import UIKit
#endif

enum RepeatMode: Int, CaseIterable {
    case off = 0
    case all = 1
    case one = 2

    var icon: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var isActive: Bool { self != .off }
}

class AudioPlayerManager: NSObject, ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentProgress: Double = 0.0
    @Published var currentTime: TimeInterval = 0.0
    @Published var totalDuration: TimeInterval = 0.0
    @Published var currentTrackTitle: String = ""
    @Published var currentTrackArtist: String = ""
    @Published var currentTrackArtwork: UIImage? = nil
    @Published var currentTrackIndex: Int = -1
    @Published var isShuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off

    private var player: AVPlayer?
    private var timeObserverToken: Any?
    private var currentTrackURL: URL?
    private var playerItemObservation: NSObjectProtocol?

    var playlist: [AudioTrack] = []
    private var shuffledIndices: [Int] = []
    private var shufflePosition: Int = 0

    var onTrackChanged: ((Int) -> Void)?

    override init() {
        super.init()
        setupAudioSession()
        setupRemoteCommandCenter()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }

    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set audio session: \(error.localizedDescription)")
        }
    }

    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self, !self.isPlaying else { return .commandFailed }
            self.playPause()
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self, self.isPlaying else { return .commandFailed }
            self.playPause()
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.playPause()
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNextTrack()
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPreviousTrack()
            return .success
        }

        commandCenter.skipForwardCommand.preferredIntervals = [30]
        commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            self?.seekForward(by: 30)
            return .success
        }

        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            self?.seekBackward(by: 15)
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let progress = self.totalDuration > 0 ? positionEvent.positionTime / self.totalDuration : 0
            self.seek(toProgress: progress)
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        var nowPlayingInfo = [String: Any]()
        nowPlayingInfo[MPMediaItemPropertyTitle] = currentTrackTitle
        nowPlayingInfo[MPMediaItemPropertyArtist] = currentTrackArtist
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = totalDuration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = player?.rate ?? 0

        if let artwork = currentTrackArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }

    // MARK: - Shuffle

    func toggleShuffle() {
        isShuffleEnabled.toggle()
        if isShuffleEnabled {
            regenerateShuffleOrder()
        }
    }

    private func regenerateShuffleOrder() {
        guard !playlist.isEmpty else { return }
        shuffledIndices = Array(0..<playlist.count).filter { $0 != currentTrackIndex }.shuffled()
        shuffledIndices.insert(currentTrackIndex, at: 0)
        shufflePosition = 0
    }

    func cycleRepeatMode() {
        let allCases = RepeatMode.allCases
        let nextIndex = (repeatMode.rawValue + 1) % allCases.count
        repeatMode = allCases[nextIndex]
    }

    // MARK: - Playlist management

    func setPlaylist(_ tracks: [AudioTrack], startAt index: Int) {
        playlist = tracks
        currentTrackIndex = index
        if isShuffleEnabled {
            regenerateShuffleOrder()
        }
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
        if isShuffleEnabled {
            shufflePosition += 1
            if shufflePosition < shuffledIndices.count {
                playTrack(at: shuffledIndices[shufflePosition])
            } else if repeatMode == .all {
                regenerateShuffleOrder()
                if let first = shuffledIndices.first {
                    playTrack(at: first)
                }
            } else {
                stopAudio()
            }
            return
        }

        let nextIndex = currentTrackIndex + 1
        if playlist.indices.contains(nextIndex) {
            playTrack(at: nextIndex)
        } else if repeatMode == .all {
            playTrack(at: 0)
        } else {
            stopAudio()
        }
    }

    func playPreviousTrack() {
        if currentTime > 3 {
            seek(toProgress: 0)
            return
        }

        if isShuffleEnabled {
            shufflePosition -= 1
            if shufflePosition >= 0, shuffledIndices.indices.contains(shufflePosition) {
                playTrack(at: shuffledIndices[shufflePosition])
            } else {
                shufflePosition = 0
                seek(toProgress: 0)
            }
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

    func playAudio(url: URL, title: String, artist: String, artworkData: Data?) {
        if currentTrackURL == url, let existingPlayer = player {
            currentTrackTitle = title
            currentTrackArtist = artist
            currentTrackArtwork = artworkData.flatMap(UIImage.init)

            if !isPlaying {
                existingPlayer.play()
                isPlaying = true
            }

            updateNowPlayingInfo()
            return
        }

        stopAudio()

        currentTrackURL = url
        currentTrackTitle = title
        currentTrackArtist = artist
        currentTrackArtwork = artworkData.flatMap(UIImage.init)

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Observe end of track
        playerItemObservation = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handleTrackFinished()
        }

        playerItem.asset.loadValuesAsynchronously(forKeys: ["duration"]) { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                let seconds = CMTimeGetSeconds(playerItem.asset.duration)
                self.totalDuration = seconds.isFinite ? max(0, seconds) : 0
                self.updateNowPlayingInfo()
            }
        }

        timeObserverToken = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            guard let self = self else { return }
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            self.currentTime = seconds
            self.currentProgress = self.totalDuration > 0 ? self.currentTime / self.totalDuration : 0.0
            self.updateNowPlayingInfo()
        }

        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    private func handleTrackFinished() {
        if repeatMode == .one {
            seek(toProgress: 0)
            player?.play()
            isPlaying = true
            return
        }
        playNextTrack()
    }

    func playPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        updateNowPlayingInfo()
    }

    func pause() {
        guard let player = player, isPlaying else { return }
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func seek(toProgress progress: Double) {
        guard let player = player, totalDuration > 0 else { return }

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
        guard player != nil else { return }
        let newTime = totalDuration > 0
            ? min(totalDuration, currentTime + seconds)
            : max(0, currentTime + seconds)
        let progress = totalDuration > 0 ? newTime / totalDuration : 0
        seek(toProgress: progress)
    }

    func seekBackward(by seconds: Double) {
        guard player != nil else { return }
        let newTime = max(0, currentTime - seconds)
        let progress = totalDuration > 0 ? newTime / totalDuration : 0
        seek(toProgress: progress)
    }

    func stopAudio() {
        if let observation = playerItemObservation {
            NotificationCenter.default.removeObserver(observation)
            playerItemObservation = nil
        }
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        currentProgress = 0.0
        currentTime = 0.0
        totalDuration = 0.0
        currentTrackURL = nil
        currentTrackTitle = ""
        currentTrackArtist = ""
        currentTrackArtwork = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Interruptions

    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        if type == .began {
            if isPlaying {
                player?.pause()
                isPlaying = false
                updateNowPlayingInfo()
            }
        } else if type == .ended {
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume), !isPlaying, currentTrackURL != nil {
                    player?.play()
                    isPlaying = true
                    updateNowPlayingInfo()
                }
            }
        }
    }

    deinit {
        if let observation = playerItemObservation {
            NotificationCenter.default.removeObserver(observation)
        }
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        NotificationCenter.default.removeObserver(self)
    }
}
