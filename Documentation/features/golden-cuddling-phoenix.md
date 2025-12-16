# Event Attachments Feature - Implementation Plan

## Overview
Add a FamCal-specific attachment system for events that allows users to attach any file type (concert tickets, flight confirmations, photos, etc.). This will be a **Pro feature** with storage limits for free users.

## Requirements
- Pro feature with small storage capacity for free tier
- **Document files only** (PDF, Word, Excel, PowerPoint, Pages, Numbers, Keynote, text files)
- Files visible to all family members who can see the event
- Use cases: concert tickets (PDF), flight confirmations (PDF), itineraries, reservation confirmations
- Store files in Supabase Storage (S3-compatible)
- **Supabase limits**: 100GB total storage on Pro plan, so conservative per-user limits needed

## Architecture Overview

### Data Flow
```
User selects file → Upload to Supabase Storage → Store metadata in Supabase DB →
Sync to Core Data → Display in EventDetailView → Tap to preview with QuickLook
```

### Three-Layer Architecture (Following Existing Pattern)
1. **Supabase Storage + REST API** - Cloud storage for files and metadata
2. **SupabaseManager/SupabaseDataManager** - API client and orchestration
3. **Core Data** - Local cache of attachment metadata

## Critical Files to Modify/Create

### New Files to Create
- [ ] `/FamCal/Models/AttachmentModels.swift` - DTO and view models
- [ ] `/FamCal/Views/Shared/FilePicker.swift` - Document picker wrapper
- [ ] `/FamCal/Views/Shared/AttachmentRow.swift` - Attachment display component
- [ ] `/FamCal/Views/Shared/AttachmentPreview.swift` - QuickLook preview wrapper

### Files to Modify
- [ ] `/FamCal/Managers/SupabaseManager.swift` - Add Storage API methods
- [ ] `/FamCal/Managers/SupabaseDataManager.swift` - Add attachment fetch/sync orchestration
- [ ] `/FamCal/Managers/AppSettingsManager.swift` - Add storage limits
- [ ] `/FamCal/Utilities/SupabaseDataSync.swift` - Add attachment sync logic
- [ ] `/FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel/contents` - Add Attachment entity
- [ ] `/FamCal/Views/Events/EventDetailView.swift` - Add attachments card
- [ ] `/FamCal/Views/Shared/PremiumBannerView.swift` - Add attachment limits to Pro comparison

### Database Schema (Supabase)
```sql
-- New table: event_attachments
CREATE TABLE event_attachments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users NOT NULL,
    family_id UUID REFERENCES families(id) NOT NULL,  -- CRITICAL: For family-scoped access
    event_identifier TEXT NOT NULL,  -- Links to EventKit event
    file_name TEXT NOT NULL,
    file_size INTEGER NOT NULL,      -- Bytes
    file_type TEXT,                  -- MIME type
    storage_path TEXT NOT NULL,      -- Supabase Storage path
    uploaded_at TIMESTAMP DEFAULT NOW(),
    uploaded_by UUID REFERENCES auth.users,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Indexes for quick lookups
CREATE INDEX idx_event_attachments_event ON event_attachments(event_identifier);
CREATE INDEX idx_event_attachments_user ON event_attachments(user_id);
CREATE INDEX idx_event_attachments_family ON event_attachments(family_id);

-- RLS Policies for family sharing
ALTER TABLE event_attachments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view family attachments" ON event_attachments
  FOR SELECT USING (
    family_id IN (
      SELECT family_id FROM profiles WHERE id = auth.uid()
    )
  );

CREATE POLICY "Users can manage own attachments" ON event_attachments
  FOR ALL USING (user_id = auth.uid());

-- Storage bucket (create via Supabase UI or SQL)
INSERT INTO storage.buckets (id, name, public)
VALUES ('event-attachments', 'event-attachments', false);

-- Storage bucket RLS policies
CREATE POLICY "Users can upload to family folder" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'event-attachments' AND
    (storage.foldername(name))[1] IN (
      SELECT family_id::text FROM profiles WHERE id = auth.uid()
    )
  );

CREATE POLICY "Users can read family attachments" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'event-attachments' AND
    (storage.foldername(name))[1] IN (
      SELECT family_id::text FROM profiles WHERE id = auth.uid()
    )
  );

CREATE POLICY "Users can delete own attachments" ON storage.objects
  FOR DELETE TO authenticated
  USING (bucket_id = 'event-attachments' AND auth.uid()::text = (storage.foldername(name))[2]);
```

