import Foundation
import AVFoundation
import UIKit

struct AudioTrackMetadata {
    let title: String
    let artist: String?
    let album: String?
    let artworkData: Data?
    let duration: TimeInterval
    let isPodcast: Bool
}

enum AudioMetadataExtractor {
    static func extractMetadata(from url: URL, completion: @escaping (AudioTrackMetadata?) -> Void) {
        let asset = AVAsset(url: url)
        let keys = ["commonMetadata", "duration", "availableMetadataFormats"]

        asset.loadValuesAsynchronously(forKeys: keys) {
            // Verify all keys loaded
            for key in keys {
                let status = asset.statusOfValue(forKey: key, error: nil)
                if status != .loaded {
                    DispatchQueue.main.async {
                        // Fallback: return basic metadata from filename
                        let fallback = AudioTrackMetadata(
                            title: url.deletingPathExtension().lastPathComponent,
                            artist: nil,
                            album: nil,
                            artworkData: nil,
                            duration: 0,
                            isPodcast: false
                        )
                        completion(fallback)
                    }
                    return
                }
            }

            var title: String?
            var artist: String?
            var album: String?
            var genre: String?
            var artworkData: Data?

            for format in asset.availableMetadataFormats {
                for item in asset.metadata(ofFormat: format) {
                    switch item.commonKey {
                    case .commonKeyTitle:
                        title = title ?? item.stringValue
                    case .commonKeyArtist:
                        artist = artist ?? item.stringValue
                    case .commonKeyAlbumName:
                        album = album ?? item.stringValue
                    case .commonKeyArtwork:
                        artworkData = artworkData ?? item.dataValue
                    default:
                        break
                    }

                    // Check for genre in iTunes metadata
                    if item.key as? String == "genre" || item.identifier == .iTunesMetadataUserGenre {
                        genre = item.stringValue
                    }
                }
            }

            let seconds = CMTimeGetSeconds(asset.duration)
            let duration: TimeInterval = seconds.isFinite ? max(0, seconds) : 0

            // Improved podcast heuristic
            let isPodcast = detectPodcast(
                title: title,
                artist: artist,
                album: album,
                genre: genre,
                duration: duration
            )

            // Compress artwork for storage efficiency
            let compressedArtwork = compressArtwork(artworkData, maxDimension: 300)

            let finalTitle = title ?? url.deletingPathExtension().lastPathComponent

            DispatchQueue.main.async {
                completion(AudioTrackMetadata(
                    title: finalTitle,
                    artist: artist,
                    album: album,
                    artworkData: compressedArtwork,
                    duration: duration,
                    isPodcast: isPodcast
                ))
            }
        }
    }

    private static func detectPodcast(
        title: String?,
        artist: String?,
        album: String?,
        genre: String?,
        duration: TimeInterval
    ) -> Bool {
        let searchText = [title, artist, album, genre]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")

        let podcastKeywords = ["podcast", "episode", "ep.", "ep ", "episodio"]
        if podcastKeywords.contains(where: { searchText.contains($0) }) {
            return true
        }

        if let g = genre?.lowercased(), g.contains("podcast") {
            return true
        }

        // Long audio (> 15 min) without album metadata is likely a podcast
        if duration > 900 && album == nil {
            return true
        }

        return false
    }

    private static func compressArtwork(_ data: Data?, maxDimension: CGFloat) -> Data? {
        guard let data = data, let image = UIImage(data: data) else { return nil }

        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return image.jpegData(compressionQuality: 0.7)
        }

        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.7)
    }
}
