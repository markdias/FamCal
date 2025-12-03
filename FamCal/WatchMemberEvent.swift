import Foundation

/// Shared model for the watch interface to describe the upcoming event per member.
struct WatchMemberEvent: Codable, Identifiable {
    let memberId: UUID
    let memberName: String
    let memberColorHex: String
    let calendarColorHex: String
    let calendarTitle: String?
    let eventTitle: String?
    let eventIdentifier: String?
    let startDate: Date?
    let endDate: Date?
    let location: String?
    let attendees: [String]

    var id: String {
        memberId.uuidString
    }

    var hasEvent: Bool {
        eventTitle != nil && startDate != nil
    }
}