### Core Data Entity
```swift
// Attachment entity
entity Attachment {
    id: UUID
    eventIdentifier: String
    fileName: String
    fileSize: Int64
    fileType: String?
    storagePath: String
    localPath: String?        // Cached file location
    uploadStatus: String?     // "pending", "uploading", "uploaded", "failed"
    uploadedAt: Date?
    uploadedBy: String?
    createdAt: Date?
    modifiedAt: Date?         // CRITICAL: For sync conflict resolution
}
```

### Supabase Storage Bucket Structure
```
event-attachments/
  {family_id}/                  # CHANGED: Family-scoped instead of user-scoped
    {event_identifier}/
      {user_id}_{timestamp}_{filename}
```

**Rationale:** Family-scoped paths enable simpler RLS policies and align with the app's family-sharing model.

## Implementation Steps

### Step 1: Pro Feature Configuration
**File:** `AppSettingsManager.swift`

Add storage limits with caching:
```swift
// Storage quota tracking with cache
@Published var attachmentStorageUsedBytes: Int64 = AppGroupDefaults.shared.object(forKey: "attachmentStorageUsedBytes") as? Int64 ?? 0

var maxAttachmentStorageMB: Int {
    isProUser ? 250 : 25  // 250MB Pro, 25MB Free (conservative for Supabase limits)
}

var currentAttachmentStorageMB: Double {
    Double(attachmentStorageUsedBytes) / 1_048_576.0  // Bytes to MB
}

var isAtAttachmentStorageLimit: Bool {
    currentAttachmentStorageMB >= Double(maxAttachmentStorageMB)
}

// Incremental quota updates (call on upload/delete)
func incrementStorageUsed(by bytes: Int64) {
    attachmentStorageUsedBytes += bytes
    AppGroupDefaults.shared.set(attachmentStorageUsedBytes, forKey: "attachmentStorageUsedBytes")
}

func decrementStorageUsed(by bytes: Int64) {
    attachmentStorageUsedBytes = max(0, attachmentStorageUsedBytes - bytes)
    AppGroupDefaults.shared.set(attachmentStorageUsedBytes, forKey: "attachmentStorageUsedBytes")
}

// Refresh from Supabase (call periodically or on app launch)
func refreshStorageQuota() async {
    do {
        let totalBytes = try await supabaseManager.getTotalStorageUsed()
        await MainActor.run {
            attachmentStorageUsedBytes = totalBytes
            AppGroupDefaults.shared.set(totalBytes, forKey: "attachmentStorageUsedBytes")
        }
    } catch {
        print("Failed to refresh storage quota: \(error)")
    }
}
```

### Step 2: Data Models
**File:** `Models/AttachmentModels.swift`

