import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @ObservedObject var connectivityManager: WatchConnectivityManager
    var initialTrackIndex: Int

    private var tracks: [AudioTrack] {
        connectivityManager.receivedAudioTracks
    }

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
        ScrollView {
            VStack(spacing: 6) {
                // Track counter
                Text("\(audioPlayerManager.currentTrackIndex + 1) of \(tracks.count)")
                    .font(IPodTheme.font(11))
                    .foregroundColor(IPodTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                // Artwork + metadata
                HStack(spacing: 8) {
                    Group {
                        if let artworkData = currentTrack.artworkData, let artwork = UIImage(data: artworkData) {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            Image(systemName: "music.note.list")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(4)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentTrack.title)
                            .font(IPodTheme.font(14, weight: .bold))
                            .foregroundColor(IPodTheme.textPrimary)
                            .lineLimit(2)
                        Text(currentTrack.artist ?? "Unknown Artist")
                            .font(IPodTheme.font(11))
                            .foregroundColor(IPodTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()
                }
                .padding(.horizontal, 8)

                // Progress bar
                IPodProgressBar(
                    progress: audioPlayerManager.currentProgress,
                    currentTime: audioPlayerManager.currentTime,
                    totalDuration: audioPlayerManager.totalDuration
                )
                .padding(.horizontal, 8)

                // Playback controls
                HStack(spacing: 12) {
                    Button(action: { audioPlayerManager.playPreviousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(IPodTheme.textPrimary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { audioPlayerManager.seekBackward(by: 15) }) {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 14))
                            .foregroundColor(IPodTheme.textPrimary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { audioPlayerManager.playPause() }) {
                        Image(systemName: audioPlayerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(IPodTheme.textPrimary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { audioPlayerManager.seekForward(by: 30) }) {
                        Image(systemName: "goforward.30")
                            .font(.system(size: 14))
                            .foregroundColor(IPodTheme.textPrimary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { audioPlayerManager.playNextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(IPodTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 6)

                // Shuffle / Repeat
                HStack(spacing: 16) {
                    Button(action: { audioPlayerManager.toggleShuffle() }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 12))
                            .foregroundColor(audioPlayerManager.isShuffleEnabled ? IPodTheme.highlightStart : IPodTheme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Button(action: { audioPlayerManager.cycleRepeatMode() }) {
                        Image(systemName: audioPlayerManager.repeatMode.icon)
                            .font(.system(size: 12))
                            .foregroundColor(audioPlayerManager.repeatMode.isActive ? IPodTheme.highlightStart : IPodTheme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Delete track
                    Button(action: {
                        let trackToDelete = currentTrack
                        audioPlayerManager.playNextTrack()
                        connectivityManager.deleteTrack(trackToDelete)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
            }
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .onAppear {
            guard tracks.indices.contains(initialTrackIndex) else { return }
            let track = tracks[initialTrackIndex]

            // Only start playback if it's a different track or not playing
            if audioPlayerManager.currentTrackIndex == initialTrackIndex && audioPlayerManager.isPlaying {
                return
            }

            audioPlayerManager.setPlaylist(tracks, startAt: initialTrackIndex)
            audioPlayerManager.playAudio(
                url: track.filePath,
                title: track.title,
                artist: track.artist ?? "",
                artworkData: track.artworkData
            )
        }
        .navigationTitle("Now Playing")
        .navigationBarTitleDisplayMode(.inline)
    }
}
