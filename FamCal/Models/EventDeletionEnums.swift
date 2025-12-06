import Foundation

// MARK: - Deletion Type
enum DeletionType: String, Codable {
    case hard = "hard"        // Permanent deletion from EventKit and CoreData
    case soft = "soft"        // Marked as not attending, event remains
}

// MARK: - Deletion Scope
enum DeleteScope: CaseIterable {
    case singleCalendar       // Delete only in this person's calendar
    case allLinked            // Delete in all linked calendars

    var displayName: String {
        switch self {
        case .singleCalendar:
            return "This calendar only"
        case .allLinked:
            return "All linked calendars"
        }
    }
}

// MARK: - Deletion Target
enum DeletionTarget: CaseIterable {
    case singleOccurrence     // Delete/mark this occurrence only
    case thisAndFuture        // Delete/mark this and all future occurrences
    case allInSeries          // Delete/mark entire recurrence

    var displayName: String {
        switch self {
        case .singleOccurrence:
            return "This event only"
        case .thisAndFuture:
            return "This and future events"
        case .allInSeries:
            return "All events in series"
        }
    }
}

// MARK: - Delete Action Type
enum DeleteActionType: CaseIterable {
    case hardDelete           // Permanent removal from calendar
    case softDelete           // Mark isAttending=false

    var displayName: String {
        switch self {
        case .hardDelete:
            return "Delete permanently"
        case .softDelete:
            return "Mark as not attending"
        }
    }
}

// MARK: - Deletion Context
struct DeletionContext {
    let scope: DeleteScope
    let target: DeletionTarget
    let actionType: DeleteActionType
    let affectedPeople: [String]  // Names of affected family members
    let linkedEventCount: Int
    let personName: String?       // Single person being affected (if applicable)
    let isRecurring: Bool

    // Event details for confirmation
    let eventTitle: String?
    let eventDate: String?
    let eventTime: String?
    let eventLocation: String?

    private var eventDetailsSection: String {
        var details = ""

        if let title = eventTitle {
            details += "📅 \(title)\n"
        }

        if let date = eventDate {
            details += "📆 \(date)"
            if let time = eventTime {
                details += " at \(time)"
            }
            details += "\n"
        }

        if let location = eventLocation, !location.isEmpty {
            details += "📍 \(location)\n"
        }

        return details.isEmpty ? "" : details + "\n"
    }

    var displayMessage: String {
        let eventDetails = eventDetailsSection

        switch (scope, target, actionType) {
        case (.allLinked, .singleOccurrence, .hardDelete):
            if affectedPeople.count == 1 {
                return "\(eventDetails)Delete '\(affectedPeople[0])'s event for all \(linkedEventCount) people?\n\nThe rest of the recurring series continues."
            }
            return "\(eventDetails)Delete this event for all \(linkedEventCount) people?\n\nThe rest of the recurring series continues."

        case (.singleCalendar, .singleOccurrence, .softDelete):
            if let person = personName {
                return "\(eventDetails)Mark \(person) as not attending this event?\n\nOthers keep their copies."
            }
            return "\(eventDetails)Mark as not attending this event?"

        case (.singleCalendar, .singleOccurrence, .hardDelete):
            if let person = personName {
                return "\(eventDetails)Remove \(person) from this event?\n\nOthers keep their copies."
            }
            return "\(eventDetails)Delete from this event?"

        case (.allLinked, .allInSeries, .hardDelete):
            return "\(eventDetails)Delete this entire recurring event for all \(linkedEventCount) people?\n\nThis cannot be undone."

        case (.singleCalendar, .allInSeries, .softDelete):
            if let person = personName {
                return "\(eventDetails)Mark \(person) as not attending all \(affectedPeople.count) instances of this recurring event?"
            }
            return "\(eventDetails)Mark as not attending all instances?"

        case (.singleCalendar, .allInSeries, .hardDelete):
            if let person = personName {
                return "\(eventDetails)Remove \(person) from all \(affectedPeople.count) instances of this recurring event?\n\nThis cannot be undone."
            }
            return "\(eventDetails)Delete from all instances?"

        case (.singleCalendar, .thisAndFuture, .softDelete):
            if let person = personName {
                return "\(eventDetails)Mark \(person) as not attending this event and all future occurrences?"
            }
            return "\(eventDetails)Mark as not attending this and future events?"

        case (.singleCalendar, .thisAndFuture, .hardDelete):
            if let person = personName {
                return "\(eventDetails)Remove \(person) from this event and all future occurrences?\n\nThis cannot be undone."
            }
            return "\(eventDetails)Delete from this and future events?"

        case (.allLinked, .thisAndFuture, .hardDelete):
            return "\(eventDetails)Delete this event and all future occurrences for all \(linkedEventCount) people?\n\nThis cannot be undone."

        default:
            return "\(eventDetails)Delete event?"
        }
    }

    var actionButtonTitle: String {
        switch actionType {
        case .hardDelete:
            return "Delete"
        case .softDelete:
            return "Mark as Not Attending"
        }
    }
}