```swift
import Foundation
import UniformTypeIdentifiers

// Supabase DTO
struct AttachmentDTO: Codable {
    let id: String
    let user_id: String
    let family_id: String           // Added for family sharing
    let event_identifier: String
    let file_name: String
    let file_size: Int
    let file_type: String?
    let storage_path: String
    let uploaded_at: String?
    let uploaded_by: String?
    let created_at: String?
    let updated_at: String?
}

// View model for UI
struct AttachmentViewModel: Identifiable {
    let id: UUID
    let fileName: String
    let fileSize: Int64
    let fileType: String?
    let storagePath: String
    let localPath: String?

    var fileSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var fileIcon: String {
        guard let mimeType = fileType else { return "doc.fill" }

        switch mimeType {
        case "application/pdf":
            return "doc.text.fill"
        case let type where type.contains("spreadsheet") || type.contains("excel") || type.contains("sheet"):
            return "tablecells.fill"
        case let type where type.contains("presentation") || type.contains("powerpoint") || type.contains("keynote"):
            return "play.rectangle.fill"
        case let type where type.contains("word") || type.contains("document"):
            return "doc.richtext.fill"
        case "text/plain":
            return "doc.plaintext"
        default:
            return "doc.fill"
        }
    }

    // Validate if file type is allowed (documents only)
    static func isAllowedFileType(_ mimeType: String) -> Bool {
        let allowedTypes = [
            "application/pdf",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-powerpoint",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "application/vnd.apple.pages",
            "application/vnd.apple.numbers",
            "application/vnd.apple.keynote",
            "text/plain",
            "text/csv",
            "application/rtf"
        ]
        return allowedTypes.contains(mimeType) || mimeType.hasPrefix("text/")
    }
}

// Error types
enum AttachmentError: Error, LocalizedError {
    case storageLimitReached
    case fileTooLarge(maxMB: Int)
    case invalidFileType
    case uploadFailed(statusCode: Int)
    case downloadFailed
    case fileNotFound
    case metadataCreationFailed

    var errorDescription: String? {
        switch self {
        case .storageLimitReached:
            return "Storage limit reached. Upgrade to Pro for 1GB storage."
        case .fileTooLarge(let maxMB):
            return "File exceeds \(maxMB)MB limit"
        case .invalidFileType:
            return "This file type is not supported"
        case .uploadFailed(let statusCode):
            return "Upload failed with error code \(statusCode)"
        case .downloadFailed:
            return "Failed to download attachment"
        case .fileNotFound:
            return "File not found"
        case .metadataCreationFailed:
            return "Failed to save attachment metadata"
        }
    }
}

// MIME type detection extension
extension URL {
    var mimeType: String {
        if let uti = UTType(filenameExtension: self.pathExtension) {
            return uti.preferredMIMEType ?? "application/octet-stream"
        }
        return "application/octet-stream"
    }
}
```

### Step 3: Supabase Storage Integration
**File:** `Managers/SupabaseManager.swift`

