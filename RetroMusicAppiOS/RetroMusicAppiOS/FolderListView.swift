import SwiftUI

struct FolderListView: View {
    @Binding var folders: [Folder]
    @Binding var selectedFolder: Folder?
    @Binding var showDocumentPicker: Bool
    @Binding var selectedFileURL: URL?
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    @State private var showingAddFolderAlert = false
    @State private var newFolderName = ""
    @State private var folderPendingRename: Folder?
    @State private var renamedFolderName = ""
    @State private var folderPendingDeletion: Folder?

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Playlists")

            ScrollView {
                VStack(spacing: 0) {
                    ForEach($folders) { $folder in
                        HStack(spacing: 0) {
                            NavigationLink(destination: AudioTrackListView(
                                folder: $folder,
                                showDocumentPicker: $showDocumentPicker,
                                selectedFileURL: $selectedFileURL,
                                connectivityManager: connectivityManager,
                                audioPlayerManager: audioPlayerManager
                            )) {
                                IPodMenuRow(label: folder.name, icon: "folder.fill")
                            }
                            .buttonStyle(IPodButtonStyle())

                            Menu {
                                Button {
                                    startRenaming(folder)
                                } label: {
                                    Label("Renombrar", systemImage: "pencil")
                                }

                                Button(role: .destructive) {
                                    folderPendingDeletion = folder
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundColor(IPodTheme.textSecondary)
                                    .frame(width: 44, height: 40)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Editar playlist")
                        }

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
                        .foregroundColor(IPodTheme.textPrimary)
                }
            }
        }
        .alert("Nueva playlist", isPresented: $showingAddFolderAlert) {
            TextField("Nombre", text: $newFolderName)
            Button("Guardar") {
                let playlistName = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                let newFolder = Folder(
                    id: UUID(),
                    name: playlistName.isEmpty ? "Playlist sin titulo" : playlistName,
                    audioTracks: []
                )
                folders.append(newFolder)
                newFolderName = ""
            }
            Button("Cancelar", role: .cancel) { newFolderName = "" }
        }
        .alert("Renombrar playlist", isPresented: renameAlertBinding()) {
            TextField("Nombre", text: $renamedFolderName)
            Button("Guardar") {
                saveRenamedFolder()
            }
            Button("Cancelar", role: .cancel) {
                resetRenameState()
            }
        } message: {
            Text("Cambia el nombre de la playlist.")
        }
        .alert("Eliminar playlist", isPresented: deleteAlertBinding(), presenting: folderPendingDeletion) { folder in
            Button("Eliminar", role: .destructive) {
                deleteFolder(folder)
            }
            Button("Cancelar", role: .cancel) {
                folderPendingDeletion = nil
            }
        } message: { folder in
            Text("Se eliminará \"\(folder.name)\" del iPhone.")
        }
    }

    private func startRenaming(_ folder: Folder) {
        folderPendingRename = folder
        renamedFolderName = folder.name
    }

    private func saveRenamedFolder() {
        let trimmedName = renamedFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let folder = folderPendingRename,
              let index = folders.firstIndex(where: { $0.id == folder.id }) else {
            return
        }

        folders[index].name = trimmedName
        resetRenameState()
    }

    private func deleteFolder(_ folder: Folder) {
        guard let index = folders.firstIndex(where: { $0.id == folder.id }) else {
            folderPendingDeletion = nil
            return
        }

        folders[index].audioTracks.forEach { removeFileIfExists(at: $0.filePath) }
        folders.remove(at: index)

        if selectedFolder?.id == folder.id {
            selectedFolder = nil
        }

        folderPendingDeletion = nil
    }

    private func renameAlertBinding() -> Binding<Bool> {
        Binding(
            get: { folderPendingRename != nil },
            set: { isPresented in
                if !isPresented {
                    resetRenameState()
                }
            }
        )
    }

    private func deleteAlertBinding() -> Binding<Bool> {
        Binding(
            get: { folderPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    folderPendingDeletion = nil
                }
            }
        )
    }

    private func resetRenameState() {
        folderPendingRename = nil
        renamedFolderName = ""
    }

    private func removeFileIfExists(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
