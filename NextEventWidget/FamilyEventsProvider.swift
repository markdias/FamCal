//
//  FamilyEventsProvider.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import WidgetKit
import EventKit
import CoreData
import UIKit

/// Timeline provider for family events widget
struct FamilyEventsProvider: TimelineProvider {
    typealias Entry = FamilyEventsEntry

    /// Placeholder shown while loading
    func placeholder(in context: Context) -> FamilyEventsEntry {
        return FamilyEventsEntry(date: Date())
    }

    /// Snapshot for widget preview
    func getSnapshot(in context: Context, completion: @escaping (FamilyEventsEntry) -> Void) {
        let entry = loadEvents()
        completion(entry)
    }

    /// Main timeline generation
    func getTimeline(in context: Context, completion: @escaping (Timeline<FamilyEventsEntry>) -> Void) {
        let entry = loadEvents()

        // Refresh more frequently to catch login state changes (1 minute for faster auth detection)
        let refreshInterval = isUserAuthenticated() ? 5 : 1 // 1 min if not auth'd, 5 min if auth'd
        let nextRefreshDate = Calendar.current.date(byAdding: .minute, value: refreshInterval, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextRefreshDate))

        completion(timeline)
    }

    /// Check if user is authenticated by checking app group UserDefaults
    private func isUserAuthenticated() -> Bool {
        // Try app group first (shared with main app)
        if let appGroupDefaults = UserDefaults(suiteName: "group.com.markdias.famli") {
            return appGroupDefaults.bool(forKey: "com.famcal.auth.isAuthenticated")
        }
        // Fallback to standard defaults
        return UserDefaults.standard.bool(forKey: "com.famcal.auth.isAuthenticated")
    }

    /// Load all upcoming events for family members
    private func loadEvents() -> FamilyEventsEntry {
        // Check authentication first
        if !isUserAuthenticated() {
            print("⚠️ Widget: User not authenticated")
            return FamilyEventsEntry(date: Date(), errorMessage: "Please log in to see events", isAuthenticated: false)
        }

        do {
            // Get max events from user preferences using app group
            guard let defaults = UserDefaults(suiteName: "group.com.markdias.famli") else {
                return FamilyEventsEntry(date: Date(), errorMessage: "Cannot access widget settings")
            }

            let maxEvents = defaults.integer(forKey: "widgetMaxEvents")
            let actualMaxEvents = maxEvents > 0 ? maxEvents : 10 // Default to 10

            // First try to get app group container
            let appGroupID = "group.com.markdias.famli"
            guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                return FamilyEventsEntry(date: Date(), errorMessage: "App groups not accessible")
            }

            // Construct the database URL
            let storeURL = appGroupURL.appendingPathComponent("FamCal.sqlite")

            // Check if database file exists
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: storeURL.path) {
                return FamilyEventsEntry(date: Date(), errorMessage: "Database not initialized yet")
            }

            // Load data model
            var modelURL = Bundle.main.url(forResource: "FamCal", withExtension: "momd")

            if modelURL == nil {
                if let widgetBundlePath = Bundle.main.bundlePath as NSString? {
                    let pluginsPath = widgetBundlePath.deletingLastPathComponent
                    let appPath = (pluginsPath as NSString).deletingLastPathComponent
                    modelURL = URL(fileURLWithPath: appPath).appendingPathComponent("FamCal.momd")

                    if !fileManager.fileExists(atPath: modelURL!.path) {
                        modelURL = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/FamCal.momd")
                    }
                }
            }

            guard let modelURL = modelURL, fileManager.fileExists(atPath: modelURL.path) else {
                return FamilyEventsEntry(date: Date(), errorMessage: "Data model not found")
            }

            guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
                return FamilyEventsEntry(date: Date(), errorMessage: "Failed to load data model")
            }

            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

            let storeOptions: [String: Any] = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentStoreFileProtectionKey: FileProtectionType.none,
                NSReadOnlyPersistentStoreOption: true
            ]

            try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: storeOptions
            )

            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator

            // Fetch family members
            let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FamilyMember")
            fetchRequest.returnsObjectsAsFaults = false
            fetchRequest.resultType = .dictionaryResultType

            let results = try context.fetch(fetchRequest) as? [[String: Any]] ?? []

            guard !results.isEmpty else {
                print("⚠️ Widget: No family members found in database")
                return FamilyEventsEntry(date: Date(), errorMessage: "No family members configured")
            }

            print("✅ Widget: Found \(results.count) family member(s)")

            // Get event range preferences
            let pastDays = defaults.integer(forKey: "eventsPastDays")
            let futureDays = defaults.integer(forKey: "eventsFutureDays")

            let startDate = Calendar.current.date(byAdding: .day, value: -(pastDays > 0 ? pastDays : 90), to: Date()) ?? Date()
            let endDate = Calendar.current.date(byAdding: .day, value: futureDays > 0 ? futureDays : 180, to: Date()) ?? Date()

            // Collect all calendar IDs from family members and shared calendars
            var memberCalendarMap: [String: (memberId: UUID, name: String, colorHex: String)] = [:]

            for result in results {
                let id = (result["id"] as? UUID) ?? UUID()
                let name = (result["name"] as? String) ?? "Unknown"
                let colorHex = (result["colorHex"] as? String) ?? "#007AFF"

                if let calendarID = result["linkedCalendarID"] as? String, !calendarID.isEmpty {
                    memberCalendarMap[calendarID] = (memberId: id, name: name, colorHex: colorHex)
                }
            }

            // Fetch FamilyMemberCalendar entities (as objects to properly handle relationships)
            let memberCalendarRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "FamilyMemberCalendar")
            memberCalendarRequest.returnsObjectsAsFaults = false

            do {
                let memberCalendarObjects = try context.fetch(memberCalendarRequest)
                for calendarObj in memberCalendarObjects {
                    if let calendarID = calendarObj.value(forKey: "calendarID") as? String, !calendarID.isEmpty {
                        if let memberObj = calendarObj.value(forKey: "familyMember") as? NSManagedObject {
                            let calendarColorHex = (calendarObj.value(forKey: "calendarColorHex") as? String)
                            if let name = memberObj.value(forKey: "name") as? String,
                               let colorHex = (calendarColorHex ?? memberObj.value(forKey: "colorHex") as? String),
                               let id = memberObj.value(forKey: "id") as? UUID {
                                memberCalendarMap[calendarID] = (memberId: id, name: name, colorHex: colorHex)
                                print("✅ Widget: Added member calendar: \(name) - \(calendarID)")
                            }
                        }
                    }
                }
            } catch {
                print("⚠️ Widget: Error fetching FamilyMemberCalendar: \(error)")
            }

            // Fetch shared calendars
            let sharedCalendarRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SharedCalendar")
            sharedCalendarRequest.returnsObjectsAsFaults = false
            sharedCalendarRequest.resultType = .dictionaryResultType

            if let sharedCalResults = try context.fetch(sharedCalendarRequest) as? [[String: Any]] {
                for result in sharedCalResults {
                    if let calendarID = result["calendarID"] as? String, !calendarID.isEmpty {
                        if memberCalendarMap[calendarID] == nil {
                            memberCalendarMap[calendarID] = (
                                memberId: UUID(),
                                name: (result["calendarName"] as? String) ?? "Shared Calendar",
                                colorHex: (result["calendarColorHex"] as? String) ?? "#555555"
                            )
                        }
                    }
                }
            }

            guard !memberCalendarMap.isEmpty else {
                print("⚠️ Widget: No calendars found in memberCalendarMap")
                print("   - Legacy linkedCalendarID calendars: \(results.filter { ($0["linkedCalendarID"] as? String)?.isEmpty == false }.count)")

                // Fetch to check how many FamilyMemberCalendar records exist
                let memberCalendarCountRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "FamilyMemberCalendar")
                if let count = try? context.fetch(memberCalendarCountRequest).count {
                    print("   - FamilyMemberCalendar records in DB: \(count)")
                }

                // Fetch to check how many SharedCalendar records exist
                let sharedCalendarCountRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "SharedCalendar")
                sharedCalendarCountRequest.resultType = .countResultType
                if let countResult = try? context.fetch(sharedCalendarCountRequest).first as? Int {
                    print("   - SharedCalendar records in DB: \(countResult)")
                }

                return FamilyEventsEntry(date: Date(), errorMessage: "No calendars found")
            }

            print("✅ Widget: Found \(memberCalendarMap.count) calendars in total")

            // Check calendar access
            let calendarAccess = EKEventStore.authorizationStatus(for: .event)
            if calendarAccess == .denied || calendarAccess == .restricted {
                return FamilyEventsEntry(date: Date(), errorMessage: "Calendar access required - enable in Settings")
            }

            // Fetch all upcoming events
            let eventStore = EKEventStore()
            let calendarIDs = Array(memberCalendarMap.keys)
            let calendars = eventStore.calendars(for: .event)
                .filter { calendarIDs.contains($0.calendarIdentifier) }

            guard !calendars.isEmpty else {
                return FamilyEventsEntry(date: Date(), errorMessage: "No calendars found")
            }

            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
            let ekEvents = eventStore.events(matching: predicate)
                .filter { !$0.isAllDay }
                .filter { $0.endDate > Date() }
                .sorted { $0.startDate < $1.startDate }

            // Convert to EventItems
            var eventItems: [EventItem] = []
            for ekEvent in ekEvents.prefix(actualMaxEvents) {
                guard let calendarID = ekEvent.calendar.calendarIdentifier as String?,
                      let memberInfo = memberCalendarMap[calendarID] else {
                    continue
                }

                // Get calendar color from EKCalendar
                var calendarColorHex = "#007AFF"  // Default blue
                if let cgColor = ekEvent.calendar.cgColor,
                   let components = cgColor.components, components.count >= 3 {
                    let r = Int(components[0] * 255)
                    let g = Int(components[1] * 255)
                    let b = Int(components[2] * 255)
                    calendarColorHex = String(format: "#%02X%02X%02X", r, g, b)
                }

                let eventItem = EventItem(
                    id: ekEvent.eventIdentifier,
                    title: ekEvent.title ?? "Event",
                    startDate: ekEvent.startDate,
                    endDate: ekEvent.endDate,
                    memberName: memberInfo.name,
                    memberColorHex: memberInfo.colorHex,
                    calendarColorHex: calendarColorHex,
                    location: ekEvent.location
                )
                eventItems.append(eventItem)
            }

            // Read widget display settings
            let showTime = defaults.object(forKey: "widgetShowTime") as? Bool ?? true
            let showLocation = defaults.object(forKey: "widgetShowLocation") as? Bool ?? true
            let showAttendees = defaults.object(forKey: "widgetShowAttendees") as? Bool ?? true
            let showDrivers = defaults.object(forKey: "widgetShowDrivers") as? Bool ?? true

            if eventItems.isEmpty {
                return FamilyEventsEntry(date: Date(), errorMessage: "No upcoming events")
            }

            return FamilyEventsEntry(date: Date(), events: eventItems, maxEvents: actualMaxEvents, showTime: showTime, showLocation: showLocation, showAttendees: showAttendees, showDrivers: showDrivers)

        } catch {
            let errorMsg = "Error: \(error.localizedDescription)"
            print("❌ Widget Error: \(errorMsg)")
            let nserror = error as NSError
            print("   Domain: \(nserror.domain)")
            print("   Code: \(nserror.code)")
            return FamilyEventsEntry(date: Date(), errorMessage: errorMsg)
        }
    }
}
