import SwiftUI
import UniformTypeIdentifiers

#if !os(watchOS)
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileURL: URL?
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [
            UTType.mp3,
            UTType.mpeg4Audio,
            UTType.wav,
            UTType("public.audio")! // Fallback for other audio types
        ], asCopy: true)
        documentPicker.delegate = context.coordinator
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No update needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ documentPicker: DocumentPicker) {
            self.parent = documentPicker
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.selectedFileURL = url
            parent.onPick(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("Document picker was cancelled")
        }
    }
}
#endif
