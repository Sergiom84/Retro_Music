import Foundation

struct TransferTrackMetadata: Codable {
    let id: UUID
    let title: String
    let artist: String?
    let album: String?
    let duration: TimeInterval
    let isPodcast: Bool
    let storedFileName: String
}
