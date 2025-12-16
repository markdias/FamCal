import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI wrapper for UIDocumentPickerViewController
/// Allows users to select document files for attachment uploads
struct FilePicker: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    var onFilePicked: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Create document picker with supported file types
        var allowedTypes: [UTType] = [
            .pdf,
            .plainText,
            .rtf,
        ]

        // Add Microsoft Office formats using MIME types
        if let docType = UTType(mimeType: "application/msword") {
            allowedTypes.append(docType)
        }
        if let docxType = UTType(mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document") {
            allowedTypes.append(docxType)
        }
        if let xlsType = UTType(mimeType: "application/vnd.ms-excel") {
            allowedTypes.append(xlsType)
        }
        if let xlsxType = UTType(mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet") {
            allowedTypes.append(xlsxType)
        }
        if let pptType = UTType(mimeType: "application/vnd.ms-powerpoint") {
            allowedTypes.append(pptType)
        }
        if let pptxType = UTType(mimeType: "application/vnd.openxmlformats-officedocument.presentationml.presentation") {
            allowedTypes.append(pptxType)
        }

        // Add Apple iWork formats
        if let pagesType = UTType(filenameExtension: "pages") {
            allowedTypes.append(pagesType)
        }
        if let numbersType = UTType(filenameExtension: "numbers") {
            allowedTypes.append(numbersType)
        }
        if let keynoteType = UTType(filenameExtension: "keynote") {
            allowedTypes.append(keynoteType)
        }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFilePicked: onFilePicked, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onFilePicked: (URL) -> Void
        let dismiss: DismissAction

        init(onFilePicked: @escaping (URL) -> Void, dismiss: DismissAction) {
            self.onFilePicked = onFilePicked
            self.dismiss = dismiss
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                // Start accessing the security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }

                    // Make a copy to the app's Documents directory while we have access
                    let fileManager = FileManager.default
                    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let destinationURL = documentsURL.appendingPathComponent(url.lastPathComponent)

                    do {
                        // Remove existing file if it exists
                        try? fileManager.removeItem(at: destinationURL)
                        // Copy the file
                        try fileManager.copyItem(at: url, to: destinationURL)
                        onFilePicked(destinationURL)
                    } catch {
                        print("❌ Error copying file: \(error)")
                    }
                }
            }
            dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            dismiss()
        }
    }
}

/// Preview of FilePicker
#Preview {
    VStack {
        Text("FilePicker available through UI context only")
    }
}