Add complete REST API implementation:
```swift
// Upload file to Storage (family-scoped path)
func uploadAttachment(
    familyId: String,
    eventIdentifier: String,
    fileData: Data,
    fileName: String,
    fileType: String
) async throws -> String {
    let timestamp = Int(Date().timeIntervalSince1970)
    let storagePath = "\(familyId)/\(eventIdentifier)/\(userId)_\(timestamp)_\(fileName)"

    let url = supabaseURL.appendingPathComponent("storage/v1/object/event-attachments/\(storagePath)")
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(anonKey, forHTTPHeaderField: "apikey")

    guard let accessToken = await authManager.getAccessToken() else {
        throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
    }
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    request.setValue(fileType, forHTTPHeaderField: "Content-Type")
    request.httpBody = fileData

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw AttachmentError.uploadFailed(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
    }

    return storagePath
}

// Download file from Storage (authenticated)
func downloadAttachment(storagePath: String) async throws -> Data {
    let url = supabaseURL.appendingPathComponent("storage/v1/object/event-attachments/\(storagePath)")
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue(anonKey, forHTTPHeaderField: "apikey")

    guard let accessToken = await authManager.getAccessToken() else {
        throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
    }
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw AttachmentError.downloadFailed
    }

    return data
}

// Delete file from Storage (with 404 tolerance)
func deleteAttachment(storagePath: String) async throws {
    let url = supabaseURL.appendingPathComponent("storage/v1/object/event-attachments/\(storagePath)")
    var request = URLRequest(url: url)
    request.httpMethod = "DELETE"
    request.setValue(anonKey, forHTTPHeaderField: "apikey")

    guard let accessToken = await authManager.getAccessToken() else {
        throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
    }
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    let (_, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) || httpResponse.statusCode == 404 else {
        throw AttachmentError.downloadFailed
    }
}

// Create metadata record
func createAttachmentMetadata(
    familyId: String,
    eventIdentifier: String,
    fileName: String,
    fileSize: Int,
    fileType: String?,
    storagePath: String
) async throws -> AttachmentDTO {
    struct CreateBody: Encodable {
        let user_id: String
        let family_id: String
        let event_identifier: String
        let file_name: String
        let file_size: Int
        let file_type: String?
        let storage_path: String
        let uploaded_by: String
    }

    let body = CreateBody(
        user_id: userId,
        family_id: familyId,
        event_identifier: eventIdentifier,
        file_name: fileName,
        file_size: fileSize,
        file_type: fileType,
        storage_path: storagePath,
        uploaded_by: userId
    )

    guard let accessToken = await authManager.getAccessToken() else {
        throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
    }

    let (data, statusCode) = try await makeRequest(
        "POST",
        path: "rest/v1/event_attachments",
        body: body,
        userToken: accessToken
    )

    guard statusCode == 201 else {
        throw AttachmentError.metadataCreationFailed
    }

    let attachments = try JSONDecoder().decode([AttachmentDTO].self, from: data)
    guard let attachment = attachments.first else {
        throw AttachmentError.metadataCreationFailed
    }

    return attachment
}

// Get attachments for event
func getAttachmentsForEvent(eventIdentifier: String) async throws -> [AttachmentDTO] {
    let queryItems = [
        URLQueryItem(name: "event_identifier", value: "eq.\(eventIdentifier)"),
        URLQueryItem(name: "order", value: "uploaded_at.desc")
    ]

    guard let accessToken = await authManager.getAccessToken() else {
        throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
    }

    let (data, statusCode) = try await makeRequest(
        "GET",
        path: "rest/v1/event_attachments",
        queryItems: queryItems,
        userToken: accessToken
    )

    guard statusCode == 200 else {
        throw NSError(domain: "SupabaseManager", code: statusCode)
    }

    return try JSONDecoder().decode([AttachmentDTO].self, from: data)
}

// Delete attachment metadata (with 404 tolerance)
func deleteAttachmentMetadata(attachmentId: String) async throws {
    let queryItems = [URLQueryItem(name: "id", value: "eq.\(attachmentId)")]

    guard let accessToken = await authManager.getAccessToken() else {
        throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
    }

    do {
        let (_, statusCode) = try await makeRequest(
            "DELETE",
            path: "rest/v1/event_attachments",
            queryItems: queryItems,
            userToken: accessToken
        )

        guard statusCode == 204 || statusCode == 404 else {
            throw NSError(domain: "SupabaseManager", code: statusCode)
        }
    } catch let error as NSError where error.code == 404 {
        // Already deleted, ignore
        print("Attachment metadata already deleted: \(attachmentId)")
    }
}

// Get total storage used (with aggregation)
func getTotalStorageUsed() async throws -> Int64 {
    // Note: PostgREST aggregation syntax
    let queryItems = [
        URLQueryItem(name: "user_id", value: "eq.\(userId)"),
        URLQueryItem(name: "select", value: "file_size.sum()")
    ]

    guard let accessToken = await authManager.getAccessToken() else {
        throw NSError(domain: "SupabaseManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No access token"])
    }

    let (data, statusCode) = try await makeRequest(
        "GET",
        path: "rest/v1/rpc/get_attachment_storage_used",  // Use RPC for aggregation
        queryItems: queryItems,
        userToken: accessToken
    )

    guard statusCode == 200 else {
        return 0  // Graceful fallback
    }

    // Alternative: Create a Postgres function for this
    // For now, fetch all and sum locally
    let attachments = try JSONDecoder().decode([AttachmentDTO].self, from: data)
    return attachments.reduce(0) { $0 + Int64($1.file_size) }
}
```

