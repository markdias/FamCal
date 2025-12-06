import Foundation

struct MeetingLinkHelper {
    /// Returns a URL that can be opened for the given raw meeting link.
    /// Adds an `https://` prefix when the user omits a scheme.
    static func normalizedURL(from rawLink: String?) -> URL? {
        let trimmed = rawLink?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00a0}", with: "") // trim non-breaking spaces

        guard let cleaned = trimmed, !cleaned.isEmpty else {
            return nil
        }

        if let url = URL(string: cleaned), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(cleaned)")
    }

    /// Provides a concise label for the meeting link (e.g., "zoom.us" or the last path component).
    static func displayLabel(for link: String?) -> String {
        guard let link, let url = URL(string: link) else {
            return "Join meeting"
        }
        if let host = url.host?.replacingOccurrences(of: "www.", with: ""), !host.isEmpty {
            return host
        }
        if !url.lastPathComponent.isEmpty {
            return url.lastPathComponent
        }
        return "Join meeting"
    }
}
