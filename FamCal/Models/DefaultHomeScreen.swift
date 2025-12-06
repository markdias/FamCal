import Foundation

enum DefaultHomeScreen: String, CaseIterable, Identifiable {
    case family
    case calendarMonth
    case calendarDay

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .family:
            return "Family view"
        case .calendarMonth:
            return "Calendar (Month)"
        case .calendarDay:
            return "Calendar (Day)"
        }
    }

    var description: String {
        switch self {
        case .family:
            return "Start on the main Family view"
        case .calendarMonth:
            return "Open the Calendar in month view"
        case .calendarDay:
            return "Open the Calendar in day view"
        }
    }
}
