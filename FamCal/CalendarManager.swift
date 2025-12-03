//
//  CalendarManager.swift
//  FamCal
//
//  Created by Mark Dias on 17/11/2025.
//

@preconcurrency import EventKit
import EventKitUI
import UIKit
import CoreData

// EventKit types are not marked Sendable, but we serialize access via `eventStoreQueue`.
extension EKEventStore: @unchecked @retroactive Sendable {}

struct AvailableCalendar {
    let id: String
    let title: String
    let color: UIColor
    let sourceTitle: String  // Account name (e.g., "iCloud", "Gmail")
    let sourceType: EKSourceType
}

struct UpcomingCalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let location: String?
    let meetingLink: String?
    let startDate: Date
    let endDate: Date
    let calendarID: String
    let calendarColor: UIColor
    let calendarTitle: String
    let hasRecurrence: Bool
    let recurrenceRule: EKRecurrenceRule?
    let isAllDay: Bool

    static func == (lhs: UpcomingCalendarEvent, rhs: UpcomingCalendarEvent) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.location == rhs.location &&
        lhs.meetingLink == rhs.meetingLink &&
        lhs.startDate == rhs.startDate &&
        lhs.endDate == rhs.endDate &&
        lhs.calendarID == rhs.calendarID &&
        lhs.calendarTitle == rhs.calendarTitle &&
        lhs.hasRecurrence == rhs.hasRecurrence &&
        lhs.isAllDay == rhs.isAllDay
    }
}
final class CalendarManager {
    static let shared = CalendarManager()

    private let eventStore = EKEventStore()
    private let eventStoreQueue = DispatchQueue(label: "com.famcal.eventstore", qos: .userInitiated)

    func resetStore() {
        print("🔄 CalendarManager: resetStore() called")
        eventStore.reset()
        print("✅ CalendarManager: eventStore.reset() completed")
    }

    func fetchAvailableCalendars() -> [AvailableCalendar] {
        let calendars = eventStore.calendars(for: .event)
        return calendars.map { calendar in
            let calendarColor: UIColor
            if let cgColor = calendar.cgColor {
                calendarColor = UIColor(cgColor: cgColor)
            } else {
                calendarColor = .systemBlue
            }

            return AvailableCalendar(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                color: calendarColor,
                sourceTitle: calendar.source.title,
                sourceType: calendar.source.sourceType
            )
        }
    }

    func findMatchingCalendar(for personName: String, in availableCalendars: [AvailableCalendar]) -> AvailableCalendar? {
        let lowercasedName = personName.lowercased()
        return availableCalendars.first { calendar in
            calendar.title.lowercased() == lowercasedName
        }
    }

    func createLocalCalendar(with name: String) -> AvailableCalendar? {
        print("🔵 Starting calendar creation for: \(name)")

        // List available sources for debugging
        let allSources = eventStore.sources
        print("📋 Available sources: \(allSources.map { "\($0.title) (\($0.sourceType.rawValue))" }.joined(separator: ", "))")

        // Prefer iCloud source, fall back to other sources
        var targetSource: EKSource?

        // Try iCloud first
        if let iCloudSource = allSources.first(where: { $0.sourceType == .calDAV && $0.title.contains("iCloud") }) {
            targetSource = iCloudSource
            print("✅ Found iCloud source: \(iCloudSource.title)")
        } else if let iCloudSource = allSources.first(where: { $0.sourceType == .calDAV }) {
            targetSource = iCloudSource
            print("✅ Found CalDAV source: \(iCloudSource.title)")
        } else if let localSource = allSources.first(where: { $0.sourceType == .local }) {
            targetSource = localSource
            print("✅ Found local source: \(localSource.title)")
        } else if !allSources.isEmpty {
            // Use the first available source
            targetSource = allSources.first
            print("⚠️ Using first available source: \(targetSource?.title ?? "Unknown")")
        }

        guard let source = targetSource else {
            print("❌ Could not find any calendar source")
            print("   Available source types: \(allSources.map { "\($0.sourceType.rawValue)" })")
            return nil
        }

        let calendar = EKCalendar(for: .event, eventStore: eventStore)
        calendar.title = name
        calendar.source = source

        // Set a default color for the calendar
        if #available(iOS 15.0, *) {
            calendar.cgColor = UIColor.systemBlue.cgColor
        }

