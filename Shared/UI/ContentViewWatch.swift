import SwiftUI

#if os(watchOS)
struct ContentViewWatch: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @ObservedObject var connectivityManager: WatchConnectivityManager

    private var musicTracks: [AudioTrack] {
        connectivityManager.receivedAudioTracks.filter { !$0.isPodcast }
    }

    private var podcastTracks: [AudioTrack] {
        connectivityManager.receivedAudioTracks.filter(\.isPodcast)
    }

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "RetroMusic")

            VStack(spacing: 0) {
                NavigationLink(
                    destination: WatchLibrarySectionView(
                        title: "Música",
                        tracks: musicTracks,
                        audioPlayerManager: audioPlayerManager,
                        connectivityManager: connectivityManager
                    )
                ) {
                    IPodMenuRow(label: "Música", icon: "music.note")
                }
                .buttonStyle(IPodButtonStyle())

                IPodSeparator()

                NavigationLink(
                    destination: WatchLibrarySectionView(
                        title: "Podcast",
                        tracks: podcastTracks,
                        audioPlayerManager: audioPlayerManager,
                        connectivityManager: connectivityManager
                    )
                ) {
                    IPodMenuRow(label: "Podcast", icon: "mic.fill")
                }
                .buttonStyle(IPodButtonStyle())

                IPodSeparator()

                NavigationLink(destination: WatchRadioListView(audioPlayerManager: audioPlayerManager)) {
                    IPodMenuRow(label: "Radio", icon: "dot.radiowaves.left.and.right")
                }
                .buttonStyle(IPodButtonStyle())

                IPodSeparator()
            }

            Spacer()
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
    }
}

private struct WatchLibrarySectionView: View {
    let title: String
    let tracks: [AudioTrack]
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @State private var editingTrack: AudioTrack?

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: title)

            if tracks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 30))
                        .foregroundColor(IPodTheme.textSecondary)
                    Text("Sin contenido")
                        .font(IPodTheme.font(13, weight: .bold))
                        .foregroundColor(IPodTheme.textPrimary)
                    Text("Transfiere desde iPhone")
                        .font(IPodTheme.font(11))
                        .foregroundColor(IPodTheme.textSecondary)
                }
                .padding(.top, 20)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            HStack(spacing: 6) {
                                NavigationLink(
                                    destination: NowPlayingView(
                                        audioPlayerManager: audioPlayerManager,
                                        tracks: tracks,
                                        initialTrackIndex: index
                                    )
                                ) {
                                    IPodTrackRow(track: track)
                                }
                                .buttonStyle(IPodButtonStyle())

                                Button {
                                    editingTrack = track
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(IPodTheme.textSecondary)
                                        .padding(.trailing, 10)
                                }
                                .buttonStyle(.plain)
                            }

                            IPodSeparator()
                        }
                    }
                }
            }
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .sheet(item: $editingTrack) { track in
            WatchTrackEditorView(
                track: track,
                connectivityManager: connectivityManager,
                audioPlayerManager: audioPlayerManager
            )
        }
    }
}

private struct WatchTrackEditorView: View {
    let track: AudioTrack
    @ObservedObject var connectivityManager: WatchConnectivityManager
    @ObservedObject var audioPlayerManager: AudioPlayerManager

    @Environment(\.dismiss) private var dismiss
    @State private var editedTitle: String
    @State private var showingDeleteConfirmation = false

    init(track: AudioTrack, connectivityManager: WatchConnectivityManager, audioPlayerManager: AudioPlayerManager) {
        self.track = track
        self.connectivityManager = connectivityManager
        self.audioPlayerManager = audioPlayerManager
        _editedTitle = State(initialValue: track.title)
    }

