import SwiftUI

struct RadioListView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @ObservedObject var stationStore: UserRadioStationStore
    @ObservedObject var connectivityManager: WatchConnectivityManager

    @State private var showingAddStation = false

    private var radioStations: [RadioStation] {
        RadioCatalog.stations(adding: stationStore.stations)
    }

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Radio")

            VStack(spacing: 0) {
                ForEach(radioStations) { station in
                    RadioStationListRow(
                        station: station,
                        audioPlayerManager: audioPlayerManager,
                        stationStore: stationStore,
                        connectivityManager: connectivityManager
                    )

                    IPodSeparator()
                }
            }

            Spacer()
        }
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddStation = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(IPodTheme.textPrimary)
                }
                .accessibilityLabel("Añadir emisora")
            }
        }
        .sheet(isPresented: $showingAddStation) {
            AddRadioStationView(stationStore: stationStore)
        }
    }
}

private struct RadioStationListRow: View {
    let station: RadioStation
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    @ObservedObject var stationStore: UserRadioStationStore
    @ObservedObject var connectivityManager: WatchConnectivityManager

    private var transferStatus: TransferStatus {
        connectivityManager.radioTransferStatusByStationId[station.id] ?? .idle
    }

    var body: some View {
        HStack(spacing: 4) {
            NavigationLink(
                destination: RadioPlayerView(
                    station: station,
                    audioPlayerManager: audioPlayerManager
                )
            ) {
                IPodMenuRow(
                    label: station.name,
                    icon: "antenna.radiowaves.left.and.right",
                    showChevron: !station.isUserAdded
                )
            }
            .buttonStyle(IPodButtonStyle())

            if station.isUserAdded {
                Button {
                    connectivityManager.transferRadioStationToWatch(station)
                } label: {
                    Image(systemName: transferButtonIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(transferButtonColor)
                        .frame(width: 34, height: 38)
                }
                .buttonStyle(.plain)
                .disabled(isTransferPending)
                .accessibilityLabel("Mandar al Apple Watch")

                Button {
                    stationStore.removeStation(id: station.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.red.opacity(0.86))
                        .frame(width: 34, height: 38)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Eliminar emisora")
            }
        }
    }

    private var isTransferPending: Bool {
        if case .queued = transferStatus {
            return true
        }
        if case .transferring = transferStatus {
            return true
        }
        return false
    }

    private var transferButtonIcon: String {
        switch transferStatus {
        case .idle:
            return "applewatch"
        case .queued, .transferring:
            return "clock"
        case .sent:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private var transferButtonColor: Color {
        switch transferStatus {
        case .sent:
            return .green
        case .error:
            return .red
        default:
            return IPodTheme.textPrimary
        }
    }
}

private struct AddRadioStationView: View {
    @ObservedObject var stationStore: UserRadioStationStore
    @Environment(\.dismiss) private var dismiss

    @State private var stationName = ""
    @State private var stationURL = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nombre")
                        .font(IPodTheme.font(13, weight: .bold))
                        .foregroundColor(IPodTheme.textPrimary)

                    TextField("Pure Ibiza", text: $stationName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("URL")
                        .font(IPodTheme.font(13, weight: .bold))
                        .foregroundColor(IPodTheme.textPrimary)

                    TextField("https://...", text: $stationURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(IPodTheme.font(12))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: saveStation) {
                    Label("Guardar", systemImage: "checkmark")
                        .font(IPodTheme.font(15, weight: .bold))
                        .foregroundColor(IPodTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.30))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(IPodTheme.separatorColor, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(20)
            .background(IPodTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("Nueva emisora")
            .navigationBarTitleDisplayMode(.inline)
            .tint(IPodTheme.textSecondary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func saveStation() {
        let trimmedName = stationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Introduce un nombre."
            return
        }

        guard let normalizedURL = RadioStation.normalizedStreamURL(from: stationURL) else {
            errorMessage = "Introduce una URL http o https valida."
            return
        }

        stationStore.addStation(name: trimmedName, streamURL: normalizedURL)
        dismiss()
    }
}

private struct RadioPlayerView: View {
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
        VStack(spacing: 18) {
            Spacer(minLength: 6)

            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 46, weight: .semibold))
                .foregroundColor(IPodTheme.textPrimary)

            VStack(spacing: 6) {
                Text(station.name)
                    .font(IPodTheme.font(24, weight: .bold))
                    .foregroundColor(IPodTheme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Live Radio")
                    .font(IPodTheme.font(14))
                    .foregroundColor(IPodTheme.textSecondary)
            }

            statusView
                .frame(maxWidth: 420)

            VStack(spacing: 10) {
                Button(action: togglePlayback) {
                    Label(playButtonLabel, systemImage: playButtonIcon)
                        .font(IPodTheme.font(15, weight: .bold))
                        .foregroundColor(playButtonForegroundColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(playButtonBackgroundColor)
                        )
                }
                .buttonStyle(.plain)

                Button(action: audioPlayerManager.stopAudio) {
                    Label("Detener", systemImage: "stop.fill")
                        .font(IPodTheme.font(15, weight: .bold))
                        .foregroundColor(IPodTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.24))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 360)

            Spacer(minLength: 28)
        }
        .padding(.horizontal, 24)
        .background(IPodTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: handleOnAppear)
        .onChange(of: audioPlayerManager.playbackErrorCode) { _, _ in
            attemptCompatibilityFallbackIfNeeded()
        }
    }

    private var playButtonForegroundColor: Color {
        currentErrorMessage != nil ? IPodTheme.textPrimary : .white
    }

    private var playButtonBackgroundColor: Color {
        currentErrorMessage != nil ? Color.white.opacity(0.24) : Color.black.opacity(0.52)
    }

    @ViewBuilder
    private var statusView: some View {
        if let errorMessage = currentErrorMessage {
            VStack(spacing: 8) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 30))
                    .foregroundColor(.red)
                Text("No se pudo conectar")
                    .font(IPodTheme.font(15, weight: .bold))
                    .foregroundColor(IPodTheme.textPrimary)
                Text(errorMessage)
                    .font(IPodTheme.font(13))
                    .foregroundColor(IPodTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        } else if isBufferingCurrentStation {
            VStack(spacing: 8) {
                ProgressView()
                Text("Conectando...")
                    .font(IPodTheme.font(15, weight: .bold))
                    .foregroundColor(IPodTheme.textPrimary)
                Text(usingCompatibilityFallback ? "Modo compatibilidad HTTP" : "Stream directo")
                    .font(IPodTheme.font(13))
                    .foregroundColor(IPodTheme.textSecondary)
            }
        } else if isCurrentStation && audioPlayerManager.isPlaying {
            VStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 34))
                    .foregroundColor(IPodTheme.textPrimary)
                Text("En directo")
                    .font(IPodTheme.font(15, weight: .bold))
                    .foregroundColor(IPodTheme.textSecondary)
                if usingCompatibilityFallback {
                    Text("Compatibilidad HTTP")
                        .font(IPodTheme.font(13))
                        .foregroundColor(IPodTheme.textSecondary)
                }
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "play.circle")
                    .font(.system(size: 34))
                    .foregroundColor(IPodTheme.textPrimary)
                Text("Listo")
                    .font(IPodTheme.font(15))
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
            NSURLErrorSecureConnectionFailed,
            NSURLErrorServerCertificateUntrusted,
            NSURLErrorServerCertificateHasBadDate,
            NSURLErrorServerCertificateNotYetValid,
            NSURLErrorServerCertificateHasUnknownRoot,
            NSURLErrorClientCertificateRejected,
            NSURLErrorCannotConnectToHost,
            NSURLErrorCannotFindHost,
            NSURLErrorNetworkConnectionLost,
            NSURLErrorResourceUnavailable,
            NSURLErrorAppTransportSecurityRequiresSecureConnection
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
