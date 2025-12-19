import SwiftUI
import QuickLook

/// Presents a QuickLook preview for attachment files
struct AttachmentPreview: UIViewControllerRepresentable {
    let fileURL: URL
    let onDismiss: () -> Void

    class PreviewItem: NSObject, QLPreviewItem {
        let url: URL
        init(url: URL) { self.url = url }
        var previewItemURL: URL? { url }
        var previewItemTitle: String? { url.lastPathComponent }
    }

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
        lazy var item = PreviewItem(url: fileURL)

        init(fileURL: URL, onDismiss: @escaping () -> Void) {
            self.fileURL = fileURL
            self.onDismiss = onDismiss
        }

        // MARK: - QLPreviewControllerDataSource

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return item
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
    /// Optional callback to avoid dismissing parent sheets when nested
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        AttachmentPreview(fileURL: fileURL, onDismiss: {
            if let onDismiss = onDismiss {
                onDismiss()
            } else {
                dismiss()
            }
        })
    }
}

#Preview {
    Text("QuickLook preview available at runtime with valid file URL")
}
