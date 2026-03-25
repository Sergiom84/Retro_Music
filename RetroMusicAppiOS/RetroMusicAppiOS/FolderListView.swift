import SwiftUI

struct FolderListView: View {
    @Binding var folders: [Folder]
    @Binding var showDocumentPicker: Bool
    @Binding var selectedFileURL: URL?
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    @State private var showingAddFolderAlert = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Folders")

            List {
                ForEach($folders) { $folder in
                    NavigationLink(destination: AudioTrackListView(
                        folder: $folder,
                        showDocumentPicker: $showDocumentPicker,
                        selectedFileURL: $selectedFileURL,
                        connectivityManager: connectivityManager,
                        audioPlayerManager: audioPlayerManager,
                        allFolders: $folders
                    )) {
                        IPodMenuRow(label: folder.name, icon: "folder.fill")
                    }
                    .buttonStyle(IPodButtonStyle())
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteFolders)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddFolderAlert = true }) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(IPodTheme.highlightStart)
                }
            }
        }
        .alert("New Folder", isPresented: $showingAddFolderAlert) {
            TextField("Folder Name", text: $newFolderName)
            Button("Add") {
                addFolder()
            }
            Button("Cancel", role: .cancel) { newFolderName = "" }
        }
    }

    private func addFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            newFolderName = ""
            return
        }

        // Avoid duplicates
        let nameExists = folders.contains { $0.name.lowercased() == trimmed.lowercased() }
        let finalName = nameExists ? "\(trimmed) (\(folders.count + 1))" : trimmed

        folders.append(Folder(id: UUID(), name: finalName, audioTracks: []))
        newFolderName = ""
    }

    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            guard folders.indices.contains(index) else { continue }
            let folder = folders[index]
            // Clean up associated audio files
            for track in folder.audioTracks {
                try? FileManager.default.removeItem(at: track.filePath)
            }
        }
        folders.remove(atOffsets: offsets)
    }
}
