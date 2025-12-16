import SwiftUI
import QuickLook

/// Presents a QuickLook preview for attachment files
struct AttachmentPreview: UIViewControllerRepresentable {
    let fileURL: URL
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL, onDismiss: onDismiss)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let fileURL: URL
        let onDismiss: () -> Void

        init(fileURL: URL, onDismiss: @escaping () -> Void) {
            self.fileURL = fileURL
            self.onDismiss = onDismiss
        }

        // MARK: - QLPreviewControllerDataSource

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return fileURL as QLPreviewItem
        }

        // MARK: - QLPreviewControllerDelegate

        func previewControllerWillDismiss(_ controller: QLPreviewController) {
            onDismiss()
        }
    }
}

/// SwiftUI view wrapper for QuickLook preview
struct AttachmentPreviewView: View {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss

    var body: some View {
        AttachmentPreview(fileURL: fileURL, onDismiss: {
            dismiss()
        })
    }
}

#Preview {
    Text("QuickLook preview available at runtime with valid file URL")
}