**Note:** You'll need to create a Postgres function for efficient storage calculation:
```sql
CREATE OR REPLACE FUNCTION get_attachment_storage_used(p_user_id UUID)
RETURNS BIGINT AS $$
  SELECT COALESCE(SUM(file_size), 0)::BIGINT
  FROM event_attachments
  WHERE user_id = p_user_id;
$$ LANGUAGE SQL STABLE;
```

### Step 4: Data Sync & File Caching
**File:** `Managers/SupabaseDataManager.swift`

```swift
@Published var attachments: [String: [AttachmentDTO]] = [:]  // Keyed by event_identifier

// File caching helpers
private func getAttachmentsCacheDirectory() -> URL {
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
    let attachmentsDir = cacheDir.appendingPathComponent("Attachments", isDirectory: true)

    if !FileManager.default.fileExists(atPath: attachmentsDir.path) {
        try? FileManager.default.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)
    }

    return attachmentsDir
}

private func saveAttachmentLocally(fileData: Data, storagePath: String, context: NSManagedObjectContext) throws {
    let cacheDir = getAttachmentsCacheDirectory()
    let fileName = storagePath.replacingOccurrences(of: "/", with: "_")
    let localURL = cacheDir.appendingPathComponent(fileName)

    try fileData.write(to: localURL)

    // Update Core Data with local path
    let fetchRequest = Attachment.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "storagePath == %@", storagePath)
    if let attachment = try context.fetch(fetchRequest).first {
        attachment.localPath = localURL.path
        attachment.uploadStatus = "uploaded"
        try context.save()
    }
}

private func deleteLocalAttachment(storagePath: String) {
    let cacheDir = getAttachmentsCacheDirectory()
    let fileName = storagePath.replacingOccurrences(of: "/", with: "_")
    let localURL = cacheDir.appendingPathComponent(fileName)

    try? FileManager.default.removeItem(at: localURL)
}

func clearAttachmentCache() {
    let cacheDir = getAttachmentsCacheDirectory()
    try? FileManager.default.removeItem(at: cacheDir)
}

// Fetch attachments for event
func fetchAttachmentsForEvent(eventIdentifier: String) async {
    do {
        let attachments = try await supabaseManager.getAttachmentsForEvent(eventIdentifier: eventIdentifier)

        await MainActor.run {
            self.attachments[eventIdentifier] = attachments
        }

        // Update quota whenever we fetch
        await appSettingsManager.refreshStorageQuota()

        if let context = managedObjectContext {
            SupabaseDataSync.shared.syncAttachmentsFromSupabase(attachments, to: context)
        }
    } catch {
        print("Failed to fetch attachments: \(error)")
    }
}

// Upload attachment with all validations
func uploadAttachment(
    familyId: String,
    eventIdentifier: String,
    fileURL: URL
) async throws -> AttachmentDTO {
    let fileData = try Data(contentsOf: fileURL)
    let fileSizeMB = Double(fileData.count) / 1_048_576.0

    let fileName = fileURL.lastPathComponent
    let fileType = fileURL.mimeType

    // Validate file type (documents only)
    guard AttachmentViewModel.isAllowedFileType(fileType) else {
        throw AttachmentError.invalidFileType
    }

    // Check individual file size limit
    let maxFileSizeMB = appSettingsManager.isProUser ? 25 : 5
    guard fileSizeMB <= Double(maxFileSizeMB) else {
        throw AttachmentError.fileTooLarge(maxMB: maxFileSizeMB)
    }

    // Check total storage quota
    guard !appSettingsManager.isAtAttachmentStorageLimit else {
        throw AttachmentError.storageLimitReached
    }

    let fileName = fileURL.lastPathComponent
    let fileType = fileURL.mimeType

    var uploadedStoragePath: String?

    do {
        // Upload file to Storage
        let storagePath = try await supabaseManager.uploadAttachment(
            familyId: familyId,
            eventIdentifier: eventIdentifier,
            fileData: fileData,
            fileName: fileName,
            fileType: fileType
        )
        uploadedStoragePath = storagePath

        // Create metadata
        let attachment = try await supabaseManager.createAttachmentMetadata(
            familyId: familyId,
            eventIdentifier: eventIdentifier,
            fileName: fileName,
            fileSize: fileData.count,
            fileType: fileType,
            storagePath: storagePath
        )

        // Update quota
        await appSettingsManager.incrementStorageUsed(by: Int64(fileData.count))

        // Cache locally
        if let context = managedObjectContext {
            try saveAttachmentLocally(fileData: fileData, storagePath: storagePath, context: context)
        }

        // Sync to Core Data
        if let context = managedObjectContext {
            SupabaseDataSync.shared.syncAttachmentsFromSupabase([attachment], to: context)
        }

        return attachment

    } catch {
        // Cleanup orphaned file if metadata creation failed
        if let path = uploadedStoragePath {
            try? await supabaseManager.deleteAttachment(storagePath: path)
        }
        throw error
    }
}

// Delete attachment
func deleteAttachment(attachmentId: String, storagePath: String, fileSize: Int64) async throws {
    // Delete from Storage (ignore 404)
    do {
        try await supabaseManager.deleteAttachment(storagePath: storagePath)
    } catch let error as NSError where error.code == 404 {
        print("File already deleted from storage")
    }

    // Delete metadata (ignore 404)
    do {
        try await supabaseManager.deleteAttachmentMetadata(attachmentId: attachmentId)
    } catch let error as NSError where error.code == 404 {
        print("Metadata already deleted")
    }

    // Update quota
    await appSettingsManager.decrementStorageUsed(by: fileSize)

    // Delete local cache
    deleteLocalAttachment(storagePath: storagePath)

    // Update Core Data
    if let context = managedObjectContext {
        SupabaseDataSync.shared.deleteAttachment(attachmentId: attachmentId, from: context)
    }
}

// Retry pending uploads (for offline support)
func retryPendingUploads() async {
    guard let context = managedObjectContext else { return }

    let fetchRequest = Attachment.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "uploadStatus == %@", "pending")

    guard let pendingAttachments = try? context.fetch(fetchRequest) else { return }

    for attachment in pendingAttachments {
        // Re-upload logic would go here
        print("Retrying upload for: \(attachment.fileName ?? "unknown")")
    }
}
```