    var body: some View {
        VStack(spacing: 10) {
            IPodTitleBar(title: "Editar")

            VStack(alignment: .leading, spacing: 8) {
                Text("Nombre")
                    .font(IPodTheme.font(11, weight: .bold))
                    .foregroundColor(IPodTheme.textPrimary)

                TextField("Título", text: $editedTitle)
                    .textInputAutocapitalization(.words)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                    )
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            Button("Guardar") {
                let trimmedTitle = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedTitle.isEmpty else { return }
                connectivityManager.renameTrack(id: track.id, newTitle: trimmedTitle)
                if audioPlayerManager.isCurrentTrack(url: track.filePath) {
                    audioPlayerManager.currentTrackTitle = trimmedTitle
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)

            Button("Eliminar", role: .destructive) {
                showingDeleteConfirmation = true
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding(.bottom, 8)
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .confirmationDialog("Eliminar pista", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                if audioPlayerManager.isCurrentTrack(url: track.filePath) {
                    audioPlayerManager.stopAudio()
                }
                connectivityManager.deleteTrack(id: track.id)
                dismiss()
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Esta acción borrará el archivo del reloj.")
        }
    }
}

private struct WatchRadioListView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    private let stations = RadioCatalog.stations

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Radio")

            VStack(spacing: 0) {
                ForEach(stations) { station in
                    NavigationLink(
                        destination: WatchRadioPlayerView(
                            station: station,
                            audioPlayerManager: audioPlayerManager
                        )
                    ) {
                        IPodMenuRow(label: station.name, icon: "antenna.radiowaves.left.and.right")
                    }
                    .buttonStyle(IPodButtonStyle())

                    IPodSeparator()
                }
            }

            Spacer()
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
    }
}

private struct WatchRadioPlayerView: View {
    let station: RadioStation
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @State private var attemptedCompatibilityFallback = false
    @State private var usingCompatibilityFallback = false

    private var isCurrentStation: Bool {
        audioPlayerManager.isLiveStreamPlayback && audioPlayerManager.currentTrackTitle == station.name
    }

    private var currentErrorMessage: String? {
        guard isCurrentStation else { return nil }
        return audioPlayerManager.playbackErrorMessage
    }

    private var isBufferingCurrentStation: Bool {
        isCurrentStation && audioPlayerManager.isBuffering
    }

    private var playButtonLabel: String {
        if currentErrorMessage != nil {
            return "Reintentar"
        }
        return isCurrentStation && audioPlayerManager.isPlaying ? "Pausar" : "Reproducir"
    }

    private var playButtonIcon: String {
        if currentErrorMessage != nil {
            return "arrow.clockwise"
        }
        return isCurrentStation && audioPlayerManager.isPlaying ? "pause.fill" : "play.fill"
    }

    var body: some View {
        VStack(spacing: 10) {
            Spacer()

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 28))
                .foregroundColor(IPodTheme.textPrimary)

            Text(station.name)
                .font(IPodTheme.font(15, weight: .bold))
                .foregroundColor(IPodTheme.textPrimary)
                .multilineTextAlignment(.center)

            Text("Vol \(Int((audioPlayerManager.playbackVolume * 100).rounded()))%")
                .font(IPodTheme.font(10))
                .foregroundColor(IPodTheme.textSecondary)