        print("📍 Calendar object created, attempting to save...")

        do {
            try eventStore.saveCalendar(calendar, commit: true)
            print("✅ Calendar saved to EventKit")
            print("   Calendar ID: \(calendar.calendarIdentifier)")
            print("   Calendar title: \(calendar.title)")

            // Give the system a moment to register the new calendar
            Thread.sleep(forTimeInterval: 0.1)

            // Refresh calendars from store to get the updated list
            let updatedCalendars = eventStore.calendars(for: .event)
            print("📊 Refreshed calendar list, total calendars: \(updatedCalendars.count)")

            if let savedCalendar = updatedCalendars.first(where: { $0.calendarIdentifier == calendar.calendarIdentifier }) {
                print("✅ Found newly created calendar in refreshed list by ID")

                let calendarColor: UIColor
                if let cgColor = savedCalendar.cgColor {
                    calendarColor = UIColor(cgColor: cgColor)
                } else {
                    calendarColor = .systemBlue
                }

                let result = AvailableCalendar(
                    id: savedCalendar.calendarIdentifier,
                    title: savedCalendar.title,
                    color: calendarColor,
                    sourceTitle: savedCalendar.source.title,
                    sourceType: savedCalendar.source.sourceType
                )

                print("✅ Successfully created and returned AvailableCalendar: \(result.title)")
                return result
            }

            // Fallback: try to find by title in case the ID changed
            print("⚠️ Not found by ID, trying fallback search by title...")
            if let savedCalendar = updatedCalendars.first(where: { $0.title.lowercased() == name.lowercased() }) {
                print("✅ Found calendar by title match in fallback")

                let calendarColor: UIColor
                if let cgColor = savedCalendar.cgColor {
                    calendarColor = UIColor(cgColor: cgColor)
                } else {
                    calendarColor = .systemBlue
                }

                let result = AvailableCalendar(
                    id: savedCalendar.calendarIdentifier,
                    title: savedCalendar.title,
                    color: calendarColor,
                    sourceTitle: savedCalendar.source.title,
                    sourceType: savedCalendar.source.sourceType
                )

                print("✅ Successfully created and returned AvailableCalendar via fallback: \(result.title)")
                return result
            }

            print("⚠️ Calendar created but not found in updated list")
            print("   Looking for ID: \(calendar.calendarIdentifier)")
            print("   Looking for title: \(name)")
            print("   Available calendars: \(updatedCalendars.map { "\($0.title) (\($0.calendarIdentifier))" })")
            return nil
        } catch {
            print("❌ Error creating calendar: \(error.localizedDescription)")
            if let ekError = error as? EKError {
                print("   EKError code: \(ekError.errorCode)")
                print("   EKError: \(ekError)")
            }
            return nil
        }
    }

    // MARK: - Private Helper Method for Robust Event Lookup

    private func findEvent(withIdentifier identifier: String, occurrenceStartDate: Date? = nil) -> EKEvent? {
        let calendars = eventStore.calendars(for: .event)

        if let occurrenceDate = occurrenceStartDate {
            // Tight search window around the specific occurrence start time
            let searchStart = occurrenceDate.addingTimeInterval(-300) // 5 min before
            let searchEnd = occurrenceDate.addingTimeInterval(300) // 5 min after
            let predicate = eventStore.predicateForEvents(
                withStart: searchStart,
                end: searchEnd,
                calendars: calendars
            )
            let matches = eventStore.events(matching: predicate)
            if let occurrence = matches.first(where: {
                $0.eventIdentifier == identifier &&
                abs($0.startDate.timeIntervalSince(occurrenceDate)) < 1
            }) {
                return occurrence
            }
        }

        // The event(withIdentifier:) method doesn't always work reliably, but try it next
        if let event = eventStore.event(withIdentifier: identifier) {
            // If we were looking for a specific occurrence, make sure the dates match before returning
            if let occurrenceDate = occurrenceStartDate {
                if abs(event.startDate.timeIntervalSince(occurrenceDate)) < 1 {
                    return event
                }
            } else {
                return event
            }
        }

        // Fallback: search through all event calendars
        for calendar in calendars {
            let predicate = eventStore.predicateForEvents(withStart: Date(timeIntervalSince1970: 0),
                                                           end: Date(timeIntervalSince1970: Date().timeIntervalSince1970 + 86400 * 365 * 2),
                                                           calendars: [calendar])
            let events = eventStore.events(matching: predicate)
            if let event = events.first(where: {
                guard $0.eventIdentifier == identifier else { return false }
                if let occurrenceDate = occurrenceStartDate {
                    return abs($0.startDate.timeIntervalSince(occurrenceDate)) < 1
                }
                return true
            }) {
                return event
            }
        }

        return nil
    }

    func fetchEventDetails(withIdentifier identifier: String, occurrenceStartDate: Date? = nil) -> EKEvent? {
        return findEvent(withIdentifier: identifier, occurrenceStartDate: occurrenceStartDate)
    }

    func fetchNextEventsAsync(for calendarIDs: [String], limit: Int, pastDays: Int = 90, futureDays: Int = 180) async -> [UpcomingCalendarEvent] {
        // Offload heavy EventKit queries to a background queue to avoid blocking the main actor
        return await withCheckedContinuation { continuation in
            let store = eventStore
            let ids = calendarIDs
            eventStoreQueue.async {
                let results = Self.fetchNextEvents(
                    in: store,
                    calendarIDs: ids,
                    limit: limit,
                    pastDays: pastDays,
                    futureDays: futureDays
                )
                continuation.resume(returning: results)
            }
        }
    }

    func fetchNextEvents(for calendarIDs: [String], limit: Int, pastDays: Int = 90, futureDays: Int = 180) -> [UpcomingCalendarEvent] {
        Self.fetchNextEvents(
            in: eventStore,
            calendarIDs: calendarIDs,
            limit: limit,
            pastDays: pastDays,
            futureDays: futureDays
        )
    }

    private static func fetchNextEvents(in store: EKEventStore, calendarIDs: [String], limit: Int, pastDays: Int, futureDays: Int) -> [UpcomingCalendarEvent] {
        let calendars = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        guard !calendars.isEmpty else { return [] }

        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -pastDays, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .day, value: futureDays, to: Date()) ?? Date()

        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        var results: [UpcomingCalendarEvent] = []

        for event in events {
            // Filter out soft-deleted events (marked as not attending)
            if isSoftDeletedEvent(eventIdentifier: event.eventIdentifier) {
                print("⊘ Filtering out soft-deleted event: \(event.title ?? "Unknown") (\(event.eventIdentifier ?? "Unknown"))")
                continue
            }

            let calendarColor = event.calendar.cgColor.map { UIColor(cgColor: $0) } ?? .systemBlue

            let upcomingEvent = UpcomingCalendarEvent(
                id: event.eventIdentifier,
                title: event.title,
                location: event.location,
                meetingLink: event.url?.absoluteString,
                startDate: event.startDate,
                endDate: event.endDate,
                calendarID: event.calendar.calendarIdentifier,
                calendarColor: calendarColor,
                calendarTitle: event.calendar.title,
                hasRecurrence: event.hasRecurrenceRules,
                recurrenceRule: event.recurrenceRules?.first,
                isAllDay: event.isAllDay
            )
            results.append(upcomingEvent)

            if limit > 0 && results.count >= limit {
                break
            }
        }

        return results
    }

    /// Check if an event is soft-deleted (marked as not attending)
    private static func isSoftDeletedEvent(eventIdentifier: String) -> Bool {
        let viewContext = PersistenceController.shared.container.viewContext
        let fetchRequest = FamilyEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@ AND isAttending == false", eventIdentifier)

        do {
            let results = try viewContext.fetch(fetchRequest)
            return !results.isEmpty
        } catch {
            print("⚠️ Error checking soft delete status for event \(eventIdentifier): \(error.localizedDescription)")
            return false
        }
    }

    func calculateRecurringOccurrences(startDate: Date, endDate: Date, recurrenceRule: EKRecurrenceRule?, upcomingEvents: [UpcomingCalendarEvent], currentEventId: String, eventTitle: String, limit: Int) -> [Date] {
        guard let rule = recurrenceRule else { return [] }

        var occurrences: [Date] = []
        let calendar = Calendar.current
        let duration = endDate.timeIntervalSince(startDate)

        // Find the next event with a DIFFERENT title chronologically
        let futureEvents = upcomingEvents.filter { $0.startDate > startDate && $0.title != eventTitle }
        let nextDifferentEvent = futureEvents.min { $0.startDate < $1.startDate }

        // Calculate end limit - either when the next different event occurs or 365 days out
        let endLimit = nextDifferentEvent?.startDate ?? calendar.date(byAdding: .day, value: 365, to: startDate) ?? startDate

        // Generate occurrences based on frequency
        var currentDate = startDate
        var count = 0

        while count < limit && currentDate < endLimit {
            // Calculate next occurrence date
            let nextOccurrence = getNextOccurrence(from: currentDate, using: rule)

            // If the occurrence end time would conflict with the next different event, stop
            let occurrenceEnd = nextOccurrence.addingTimeInterval(duration)
            if let nextEvent = nextDifferentEvent, occurrenceEnd > nextEvent.startDate {
                break
            }

            // Skip the first occurrence since it's shown as the header
            if nextOccurrence > startDate {
                occurrences.append(nextOccurrence)
                count += 1
            }

            currentDate = nextOccurrence
        }

        return occurrences
    }

    private func getNextOccurrence(from date: Date, using rule: EKRecurrenceRule) -> Date {
        let calendar = Calendar.current
        let interval = rule.interval

        switch rule.frequency {
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date) ?? date
        @unknown default:
            return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        }
    }

    func createEvent(title: String, startDate: Date, endDate: Date, location: String?, notes: String?, meetingLink: String? = nil, isAllDay: Bool = false, in calendarID: String, alertOption: AlertOption? = nil) -> String? {
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.url = MeetingLinkHelper.normalizedURL(from: meetingLink)
        event.isAllDay = isAllDay
        event.calendar = calendar

        // Add alarm if alertOption is provided
        if let alertOption = alertOption {
            event.alarms = [] // Clear any default alarms
            let alarm = createAlarm(from: alertOption)
            event.addAlarm(alarm)
        }

        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Error saving event: \(error.localizedDescription)")
            return nil
        }
    }

    func createRecurringEvent(title: String, startDate: Date, endDate: Date, location: String?, notes: String?, meetingLink: String? = nil, recurrenceRule: EKRecurrenceRule, isAllDay: Bool = false, in calendarID: String, alertOption: AlertOption? = nil) -> String? {
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else { return nil }

        let event = EKEvent(eventStore: eventStore)
        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.url = MeetingLinkHelper.normalizedURL(from: meetingLink)
        event.isAllDay = isAllDay
        event.addRecurrenceRule(recurrenceRule)
        event.calendar = calendar

        // Add alarm if alertOption is provided
        if let alertOption = alertOption {
            event.alarms = [] // Clear any default alarms
            let alarm = createAlarm(from: alertOption)
            event.addAlarm(alarm)
        }

        do {
            try eventStore.save(event, span: .futureEvents)
            return event.eventIdentifier
        } catch {
            print("Error saving recurring event: \(error.localizedDescription)")
            return nil
        }
    }

    func updateEvent(withIdentifier identifier: String,
                     occurrenceStartDate: Date?,
                     in calendarID: String,
                     title: String,
                     startDate: Date,
                     endDate: Date,
                     location: String?,
                     notes: String?,
                     meetingLink: String? = nil,
                     isAllDay: Bool = false,
                     recurrenceRule: EKRecurrenceRule? = nil,
                     updateRecurrence: Bool = false,
                     span: EKSpan = .thisEvent,
                     alertOption: AlertOption? = nil) -> Bool {
        // First, find the specific calendar
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else {
            print("❌ Could not find calendar with ID: \(calendarID)")
            return false
        }

        print("📍 Searching for event in calendar: \(calendar.title)")

        // Try to find the event using robust lookup (direct + fallback search)
        guard let event = findEvent(withIdentifier: identifier, occurrenceStartDate: occurrenceStartDate) else {
            print("❌ Could not find event with identifier: \(identifier) in calendar: \(calendar.title)")
            // List available calendars for debugging
            let allCals = eventStore.calendars(for: .event)
            print("   Available calendars: \(allCals.map { "\($0.title) (\($0.calendarIdentifier))" }.joined(separator: ", "))")
            return false
        }

        // Verify the event is in the correct calendar (safely access event.calendar)
        let eventCalendarID = event.calendar.calendarIdentifier
        guard eventCalendarID == calendarID else {
            print("❌ Event found but in wrong calendar!")
            print("   Expected calendar: \(calendarID)")
            print("   Actual calendar: \(eventCalendarID)")
            return false
        }

        print("✅ Found event: \(event.title ?? "Unknown") in calendar: \(event.calendar.title)")

        event.title = title
        event.startDate = startDate
        event.endDate = endDate
        event.location = location
        event.notes = notes
        event.url = MeetingLinkHelper.normalizedURL(from: meetingLink)
        event.isAllDay = isAllDay
        if updateRecurrence {
            if let recurrenceRule = recurrenceRule {
                event.recurrenceRules = [recurrenceRule]
            } else {
                event.recurrenceRules = []
            }
        }

        // Update alarm if alertOption is provided
        if let alertOption = alertOption {
            let alarm = createAlarm(from: alertOption)
            event.alarms?.removeAll()
            event.addAlarm(alarm)
        }

        do {
            try eventStore.save(event, span: span)
            print("✅ Event updated successfully")
            return true
        } catch {
            print("❌ Error updating event: \(error.localizedDescription)")
            // Log the underlying error details
            if let ekError = error as? EKError {
                print("   EKError code: \(ekError.errorCode)")
            }
            return false
        }
    }

    func getEvent(withIdentifier identifier: String) -> EKEvent? {
        return findEvent(withIdentifier: identifier)
    }

    func getCalendar(withIdentifier calendarID: String) -> EKCalendar? {
        return eventStore.calendar(withIdentifier: calendarID)
    }

    private func createAlarm(from alertOption: AlertOption) -> EKAlarm {
        let alarm = EKAlarm()

        switch alertOption {
        case .none:
            alarm.relativeOffset = 0
        case .atTime:
            alarm.relativeOffset = 0
        case .fifteenMinsBefore:
            alarm.relativeOffset = -900  // -15 minutes in seconds
        case .oneHourBefore:
            alarm.relativeOffset = -3600  // -1 hour in seconds
        case .oneDayBefore:
            alarm.relativeOffset = -86400  // -1 day in seconds
        case .custom:
            alarm.relativeOffset = 0
        }

        return alarm
    }

    func deleteCalendar(withIdentifier calendarID: String) -> Bool {
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else {
            print("❌ Could not find calendar with ID: \(calendarID)")
            return false
        }

        do {
            try eventStore.removeCalendar(calendar, commit: true)
            print("✅ Calendar deleted successfully: \(calendar.title)")
            return true
        } catch {
            print("❌ Error deleting calendar: \(error.localizedDescription)")
            if let ekError = error as? EKError {
                print("   EKError code: \(ekError.errorCode)")
            }
            return false
        }
    }

    func deleteEvent(withIdentifier identifier: String,
                     occurrenceStartDate: Date?,
                     from calendarID: String,
                     span: EKSpan = .thisEvent) -> Bool {
        // First, find the specific calendar
        guard let calendar = eventStore.calendar(withIdentifier: calendarID) else {
            print("❌ Could not find calendar with ID: \(calendarID)")
            return false
        }

        print("📍 Searching for event to delete in calendar: \(calendar.title)")

        // Try to find the event using robust lookup (direct + fallback search)
        guard let event = findEvent(withIdentifier: identifier, occurrenceStartDate: occurrenceStartDate) else {
            print("❌ Could not find event to delete with identifier: \(identifier) in calendar: \(calendar.title)")
            // List available calendars for debugging
            let allCals = eventStore.calendars(for: .event)
            print("   Available calendars: \(allCals.map { "\($0.title) (\($0.calendarIdentifier))" }.joined(separator: ", "))")
            return false
        }

        // Verify the event is in the correct calendar (safely access event.calendar)
        let eventCalendarID = event.calendar.calendarIdentifier
        guard eventCalendarID == calendarID else {
            print("❌ Event found but in wrong calendar!")
            print("   Expected calendar: \(calendarID)")
            print("   Actual calendar: \(eventCalendarID)")
            return false
        }

        print("✅ Found event to delete: \(event.title ?? "Unknown") in calendar: \(event.calendar.title)")

        do {
            try eventStore.remove(event, span: span)
            print("✅ Event deleted successfully")
            return true
        } catch {
            print("❌ Error deleting event: \(error.localizedDescription)")
            // Log the underlying error details
            if let ekError = error as? EKError {
                print("   EKError code: \(ekError.errorCode)")
            }
            return false
        }
    }

    /// Ensure an event has the provided recurrence rule; useful when some providers drop recurrence on create.
    func enforceRecurrence(for identifier: String,
                           occurrenceStartDate: Date?,
                           in calendarID: String,
                           recurrenceRule: EKRecurrenceRule) -> Bool {
        guard eventStore.calendar(withIdentifier: calendarID) != nil else {
            print("❌ enforceRecurrence: Could not find calendar \(calendarID)")
            return false
        }

        // Try to locate the event (with or without occurrence date, since some providers need nil)
        let event: EKEvent? = findEvent(withIdentifier: identifier, occurrenceStartDate: occurrenceStartDate)
            ?? findEvent(withIdentifier: identifier, occurrenceStartDate: nil)
            ?? eventStore.event(withIdentifier: identifier)

        guard let event else {
            print("❌ enforceRecurrence: Could not find event \(identifier) in calendar \(calendarID)")
            return false
        }

        guard event.calendar.calendarIdentifier == calendarID else {
            print("❌ enforceRecurrence: Event \(identifier) is in calendar \(event.calendar.calendarIdentifier), expected \(calendarID)")
            return false
        }

        event.recurrenceRules = [recurrenceRule]

        do {
            try eventStore.save(event, span: .futureEvents)
            print("✅ enforceRecurrence: Applied recurrence to event \(identifier) in calendar \(calendarID)")
            return true
        } catch {
            print("❌ enforceRecurrence: Failed to save recurrence for event \(identifier) in calendar \(calendarID) - \(error.localizedDescription)")
            if let ekError = error as? EKError {
                print("   EKError code: \(ekError.errorCode)")
            }
            return false
        }
    }
}
