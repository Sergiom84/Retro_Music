import SwiftUI
import AVFoundation
#if !os(watchOS)
import MediaPlayer
#endif

struct NowPlayingView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @ObservedObject var connectivityManager: WatchConnectivityManager
    var tracks: [AudioTrack]
    var initialTrackIndex: Int

    var body: some View {
        let currentTrack = currentDisplayTrack
        let trackNumber = audioPlayerManager.currentTrackIndex + 1
        let totalTracks = tracks.count

        ScrollView {
            VStack(spacing: 6) {
                // Track counter "X of Y"
                Text("\(trackNumber) of \(totalTracks)")
                    .font(IPodTheme.font(11))
                    .foregroundColor(IPodTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                // Artwork + metadata side by side
                HStack(spacing: 8) {
                    // Artwork (UIKit not available as explicit module on watchOS with Xcode 26)
                    Group {
                        Image(systemName: "music.note.list")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.gray)
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(4)

                    // Track info
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

                // iPod progress bar
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
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { audioPlayerManager.seekBackward(by: 15) }) {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 14))
                            .foregroundColor(IPodTheme.textPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { audioPlayerManager.playPause() }) {
                        Image(systemName: audioPlayerManager.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(IPodTheme.textPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { audioPlayerManager.seekForward(by: 30) }) {
                        Image(systemName: "goforward.30")
                            .font(.system(size: 14))
                            .foregroundColor(IPodTheme.textPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: { audioPlayerManager.playNextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 16))
                            .foregroundColor(IPodTheme.textPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.vertical, 6)
            }
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .onAppear {
            audioPlayerManager.setPlaylist(tracks, startAt: initialTrackIndex)
            let track = tracks[initialTrackIndex]
            audioPlayerManager.playAudio(
                url: track.filePath,
                title: track.title,
                artist: track.artist ?? "",
                artworkData: track.artworkData
            )
        }
        .navigationTitle("Now Playing")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var currentDisplayTrack: AudioTrack {
        let idx = audioPlayerManager.currentTrackIndex
        if tracks.indices.contains(idx) {
            return tracks[idx]
        }
        return tracks[initialTrackIndex]
    }
}
