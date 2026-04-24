import SwiftUI

struct TrackPlayerView: View {
    @ObservedObject var player: AudioPlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(IPodTheme.textPrimary)
                        .padding(10)
                }
                Spacer()
                Text("Now Playing")
                    .font(IPodTheme.font(13, weight: .semibold))
                    .foregroundColor(IPodTheme.textSecondary)
                Spacer()
                Color.clear.frame(width: 38, height: 38)
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            IPodArtworkView(
                artworkData: player.currentTrackArtwork,
                fallbackSystemName: player.isLiveStreamPlayback
                    ? "dot.radiowaves.left.and.right"
                    : "music.note",
                fallbackColor: IPodTheme.textSecondary,
                cornerRadius: 10
            )
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: 300)
            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            .padding(.horizontal, 32)

            VStack(spacing: 4) {
                Text(player.currentTrackTitle.isEmpty ? "—" : player.currentTrackTitle)
                    .font(IPodTheme.font(18, weight: .bold))
                    .foregroundColor(IPodTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(subtitleText)
                    .font(IPodTheme.font(13))
                    .foregroundColor(IPodTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 24)

            IPodProgressBar(
                progress: player.currentProgress,
                currentTime: player.currentTime,
                totalDuration: player.totalDuration,
                isInteractive: !player.isLiveStreamPlayback
            ) { newProgress in
                player.seek(toProgress: newProgress)
            }
            .padding(.horizontal, 24)

            HStack(spacing: 28) {
                Button {
                    player.toggleShuffle()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(player.isShuffling ? .accentColor : IPodTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(player.isLiveStreamPlayback)
                .opacity(player.isLiveStreamPlayback ? 0.35 : 1)

                Button {
                    player.playPreviousTrack()
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(IPodTheme.textPrimary)
                }
                .buttonStyle(.plain)

                Button {
                    player.seekBackward(by: 30)
                } label: {
                    Image(systemName: "gobackward.30")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(IPodTheme.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(player.isLiveStreamPlayback)
                .opacity(player.isLiveStreamPlayback ? 0.35 : 1)

                Button {
                    player.playPause()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.pillBg)
                            .frame(width: 60, height: 60)
                        if player.isBuffering {
                            ProgressView().progressViewStyle(.circular).tint(.white)
                        } else {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    player.seekForward(by: 30)
                } label: {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(IPodTheme.textPrimary)
                }
                .buttonStyle(.plain)
                .disabled(player.isLiveStreamPlayback)
                .opacity(player.isLiveStreamPlayback ? 0.35 : 1)

                Button {
                    player.playNextTrack()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(IPodTheme.textPrimary)
                }
                .buttonStyle(.plain)

                Button {
                    player.cycleRepeatMode()
                } label: {
                    Image(systemName: repeatIconName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(player.repeatMode == .off ? IPodTheme.textSecondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(player.isLiveStreamPlayback)
                .opacity(player.isLiveStreamPlayback ? 0.35 : 1)
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
    }

    private var subtitleText: String {
        if player.isLiveStreamPlayback {
            return player.playbackErrorMessage ?? "Live Radio"
        }
        return player.currentTrackArtist.isEmpty ? "Unknown Artist" : player.currentTrackArtist
    }

    private var repeatIconName: String {
        switch player.repeatMode {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}
