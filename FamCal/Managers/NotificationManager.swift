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
    private let eventStore = EKEventStore()

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

        // Observe calendar changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarDatabaseChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )

        Task {
            await syncNotificationPermission()
            // Sync existing calendar events on init
            await syncCalendarNotifications()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .EKEventStoreChanged, object: eventStore)
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

    // MARK: - Calendar Change Monitoring

    @objc private func calendarDatabaseChanged() {
        print("📅 Calendar database changed - syncing notifications...")
        Task {
            await syncCalendarNotifications()
        }
    }

    /// Sync notifications for all calendar events that have alerts
    func syncCalendarNotifications() async {
        guard await ensureNotificationPermission() else {
            print("⚠️ Cannot sync calendar notifications - no permission")
            return
        }

        print("🔄 Syncing calendar notifications...")

        // Get calendar owner lookup
        let calendarLookup = fetchCalendarOwners()
        guard !calendarLookup.isEmpty else {
            print("⚠️ No calendar mappings found - skipping sync")
            return
        }

        // Check calendar access
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        let hasReadAccess: Bool
        if #available(iOS 17.0, *) {
            hasReadAccess = (calendarStatus == .fullAccess) || (calendarStatus == .writeOnly)
        } else {
            hasReadAccess = (calendarStatus == .authorized)
        }

        guard hasReadAccess else {
            print("⚠️ Calendar access not authorized - skipping sync")
            return
        }

        // Get all calendars we're tracking
        let allCalendars = eventStore.calendars(for: .event)
        let trackedCalendars = allCalendars.filter { calendarLookup[$0.calendarIdentifier] != nil }

        guard !trackedCalendars.isEmpty else {
            print("⚠️ No tracked calendars found - skipping sync")
            return
        }

        print("ℹ️ Syncing notifications for \(trackedCalendars.count) tracked calendar(s)")

        // Fetch events from now to 7 days in the future (only need near-term events for notifications)
        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 7, to: startDate) ?? startDate.addingTimeInterval(604800)

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: trackedCalendars)
        let events = eventStore.events(matching: predicate)

        print("ℹ️ Found \(events.count) upcoming event(s) in next 7 days")

        // Get existing pending notifications to avoid duplicates
        let existingNotifications = await notificationCenter.pendingNotificationRequests()
        let existingIdentifiers = Set(existingNotifications.map { $0.identifier })

        var scheduledCount = 0
        var skippedCount = 0

        for event in events {
            let eventTitle = event.title ?? "Untitled"

            // Skip events that have already ended
            if event.endDate < Date() {
                print("⏭️ Skipping '\(eventTitle)' - event already ended")
                skippedCount += 1
                continue
            }

            // Skip if event already has a notification scheduled for this occurrence
            // Create the same unique identifier we use when scheduling
            let dateFormatter = ISO8601DateFormatter()
            let dateString = dateFormatter.string(from: event.startDate)
            let notificationId = "\(event.eventIdentifier ?? "")_\(dateString)"

            if existingIdentifiers.contains(notificationId) {
                print("⏭️ Skipping '\(eventTitle)' on \(event.startDate.formatted(date: .abbreviated, time: .shortened)) - notification already scheduled")
                skippedCount += 1
                continue
            }

            // Only schedule if event has alarms
            guard let alarms = event.alarms, !alarms.isEmpty else {
                print("⏭️ Skipping '\(eventTitle)' - no alarms set")
                skippedCount += 1
                continue
            }

            // Get the first alarm to determine alert option
            guard let firstAlarm = alarms.first else {
                print("⏭️ Skipping '\(eventTitle)' - no valid alarm")
                skippedCount += 1
                continue
            }

            let alertOption = alertOptionFromAlarm(firstAlarm, eventStartDate: event.startDate)

            // Skip if alert is in the past
            if alertOption == .none {
                print("⏭️ Skipping '\(eventTitle)' - alert time in the past")
                skippedCount += 1
                continue
            }

            // Get calendar owner info
            guard let owner = calendarLookup[event.calendar.calendarIdentifier] else {
                print("⏭️ Skipping '\(eventTitle)' - calendar not tracked (ID: \(event.calendar.calendarIdentifier))")
                skippedCount += 1
                continue
            }

            // Check if we should notify for this event
            let memberIds = owner.memberId.map { [$0] } ?? []
            if !shouldNotifyForEvent(calendarId: event.calendar.calendarIdentifier, memberIds: memberIds) {
                print("⏭️ Skipping '\(eventTitle)' - filtered by notification settings")
                skippedCount += 1
                continue
            }

            // Schedule the notification
            let familyMembers = owner.memberId != nil ? [owner.displayName] : []
            let isSharedEvent = owner.memberId == nil

            print("✅ Scheduling notification for '\(eventTitle)' on \(event.startDate.formatted(date: .abbreviated, time: .shortened))")

            scheduleEventNotificationNow(
                event: event,
                alertOption: alertOption,
                familyMembers: familyMembers,
                drivers: nil,
                location: event.location,
                isSharedCalendarEvent: isSharedEvent
            )

            scheduledCount += 1
        }

        print("✅ Calendar sync complete: scheduled \(scheduledCount), skipped \(skippedCount)")
    }

    /// Convert EKAlarm to AlertOption
    private func alertOptionFromAlarm(_ alarm: EKAlarm, eventStartDate: Date) -> AlertOption {
        // relativeOffset is negative for alarms before the event
        let relativeOffset = alarm.relativeOffset
        let offsetMinutes = Int(abs(relativeOffset) / 60)

        switch offsetMinutes {
        case 0:
            return .atTime
        case 15:
            return .fifteenMinsBefore
        case 60:
            return .oneHourBefore
        case 1440: // 24 hours
            return .oneDayBefore
        default:
            // For other times, use the closest match or atTime
            return .atTime
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
        let eventTitle = event.title ?? "Event"

        // Determine the primary family member for this event
        let primaryMember = familyMembers.first ?? "Family"

        // Set title to event name and subtitle to family member
        let content = UNMutableNotificationContent()
        content.title = eventTitle

        // Use subtitle to show the family member
        if !familyMembers.isEmpty {
            content.subtitle = primaryMember
        }

        // Build body with time, additional members, driver, and location
        var body = ""
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        body = timeFormatter.string(from: event.startDate)

        // Add additional family members to body if there are multiple
        if familyMembers.count > 1 {
            let additionalMembers = familyMembers.dropFirst().joined(separator: ", ")
            body += "\nAlso with: \(additionalMembers)"
        }

        if let drivers = drivers, !drivers.isEmpty {
            body += "\nDriver: \(drivers)"
        }

        if let location = location, !location.isEmpty {
            body += "\n📍 \(location)"
        }

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

        // Create unique identifier for this occurrence
        // For recurring events, include the start date to create a unique ID per occurrence
        let dateFormatter = ISO8601DateFormatter()
        let dateString = dateFormatter.string(from: event.startDate)
        let notificationId = "\(event.eventIdentifier ?? UUID().uuidString)_\(dateString)"

        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("✅ Event notification scheduled for '\(eventTitle)' at \(triggerDate)")
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

    // MARK: - Morning Brief Image Generation

    private func generateMorningBriefImage(events: [MorningBriefEvent]) -> UIImage? {
        // Image dimensions
        let width: CGFloat = 600
        let rowHeight: CGFloat = 70
        let headerHeight: CGFloat = 80
        let padding: CGFloat = 20
        let totalHeight = headerHeight + (CGFloat(events.count) * rowHeight) + padding * 2

        let size = CGSize(width: width, height: totalHeight)
        let renderer = UIGraphicsImageRenderer(size: size)

        let image = renderer.image { context in
            let ctx = context.cgContext

            // Background gradient
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 0.95, green: 0.97, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 0.90, green: 0.93, blue: 0.98, alpha: 1.0).cgColor
            ]
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
            ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: totalHeight), options: [])

            // Header
            let headerText = "Today's Schedule"
            let headerAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .bold),
                .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0)
            ]
            headerText.draw(at: CGPoint(x: padding, y: padding + 10), withAttributes: headerAttrs)

            let dateText = formatDate(Date())
            let dateAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1.0)
            ]
            dateText.draw(at: CGPoint(x: padding, y: padding + 45), withAttributes: dateAttrs)

            // Events
            var yPos = headerHeight + padding

            for event in events {
                let rowRect = CGRect(x: padding, y: yPos, width: width - padding * 2, height: rowHeight - 10)

                // Row background
                let rowBg = UIBezierPath(roundedRect: rowRect, cornerRadius: 12)
                UIColor.white.withAlphaComponent(0.8).setFill()
                rowBg.fill()

                // Add subtle shadow
                ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.1).cgColor)

                // Time
                let timeStr = event.isAllDay ? "All day" : Self.briefTimeFormatter.string(from: event.startTime)
                let timeAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
                    .foregroundColor: UIColor.systemBlue
                ]
                timeStr.draw(at: CGPoint(x: padding + 15, y: yPos + 12), withAttributes: timeAttrs)

                // Event title
                let titleAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                    .foregroundColor: UIColor(red: 0.2, green: 0.2, blue: 0.3, alpha: 1.0)
                ]
                let truncatedTitle = event.title.count > 30 ? String(event.title.prefix(27)) + "..." : event.title
                truncatedTitle.draw(at: CGPoint(x: padding + 120, y: yPos + 10), withAttributes: titleAttrs)

                // Member name
                let member = event.attendees.first ?? "Family"
                let memberAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                    .foregroundColor: UIColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1.0)
                ]
                let memberText = "👤 \(member)"
                memberText.draw(at: CGPoint(x: padding + 120, y: yPos + 35), withAttributes: memberAttrs)

                // Location (if available)
                if let location = event.location, !location.isEmpty {
                    let locationAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                        .foregroundColor: UIColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1.0)
                    ]
                    let truncatedLocation = location.count > 25 ? String(location.prefix(22)) + "..." : location
                    let locationText = "📍 \(truncatedLocation)"
                    locationText.draw(at: CGPoint(x: padding + 320, y: yPos + 35), withAttributes: locationAttrs)
                }

                yPos += rowHeight
            }
        }

        return image
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
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
                // Create summary text for collapsed notification
                let memberCounts = Dictionary(grouping: briefEvents, by: { $0.attendees.first ?? "Family" })
                    .mapValues { $0.count }
                    .sorted { $0.value > $1.value }

                var summaryParts: [String] = []
                for (member, count) in memberCounts.prefix(3) {
                    summaryParts.append("\(count) for \(member)")
                }

                let summary = summaryParts.joined(separator: ", ")
                content.body = "\(briefEvents.count) event\(briefEvents.count == 1 ? "" : "s") today - \(summary)\nTap to view full schedule"

                // Generate and attach image with all events
                if let image = generateMorningBriefImage(events: briefEvents),
                   let imageData = image.pngData() {

                    // Use Caches directory which is accessible to notification extensions
                    guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                        print("⚠️ Failed to access caches directory")
                        return
                    }

                    let imageURL = cachesDir.appendingPathComponent("morning-brief-\(UUID().uuidString).png")
                    print("📁 Saving morning brief image to: \(imageURL.path)")

                    do {
                        try imageData.write(to: imageURL)
                        print("✅ Image file written successfully, size: \(imageData.count) bytes")

                        // Create attachment with explicit options
                        let options: [String: Any] = [
                            UNNotificationAttachmentOptionsTypeHintKey: "public.png"
                        ]
                        let attachment = try UNNotificationAttachment(
                            identifier: "schedule-image",
                            url: imageURL,
                            options: options
                        )
                        content.attachments = [attachment]
                        print("✅ Morning brief image attached successfully to notification")
                    } catch {
                        print("⚠️ Failed to attach morning brief image: \(error)")
                        print("   Error details: \(error.localizedDescription)")
                    }
                }
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
