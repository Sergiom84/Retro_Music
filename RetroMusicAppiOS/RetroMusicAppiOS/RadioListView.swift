import SwiftUI

struct RadioListView: View {
    @ObservedObject var audioPlayerManager: AudioPlayerManager
    private let radioStations = RadioCatalog.stations

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Radio")

            VStack(spacing: 0) {
                ForEach(radioStations) { station in
                    NavigationLink(
                        destination: RadioPlayerView(
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
        .navigationBarTitleDisplayMode(.inline)
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
