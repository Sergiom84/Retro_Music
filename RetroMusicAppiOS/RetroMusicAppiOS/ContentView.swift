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
                    let session = WCSession.default
                    Text("Watch: \(session.isPaired ? "✅" : "❌") | Installed: \(session.isWatchAppInstalled ? "✅" : "❌") | Reachable: \(session.isReachable ? "✅" : "❌")")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                        .padding(4)
                }
                #endif

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

                    NavigationLink(destination: RadioListView()) {
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
                        IPodMenuRow(label: "Settings", icon: "gearshape.fill")
                    }
                    .buttonStyle(IPodButtonStyle())

                    IPodSeparator()
                }

                Spacer()
            }
            .background(IPodTheme.backgroundGradient.ignoresSafeArea())
            .navigationBarHidden(true)
        }
        .onAppear(perform: loadFolders)
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
                if !decoded.isEmpty {
                    folders = decoded
                    return
                }
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

        folders = [Folder(id: UUID(), name: "My Music", audioTracks: [])]
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
