import SwiftUI
import Foundation

/// Displays all attachments for the current family
struct FamilyAttachmentsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var appSettingsManager: AppSettingsManager
    @EnvironmentObject private var dataManager: SupabaseDataManager

    struct AttachmentListItem: Identifiable {
        let attachment: AttachmentViewModel
        let eventTitle: String
        var id: String { attachment.id }
    }

    @State private var attachments: [AttachmentListItem] = []
    @State private var isLoading = false
    @State private var error: AttachmentError?
    @State private var showError = false
    @State private var previewURL: URL?
    @State private var showPreview = false
    @State private var shareURL: URL?
    @State private var showShareSheet = false

    private var theme: AppTheme { themeManager.selectedTheme }
    private var primaryTextColor: Color { theme.textPrimary }
    private var secondaryTextColor: Color { theme.textSecondary }

    var body: some View {
        ZStack {
            theme.backgroundLayer().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    attachmentsList
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Attachments")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(primaryTextColor)
            }
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onAppear { loadAttachments() }
        .sheet(isPresented: $showShareSheet) {
            if let shareURL = shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
        .alert("Attachment Error", isPresented: $showError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            if let error = error {
                Text(error.errorDescription ?? "Unknown error occurred")
            }
        })
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

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Family attachments")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(primaryTextColor)
            Text("All files uploaded to events by your family.")
                .font(.system(size: 14))
                .foregroundColor(secondaryTextColor)
        }
    }

    private var attachmentsList: some View {
        Group {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Loading attachments…")
                        .foregroundColor(secondaryTextColor)
                        .font(.system(size: 14))
                    Spacer()
                }
                .padding()
                .background(theme.cardBackground)
                .cornerRadius(12)
            } else if attachments.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No attachments yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(primaryTextColor)
                    Text("When your family uploads files to events, they’ll appear here.")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryTextColor)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.cardBackground)
                .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(attachments) { item in
                        AttachmentRow(
                            attachment: item.attachment,
                            context: "Event: \(item.eventTitle)",
                            onDownload: { downloadAttachment(item.attachment) },
                            onPreview: { previewAttachment(item.attachment) },
                            onDelete: { deleteAttachment(item.attachment) }
                        )
                        .background(theme.cardBackground)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.cardStroke, lineWidth: 1)
                )
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(theme.prefersDarkInterface ? 0.4 : 0.06), radius: theme.prefersDarkInterface ? 14 : 6, x: 0, y: theme.prefersDarkInterface ? 8 : 3)
            }
        }
    }

    // MARK: - Actions

    private func loadAttachments() {
        isLoading = true
        Task {
            await dataManager.fetchAllAttachments()
            let fetched = dataManager.allAttachments
            let titleMap = await resolveEventTitles(for: fetched.map { $0.eventIdentifier })
            let items = fetched.map { attachment in
                let title = titleMap[attachment.eventIdentifier] ?? attachment.eventIdentifier
                return AttachmentListItem(attachment: attachment, eventTitle: title)
            }

            await MainActor.run {
                attachments = items
                isLoading = false
            }
        }
    }

    private func downloadAttachment(_ attachment: AttachmentViewModel) {
        Task {
            do {
                let data = try await dataManager.downloadAttachment(storagePath: attachment.storagePath)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.fileName)
                try data.write(to: tempURL)
                await MainActor.run {
                    shareURL = tempURL
                    showShareSheet = true
                }
            } catch let error as AttachmentError {
                await MainActor.run {
                    self.error = error
                    showError = true
                }
            } catch {
                await MainActor.run {
                    self.error = .downloadFailed(error.localizedDescription)
                    showError = true
                }
            }
        }
    }

    private func previewAttachment(_ attachment: AttachmentViewModel) {
        Task {
            do {
                let data = try await dataManager.downloadAttachment(storagePath: attachment.storagePath)
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(attachment.fileName)
                try data.write(to: tempURL)
                await MainActor.run {
                    previewURL = tempURL
                    showPreview = true
                }
            } catch let error as AttachmentError {
                await MainActor.run {
                    self.error = error
                    showError = true
                }
            } catch {
                await MainActor.run {
                    self.error = .downloadFailed(error.localizedDescription)
                    showError = true
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
                    eventIdentifier: attachment.eventIdentifier
                )
                await MainActor.run {
                    attachments.removeAll { $0.id == attachment.id }
                }
            } catch let error as AttachmentError {
                await MainActor.run {
                    self.error = error
                    showError = true
                }
            } catch {
                await MainActor.run {
                    self.error = .deleteFailed(error.localizedDescription)
                    showError = true
                }
            }
        }
    }
}

// MARK: - Event title resolution
private extension FamilyAttachmentsView {
    func resolveEventTitles(for identifiers: [String]) async -> [String: String] {
        guard !identifiers.isEmpty else { return [:] }
        var map: [String: String] = [:]

        if let cachedGroups = await EventCache.shared.load() {
            for group in cachedGroups {
                var events: [GroupedEventDTO] = []
                if let next = group.nextEvent {
                    events.append(next)
                }
                events.append(contentsOf: group.upcomingEvents)

                for event in events {
                    if identifiers.contains(event.eventIdentifier) {
                        map[event.eventIdentifier] = event.title
                    }
                }
            }
        }

        return map
    }
}

struct FamilyAttachmentsView_Previews: PreviewProvider {
    static var previews: some View {
        FamilyAttachmentsView()
            .environmentObject(ThemeManager())
            .environmentObject(AppSettingsManager())
            .environmentObject(SupabaseDataManager())
    }
}
