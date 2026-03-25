import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFileURL: URL?
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var types: [UTType] = [.mp3, .mpeg4Audio, .wav, .aiff]
        if let publicAudio = UTType("public.audio") {
            types.append(publicAudio)
        }
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        documentPicker.delegate = context.coordinator
        documentPicker.allowsMultipleSelection = true
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ documentPicker: DocumentPicker) {
            self.parent = documentPicker
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            for url in urls {
                parent.selectedFileURL = url
                parent.onPick(url)
            }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}