            HStack(spacing: 8) {
                Button {
                    audioPlayerManager.setPlaybackVolume(audioPlayerManager.playbackVolume - 0.1)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.plain)

                Button {
                    audioPlayerManager.setPlaybackVolume(audioPlayerManager.playbackVolume + 0.1)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.plain)
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(IPodTheme.textPrimary)

            statusView

            Button(action: togglePlayback) {
                HStack(spacing: 6) {
                    Image(systemName: playButtonIcon)
                    Text(playButtonLabel)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)

            Button("Detener") {
                audioPlayerManager.stopAudio()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(station.name)
        .onAppear {
            handleOnAppear()
        }
        .onChange(of: audioPlayerManager.playbackErrorCode) { _, _ in
            attemptCompatibilityFallbackIfNeeded()
        }
    }

    @ViewBuilder
    private var statusView: some View {
        if let errorMessage = currentErrorMessage {
            VStack(spacing: 6) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 24))
                    .foregroundColor(.red)
                Text("No se pudo conectar")
                    .font(IPodTheme.font(11, weight: .bold))
                    .foregroundColor(IPodTheme.textPrimary)
                Text(errorMessage)
                    .font(IPodTheme.font(10))
                    .foregroundColor(IPodTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        } else if isBufferingCurrentStation {
            VStack(spacing: 6) {
                ProgressView()
                Text("Conectando...")
                    .font(IPodTheme.font(11, weight: .bold))
                    .foregroundColor(IPodTheme.textPrimary)
                Text(usingCompatibilityFallback ? "Modo compatibilidad HTTP" : "Usa la red del Apple Watch")
                    .font(IPodTheme.font(10))
                    .foregroundColor(IPodTheme.textSecondary)
            }
        } else if isCurrentStation && audioPlayerManager.isPlaying {
            VStack(spacing: 4) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 26))
                    .symbolEffect(.variableColor.iterative)
                Text("En directo")
                    .font(IPodTheme.font(11))
                    .foregroundColor(IPodTheme.textSecondary)
                if usingCompatibilityFallback {
                    Text("Compatibilidad HTTP")
                        .font(IPodTheme.font(10))
                        .foregroundColor(IPodTheme.textSecondary)
                }
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "play.circle")
                    .font(.system(size: 26))
                Text("Toca para reproducir")
                    .font(IPodTheme.font(11))
                    .foregroundColor(IPodTheme.textSecondary)
            }
        }
    }

    private func togglePlayback() {
        if isCurrentStation && audioPlayerManager.playbackErrorMessage == nil {
            if audioPlayerManager.isPlaying {
                audioPlayerManager.pause()
            } else {
                audioPlayerManager.resume()
            }
            return
        }

        playStation(useCompatibilityFallback: usingCompatibilityFallback)
    }

    private func handleOnAppear() {
        attemptedCompatibilityFallback = false
        usingCompatibilityFallback = false
        autoplayIfNeeded()
    }

    private func autoplayIfNeeded() {
        if isCurrentStation {
            if audioPlayerManager.playbackErrorMessage != nil {
                playStation(useCompatibilityFallback: usingCompatibilityFallback)
                return
            }
            if !audioPlayerManager.isPlaying {
                audioPlayerManager.resume()
            }
            return
        }

        playStation()
    }

    private func playStation(useCompatibilityFallback: Bool = false) {
        usingCompatibilityFallback = useCompatibilityFallback
        let selectedURL = useCompatibilityFallback ? (station.compatibilityStreamURL ?? station.streamURL) : station.streamURL
        audioPlayerManager.playAudio(
            url: selectedURL,
            title: station.name,
            artist: "Live Radio",
            artworkData: nil,
            isLiveStream: true
        )
    }

    private func attemptCompatibilityFallbackIfNeeded() {
        let networkFailureCodes: Set<Int> = [
            NSURLErrorSecureConnectionFailed,       // -1200
            NSURLErrorServerCertificateUntrusted,   // -1202
            NSURLErrorServerCertificateHasBadDate,  // -1201
            NSURLErrorServerCertificateNotYetValid, // -1204
            NSURLErrorServerCertificateHasUnknownRoot, // -1203
            NSURLErrorClientCertificateRejected,    // -1205
            NSURLErrorCannotConnectToHost,          // -1004
            NSURLErrorCannotFindHost,               // -1003
            NSURLErrorNetworkConnectionLost,        // -1005
            NSURLErrorResourceUnavailable,          // -1008
            NSURLErrorAppTransportSecurityRequiresSecureConnection // -1022
        ]

        guard isCurrentStation,
              !attemptedCompatibilityFallback,
              station.compatibilityStreamURL != nil,
              audioPlayerManager.playbackErrorDomain == NSURLErrorDomain,
              let code = audioPlayerManager.playbackErrorCode,
              networkFailureCodes.contains(code) else {
            return
        }

        attemptedCompatibilityFallback = true
        playStation(useCompatibilityFallback: true)
    }
}

struct ContentViewWatch_Previews: PreviewProvider {
    static var previews: some View {
        ContentViewWatch(
            audioPlayerManager: AudioPlayerManager(),
            connectivityManager: WatchConnectivityManager()
        )
    }
}
#endif
