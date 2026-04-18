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

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: folder.name)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(folder.audioTracks) { track in
                        HStack(spacing: 0) {
                            // Track row content (tappable area - future: navigate to now playing)
                            IPodTrackRow(track: track)

                            // Transfer status indicator
                            transferStatusView(for: track.id)
                                .padding(.trailing, 12)
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
                        .foregroundColor(IPodTheme.highlightStart)
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
        .onChange(of: connectivityManager.lastTransferError) { _, error in
            if let error = error {
                errorMessage = error
                showErrorAlert = true
                connectivityManager.lastTransferError = nil
            }
        }
    }

    @ViewBuilder
    private func transferStatusView(for trackId: UUID) -> some View {
        let status = connectivityManager.transferStatusByTrackId[trackId]

        switch status {
        case .queued:
            Label("En cola", systemImage: "clock")
                .font(.caption2)
                .foregroundColor(.orange)
        case .transferring:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Enviando")
                    .font(.caption2)
                    .foregroundColor(IPodTheme.highlightStart)
            }
        case .sent:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        case .idle, .none:
            Button(action: { transferTrackToWatch(track: folder.audioTracks.first { $0.id == trackId }!) }) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .foregroundColor(IPodTheme.highlightStart)
            }
        }
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

    private func deleteTrack(at offsets: IndexSet) {
        let tracksToDelete = offsets.compactMap { index in
            folder.audioTracks.indices.contains(index) ? folder.audioTracks[index] : nil
        }

        for track in tracksToDelete {
            removeFileIfExists(at: track.filePath)
        }

        folder.audioTracks.remove(atOffsets: offsets)
    }

    private func transferTrackToWatch(track: AudioTrack) {
        connectivityManager.transferFileToWatch(fileURL: track.filePath, audioTrack: track)
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