**File:** `Utilities/SupabaseDataSync.swift`

```swift
func syncAttachmentsFromSupabase(
    supabaseAttachments: [AttachmentDTO],
    to context: NSManagedObjectContext
) {
    // Follow existing pattern from syncFamilyMembersFromSupabase
    // Convert DTOs to Core Data Attachment entities
    // Handle updates/deletes
}
```

### Step 5: File Picker UI
**File:** `Views/Shared/FilePicker.swift`

```swift
import SwiftUI
import UniformTypeIdentifiers

struct FilePicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onFileSelected: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Only allow document types
        let documentTypes: [UTType] = [
            .pdf,
            .plainText,
            .rtf,
            .commaSeparatedText,
            UTType(filenameExtension: "doc")!,
            UTType(filenameExtension: "docx")!,
            UTType(filenameExtension: "xls")!,
            UTType(filenameExtension: "xlsx")!,
            UTType(filenameExtension: "ppt")!,
            UTType(filenameExtension: "pptx")!,
            UTType(filenameExtension: "pages")!,
            UTType(filenameExtension: "numbers")!,
            UTType(filenameExtension: "key")!
        ].compactMap { $0 }

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: documentTypes,
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    // Coordinator implementation
}
```

### Step 6: Attachment Row Component
**File:** `Views/Shared/AttachmentRow.swift`

