import SwiftUI
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

struct ContentView: View {
    @State private var showDocumentPicker = false
    @State private var selectedFileURL: URL?
    @State private var folders: [Folder] = []
    @State private var selectedFolder: Folder? = nil

    @StateObject var connectivityManager = WatchConnectivityManager()
    @StateObject private var radioPlayerManager = AudioPlayerManager()
    @StateObject private var radioStationStore = UserRadioStationStore()
    @StateObject private var homeModel = HomeModel()

    private static var foldersFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return docs.appendingPathComponent("retromusic_folders.json")
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                IPodTitleBar(title: "RetroMusic")
                
                // Debug info - temporal
                #if DEBUG && os(iOS)
                if WCSession.isSupported() {
                    WatchConnectivityDebugView(status: connectivityManager.sessionStatus)
                }
                #endif

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HomeSectionsView(
                            homeModel: homeModel,
                            stationStore: radioStationStore,
                            allStations: RadioCatalog.stations(adding: radioStationStore.stations),
                            onResumeMusic: {},
                            onResumePodcast: {},
                            onPlayStation: { station in
                                radioPlayerManager.playAudio(
                                    url: station.streamURL,
                                    title: station.name,
                                    artist: "Live Radio",
                                    artworkData: nil,
                                    isLiveStream: true
                                )
                            }
                        )
                        .padding(.top, 12)
                    }
                }

                // Menu items
                VStack(spacing: 0) {
                    NavigationLink(
                        destination: FolderListView(
                            folders: $folders,
                            selectedFolder: $selectedFolder,
                            showDocumentPicker: $showDocumentPicker,
                            selectedFileURL: $selectedFileURL,
                            connectivityManager: connectivityManager
                        )
                    ) {
                        IPodMenuRow(label: "Music", icon: "music.note")
                    }
                    .buttonStyle(IPodButtonStyle())

                    IPodSeparator()

                    NavigationLink(
                        destination: RadioListView(
                            audioPlayerManager: radioPlayerManager,
                            stationStore: radioStationStore,
                            connectivityManager: connectivityManager
                        )
                    ) {
                        IPodMenuRow(label: "Radio", icon: "dot.radiowaves.left.and.right")
                    }
                    .buttonStyle(IPodButtonStyle())

                    IPodSeparator()

                    NavigationLink(
                        destination: FolderListView(
                            folders: $folders,
                            selectedFolder: $selectedFolder,
                            showDocumentPicker: $showDocumentPicker,
                            selectedFileURL: $selectedFileURL,
                            connectivityManager: connectivityManager
                        )
                    ) {
                        IPodMenuRow(label: "Podcasts", icon: "mic.fill")
                    }
                    .buttonStyle(IPodButtonStyle())
                }

                Spacer()
            }
            .background(IPodTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .tint(IPodTheme.textPrimary)
        .onAppear {
            connectivityManager.refreshSessionStatus()
            loadFolders()
        }
        .onChange(of: folders) { _, _ in
            saveFolders()
        }
    }

    // MARK: - Persistence (JSON file)

    private func saveFolders() {
        do {
            let data = try JSONEncoder().encode(folders)
            try data.write(to: Self.foldersFileURL, options: .atomic)
        } catch {
            print("Error saving folders: \(error.localizedDescription)")
        }
    }

    private func loadFolders() {
        if FileManager.default.fileExists(atPath: Self.foldersFileURL.path) {
            do {
                let data = try Data(contentsOf: Self.foldersFileURL)
                let decoded = try JSONDecoder().decode([Folder].self, from: data)
                folders = decoded
                return
            } catch {
                print("Error loading folders from JSON: \(error.localizedDescription)")
            }
        }

        if let savedData = UserDefaults.standard.data(forKey: "folders"),
           let decoded = try? JSONDecoder().decode([Folder].self, from: savedData),
           !decoded.isEmpty {
            folders = decoded
            UserDefaults.standard.removeObject(forKey: "folders")
            saveFolders()
            return
        }

        folders = [Folder(id: UUID(), name: "My Playlist", audioTracks: [])]
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

#if DEBUG && os(iOS)
private struct WatchConnectivityDebugView: View {
    let status: WatchSessionStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                DebugStatusBadge(label: "Watch", isOn: status.isPaired)
                DebugStatusBadge(label: "Installed", isOn: status.isWatchAppInstalled)
                DebugStatusBadge(label: "Reachable", isOn: status.isReachable)
            }

            Text("\(status.helpText) Sesion \(status.activationLabel).")
                .font(IPodTheme.font(10))
                .foregroundColor(IPodTheme.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.46))
    }
}

private struct DebugStatusBadge: View {
    let label: String
    let isOn: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isOn ? Color.green : Color.red)
                .frame(width: 7, height: 7)

            Text(label)
                .font(IPodTheme.font(10, weight: .semibold))
                .foregroundColor(IPodTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}
#endif
