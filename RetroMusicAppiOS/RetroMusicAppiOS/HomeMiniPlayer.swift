import SwiftUI

struct HomeMiniPlayer: View {
    @ObservedObject var player: AudioPlayerManager
    @State private var showingFullScreen = false

    var body: some View {
        if !player.currentTrackTitle.isEmpty {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.divider)
                    .frame(height: 1)

                HStack(spacing: 10) {
                    Button {
                        showingFullScreen = true
                    } label: {
                        HStack(spacing: 10) {
                            IPodArtworkView(
                                artworkData: player.currentTrackArtwork,
                                fallbackSystemName: player.isLiveStreamPlayback
                                    ? "dot.radiowaves.left.and.right"
                                    : "music.note",
                                fallbackColor: .textSec,
                                cornerRadius: 4
                            )
                            .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.currentTrackTitle)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.textPri)
                                    .lineLimit(1)

                                Text(subtitleText)
                                    .font(.system(size: 11))
                                    .foregroundColor(.textSec)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    if !player.isLiveStreamPlayback {
                        Button {
                            player.playPreviousTrack()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPri)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        player.playPause()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.pillBg)
                                .frame(width: 34, height: 34)
                            if player.isBuffering {
                                ProgressView().progressViewStyle(.circular).tint(.white)
                            } else {
                                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    if !player.isLiveStreamPlayback {
                        Button {
                            player.playNextTrack()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.textPri)
                                .frame(width: 30, height: 30)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        showingFullScreen = true
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.textSec)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(IPodTheme.titleBarGradient)
            }
            .fullScreenCover(isPresented: $showingFullScreen) {
                TrackPlayerView(player: player)
            }
        }
    }

    private var subtitleText: String {
        if player.isLiveStreamPlayback {
            return player.playbackErrorMessage ?? "Live Radio"
        }
        return player.currentTrackArtist.isEmpty ? "Ahora sonando" : player.currentTrackArtist
    }
}
