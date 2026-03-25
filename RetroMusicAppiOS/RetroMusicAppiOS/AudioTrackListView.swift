import SwiftUI
import UniformTypeIdentifiers

struct AudioTrackListView: View {
    @Binding var folder: Folder
    @Binding var showDocumentPicker: Bool
    @Binding var selectedFileURL: URL?
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @Binding var allFolders: [Folder]

    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showImportError = false
    @State private var importErrorMessage = ""
    @State private var isImporting = false
    @State private var navigateToNowPlaying = false
    @State private var selectedTrackIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: folder.name)

            List {
                ForEach(Array(folder.audioTracks.enumerated()), id: \.element.id) { index, track in
                    HStack(spacing: 0) {
                        Button {
                            selectedTrackIndex = index
                            audioPlayerManager.setPlaylist(folder.audioTracks, startAt: index)
                            audioPlayerManager.playTrack(at: index)
                            navigateToNowPlaying = true
                        } label: {
                            IPodTrackRow(track: track)
                        }
                        .buttonStyle(IPodButtonStyle())

                        transferStatusView(for: track.id)
                            .padding(.trailing, 12)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteTrack)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    // Send all to watch
                    if !folder.audioTracks.isEmpty {
                        Button {
                            for track in folder.audioTracks {
                                connectivityManager.transferFileToWatch(fileURL: track.filePath, audioTrack: track)
                            }
                        } label: {
                            Image(systemName: "applewatch.radiowaves.left.and.right")
                                .foregroundColor(IPodTheme.highlightStart)
                        }
                    }

                    Button(action: { showDocumentPicker = true }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(IPodTheme.highlightStart)
                    }
                }
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPicker(selectedFileURL: $selectedFileURL) { url in
                handlePickedAudio(url: url)
            }
        }
        .background(
            NavigationLink(
                destination: iOSNowPlayingView(
                    audioPlayerManager: audioPlayerManager,
                    tracks: folder.audioTracks,
                    initialTrackIndex: selectedTrackIndex
                ),
                isActive: $navigateToNowPlaying
            ) { EmptyView() }
        )
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
        .onChange(of: connectivityManager.lastTransferError) { error in
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
            Button {
                guard let track = folder.audioTracks.first(where: { $0.id == trackId }) else { return }
                connectivityManager.transferFileToWatch(fileURL: track.filePath, audioTrack: track)
            } label: {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .foregroundColor(IPodTheme.highlightStart)
            }
        }
    }

    private func handlePickedAudio(url: URL) {
        guard !isImporting else { return }
        isImporting = true

        guard let persistedURL = persistImportedAudio(from: url) else {
            importErrorMessage = "No se pudo guardar el archivo: \(url.lastPathComponent)"
            showImportError = true
            isImporting = false
            return
        }

        AudioMetadataExtractor.extractMetadata(from: persistedURL) { [self] metadata in
            defer { isImporting = false }

            guard let metadata = metadata else {
                importErrorMessage = "No se pudo leer los metadatos del archivo"
                showImportError = true
                return
            }

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
        }

        selectedFileURL = nil
    }

    private func deleteTrack(at offsets: IndexSet) {
        for index in offsets {
            guard folder.audioTracks.indices.contains(index) else { continue }
            let track = folder.audioTracks[index]
            try? FileManager.default.removeItem(at: track.filePath)
        }
        folder.audioTracks.remove(atOffsets: offsets)
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
}
