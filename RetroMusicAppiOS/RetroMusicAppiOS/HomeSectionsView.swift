import SwiftUI

// MARK: - Color tokens

extension Color {
    static let textPri = Color(red: 0.039, green: 0.039, blue: 0.039)   // #0A0A0A
    static let textSec = Color.black.opacity(0.55)
    static let divider = Color.black.opacity(0.08)
    static let pillBg  = Color.black.opacity(0.55)
    static let rowBg   = Color(red: 0.902, green: 0.902, blue: 0.902)    // #E6E6E6
}

// MARK: - Home model

struct LastPlayedItem: Codable, Equatable {
    var title: String
    var subtitle: String
}

final class HomeModel: ObservableObject {
    @Published var lastPlayedMusic: LastPlayedItem? { didSet { save() } }
    @Published var lastPlayedPodcast: LastPlayedItem? { didSet { save() } }
    @Published var favoriteStationIDs: [String] { didSet { save() } }

    private struct Payload: Codable {
        var lastPlayedMusic: LastPlayedItem?
        var lastPlayedPodcast: LastPlayedItem?
        var favoriteStationIDs: [String]
    }

    private static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return docs.appendingPathComponent("retromusic_home.json")
    }

    init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let decoded = try? JSONDecoder().decode(Payload.self, from: data) {
            self.lastPlayedMusic = decoded.lastPlayedMusic
            self.lastPlayedPodcast = decoded.lastPlayedPodcast
            self.favoriteStationIDs = decoded.favoriteStationIDs
        } else {
            self.lastPlayedMusic = nil
            self.lastPlayedPodcast = nil
            self.favoriteStationIDs = [
                RadioCatalog.pureIbiza.id,
                RadioCatalog.globalRadio.id
            ]
        }
    }

    private func save() {
        let payload = Payload(
            lastPlayedMusic: lastPlayedMusic,
            lastPlayedPodcast: lastPlayedPodcast,
            favoriteStationIDs: favoriteStationIDs
        )
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }
}

// MARK: - Home sections

struct HomeSectionsView: View {
    @ObservedObject var homeModel: HomeModel
    @ObservedObject var stationStore: UserRadioStationStore
    let allStations: [RadioStation]

    var onResumeMusic: () -> Void = {}
    var onResumePodcast: () -> Void = {}
    var onPlayStation: (RadioStation) -> Void = { _ in }

    @State private var showingEditor = false

    private var favorites: [RadioStation] {
        homeModel.favoriteStationIDs.compactMap { id in
            allStations.first(where: { $0.id == id })
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if homeModel.lastPlayedMusic != nil || homeModel.lastPlayedPodcast != nil {
                keepListeningSection
            }
            favoritesSection
        }
        .padding(.horizontal, 16)
        .sheet(isPresented: $showingEditor) {
            FavoritesEditorView(homeModel: homeModel, allStations: allStations)
        }
    }

    // MARK: Sigue escuchando

    private var keepListeningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("SIGUE ESCUCHANDO")
            HStack(spacing: 10) {
                if let music = homeModel.lastPlayedMusic {
                    ResumeCard(
                        kindLabel: "MÚSICA",
                        icon: "music.note",
                        title: music.title,
                        subtitle: music.subtitle,
                        action: onResumeMusic
                    )
                }
                if let podcast = homeModel.lastPlayedPodcast {
                    ResumeCard(
                        kindLabel: "PODCAST",
                        icon: "mic.fill",
                        title: podcast.title,
                        subtitle: podcast.subtitle,
                        action: onResumePodcast
                    )
                }
            }
        }
    }

    // MARK: Radios favoritas

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("RADIOS FAVORITAS")
                Spacer()
                Button("Editar") { showingEditor = true }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSec)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 10),
                    GridItem(.flexible(), spacing: 10)
                ],
                spacing: 10
            ) {
                ForEach(favorites) { station in
                    FavoriteStationCell(
                        station: station,
                        onPlay: { onPlayStation(station) }
                    )
                    .contextMenu {
                        Button("Editar favoritas") { showingEditor = true }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(.textSec)
    }
}

// MARK: - Resume card

private struct ResumeCard: View {
    let kindLabel: String
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .strokeBorder(Color.textPri, lineWidth: 1.5)
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textPri)
                }
                Spacer()
            }

            Text(kindLabel)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.textSec)

            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textPri)
                .lineLimit(1)

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.textSec)
                .lineLimit(1)

            Button(action: action) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("Reanudar")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.pillBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.925, green: 0.925, blue: 0.925), // #ECECEC
                    Color(red: 0.847, green: 0.847, blue: 0.847)  // #D8D8D8
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Favorite station cell

private struct FavoriteStationCell: View {
    let station: RadioStation
    let onPlay: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.textPri)
                Spacer()
                Button(action: onPlay) {
                    ZStack {
                        Circle()
                            .fill(Color.pillBg)
                            .frame(width: 24, height: 24)
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }

            Text(station.name)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.textPri)
                .lineLimit(1)

            Text(subtitle(for: station))
                .font(.system(size: 11))
                .foregroundColor(.textSec)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func subtitle(for station: RadioStation) -> String {
        station.isUserAdded ? "My Radio" : "Live Radio"
    }
}

// MARK: - Favorites editor

private struct FavoritesEditorView: View {
    @ObservedObject var homeModel: HomeModel
    let allStations: [RadioStation]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Selecciona hasta 4")) {
                    ForEach(allStations) { station in
                        let isSelected = homeModel.favoriteStationIDs.contains(station.id)
                        Button {
                            toggle(station)
                        } label: {
                            HStack {
                                Text(station.name)
                                    .foregroundColor(.textPri)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .disabled(!isSelected && homeModel.favoriteStationIDs.count >= 4)
                    }
                }
            }
            .navigationTitle("Radios favoritas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func toggle(_ station: RadioStation) {
        if let index = homeModel.favoriteStationIDs.firstIndex(of: station.id) {
            homeModel.favoriteStationIDs.remove(at: index)
        } else if homeModel.favoriteStationIDs.count < 4 {
            homeModel.favoriteStationIDs.append(station.id)
        }
    }
}
