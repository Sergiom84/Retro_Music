import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PhotoThumbnail: View {
    let photo: Photo
    
    var body: some View {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: photo.imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .foregroundColor(.gray)
        }
        #else
        Rectangle()
            .foregroundColor(.gray)
        #endif
    }
}
