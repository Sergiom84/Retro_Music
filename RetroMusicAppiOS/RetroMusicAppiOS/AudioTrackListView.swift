import SwiftUI
import UniformTypeIdentifiers

struct AudioTrackListView: View {
    @Binding var folder: Folder
    @Binding var showDocumentPicker: Bool
    @Binding var selectedFileURL: URL?
    @ObservedObject var connectivityManager: WatchConnectivityManager

    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var trackPendingRename: AudioTrack?
    @State private var renamedTitle: String = ""
    @State private var trackPendingDeletion: AudioTrack?

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: folder.name)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(folder.audioTracks) { track in
                        HStack(spacing: 0) {
                            IPodTrackRow(track: track)

                            transferStatusView(for: track)
                                .frame(width: 96, alignment: .trailing)

                            Menu {
                                Button {
                                    startRenaming(track)
                                } label: {
                                    Label("Renombrar", systemImage: "pencil")
                                }

                                Button {
                                    setPodcastFlag(track, isPodcast: !track.isPodcast)
                                } label: {
                                    Label(
                                        track.isPodcast ? "Marcar como música" : "Marcar como podcast",
                                        systemImage: track.isPodcast ? "music.note" : "mic.fill"
                                    )
                                }

                                Button(role: .destructive) {
                                    trackPendingDeletion = track
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundColor(IPodTheme.textSecondary)
                                    .padding(.horizontal, 12)
                            }
                        }
                        .background(Color.clear)

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
        #if !os(watchOS)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showDocumentPicker = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(IPodTheme.textPrimary)
                }
            }
        }
        #endif
        #if !os(watchOS)
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(selectedFileURL: $selectedFileURL) { url in
                handlePickedAudio(url: url)
            }
        }
        #endif
        .alert("Error de transferencia", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .alert("Error de importacion", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
        .alert("Renombrar pista", isPresented: renameAlertBinding()) {
            TextField("Título", text: $renamedTitle)
            Button("Guardar") {
                saveRenamedTrack()
            }
            Button("Cancelar", role: .cancel) {
                resetRenameState()
            }
        } message: {
            Text("Cambia el nombre que se muestra en la biblioteca del iPhone.")
        }
        .alert("Eliminar pista", isPresented: deleteAlertBinding(), presenting: trackPendingDeletion) { track in
            Button("Eliminar", role: .destructive) {
                deleteTrack(track)
            }
            Button("Cancelar", role: .cancel) {
                trackPendingDeletion = nil
            }
        } message: { track in
            Text("Se eliminará \"\(track.title)\" del iPhone.")
        }
        .onChange(of: connectivityManager.lastTransferError) { _, error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
                connectivityManager.lastTransferError = nil
            }
        }
    }

    @ViewBuilder
    private func transferStatusView(for track: AudioTrack) -> some View {
        let trackId = track.id
        let status = connectivityManager.transferStatusByTrackId[trackId]
        let isSynced = connectivityManager.isTrackSyncedToWatch(trackId)
        let progress = connectivityManager.transferProgressByTrackId[trackId]

        switch status {
        case .queued:
            transferProgressLabel(progress, fallbackText: "En cola", tint: .orange)
        case .transferring:
            transferProgressLabel(progress, fallbackText: "Enviando", tint: IPodTheme.textSecondary)
        case .sent:
            Label("En reloj", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
        case .error:
            Button(action: { transferTrackToWatch(track: track) }) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            }
        case .idle, .none:
            if isSynced {
                Label("En reloj", systemImage: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Button(action: { transferTrackToWatch(track: track) }) {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .foregroundColor(IPodTheme.textPrimary)
                }
            }
        }
    }

    private func transferProgressLabel(
        _ progress: TransferProgressSnapshot?,
        fallbackText: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            if let progress {
                ProgressView(value: progress.fractionCompleted, total: 1)
                    .progressViewStyle(.linear)
                    .tint(tint)
                    .frame(width: 58)

                Text(progressPrimaryText(progress))
                    .font(.caption2)
                    .foregroundColor(tint)

                if let etaText = progressETA(progress) {
                    Text(etaText)
                        .font(.caption2)
                        .foregroundColor(IPodTheme.textSecondary)
                }
            } else {
                Text(fallbackText)
                    .font(.caption2)
                    .foregroundColor(tint)
            }
        }
    }

    private func progressPrimaryText(_ progress: TransferProgressSnapshot) -> String {
        let percentage = Int((progress.fractionCompleted * 100).rounded())
        return "\(percentage)%"
    }

    private func progressETA(_ progress: TransferProgressSnapshot) -> String? {
        guard let eta = progress.estimatedTimeRemaining,
              eta.isFinite,
              eta > 0 else {
            return nil
        }

        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = eta >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2

        guard let formatted = formatter.string(from: eta) else { return nil }
        return "Restan \(formatted)"
    }

    private func handlePickedAudio(url: URL) {
        guard let persistedURL = persistImportedAudio(from: url) else {
            importErrorMessage = "No se pudo guardar el archivo: \(url.lastPathComponent)"
            showImportError = true
            return
        }

        AudioMetadataExtractor.extractMetadata(from: persistedURL) { metadata in
            DispatchQueue.main.async {
                if let metadata = metadata {
                    let newTrack = AudioTrack(
                        id: UUID(),
                        title: metadata.title,
                        artist: metadata.artist,
                        album: metadata.album,
                        artworkData: metadata.artworkData,
                        filePath: persistedURL,
                        duration: metadata.duration,
                        isPodcast: metadata.isPodcast
                    )
                    folder.audioTracks.append(newTrack)
                } else {
                    importErrorMessage = "No se pudo leer los metadatos del archivo"
                    showImportError = true
                }
            }
        }

        selectedFileURL = nil
    }

    private func transferTrackToWatch(track: AudioTrack) {
        connectivityManager.transferFileToWatch(fileURL: track.filePath, audioTrack: track)
    }

    private func startRenaming(_ track: AudioTrack) {
        trackPendingRename = track
        renamedTitle = track.title
    }

    private func saveRenamedTrack() {
        let trimmedTitle = renamedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty,
              let track = trackPendingRename,
              let index = folder.audioTracks.firstIndex(where: { $0.id == track.id }) else {
            return
        }

        folder.audioTracks[index].title = trimmedTitle
        resetRenameState()
    }

    private func setPodcastFlag(_ track: AudioTrack, isPodcast: Bool) {
        guard let index = folder.audioTracks.firstIndex(where: { $0.id == track.id }) else {
            return
        }

        folder.audioTracks[index].isPodcast = isPodcast
        connectivityManager.markTrackNeedsResync(track.id)
    }

    private func deleteTrack(_ track: AudioTrack) {
        guard let index = folder.audioTracks.firstIndex(where: { $0.id == track.id }) else {
            trackPendingDeletion = nil
            return
        }

        removeFileIfExists(at: folder.audioTracks[index].filePath)
        folder.audioTracks.remove(at: index)
        trackPendingDeletion = nil
    }

    private func renameAlertBinding() -> Binding<Bool> {
        Binding(
            get: { trackPendingRename != nil },
            set: { isPresented in
                if !isPresented {
                    resetRenameState()
                }
            }
        )
    }

    private func deleteAlertBinding() -> Binding<Bool> {
        Binding(
            get: { trackPendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    trackPendingDeletion = nil
                }
            }
        )
    }

    private func resetRenameState() {
        trackPendingRename = nil
        renamedTitle = ""
    }

    private func persistImportedAudio(from sourceURL: URL) -> URL? {
        let didAccessSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccessSecurityScope {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let destinationURL = documentsURL.appendingPathComponent("\(UUID().uuidString)_\(sourceURL.lastPathComponent)")

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Error copying imported audio: \(error.localizedDescription)")
            return nil
        }
    }

    private func removeFileIfExists(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
