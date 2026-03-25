import SwiftUI

@main
struct RetroMusicWatchApp: App {
    @StateObject var audioPlayerManager = AudioPlayerManager()
    @StateObject var connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView(audioPlayerManager: audioPlayerManager, connectivityManager: connectivityManager)
        }
    }
}
