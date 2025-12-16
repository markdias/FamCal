import SwiftUI

/// Displays a single attachment row with file info and action buttons
struct AttachmentRow: View {
    let attachment: AttachmentViewModel
    let onDownload: () -> Void
    let onPreview: () -> Void
    let onDelete: () -> Void

    @State private var isLoading = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // File Icon
                Image(systemName: attachment.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)

                // File Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(attachment.fileName)
                        .font(.system(.body, design: .default))
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text(attachment.fileSizeFormatted)
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(.secondary)

                        Divider()
                            .frame(height: 12)

                        Text(attachment.uploadedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(.caption, design: .default))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Action Buttons
                HStack(spacing: 12) {
                    // Download Button
                    Button(action: {
                        isLoading = true
                        onDownload()
                    }) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.blue)
                    }
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.5 : 1.0)

                    // Preview Button
                    Button(action: {
                        onPreview()
                    }) {
                        Image(systemName: "eye.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.green)
                    }

                    // Delete Button (only for owner)
                    if attachment.canDelete {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            Image(systemName: "trash.circle")
                                .font(.system(size: 18))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .padding(12)

            Divider()
        }
        .confirmationDialog(
            "Delete Attachment",
            isPresented: $showDeleteConfirmation,
            actions: {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            },
            message: {
                Text("Are you sure you want to delete \(attachment.fileName)?")
            }
        )
    }
}

#Preview {
    VStack {
        AttachmentRow(
            attachment: AttachmentViewModel(
                from: AttachmentResponseDTO(
                    id: UUID().uuidString,
                    user_id: "user-123",
                    family_id: "family-456",
                    event_identifier: "event-789",
                    file_name: "Document.pdf",
                    file_size: 2048000,
                    file_type: "application/pdf",
                    storage_path: "family/event/user_timestamp_file.pdf",
                    uploaded_at: ISO8601DateFormatter().string(from: Date()),
                    uploaded_by: "user-123",
                    created_at: ISO8601DateFormatter().string(from: Date()),
                    updated_at: ISO8601DateFormatter().string(from: Date())
                ),
                canDelete: true
            ),
            onDownload: {},
            onPreview: {},
            onDelete: {}
        )
    }
    .padding()
}
