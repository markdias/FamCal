//
//  EventEnums.swift
//  FamCal
//
//  Created by Claude on 2025-11-20.
//

import Foundation

enum RepeatOption: String, CaseIterable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
}

enum AlertOption: String, CaseIterable, Identifiable {
    case none = "None"
    case atTime = "At time of event"
    case fifteenMinsBefore = "15 minutes before"
    case oneHourBefore = "1 hour before"
    case oneDayBefore = "1 day before"
    case custom = "Custom"

    var id: String { rawValue }
}

enum ShowAsOption: String, CaseIterable, Codable {
    case busy = "Busy"
    case free = "Free"
}
