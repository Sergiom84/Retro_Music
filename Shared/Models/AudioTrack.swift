import Foundation

struct AudioTrack: Identifiable, Codable, Equatable {
    let id: UUID
    let title: String
    let artist: String?
    let album: String?
    let artworkData: Data?
    var storedFileName: String
    let duration: TimeInterval
    let isPodcast: Bool

    var filePath: URL {
        get {
            Self.documentsDirectory.appendingPathComponent(storedFileName)
        }
        set {
            storedFileName = newValue.lastPathComponent
        }
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    }

    init(
        id: UUID,
        title: String,
        artist: String?,
        album: String?,
        artworkData: Data?,
        filePath: URL,
        duration: TimeInterval,
        isPodcast: Bool
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkData = artworkData
        self.storedFileName = filePath.lastPathComponent
        self.duration = duration
        self.isPodcast = isPodcast
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case album
        case artworkData
        case storedFileName
        case filePath
        case duration
        case isPodcast
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decodeIfPresent(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        artworkData = try container.decodeIfPresent(Data.self, forKey: .artworkData)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        isPodcast = try container.decode(Bool.self, forKey: .isPodcast)

        if let fileName = try container.decodeIfPresent(String.self, forKey: .storedFileName), !fileName.isEmpty {
            storedFileName = fileName
        } else if let legacyURL = try container.decodeIfPresent(URL.self, forKey: .filePath) {
            storedFileName = legacyURL.lastPathComponent
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .storedFileName,
                in: container,
                debugDescription: "Missing stored audio file reference."
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(artworkData, forKey: .artworkData)
        try container.encode(storedFileName, forKey: .storedFileName)
        try container.encode(duration, forKey: .duration)
        try container.encode(isPodcast, forKey: .isPodcast)
    }

    static func == (lhs: AudioTrack, rhs: AudioTrack) -> Bool {
        lhs.id == rhs.id
    }
}
