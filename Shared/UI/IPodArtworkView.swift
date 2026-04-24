import SwiftUI
import ImageIO
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif

struct IPodArtworkView: View {
    let artworkData: Data?
    var fallbackSystemName: String = "music.note"
    var fallbackColor: Color = .gray
    var cornerRadius: CGFloat = 4

    var body: some View {
        Group {
            if let artworkImage {
                artworkImage
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(0.45))

                    Image(systemName: fallbackSystemName)
                        .resizable()
                        .scaledToFit()
                        .padding(10)
                        .foregroundColor(fallbackColor)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }

    private var artworkImage: Image? {
        guard let artworkData else { return nil }

        #if canImport(UIKit)
        if let image = UIImage(data: artworkData) {
            return Image(uiImage: image)
        }
        #endif

        guard let source = CGImageSourceCreateWithData(artworkData as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}
