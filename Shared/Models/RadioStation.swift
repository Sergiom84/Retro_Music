import Foundation
import Combine

struct RadioStation: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let streamURL: URL
    let compatibilityStreamURL: URL?
    let webPlayerURL: URL?
    let isUserAdded: Bool

    init(
        id: String,
        name: String,
        streamURL: URL,
        compatibilityStreamURL: URL? = nil,
        webPlayerURL: URL? = nil,
        isUserAdded: Bool = false
    ) {
        self.id = id
        self.name = name
        self.streamURL = streamURL
        self.compatibilityStreamURL = compatibilityStreamURL
        self.webPlayerURL = webPlayerURL
        self.isUserAdded = isUserAdded
    }

    static func makeUserStation(name: String, streamURL: URL) -> RadioStation {
        RadioStation(
            id: "custom-\(UUID().uuidString)",
            name: name,
            streamURL: streamURL,
            isUserAdded: true
        )
    }

    static func normalizedStreamURL(from rawValue: String) -> URL? {
        let trimmedValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else { return nil }

        let candidateValue = trimmedValue.contains("://") ? trimmedValue : "https://\(trimmedValue)"
        guard let components = URLComponents(string: candidateValue),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = components.host,
              !host.isEmpty else {
            return nil
        }

        return components.url
    }
}

enum RadioCatalog {
    static let pureIbiza = RadioStation(
        id: "pure-ibiza",
        name: "Pure Ibiza",
        streamURL: URL(string: "https://pureibizaradio.streaming-pro.com:8028/stream.mp3")!,
        compatibilityStreamURL: URL(string: "http://pureibizaradio.streaming-pro.com:8028/stream.mp3"),
        webPlayerURL: URL(string: "https://www.pureibizaradio.com/player/")
    )

    static let globalRadio = RadioStation(
        id: "global-radio",
        name: "Global Radio",
        streamURL: URL(string: "https://listenssl.ibizaglobalradio.com:8024/ibizaglobalradio.mp3")!,
        compatibilityStreamURL: nil,
        webPlayerURL: URL(string: "https://www.ibizaglobalradio.com/player-popup.html")
    )

    static let stations: [RadioStation] = [
        pureIbiza,
        globalRadio
    ]

    static func stations(adding userStations: [RadioStation]) -> [RadioStation] {
        let baseStationIDs = Set(stations.map(\.id))
        let uniqueUserStations = userStations.filter { !baseStationIDs.contains($0.id) }
        return stations + uniqueUserStations
    }
}

enum RadioStationPersistence {
    static let fileName = "retromusic_radio_stations.json"

    static var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return docs.appendingPathComponent(fileName)
    }

    static func load() -> [RadioStation] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([RadioStation].self, from: data)
        } catch {
            print("Error loading radio stations: \(error.localizedDescription)")
            return []
        }
    }

    static func save(_ stations: [RadioStation]) {
        do {
            let data = try JSONEncoder().encode(stations)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Error saving radio stations: \(error.localizedDescription)")
        }
    }

    static func upserting(_ station: RadioStation, in stations: [RadioStation]) -> [RadioStation] {
        var updatedStations = stations
        if let index = updatedStations.firstIndex(where: { $0.id == station.id || $0.streamURL == station.streamURL }) {
            updatedStations[index] = station
        } else {
            updatedStations.append(station)
        }
        return updatedStations
    }
}

final class UserRadioStationStore: ObservableObject {
    @Published private(set) var stations: [RadioStation] = [] {
        didSet {
            RadioStationPersistence.save(stations)
        }
    }

    init() {
        stations = RadioStationPersistence.load()
    }

    @discardableResult
    func addStation(name: String, streamURL: URL) -> RadioStation {
        let station = RadioStation.makeUserStation(name: name, streamURL: streamURL)
        stations = RadioStationPersistence.upserting(station, in: stations)
        return station
    }

    func removeStation(id: String) {
        stations.removeAll { $0.id == id }
    }

    func upsertStation(_ station: RadioStation) {
        stations = RadioStationPersistence.upserting(station, in: stations)
    }
}
