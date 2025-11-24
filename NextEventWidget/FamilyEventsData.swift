//
//  FamilyEventsData.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import WidgetKit

/// Event item for family events list
struct EventItem: Codable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let memberName: String
    let memberColorHex: String
    let calendarColorHex: String
    let location: String?
}

/// Timeline entry for family events widget
struct FamilyEventsEntry: TimelineEntry {
    let date: Date
    let events: [EventItem]
    let errorMessage: String?
    let maxEvents: Int
    let showTime: Bool
    let showLocation: Bool
    let showAttendees: Bool
    let showDrivers: Bool
    let isAuthenticated: Bool

    /// Initialize with event list
    init(date: Date = Date(), events: [EventItem], maxEvents: Int = 10, showTime: Bool = true, showLocation: Bool = true, showAttendees: Bool = true, showDrivers: Bool = true) {
        self.date = date
        self.events = events
        self.maxEvents = maxEvents
        self.errorMessage = nil
        self.showTime = showTime
        self.showLocation = showLocation
        self.showAttendees = showAttendees
        self.showDrivers = showDrivers
        self.isAuthenticated = true
    }

    /// Initialize with error
    init(date: Date = Date(), errorMessage: String, isAuthenticated: Bool = true) {
        self.date = date
        self.events = []
        self.maxEvents = 10
        self.errorMessage = errorMessage
        self.showTime = true
        self.showLocation = true
        self.showAttendees = true
        self.showDrivers = true
        self.isAuthenticated = isAuthenticated
    }

    /// Initialize as placeholder
    init(date: Date = Date()) {
        self.date = date
        self.events = []
        self.maxEvents = 10
        self.errorMessage = nil
        self.showTime = true
        self.showLocation = true
        self.showAttendees = true
        self.showDrivers = true
        self.isAuthenticated = true
    }
}
