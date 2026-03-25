import SwiftUI

struct iOSNowPlayingView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    var tracks: [AudioTrack]
    var initialTrackIndex: Int

    @Environment(\.dismiss) private var dismiss

    private var currentTrack: AudioTrack {
        let idx = audioPlayerManager.currentTrackIndex
        if tracks.indices.contains(idx) {
            return tracks[idx]
        }
        if tracks.indices.contains(initialTrackIndex) {
            return tracks[initialTrackIndex]
        }
        return tracks[0]
    }

    var body: some View {
        VStack(spacing: 0) {
            // iPod screen area
            VStack(spacing: 0) {
                IPodTitleBar(title: "Now Playing")

                VStack(spacing: 12) {
                    // Track counter
                    Text("\(audioPlayerManager.currentTrackIndex + 1) of \(tracks.count)")
                        .font(IPodTheme.font(12))
                        .foregroundColor(IPodTheme.textSecondary)

                    // Artwork
                    Group {
                        if let artworkData = currentTrack.artworkData, let uiImage = UIImage(data: artworkData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(white: 0.85))
                                Image(systemName: "music.note")
                                    .font(.system(size: 50))
                                    .foregroundColor(Color(white: 0.6))
                            }
                        }
                    }
                    .frame(maxWidth: 200, maxHeight: 200)
                    .cornerRadius(12)
                    .shadow(radius: 4)

                    // Track info
                    VStack(spacing: 4) {
                        Text(currentTrack.title)
                            .font(IPodTheme.font(17, weight: .bold))
                            .foregroundColor(IPodTheme.textPrimary)
                            .lineLimit(1)
                        Text(currentTrack.artist ?? "Unknown Artist")
                            .font(IPodTheme.font(14))
                            .foregroundColor(IPodTheme.textSecondary)
                            .lineLimit(1)
                        if let album = currentTrack.album {
                            Text(album)
                                .font(IPodTheme.font(12))
                                .foregroundColor(IPodTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }

                    // Progress bar
                    IPodProgressBar(
                        progress: audioPlayerManager.currentProgress,
                        currentTime: audioPlayerManager.currentTime,
                        totalDuration: audioPlayerManager.totalDuration
                    )
                    .padding(.horizontal, 20)

                    // Shuffle / Repeat indicators
                    HStack(spacing: 20) {
                        Button(action: { audioPlayerManager.toggleShuffle() }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 14))
                                .foregroundColor(audioPlayerManager.isShuffleEnabled ? IPodTheme.highlightStart : IPodTheme.textSecondary)
                        }

                        Spacer()

                        Button(action: { audioPlayerManager.cycleRepeatMode() }) {
                            Image(systemName: audioPlayerManager.repeatMode.icon)
                                .font(.system(size: 14))
                                .foregroundColor(audioPlayerManager.repeatMode.isActive ? IPodTheme.highlightStart : IPodTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 12)
            }
            .background(IPodTheme.backgroundGradient)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            .padding(.top, 8)

            Spacer(minLength: 16)

            // Click Wheel
            IPodClickWheel(
                onMenu: { dismiss() },
                onPrevious: { audioPlayerManager.playPreviousTrack() },
                onNext: { audioPlayerManager.playNextTrack() },
                onPlayPause: { audioPlayerManager.playPause() },
                onSelect: { audioPlayerManager.playPause() }
            )
            .padding(.bottom, 20)
        }
        .background(Color(white: 0.92).ignoresSafeArea())
        .navigationBarHidden(true)
        .onAppear {
            if audioPlayerManager.currentTrackIndex != initialTrackIndex || !audioPlayerManager.isPlaying {
                audioPlayerManager.setPlaylist(tracks, startAt: initialTrackIndex)
                let track = tracks[initialTrackIndex]
                audioPlayerManager.playAudio(
                    url: track.filePath,
                    title: track.title,
                    artist: track.artist ?? "",
                    artworkData: track.artworkData
                )
            }
        }
    }
}
