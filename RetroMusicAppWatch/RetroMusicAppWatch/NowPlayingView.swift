import SwiftUI
import AVFoundation
#if !os(watchOS)
import MediaPlayer
#endif

struct NowPlayingView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    var tracks: [AudioTrack]
    var initialTrackIndex: Int

    var body: some View {
        let currentTrack = currentDisplayTrack

        VStack(spacing: 8) {
            Text("\(displayTrackNumber) de \(tracks.count)")
                .font(IPodTheme.font(11))
                .foregroundColor(IPodTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)

            HStack(spacing: 8) {
                IPodArtworkView(
                    artworkData: currentTrack.artworkData,
                    fallbackSystemName: currentTrack.isPodcast ? "mic.fill" : "music.note.list",
                    cornerRadius: 6
                )
                .frame(width: 62, height: 62)
                .shadow(color: .black.opacity(0.08), radius: 2, y: 1)

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

            Text("Vol \(Int((audioPlayerManager.playbackVolume * 100).rounded()))%")
                .font(IPodTheme.font(10))
                .foregroundColor(IPodTheme.textSecondary)

            HStack(spacing: 8) {
                Button {
                    audioPlayerManager.setPlaybackVolume(audioPlayerManager.playbackVolume - 0.1)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)

                Button {
                    audioPlayerManager.setPlaybackVolume(audioPlayerManager.playbackVolume + 0.1)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(IPodTheme.textPrimary)

            IPodProgressBar(
                progress: audioPlayerManager.currentProgress,
                currentTime: audioPlayerManager.currentTime,
                totalDuration: audioPlayerManager.totalDuration,
                isInteractive: showsInteractiveProgress
            ) { newProgress in
                audioPlayerManager.seek(toProgress: newProgress)
            }
            .padding(.horizontal, 8)

            HStack(spacing: 12) {
                Button(action: { audioPlayerManager.playPreviousTrack() }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(IPodTheme.textPrimary)
                }
                .buttonStyle(PlainButtonStyle())

                Button(action: { audioPlayerManager.seekBackward(by: 30) }) {
                    Image(systemName: "gobackward.30")
                        .font(.system(size: 14))
                        .foregroundColor(IPodTheme.textPrimary)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!canSeekManually)
                .opacity(canSeekManually ? 1 : 0.45)

                Button(action: togglePlayback) {
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
                .disabled(!canSeekManually)
                .opacity(canSeekManually ? 1 : 0.45)

                Button(action: { audioPlayerManager.playNextTrack() }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 16))
                        .foregroundColor(IPodTheme.textPrimary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.vertical, 6)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    private var displayTrackNumber: Int {
        let idx = audioPlayerManager.currentTrackIndex
        if tracks.indices.contains(idx) {
            return idx + 1
        }
        return initialTrackIndex + 1
    }

    private var canSeekManually: Bool {
        !audioPlayerManager.isLiveStreamPlayback && audioPlayerManager.totalDuration > 0
    }

    private var showsInteractiveProgress: Bool {
        !audioPlayerManager.isLiveStreamPlayback
    }

    private func togglePlayback() {
        if audioPlayerManager.isPlaying {
            audioPlayerManager.pause()
        } else {
            audioPlayerManager.resume()
        }
    }
}
