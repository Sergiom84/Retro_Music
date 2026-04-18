import SwiftUI

@main
struct RetroMusicAppWatch_Watch_AppApp: App {
    @StateObject var audioPlayerManager = AudioPlayerManager()
    @StateObject var connectivityManager = WatchConnectivityManager()

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentViewWatch(audioPlayerManager: audioPlayerManager, connectivityManager: connectivityManager)
            }
        }
    }
}
