import Foundation

struct Folder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var audioTracks: [AudioTrack]
}
