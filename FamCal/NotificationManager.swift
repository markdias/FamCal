//
//  NotificationManager.swift
//  FamCal
//
//  Created by Mark Dias on 20/11/2025.
//

import Foundation
import Combine
import UserNotifications
import EventKit
import CoreData
import UIKit
import MapKit
import CoreLocation

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    @Published var notificationsEnabled = false
    @Published var morningBriefEnabled = false
    @Published var morningBriefTime = TimeComponents(hour: 8, minute: 0)
    @Published var selectedMembersForNotifications: Set<UUID> = []
    @Published var selectedCalendarsForNotifications: Set<String> = []

    private struct CalendarOwnerInfo {
        let memberId: UUID?
        let displayName: String
    }

    private static let briefTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private let userDefaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()

    // UserDefaults keys
    private let enabledKey = "notificationsEnabled"
    private let morningBriefEnabledKey = "morningBriefEnabled"
    private let morningBriefTimeKey = "morningBriefTime"
    private let selectedMembersKey = "selectedMembersForNotifications"
    private let selectedCalendarsKey = "selectedCalendarsForNotifications"

    override init() {
        super.init()
        loadSettings()
        notificationCenter.delegate = self
        Task {
            await syncNotificationPermission()
        }
    }

    // MARK: - Permission Handling

    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.notificationsEnabled = granted
                AppSettingsManager.shared.notificationsEnabled = granted
                if granted {
                    saveSettings()
                    // Also auto-enable morning brief when user grants notification permission
                    AppSettingsManager.shared.morningBriefEnabled = true
                    Task { await AppSettingsManager.shared.saveSettings() }
                    print("✅ Notifications enabled. Auto-enabling morning brief...")
                }
            }
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }

    func checkNotificationPermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral
    }

    @MainActor
    private func syncNotificationPermission() async {
        let settings = await notificationCenter.notificationSettings()
        if settings.authorizationStatus == .authorized && notificationsEnabled == false {
            notificationsEnabled = true
            AppSettingsManager.shared.notificationsEnabled = true
            saveSettings()
        }
    }

    // MARK: - Settings Management

    private func loadSettings() {
        notificationsEnabled = userDefaults.bool(forKey: enabledKey)
        morningBriefEnabled = userDefaults.bool(forKey: morningBriefEnabledKey)

        if let timeData = userDefaults.data(forKey: morningBriefTimeKey),
           let decoded = try? JSONDecoder().decode(TimeComponents.self, from: timeData) {
            morningBriefTime = decoded
        }

        if let membersData = userDefaults.data(forKey: selectedMembersKey),
           let decoded = try? JSONDecoder().decode([String].self, from: membersData) {
            selectedMembersForNotifications = Set(decoded.compactMap(UUID.init))
        }

        if let calendarsData = userDefaults.data(forKey: selectedCalendarsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: calendarsData) {
            selectedCalendarsForNotifications = Set(decoded)
        }
    }

    func saveSettings() {
        userDefaults.set(notificationsEnabled, forKey: enabledKey)
        userDefaults.set(morningBriefEnabled, forKey: morningBriefEnabledKey)

        if let encoded = try? JSONEncoder().encode(morningBriefTime) {
            userDefaults.set(encoded, forKey: morningBriefTimeKey)
        }

        let memberIds = selectedMembersForNotifications.map { $0.uuidString }
        if let encoded = try? JSONEncoder().encode(memberIds) {
            userDefaults.set(encoded, forKey: selectedMembersKey)
        }

        let calendars = Array(selectedCalendarsForNotifications)
        if let encoded = try? JSONEncoder().encode(calendars) {
            userDefaults.set(encoded, forKey: selectedCalendarsKey)
        }
    }

    // MARK: - Event Notification Scheduling

    func scheduleEventNotification(
        event: EKEvent,
        alertOption: AlertOption,
        familyMembers: [String] = [],
        drivers: String? = nil,
        location: String? = nil,
        isSharedCalendarEvent: Bool = false
    ) {
        Task {
            guard await ensureNotificationPermission() else { return }
            scheduleEventNotificationNow(
                event: event,
                alertOption: alertOption,
                familyMembers: familyMembers,
                drivers: drivers,
                location: location,
                isSharedCalendarEvent: isSharedCalendarEvent
            )
        }
    }

    @discardableResult
    private func ensureNotificationPermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        let isAuthorized = settings.authorizationStatus == .authorized
            || settings.authorizationStatus == .provisional
            || settings.authorizationStatus == .ephemeral

        if !notificationsEnabled {
            if isAuthorized {
                print("✅ System permission already granted, enabling notifications in app...")
                await MainActor.run {
                    self.notificationsEnabled = true
                    AppSettingsManager.shared.notificationsEnabled = true
                    self.saveSettings()
                }
                return true
            }

            print("🔔 Notifications disabled in app settings, requesting permission...")
            let granted = await self.requestNotificationPermission()
            if !granted {
                await MainActor.run {
                    self.notificationsEnabled = false
                    AppSettingsManager.shared.notificationsEnabled = false
                    self.saveSettings()
                }
            }
            return granted
        }

        if !isAuthorized {
            print("⚠️ Notifications enabled in app but denied at system level. Prompting again...")
            let granted = await self.requestNotificationPermission()
            if !granted {
                await MainActor.run {
                    self.notificationsEnabled = false
                    AppSettingsManager.shared.notificationsEnabled = false
                    self.saveSettings()
                }
            }
            return granted
        }

        return true
    }

    private func scheduleEventNotificationNow(
        event: EKEvent,
        alertOption: AlertOption,
        familyMembers: [String],
        drivers: String?,
        location: String?,
        isSharedCalendarEvent: Bool
    ) {
        // Schedule a local notification for immediate feedback
        let triggerDate = calculateTriggerDate(from: event.startDate, alertOption: alertOption)

        // Validate trigger date is in the future
        let now = Date()
        guard triggerDate > now else {
            print("⚠️ Event notification skipped - trigger date (\(triggerDate)) is in the past (now: \(now))")
            return
        }

        // Build notification content
        let title = event.title ?? "Event"

        var body = ""
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        body = timeFormatter.string(from: event.startDate)

        // Add family members to body - only show if shared calendar event or multiple members
        if !familyMembers.isEmpty && (isSharedCalendarEvent || familyMembers.count > 1) {
            body += "\nWith: \(familyMembers.joined(separator: ", "))"
        }

        if let drivers = drivers, !drivers.isEmpty {
            body += "\nDriver: \(drivers)"
        }

        if let location = location, !location.isEmpty {
            body += "\n📍 \(location)"
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Build userInfo with all relevant data
        var userInfoDict: [AnyHashable: Any] = [
            "eventIdentifier": event.eventIdentifier ?? "",
            "eventStart": event.startDate.timeIntervalSince1970,
            "isSharedCalendarEvent": isSharedCalendarEvent
        ]

        if let location = location, !location.isEmpty {
            userInfoDict["location"] = location
        }

        if !familyMembers.isEmpty {
            userInfoDict["familyMembers"] = familyMembers.joined(separator: ", ")
        }

        if let drivers = drivers, !drivers.isEmpty {
            userInfoDict["drivers"] = drivers
        }

        content.userInfo = userInfoDict

        // Set category for custom notification UI
        content.categoryIdentifier = "EVENT_NOTIFICATION"

        // Allow interruption for important events
        content.interruptionLevel = .timeSensitive

        // Create custom actions for location if available
        if let location = location, !location.isEmpty {
            let openMapsAction = UNNotificationAction(
                identifier: "OPEN_MAPS",
                title: "Get Directions",
                options: [.foreground]
            )

            let category = UNNotificationCategory(
                identifier: "EVENT_NOTIFICATION",
                actions: [openMapsAction],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: "Event scheduled",
                options: []
            )

            UNUserNotificationCenter.current().setNotificationCategories([category])
        }

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: event.eventIdentifier ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("✅ Event notification scheduled for '\(title)' at \(triggerDate)")
            }
        }
    }

    private func fetchCalendarOwners() -> [String: CalendarOwnerInfo] {
        let context = PersistenceController.shared.container.viewContext
        var lookup: [String: CalendarOwnerInfo] = [:]

        context.performAndWait {
            let fetchRequest: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
            fetchRequest.relationshipKeyPathsForPrefetching = ["memberCalendars", "sharedCalendars", "personalCalendars"]

            if let members = try? context.fetch(fetchRequest) {
                print("ℹ️ Morning brief: Found \(members.count) family member(s)")
                for member in members {
                    let memberId = member.id
                    let name = member.name ?? "Family Member"
                    print("  → \(name):")

                    if let linkedCalendarID = member.linkedCalendarID, !linkedCalendarID.isEmpty {
                        lookup[linkedCalendarID] = CalendarOwnerInfo(memberId: memberId, displayName: name)
                        print("    - Linked calendar: \(linkedCalendarID)")
                    }

                    if let calendars = member.memberCalendars as? Set<FamilyMemberCalendar> {
                        for calendar in calendars {
                            if let calendarID = calendar.calendarID, !calendarID.isEmpty {
                                lookup[calendarID] = CalendarOwnerInfo(memberId: memberId, displayName: name)
                                print("    - Member calendar: \(calendarID)")
                            }
                        }
                    }

                    if let personalCalendars = member.personalCalendars as? Set<PersonalCalendar> {
                        for personal in personalCalendars {
                            if let calendarID = personal.calendarID, !calendarID.isEmpty {
                                lookup[calendarID] = CalendarOwnerInfo(memberId: memberId, displayName: name)
                                print("    - Personal calendar: \(calendarID)")
                            }
                        }
                    }

                    if let sharedCalendars = member.sharedCalendars as? Set<SharedCalendar> {
                        for shared in sharedCalendars {
                            if let calendarID = shared.calendarID, !calendarID.isEmpty {
                                if lookup[calendarID] == nil {
                                    let displayName = shared.calendarName ?? "Shared Calendar"
                                    lookup[calendarID] = CalendarOwnerInfo(memberId: nil, displayName: displayName)
                                    print("    - Shared calendar: \(calendarID)")
                                }
                            }
                        }
                    }
                }
            } else {
                print("⚠️ Morning brief: Failed to fetch family members from CoreData")
            }
        }

        print("ℹ️ Morning brief: Calendar lookup has \(lookup.count) entries")
        return lookup
    }

    func fetchMorningBriefEvents() -> [MorningBriefEvent] {
        let appSettings = AppSettingsManager.shared

        // Check if we should skip today (weekday only setting)
        if appSettings.morningBriefWeekdaysOnly {
            let calendar = Calendar.current
            let weekday = calendar.component(.weekday, from: Date())
            // weekday: 1 = Sunday, 2 = Monday, ..., 7 = Saturday
            if weekday == 1 || weekday == 7 {
                print("ℹ️ Morning brief: Skipping weekend (today is weekday \(weekday))")
                return []
            }
        }

        let calendarLookup = fetchCalendarOwners()
        guard !calendarLookup.isEmpty else {
            print("⚠️ Morning brief: No calendar mappings found for family members")
            return []
        }

        // Filter calendars by selected members if specified
        let filteredLookup = calendarLookup
        if let selectedMembers = appSettings.morningBriefSelectedMembers, !selectedMembers.isEmpty {
            print("ℹ️ Morning brief: Filtering to \(selectedMembers.count) selected member(s)")
            // Would need to filter here based on member UUID
            // For now, we'll use all calendars if no members selected
        } else if appSettings.morningBriefSelectedMembers == nil {
            print("ℹ️ Morning brief: Including all members (default)")
        }

        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        let hasReadAccess: Bool
        if #available(iOS 17.0, *) {
            hasReadAccess = (calendarStatus == .fullAccess) || (calendarStatus == .writeOnly)
        } else {
            hasReadAccess = (calendarStatus == .authorized)
        }

        guard hasReadAccess else {
            print("⚠️ Morning brief: Calendar access not authorized for reading (status=\(calendarStatus.rawValue))")
            return []
        }

        let eventStore = EKEventStore()
        let allCalendars = eventStore.calendars(for: .event)
        print("ℹ️ Morning brief: Device has \(allCalendars.count) calendar(s)")

        let calendars = allCalendars
            .filter { filteredLookup[$0.calendarIdentifier] != nil }

        print("ℹ️ Morning brief: \(calendars.count) calendar(s) match our lookup")
        for cal in calendars {
            print("  → \(cal.title) [\(cal.calendarIdentifier)]")
        }

        guard !calendars.isEmpty else {
            print("⚠️ Morning brief: No matching calendars found on device")
            print("  Device calendars: \(allCalendars.map { $0.calendarIdentifier })")
            print("  Lookup keys: \(Array(filteredLookup.keys))")
            return []
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay.addingTimeInterval(86400)

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let events = eventStore.events(matching: predicate)
            .filter { $0.endDate >= startOfDay }
            .sorted { $0.startDate < $1.startDate }

        var briefEvents: [MorningBriefEvent] = []

        for event in events {
            guard let owner = calendarLookup[event.calendar.calendarIdentifier] else { continue }

            let memberIds = owner.memberId.map { [$0] } ?? []
            if !shouldNotifyForEvent(calendarId: event.calendar.calendarIdentifier, memberIds: memberIds) {
                continue
            }

            let briefEvent = MorningBriefEvent(
                title: event.title ?? "Event",
                startTime: event.startDate,
                endTime: event.endDate,
                location: event.location,
                driver: nil,
                attendees: [owner.displayName],
                meetingLink: event.url?.absoluteString,
                isAllDay: event.isAllDay
            )
            briefEvents.append(briefEvent)
        }

        print("ℹ️ Morning brief: Prepared \(briefEvents.count) event(s) for today")
        return briefEvents
    }


    func cancelEventNotifications(for eventIdentifier: String) async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let identifiersToRemove = pending
            .filter { $0.identifier.starts(with: eventIdentifier) }
            .map { $0.identifier }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
    }

    // MARK: - Morning Brief

    func scheduleMorningBrief(withEvents events: [MorningBriefEvent] = []) {
        Task {
            // Sync with app settings so toggles in UI take effect here
            let appSettings = AppSettingsManager.shared
            await MainActor.run {
                notificationsEnabled = appSettings.notificationsEnabled
                morningBriefEnabled = appSettings.morningBriefEnabled
                morningBriefTime = TimeComponents(hour: appSettings.morningBriefTimeHour, minute: appSettings.morningBriefTimeMinute)
                saveSettings()
            }

            print("📋 scheduleMorningBrief() called")
            print("   notificationsEnabled: \(notificationsEnabled)")
            print("   morningBriefEnabled: \(morningBriefEnabled)")

            let hasPermission = await ensureNotificationPermission()
            print("   hasPermission: \(hasPermission)")

            guard hasPermission, notificationsEnabled && morningBriefEnabled else {
                print("⚠️ scheduleMorningBrief cancelled - permission:\(hasPermission), enabled:\(notificationsEnabled), briefEnabled:\(morningBriefEnabled)")
                cancelMorningBrief()
                return
            }

            // Cancel existing morning brief first
            notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morningBrief"])

            let content = UNMutableNotificationContent()
            content.title = "Good Morning"

            // Build body based on events
            let briefEvents = events.isEmpty ? fetchMorningBriefEvents() : events

            print("📅 Found \(briefEvents.count) event(s) for morning brief")
            for (i, event) in briefEvents.enumerated() {
                print("   \(i+1). \(event.title) at \(event.startTimeString)")
            }

            if briefEvents.isEmpty {
                content.body = "No events scheduled for today. Open FamCal to add one."
            } else {
                var bodyLines = ["\(briefEvents.count) event\(briefEvents.count == 1 ? "" : "s") today:"]

                for (index, event) in briefEvents.prefix(5).enumerated() {
                    let timeStr = event.isAllDay ? "All day" : Self.briefTimeFormatter.string(from: event.startTime)
                    let member = event.attendees.first ?? "Family"
                    let locationText = (event.location?.isEmpty ?? true) ? "" : " @ \(event.location!)"
                    bodyLines.append("\(index + 1). \(event.title) — \(member) · \(timeStr)\(locationText)")
                }

                if briefEvents.count > 5 {
                    bodyLines.append("...and \(briefEvents.count - 5) more")
                }

                content.body = bodyLines.joined(separator: "\n")
            }

            // Set notification sound based on settings
            if appSettings.morningBriefNotificationSound == "none" {
                content.sound = nil
            } else if appSettings.morningBriefNotificationSound == "default" {
                content.sound = .default
            } else {
                // Custom sound file support
                content.sound = UNNotificationSound(named: UNNotificationSoundName(appSettings.morningBriefNotificationSound))
            }

            // Store events info for notification handling
            if !briefEvents.isEmpty {
                var userInfoDict: [AnyHashable: Any] = [
                    "eventCount": briefEvents.count,
                    "isMorningBrief": true
                ]

                for (index, event) in briefEvents.enumerated() {
                    userInfoDict["event_\(index)_title"] = event.title
                    userInfoDict["event_\(index)_member"] = event.attendees.first ?? "Family"
                    userInfoDict["event_\(index)_time"] = event.isAllDay ? "All day" : event.startTimeString
                    if let location = event.location {
                        userInfoDict["event_\(index)_location"] = location
                    }
                    if let driver = event.driver {
                        userInfoDict["event_\(index)_driver"] = driver
                    }
                }

                content.userInfo = userInfoDict
            }

            content.categoryIdentifier = "MORNING_BRIEF"
            content.interruptionLevel = .timeSensitive

            // Schedule two notifications:
            // 1. An immediate notification to test delivery now
            // 2. A repeating daily notification at the set time

            do {
                // Send immediate notification for testing
                let immediateContent = UNMutableNotificationContent()
                immediateContent.title = content.title
                immediateContent.body = content.body
                immediateContent.sound = content.sound
                immediateContent.userInfo = content.userInfo
                immediateContent.categoryIdentifier = content.categoryIdentifier
                immediateContent.interruptionLevel = content.interruptionLevel

                let immediateTrigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
                let immediateRequest = UNNotificationRequest(identifier: "morningBrief_immediate", content: immediateContent, trigger: immediateTrigger)
                try await notificationCenter.add(immediateRequest)
                print("✅ Morning brief notification sent immediately")

                // Also schedule the daily repeating notification
                var components = DateComponents()
                components.hour = morningBriefTime.hour
                components.minute = morningBriefTime.minute

                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let request = UNNotificationRequest(identifier: "morningBrief", content: content, trigger: trigger)

                try await notificationCenter.add(request)
                print("✅ Morning brief also scheduled daily for \(self.morningBriefTime.hour):\(String(format: "%02d", self.morningBriefTime.minute))")
            } catch {
                print("❌ Error scheduling morning brief: \(error)")
            }
        }
    }

    func cancelMorningBrief() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morningBrief"])
    }

    /// Re-schedule morning brief with current settings
    /// Call this on app launch to ensure morning brief is scheduled if enabled
    @MainActor
    func ensureMorningBriefScheduled() {
        print("ℹ️ Checking if morning brief needs to be scheduled...")
        // Sync with app settings
        let appSettings = AppSettingsManager.shared
        Task {
            await MainActor.run {
                notificationsEnabled = appSettings.notificationsEnabled
                morningBriefEnabled = appSettings.morningBriefEnabled
                morningBriefTime = TimeComponents(hour: appSettings.morningBriefTimeHour, minute: appSettings.morningBriefTimeMinute)
            }

            if notificationsEnabled && morningBriefEnabled {
                print("✅ Scheduling morning brief from ensureMorningBriefScheduled")
                scheduleMorningBrief()
            } else {
                print("ℹ️ Morning brief not enabled (notificationsEnabled: \(notificationsEnabled), morningBriefEnabled: \(morningBriefEnabled))")
            }
        }
    }

    /// Fetch pending notifications (for debugging)
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await notificationCenter.pendingNotificationRequests()
    }

    /// Fetch delivered notifications (for debugging)
    func getDeliveredNotifications() async -> [UNNotification] {
        return await notificationCenter.deliveredNotifications()
    }

    // MARK: - Helper Methods

    private func calculateTriggerDate(from eventDate: Date, alertOption: AlertOption) -> Date {
        let calendar = Calendar.current

        switch alertOption {
        case .none:
            return eventDate
        case .atTime:
            return eventDate
        case .fifteenMinsBefore:
            return calendar.date(byAdding: .minute, value: -15, to: eventDate) ?? eventDate
        case .oneHourBefore:
            return calendar.date(byAdding: .hour, value: -1, to: eventDate) ?? eventDate
        case .oneDayBefore:
            return calendar.date(byAdding: .day, value: -1, to: eventDate) ?? eventDate
        case .custom:
            return eventDate
        }
    }

    func shouldNotifyForEvent(
        calendarId: String,
        memberIds: [UUID]
    ) -> Bool {
        // If no specific members/calendars are selected, notify for everything (catch-all)
        if selectedMembersForNotifications.isEmpty && selectedCalendarsForNotifications.isEmpty {
            return true
        }

        // Otherwise check if calendar is selected
        if !selectedCalendarsForNotifications.isEmpty && !selectedCalendarsForNotifications.contains(calendarId) {
            return false
        }

        // Check if at least one member is selected (or none specified means all)
        if selectedMembersForNotifications.isEmpty {
            return true
        }

        return memberIds.contains { selectedMembersForNotifications.contains($0) }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    // Handle notifications when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    // Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Check if this is a custom action (e.g., "Get Directions")
        if response.actionIdentifier == "OPEN_MAPS" {
            // Handle Get Directions action
            if let location = userInfo["location"] as? String {
                openMapsForLocation(location)
            }
        } else if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // Handle default tap (open event details)
            if let eventIdentifier = userInfo["eventIdentifier"] as? String {
                NotificationCenter.default.post(
                    name: NSNotification.Name("openEventDetail"),
                    object: nil,
                    userInfo: ["eventIdentifier": eventIdentifier]
                )
            }
        }

        completionHandler()
    }

    private func openMapsForLocation(_ address: String) {
        // Get the user's preferred maps app from app settings
        let preferredMapsApp = UserDefaults.standard.string(forKey: "defaultMapsApp") ?? "Apple Maps"

        // Use MapsUtility with the user's preferred app
        MapsUtility.openLocation(address, in: preferredMapsApp)
        print("🗺️ Opening \(preferredMapsApp) for location: \(address)")
    }
}

// MARK: - Time Components

struct TimeComponents: Codable, Hashable {
    var hour: Int
    var minute: Int

    func toDate() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? Date()
    }
}