```swift
struct AttachmentRow: View {
    let attachment: AttachmentViewModel
    let onDelete: () -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: attachment.fileIcon)
                .foregroundColor(.blue)
                .frame(width: 32, height: 32)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(attachment.fileSizeFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
```

### Step 7: QuickLook Preview
**File:** `Views/Shared/AttachmentPreview.swift`

```swift
import SwiftUI
import QuickLook

struct AttachmentPreview: UIViewControllerRepresentable {
    let fileURL: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(fileURL: fileURL)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let fileURL: URL

        init(fileURL: URL) {
            self.fileURL = fileURL
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            fileURL as QLPreviewItem
        }
    }
}
```

### Step 8: EventDetailView Integration
**File:** `Views/Events/EventDetailView.swift`

Add after checklistSection (around line 587):

```swift
private var attachmentsCard: some View {
    VStack(alignment: .leading, spacing: 10) {
        HStack {
            Text("Attachments")
                .font(.subheadline.weight(.semibold))
            Spacer()

            if !appSettingsManager.isProUser {
                Text("Pro")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }

            if attachments.count > 0 {
                Text("\(attachments.count)")
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }

        if attachments.isEmpty {
            Text("No attachments yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            VStack(spacing: 10) {
                ForEach(attachments) { attachment in
                    AttachmentRow(
                        attachment: attachment,
                        onDelete: { deleteAttachment(attachment) },
                        onTap: { previewAttachment(attachment) }
                    )
                }
            }
        }

        Button(action: {
            if appSettingsManager.isProUser || !appSettingsManager.isAtAttachmentStorageLimit {
                showingFilePicker = true
            } else {
                showingProUpsell = true
            }
        }) {
            Label("Add Attachment", systemImage: "paperclip")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .disabled(appSettingsManager.isAtAttachmentStorageLimit && !appSettingsManager.isProUser)
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
}

// State variables
@State private var attachments: [AttachmentViewModel] = []
@State private var showingFilePicker = false
@State private var showingProUpsell = false
@State private var previewURL: URL?
@State private var showingPreview = false

// Methods
private func loadAttachments() {
    Task {
        await supabaseDataManager.fetchAttachmentsForEvent(eventIdentifier: event.id)
        // Convert to view models
    }
}

private func uploadAttachment(fileURL: URL) {
    Task {
        try await supabaseDataManager.uploadAttachment(
            eventIdentifier: event.id,
            fileURL: fileURL
        )
        await loadAttachments()
    }
}

private func deleteAttachment(_ attachment: AttachmentViewModel) {
    Task {
        try await supabaseDataManager.deleteAttachment(
            attachmentId: attachment.id.uuidString,
            storagePath: attachment.storagePath
        )
        await loadAttachments()
    }
}

private func previewAttachment(_ attachment: AttachmentViewModel) {
    Task {
        if let localPath = attachment.localPath,
           FileManager.default.fileExists(atPath: localPath) {
            previewURL = URL(fileURLWithPath: localPath)
        } else {
            // Download from Supabase
            let data = try await supabaseDataManager.supabaseManager.downloadAttachment(
                storagePath: attachment.storagePath
            )
            let localURL = try saveToTempDirectory(data: data, fileName: attachment.fileName)
            previewURL = localURL
        }
        showingPreview = true
    }
}
```

Add to body VStack:
```swift
VStack(spacing: 14) {
    titleCard
    quickActionsCard
    checklistSection
    attachmentsCard  // ← NEW
    linkedCalendarsCompact
    mapSection
    deleteButton
}
```

Add sheets:
```swift
.sheet(isPresented: $showingFilePicker) {
    FilePicker(isPresented: $showingFilePicker) { fileURL in
        uploadAttachment(fileURL: fileURL)
    }
}
.sheet(isPresented: $showingPreview) {
    if let url = previewURL {
        AttachmentPreview(fileURL: url)
    }
}
.sheet(isPresented: $showingProUpsell) {
    FamCalProView()
}
```

