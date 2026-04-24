import SwiftUI

struct ContentView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @ObservedObject var connectivityManager: WatchConnectivityManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Title bar
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
                                tracks: connectivityManager.receivedAudioTracks,
                                initialTrackIndex: index
                            )
                        ) {
                            IPodTrackRow(track: track)
                        }
                        .buttonStyle(IPodButtonStyle())

                        Rectangle()
                            .fill(IPodTheme.separatorColor)
                            .frame(height: 0.5)
                            .padding(.leading, 12)
                    }
                }
            }
            .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(audioPlayerManager: AudioPlayerManager(), connectivityManager: WatchConnectivityManager())
    }
}
