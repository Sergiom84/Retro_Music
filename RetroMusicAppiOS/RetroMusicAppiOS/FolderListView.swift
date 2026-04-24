import SwiftUI

struct FolderListView: View {
    @Binding var folders: [Folder]
    @Binding var selectedFolder: Folder?
    @Binding var showDocumentPicker: Bool
    @Binding var selectedFileURL: URL?
    @ObservedObject var connectivityManager: WatchConnectivityManager

    @State private var showingAddFolderAlert = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Playlists")

            ScrollView {
                VStack(spacing: 0) {
                    ForEach($folders) { $folder in
                        NavigationLink(destination: AudioTrackListView(
                            folder: $folder,
                            showDocumentPicker: $showDocumentPicker,
                            selectedFileURL: $selectedFileURL,
                            connectivityManager: connectivityManager
                        )) {
                            IPodMenuRow(label: folder.name, icon: "folder.fill")
                        }
                        .buttonStyle(IPodButtonStyle())

                        IPodSeparator()
                    }
                }
            }

            Spacer()
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddFolderAlert = true }) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(IPodTheme.highlightStart)
                }
            }
        }
        .alert("New Playlist", isPresented: $showingAddFolderAlert) {
            TextField("Playlist Name", text: $newFolderName)
            Button("Add") {
                let playlistName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                let newFolder = Folder(
                    id: UUID(),
                    name: playlistName.isEmpty ? "Untitled Playlist" : playlistName,
                    audioTracks: []
                )
                folders.append(newFolder)
                newFolderName = ""
            }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
    }
}
