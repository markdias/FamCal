import Foundation

// MARK: - DTOs for Supabase Communication

/// DTO for uploading attachment metadata to Supabase
struct AttachmentUploadDTO: Codable {
    let user_id: String
    let family_id: String
    let event_identifier: String
    let file_name: String
    let file_size: Int
    let file_type: String?
    let storage_path: String
    let uploaded_by: String?
}

/// DTO for receiving attachment data from Supabase
struct AttachmentResponseDTO: Codable, Identifiable {
    let id: String
    let user_id: String
    let family_id: String
    let event_identifier: String
    let file_name: String
    let file_size: Int
    let file_type: String?
    let storage_path: String
    let uploaded_at: String
    let uploaded_by: String?
    let created_at: String
    let updated_at: String
}

// MARK: - View Models

/// View model for displaying attachment information in UI
struct AttachmentViewModel: Identifiable {
    let id: String
    let fileName: String
    let fileSize: Int
    let fileSizeFormatted: String
    let fileType: String?
    let uploadedAt: Date
    let uploadedBy: String
    let storagePath: String
    let canDelete: Bool

    init(from dto: AttachmentResponseDTO, canDelete: Bool = false) {
        self.id = dto.id
        self.fileName = dto.file_name
        self.fileSize = dto.file_size
        self.fileSizeFormatted = Self.formatFileSize(dto.file_size)
        self.fileType = dto.file_type
        self.storagePath = dto.storage_path
        self.uploadedAt = ISO8601DateFormatter().date(from: dto.uploaded_at) ?? Date()
        self.uploadedBy = dto.uploaded_by ?? "Unknown"
        self.canDelete = canDelete
    }

    /// Format file size in human-readable format
    static func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    /// Get icon name based on file type
    var iconName: String {
        guard let fileType = fileType?.lowercased() else { return "doc" }

        switch fileType {
        case "application/pdf":
            return "doc.pdf"
        case "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            return "doc.text"
        case "application/vnd.ms-excel", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet":
            return "tablecells"
        case "application/vnd.ms-powerpoint", "application/vnd.openxmlformats-officedocument.presentationml.presentation":
            return "play.square"
        case "application/vnd.apple.pages", "text/plain", "text/rtf":
            return "doc.text"
        case "application/vnd.apple.numbers":
            return "tablecells"
        case "application/vnd.apple.keynote":
            return "play.square"
        default:
            return "doc"
        }
    }
}

// MARK: - Error Types

enum AttachmentError: LocalizedError {
    case invalidFileType
    case fileTooLarge(maxSize: Int)
    case quotaExceeded(used: Int, limit: Int)
    case networkError(String)
    case uploadFailed(String)
    case downloadFailed(String)
    case deleteFailed(String)
    case validationError(String)
    case storageError(String)
    case notFound
    case unauthorized
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidFileType:
            return "This file type is not supported. Only documents (PDF, Word, Excel, PowerPoint, Pages, Numbers, Keynote, and text files) are allowed."
        case .fileTooLarge(let maxSize):
            return "File size exceeds the maximum limit of \(AttachmentViewModel.formatFileSize(maxSize))."
        case .quotaExceeded(let used, let limit):
            return "Storage quota exceeded. You've used \(AttachmentViewModel.formatFileSize(used)) of \(AttachmentViewModel.formatFileSize(limit))."
        case .networkError(let message):
            return "Network error: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .deleteFailed(let message):
            return "Deletion failed: \(message)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .storageError(let message):
            return "Storage error: \(message)"
        case .notFound:
            return "File not found."
        case .unauthorized:
            return "You don't have permission to access this file."
        case .unknown(let message):
            return message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .invalidFileType:
            return "Try uploading a different document file."
        case .fileTooLarge:
            return "Compress the file or upgrade to Pro for higher limits."
        case .quotaExceeded:
            return "Delete unused attachments or upgrade to Pro for more storage."
        case .networkError:
            return "Check your internet connection and try again."
        case .uploadFailed, .downloadFailed, .deleteFailed:
            return "Try again later or contact support if the problem persists."
        case .unauthorized:
            return "Make sure you're a member of the correct family."
        default:
            return nil
        }
    }
}

// MARK: - File Type Validation

struct AttachmentFileTypeValidator {
    /// Supported file types for attachments
    static let allowedMimeTypes: Set<String> = [
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
        "text/rtf"
    ]

    /// File extensions supported
    static let allowedExtensions: Set<String> = [
        "pdf",
        "doc", "docx",
        "xls", "xlsx",
        "ppt", "pptx",
        "pages",
        "numbers",
        "keynote",
        "txt", "rtf"
    ]

    /// Validate if a file type is allowed
    static func isValidMimeType(_ mimeType: String) -> Bool {
        return allowedMimeTypes.contains(mimeType)
    }

    /// Validate if a file extension is allowed
    static func isValidExtension(_ fileExtension: String) -> Bool {
        return allowedExtensions.contains(fileExtension.lowercased())
    }

    /// Validate if a file is allowed based on its path
    static func isValidFile(at url: URL) -> Result<Void, AttachmentError> {
        let fileExtension = url.pathExtension.lowercased()

        if !isValidExtension(fileExtension) {
            return .failure(.invalidFileType)
        }

        return .success(())
    }

    /// Get MIME type from file extension
    static func mimeTypeForExtension(_ fileExtension: String) -> String? {
        let ext = fileExtension.lowercased()
        switch ext {
        case "pdf":
            return "application/pdf"
        case "doc":
            return "application/msword"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls":
            return "application/vnd.ms-excel"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt":
            return "application/vnd.ms-powerpoint"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "pages":
            return "application/vnd.apple.pages"
        case "numbers":
            return "application/vnd.apple.numbers"
        case "keynote":
            return "application/vnd.apple.keynote"
        case "txt":
            return "text/plain"
        case "rtf":
            return "text/rtf"
        default:
            return nil
        }
    }
}

// MARK: - Storage Quota Models

struct StorageQuota {
    let usedBytes: Int
    let limitBytes: Int

    var availableBytes: Int {
        max(0, limitBytes - usedBytes)
    }

    var percentageUsed: Double {
        limitBytes > 0 ? Double(usedBytes) / Double(limitBytes) : 0
    }

    var isExceeded: Bool {
        usedBytes > limitBytes
    }

    func canUpload(fileSize: Int) -> Bool {
        (usedBytes + fileSize) <= limitBytes
    }
}

// MARK: - Upload Request

struct AttachmentUploadRequest {
    let fileURL: URL
    let fileName: String
    let fileSize: Int
    let fileMimeType: String
    let eventIdentifier: String
    let familyId: String
}
