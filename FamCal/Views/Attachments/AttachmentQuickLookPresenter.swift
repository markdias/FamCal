import SwiftUI
import QuickLook

/// Hosts a QuickLook preview controller without requiring a SwiftUI sheet.
struct AttachmentQuickLookPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let fileURL: URL?
    var onDismiss: (() -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        context.coordinator.hostingController = controller
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.hostingController = uiViewController
        context.coordinator.updatePresentation()
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var parent: AttachmentQuickLookPresenter
        weak var hostingController: UIViewController?
        var previewController: QLPreviewController?
        var currentURL: URL?

        init(parent: AttachmentQuickLookPresenter) {
            self.parent = parent
        }

        func updatePresentation() {
            guard let host = hostingController else { return }

            if parent.isPresented, let fileURL = parent.fileURL {
                currentURL = fileURL
                if previewController == nil {
                    let preview = QLPreviewController()
                    preview.dataSource = self
                    preview.delegate = self
                    previewController = preview
                }

                if previewController?.presentingViewController == nil {
                    previewController?.modalPresentationStyle = .pageSheet
                    host.present(previewController!, animated: true)
                } else {
                    previewController?.reloadData()
                }
            } else {
                dismissPreview(animated: true)
            }
        }

        private func dismissPreview(animated: Bool) {
            guard let preview = previewController,
                  preview.presentingViewController != nil else { return }
            preview.dismiss(animated: animated) {
                self.previewController = nil
                self.currentURL = nil
            }
        }

        // MARK: - QLPreviewControllerDataSource

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            return currentURL == nil ? 0 : 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            return currentURL! as NSURL
        }

        // MARK: - QLPreviewControllerDelegate

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            DispatchQueue.main.async {
                self.parent.isPresented = false
                self.parent.onDismiss?()
            }
            previewController = nil
            currentURL = nil
        }
    }
}
