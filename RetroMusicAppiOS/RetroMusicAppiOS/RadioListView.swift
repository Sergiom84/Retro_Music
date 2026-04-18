import SwiftUI
#if canImport(SafariServices)
import SafariServices
#endif

struct RadioListView: View {
    private let radioStations = RadioCatalog.stations

    var body: some View {
        VStack(spacing: 0) {
            IPodTitleBar(title: "Radio")

            VStack(spacing: 0) {
                ForEach(radioStations) { station in
                    NavigationLink(destination: RadioPlayerView(station: station)) {
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

    var body: some View {
        VStack(spacing: 0) {
            #if canImport(SafariServices)
            SafariView(url: station.webPlayerURL ?? station.streamURL)
                .ignoresSafeArea(edges: .bottom)
            #else
            Text("Radio no disponible en este dispositivo")
                .multilineTextAlignment(.center)
                .padding()
            #endif
        }
        .navigationTitle(station.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if canImport(SafariServices)
private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif
