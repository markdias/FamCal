import SwiftUI
import QuickLook
import UIKit

/// Main card component for displaying and managing event attachments
struct AttachmentsCard: View {
    let eventIdentifier: String
    @ObservedObject var dataManager = SupabaseDataManager.shared
    @ObservedObject var appSettings = AppSettingsManager.shared

    @State private var attachments: [AttachmentViewModel] = []
    @State private var showFilePicker = false
    @State private var showPreview = false
    @State private var previewURL: URL?
    @State private var selectedAttachment: AttachmentViewModel?
    @State private var isUploading = false
    @State private var uploadError: AttachmentError?
    @State private var showUploadError = false
    @State private var isLoadingAttachments = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        VStack(spacing: 0) {
            if appSettings.isProUser || !attachments.isEmpty {
                VStack(spacing: 12) {
                    // Header with title and upload button
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "paperclip.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Attachments")
                                    .font(.system(.body, design: .default))
                                    .fontWeight(.semibold)

                                if appSettings.isProUser {
                                    Text("\(AttachmentViewModel.formatFileSize(appSettings.attachmentStorageUsed)) / \(AttachmentViewModel.formatFileSize(appSettings.attachmentStorageLimit))")
                                        .font(.system(.caption, design: .default))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Spacer()

                        // Upload Button
                        if appSettings.isProUser {
                            Button(action: {
                                print("ℹ️ Showing file picker for event \(eventIdentifier)")
                                showFilePicker = true
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.blue)
                            }
                            .disabled(isUploading)
                            .opacity(isUploading ? 0.5 : 1.0)
                        }
                    }
                    .padding(12)

                    // Storage quota bar (Pro only)
                    if appSettings.isProUser {
                        StorageQuotaBar(
                            used: appSettings.attachmentStorageUsed,
                            limit: appSettings.attachmentStorageLimit
                        )
                        .padding(.horizontal, 12)
                    }

                    // Attachments list
                    if attachments.isEmpty {
                        EmptyAttachmentsView(isProUser: appSettings.isProUser)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(attachments) { attachment in
                                AttachmentRow(
                                    attachment: attachment,
                                    onDownload: {
                                        downloadAttachment(attachment)
                                    },
                                    onPreview: {
                                        previewAttachment(attachment)
                                    },
                                    onDelete: {
                                        deleteAttachment(attachment)
                                    }
                                )
                            }
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
        }
        .onAppear {
            loadAttachments()
        }
        .sheet(isPresented: $showFilePicker) {
            FilePicker { url in
                handleFilePicked(url)
            }
        }
        .alert("Upload Error", isPresented: $showUploadError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            if let error = uploadError {
                Text(error.errorDescription ?? "Unknown error occurred")
            }
        })
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
        .background(
            AttachmentQuickLookPresenter(
                isPresented: $showPreview,
                fileURL: previewURL,
                onDismiss: {
                    showPreview = false
                }
            )
            .allowsHitTesting(false)
            .frame(width: 0, height: 0)
        )
    }

    // MARK: - Methods

    private func loadAttachments() {
        isLoadingAttachments = true
        print("ℹ️ Loading attachments for event \(eventIdentifier)")
        Task {
            await dataManager.fetchEventAttachments(eventIdentifier: eventIdentifier)
            await MainActor.run {
                attachments = dataManager.getEventAttachments(eventIdentifier)
                isLoadingAttachments = false
                print("ℹ️ Attachments loaded for event \(eventIdentifier). Count: \(attachments.count)")
            }
        }
    }

    private func handleFilePicked(_ url: URL) {
        print("ℹ️ File picked for upload: \(url.lastPathComponent) at \(url.path)")
        isUploading = true

        Task {
            do {
                let fileName = url.lastPathComponent
                let uploaded = try await dataManager.uploadAttachment(
                    fileURL: url,
                    eventIdentifier: eventIdentifier,
                    fileName: fileName
                )

                await MainActor.run {
                    attachments.insert(uploaded, at: 0)
                    isUploading = false
                }

                print("✅ Attachment uploaded: \(fileName)")
            } catch let error as AttachmentError {
                await MainActor.run {
                    uploadError = error
                    showUploadError = true
                    isUploading = false
                    print("❌ Attachment upload failed with AttachmentError: \(error.localizedDescription)")
                }
            } catch {
                await MainActor.run {
                    uploadError = .uploadFailed(error.localizedDescription)
                    showUploadError = true
                    isUploading = false
                    print("❌ Attachment upload failed with unknown error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func downloadAttachment(_ attachment: AttachmentViewModel) {
        Task {
            do {
                let data = try await dataManager.downloadAttachment(storagePath: attachment.storagePath)
                print("ℹ️ Downloaded attachment data for \(attachment.fileName). Size: \(data.count) bytes")
                if data.isEmpty {
                    throw AttachmentError.downloadFailed("Empty file data received")
                }

                // Save to temporary location for preview
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(attachment.fileName)
                try data.write(to: tempURL)

                let exists = FileManager.default.fileExists(atPath: tempURL.path)
                print("ℹ️ Temp file for download exists: \(exists) at \(tempURL.path)")

                await MainActor.run {
                    shareURL = tempURL
                    showShareSheet = true
                }
            } catch let error as AttachmentError {
                await MainActor.run {
                    uploadError = error
                    showUploadError = true
                }
            } catch {
                await MainActor.run {
                    uploadError = .downloadFailed(error.localizedDescription)
                    showUploadError = true
                }
            }
        }
    }

    private func previewAttachment(_ attachment: AttachmentViewModel) {
        Task {
            do {
                let data = try await dataManager.downloadAttachment(storagePath: attachment.storagePath)
                print("ℹ️ Preview download data for \(attachment.fileName). Size: \(data.count) bytes")
                if data.isEmpty {
                    throw AttachmentError.downloadFailed("Empty file data received")
                }

                // Save to temporary location for preview
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(attachment.fileName)
                try data.write(to: tempURL)

                let exists = FileManager.default.fileExists(atPath: tempURL.path)
                print("ℹ️ Temp file for preview exists: \(exists) at \(tempURL.path)")

                guard QLPreviewController.canPreview(tempURL as QLPreviewItem) else {
                    throw AttachmentError.downloadFailed("Cannot preview this file type")
                }

                await MainActor.run {
                    previewURL = tempURL
                    showPreview = true
                }
            } catch let error as AttachmentError {
                await MainActor.run {
                    uploadError = error
                    showUploadError = true
                }
            } catch {
                await MainActor.run {
                    uploadError = .downloadFailed(error.localizedDescription)
                    showUploadError = true
                }
            }
        }
    }

    private func deleteAttachment(_ attachment: AttachmentViewModel) {
        Task {
            do {
                try await dataManager.deleteAttachment(
                    attachmentId: attachment.id,
                    storagePath: attachment.storagePath,
                    eventIdentifier: eventIdentifier
                )

                await MainActor.run {
                    attachments.removeAll { $0.id == attachment.id }
                    appSettings.updateAttachmentStorageUsed(
                        newValue: appSettings.attachmentStorageUsed - attachment.fileSize
                    )
                }
            } catch let error as AttachmentError {
                await MainActor.run {
                    uploadError = error
                    showUploadError = true
                }
            } catch {
                await MainActor.run {
                    uploadError = .deleteFailed(error.localizedDescription)
                    showUploadError = true
                }
            }
        }
    }
}

// MARK: - Subviews

struct StorageQuotaBar: View {
    let used: Int
    let limit: Int

    var percentageUsed: Double {
        limit > 0 ? Double(used) / Double(limit) : 0
    }

    var quotaColor: Color {
        if percentageUsed >= 0.9 {
            return .red
        } else if percentageUsed >= 0.7 {
            return .orange
        } else {
            return .green
        }
    }

    var body: some View {
        VStack(spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))

                    // Progress bar
                    RoundedRectangle(cornerRadius: 4)
                        .fill(quotaColor)
                        .frame(width: geometry.size.width * percentageUsed)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(Int(percentageUsed * 100))% used")
                    .font(.system(.caption, design: .default))
                    .foregroundStyle(.secondary)

                Spacer()

                if percentageUsed >= 0.9 {
                    Label("Storage nearly full", systemImage: "exclamationmark.circle.fill")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(.red)
                }
            }
        }
    }
}

struct EmptyAttachmentsView: View {
    let isProUser: Bool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "paperclip.circle")
                .font(.system(size: 32))
                .foregroundStyle(.gray)

            if isProUser {
                VStack(spacing: 4) {
                    Text("No attachments yet")
                        .font(.system(.body, design: .default))
                        .fontWeight(.semibold)

                    Text("Add files to this event using the + button")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 4) {
                    Text("Upgrade to Pro")
                        .font(.system(.body, design: .default))
                        .fontWeight(.semibold)

                    Text("Attachments are a Pro feature")
                        .font(.system(.caption, design: .default))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
    }
}

/// Share sheet for saving or sharing downloaded files
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // no-op
    }
}

#Preview {
    VStack {
        AttachmentsCard(eventIdentifier: "event-123")
            .padding()
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
