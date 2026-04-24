import Foundation
import AVFoundation

struct AudioTrackMetadata {
    let title: String
    let artist: String?
    let album: String?
    let artworkData: Data?
    let duration: TimeInterval
    let isPodcast: Bool
}

class AudioMetadataExtractor {
    static func extractMetadata(from url: URL, completion: @escaping (AudioTrackMetadata?) -> Void) {
        let asset = AVAsset(url: url)

        Task {
            do {
                let (metadata, duration) = try await asset.load(.metadata, .duration)
                
                var title: String? = nil
                var artist: String? = nil
                var album: String? = nil
                var artworkData: Data? = nil
                var isPodcast: Bool = false
                var searchableText = [url.deletingPathExtension().lastPathComponent]
                
                for item in metadata {
                    if let stringValue = try? await item.load(.stringValue),
                       !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        searchableText.append(stringValue)
                    }

                    guard let key = item.commonKey else { continue }
                    
                    switch key {
                    case .commonKeyTitle:
                        title = try? await item.load(.stringValue)
                    case .commonKeyArtist:
                        artist = try? await item.load(.stringValue)
                    case .commonKeyAlbumName:
                        album = try? await item.load(.stringValue)
                    case .commonKeyArtwork:
                        artworkData = try? await item.load(.dataValue)
                    default:
                        break
                    }
                }
                
                let durationSeconds = CMTimeGetSeconds(duration)
                
                if searchableText.contains(where: { text in
                    text.range(of: "podcast", options: [.caseInsensitive, .diacriticInsensitive]) != nil
                }) {
                    isPodcast = true
                }
                
                let finalTitle = title ?? url.lastPathComponent
                
                let trackMetadata = AudioTrackMetadata(
                    title: finalTitle,
                    artist: artist,
                    album: album,
                    artworkData: artworkData,
                    duration: durationSeconds,
                    isPodcast: isPodcast
                )
                completion(trackMetadata)
            } catch {
                print("Failed to load metadata for \(url.lastPathComponent): \(error)")
                completion(nil)
            }
        }
    }
}
