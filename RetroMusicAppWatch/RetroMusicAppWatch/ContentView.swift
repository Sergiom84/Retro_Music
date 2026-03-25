import SwiftUI

struct ContentView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @ObservedObject var connectivityManager: WatchConnectivityManager

    var body: some View {
        NavigationView {
            Group {
                if connectivityManager.receivedAudioTracks.isEmpty {
                    emptyState
                } else {
                    trackList
                }
            }
            .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("RetroMusic")
                .font(IPodTheme.font(15, weight: .bold))
                .foregroundColor(IPodTheme.textPrimary)

            Image(systemName: "music.note.house")
                .font(.system(size: 30))
                .foregroundColor(IPodTheme.textSecondary)
                .padding(.top, 8)

            Text("No tracks yet")
                .font(IPodTheme.font(13))
                .foregroundColor(IPodTheme.textSecondary)

            Text("Send music from iPhone")
                .font(IPodTheme.font(11))
                .foregroundColor(IPodTheme.textSecondary)
        }
    }

    private var trackList: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("RetroMusic")
                    .font(IPodTheme.font(15, weight: .bold))
                    .foregroundColor(IPodTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(IPodTheme.titleBarGradient)

                ForEach(Array(connectivityManager.receivedAudioTracks.enumerated()), id: \.element.id) { index, track in
                    NavigationLink(
                        destination: NowPlayingView(
                            audioPlayerManager: audioPlayerManager,
                            connectivityManager: connectivityManager,
                            initialTrackIndex: index
                        )
                    ) {
                        IPodTrackRow(track: track)
                    }
                    .buttonStyle(IPodButtonStyle())

                    IPodSeparator()
                }
            }
        }
    }
}
