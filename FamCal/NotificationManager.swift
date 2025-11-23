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
                if granted {
                    saveSettings()
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
    }

    @MainActor
    private func syncNotificationPermission() async {
        let settings = await notificationCenter.notificationSettings()
        if settings.authorizationStatus == .authorized && notificationsEnabled == false {
            notificationsEnabled = true
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
        location: String? = nil
    ) {
        guard notificationsEnabled else {
            Task {
                print("🔔 Notifications disabled in app settings, checking system permission...")
                let granted = await self.checkNotificationPermission()
                if granted {
                    print("✅ System permission already granted, enabling in app...")
                    await MainActor.run {
                        self.notificationsEnabled = true
                        self.saveSettings()
                    }
                    // After enabling, schedule again
                    self.scheduleEventNotification(
                        event: event,
                        alertOption: alertOption,
                        familyMembers: familyMembers,
                        drivers: drivers,
                        location: location
                    )
                } else {
                    print("⚠️ System permission not granted, requesting...")
                    let granted = await self.requestNotificationPermission()
                    if granted {
                        print("✅ Permission granted by user")
                        await MainActor.run {
                            self.notificationsEnabled = true
                            self.saveSettings()
                        }
                        // After enabling, schedule again
                        self.scheduleEventNotification(
                            event: event,
                            alertOption: alertOption,
                            familyMembers: familyMembers,
                            drivers: drivers,
                            location: location
                        )
                    } else {
                        print("❌ Permission denied by user")
                    }
                }
            }
            return
        }

        // Schedule a local notification for immediate feedback
        let triggerDate = calculateTriggerDate(from: event.startDate, alertOption: alertOption)

        // Build notification content
        let title = event.title ?? "Event"

        var body = ""
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"
        body = timeFormatter.string(from: event.startDate)

        // Add family members to body
        if !familyMembers.isEmpty {
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
            "eventStart": event.startDate.timeIntervalSince1970
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


    func cancelEventNotifications(for eventIdentifier: String) async {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let identifiersToRemove = pending
            .filter { $0.identifier.starts(with: eventIdentifier) }
            .map { $0.identifier }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
    }

    // MARK: - Morning Brief

    func scheduleMorningBrief() {
        guard notificationsEnabled && morningBriefEnabled else {
            cancelMorningBrief()
            return
        }

        // Cancel existing morning brief first
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morningBrief"])

        var components = DateComponents()
        components.hour = morningBriefTime.hour
        components.minute = morningBriefTime.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Good Morning"
        content.body = "Check your family's upcoming events for today"
        content.sound = .default

        let request = UNNotificationRequest(identifier: "morningBrief", content: content, trigger: trigger)
        notificationCenter.add(request) { error in
            if let error = error {
                print("Error scheduling morning brief: \(error)")
            }
        }
    }

    func cancelMorningBrief() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morningBrief"])
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
