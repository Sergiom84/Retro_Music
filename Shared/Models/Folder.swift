import Foundation

struct Folder: Identifiable, Codable {
    let id: UUID
    var name: String
    var audioTracks: [AudioTrack]
}