### Step 9: Update Pro Feature Comparison
**File:** `Views/Shared/PremiumBannerView.swift`

Add to features array:
```swift
Feature(title: "Event attachments", freeValue: "50MB", proValue: "1GB", isBoolean: false)
```

### Step 10: Core Data Migration
**File:** `FamCal.xcdatamodeld/FamCal.xcdatamodel/contents`

Add new entity with attributes and create new model version for migration.

## Storage Limits

### Free Tier
- 50MB total storage
- Show storage usage in Settings
- Block uploads when limit reached
- Show Pro upsell

### Pro Tier
- 1GB total storage
- Show storage usage in Settings
- Warn at 90% usage

## Error Handling

1. **Storage limit reached** → Show Pro upsell
2. **Upload failure** → Retry with exponential backoff
3. **Download failure** → Show error, offer retry
4. **File too large** → Show size limit message
5. **Offline** → Queue upload for later

## Testing Checklist

- [ ] Upload various file types (PDF, images, docs)
- [ ] Preview files with QuickLook
- [ ] Delete attachments (both metadata and file)
- [ ] Free tier storage limit enforcement
- [ ] Pro tier storage tracking
- [ ] Offline upload queuing
- [ ] Multiple family members viewing same attachments
- [ ] Storage quota calculation accuracy

## Critical Implementation Notes

### Key Architectural Decisions

1. **Family-Scoped Storage**: Storage paths use `{family_id}/` instead of `{user_id}/` to enable simpler RLS policies and align with family-sharing model
2. **Quota Caching**: Storage usage cached in AppGroupDefaults and updated incrementally to avoid expensive recalculations
3. **Smart File Caching**: Files cached locally on first download with automatic cleanup
4. **Orphan Cleanup**: Upload failures trigger automatic cleanup of orphaned storage files
5. **404 Tolerance**: Delete operations ignore 404 errors to handle multi-device concurrent deletes

### Storage Limits

| Tier | Total Storage | Per-File Limit | Allowed Types |
|------|--------------|----------------|---------------|
| Free | 25MB | 5MB | Documents only |
| Pro | 250MB | 25MB | Documents only |

**Rationale**: Supabase Pro plan has 100GB total storage. With conservative 250MB per user limit, this supports 400 Pro users before hitting the limit.

### Database Setup Requirements

Before implementation, you must create in Supabase:

1. **Table**: `event_attachments` with `family_id` column
2. **RLS Policies**: Family-scoped read access, user-scoped write access
3. **Storage Bucket**: `event-attachments` (private)
4. **Storage RLS**: Family-scoped folder access
5. **Postgres Function**: `get_attachment_storage_used()` for efficient quota calculation

### Testing Priorities

**Must test before launch:**
- [ ] Family member A uploads, member B can view
- [ ] Storage quota updates correctly across devices
- [ ] Upload failure cleans up orphaned files
- [ ] Delete on Device A reflects on Device B
- [ ] Offline queue works when going from offline → online
- [ ] 10MB/100MB per-file limits enforced
- [ ] 50MB/1GB total quota enforced
- [ ] QuickLook preview works for PDF, images, docs
- [ ] Cache cleanup doesn't break active previews

## User Requirements (Confirmed)

1. ✅ Support multiple file selection at once
2. ✅ Free users: 25MB total, Pro users: 250MB total
3. ✅ On-demand download and caching
4. ✅ Show attachment count in calendar event list view
5. ✅ Supabase project exists with admin access
6. ✅ **Documents only** - no photos/videos/audio (PDF, Word, Excel, PowerPoint, Pages, Numbers, Keynote, text)

## Next Steps

1. Access Supabase MCP to check current schema and create attachment tables
2. Update plan with any necessary adjustments based on existing Supabase setup
3. Begin implementation starting with database schema and RLS policies
