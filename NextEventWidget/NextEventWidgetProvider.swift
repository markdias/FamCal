//
//  NextEventWidgetProvider.swift
//  NextEventWidget
//
//  Created by Claude Code
//

import WidgetKit
import SwiftUI
import CoreData
import EventKit
import AppIntents

/// Timeline entry for the widget
struct NextEventEntry: TimelineEntry {
    let date: Date
    let event: WidgetEventData?
    let familyMember: FamilyMemberData?
    let errorMessage: String?
    let isAuthenticated: Bool

    /// Initialize with success data
    init(date: Date = Date(), event: WidgetEventData, familyMember: FamilyMemberData) {
        self.date = date
        self.event = event
        self.familyMember = familyMember
        self.errorMessage = nil
        self.isAuthenticated = true
    }

    /// Initialize with error state
    init(date: Date = Date(), errorMessage: String) {
        self.date = date
        self.event = nil
        self.familyMember = nil
        self.errorMessage = errorMessage
        self.isAuthenticated = true
    }

    /// Initialize with placeholder
    init(date: Date = Date()) {
        self.date = date
        self.event = nil
        self.familyMember = nil
        self.errorMessage = nil
        self.isAuthenticated = true
    }

    /// Initialize with authentication required state
    init(date: Date = Date(), isAuthenticated: Bool) {
        self.date = date
        self.event = nil
        self.familyMember = nil
        self.errorMessage = nil
        self.isAuthenticated = isAuthenticated
    }
}

/// Simple family member data for widget (no CoreData dependency)
struct FamilyMemberData: Codable {
    let id: UUID
    let name: String
    let colorHex: String
}

/// Event data simplified for widget display
struct WidgetEventData: Codable {
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let colorHex: String
}

/// Timeline provider for next event widget
@available(iOSApplicationExtension 17.0, *)
struct NextEventProvider: AppIntentTimelineProvider {
    typealias Intent = NextEventConfigurationIntent
    typealias Entry = NextEventEntry

    /// Placeholder shown while loading
    func placeholder(in context: Context) -> NextEventEntry {
        return NextEventEntry(date: Date())
    }

    /// Snapshot for widget preview
    func snapshot(for configuration: NextEventConfigurationIntent, in context: Context) async -> NextEventEntry {
        let msg = "🔍 DEBUG Widget: snapshot() called with selectedMemberName: \(configuration.selectedMemberName ?? "nil")"
        print(msg)
        logToFile(msg)
        return loadNextEvent(intent: configuration)
    }

    /// Main timeline generation
    func timeline(for configuration: NextEventConfigurationIntent, in context: Context) async -> Timeline<NextEventEntry> {
        let msg = "🔍 DEBUG Widget: timeline() called with intent selectedMemberName: \(configuration.selectedMemberName ?? "nil")"
        print(msg)
        logToFile(msg)

        let entry = loadNextEvent(intent: configuration)

        // Refresh more frequently to catch login state changes (1 minute for faster auth detection)
        let refreshInterval = isUserAuthenticated() ? 5 : 1 // 1 min if not auth'd, 5 min if auth'd
        let nextRefreshDate = Calendar.current.date(byAdding: .minute, value: refreshInterval, to: Date()) ?? Date()

        let finalMsg = "✅ DEBUG Widget: timeline() returning entry, next refresh in \(refreshInterval) minutes"
        print(finalMsg)
        logToFile(finalMsg)

        return Timeline(entries: [entry], policy: .after(nextRefreshDate))
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

    /// Load the next event for the family member with soonest upcoming event
    private func loadNextEvent(intent: NextEventConfigurationIntent? = nil) -> NextEventEntry {
        let logMessage = "🔍 DEBUG Widget: loadNextEvent() called"
        print(logMessage)
        logToFile(logMessage)

        // Check authentication first
        if !isUserAuthenticated() {
            let msg = "⚠️ Widget: User not authenticated"
            print(msg)
            logToFile(msg)
            return NextEventEntry(isAuthenticated: false)
        }

        do {
            print("🔍 Widget: Starting loadNextEvent()")

            // First try to get app group container
            let appGroupID = "group.com.markdias.famli"
            guard let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                print("❌ Widget: App group container not accessible")
                return NextEventEntry(errorMessage: "App groups not accessible")
            }

            print("✅ Widget: App group URL: \(appGroupURL.path)")

            // Construct the database URL
            let storeURL = appGroupURL.appendingPathComponent("FamCal.sqlite")

            // Check if database file exists
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: storeURL.path) {
                print("❌ Widget: Database file not found at \(storeURL.path)")
                if let contents = try? fileManager.contentsOfDirectory(atPath: appGroupURL.path) {
                    print("📁 Widget: App group contents: \(contents)")
                }
                return NextEventEntry(errorMessage: "Database not initialized yet")
            }

            print("✅ Widget: Database file exists at \(storeURL.path)")

            // Create a NSPersistentStoreCoordinator directly
            // Try to load from main bundle or widget bundle
            var modelURL = Bundle.main.url(forResource: "FamCal", withExtension: "momd")

            if modelURL == nil {
                // If not found in widget bundle, try to find in app bundle
                // Widget bundle path: FamCal.app/PlugIns/mdias.FamCal.NextEventWidget.appex/
                // We need to go to: FamCal.app/FamCal.momd
                if let widgetBundlePath = Bundle.main.bundlePath as NSString? {
                    // Go up to PlugIns directory
                    let pluginsPath = widgetBundlePath.deletingLastPathComponent
                    // Go up to FamCal.app directory
                    let appPath = (pluginsPath as NSString).deletingLastPathComponent
                    // Check for FamCal.momd in the app bundle
                    modelURL = URL(fileURLWithPath: appPath).appendingPathComponent("FamCal.momd")

                    if !FileManager.default.fileExists(atPath: modelURL!.path) {
                        // Also try looking in Contents/Resources for sandboxed environments
                        modelURL = URL(fileURLWithPath: appPath).appendingPathComponent("Contents/Resources/FamCal.momd")
                    }
                }
            }

            guard let modelURL = modelURL, FileManager.default.fileExists(atPath: modelURL.path) else {
                let attemptedPath = Bundle.main.url(forResource: "FamCal", withExtension: "momd")?.path ?? "none"
                let widgetBundlePath = Bundle.main.bundlePath
                print("⚠️ Widget: Data model not found.")
                print("   Attempted bundle resource: \(attemptedPath)")
                print("   Widget bundle path: \(widgetBundlePath)")
                return NextEventEntry(errorMessage: "Data model not found")
            }

            guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
                print("❌ Widget: Failed to load data model from \(modelURL.path)")
                return NextEventEntry(errorMessage: "Failed to load data model")
            }

            print("✅ Widget: Data model loaded successfully")

            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)

            let storeOptions: [String: Any] = [
                NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentStoreFileProtectionKey: FileProtectionType.none,
                NSReadOnlyPersistentStoreOption: true
            ]

            // Add persistent store with options to handle file access issues
            do {
                try coordinator.addPersistentStore(
                    ofType: NSSQLiteStoreType,
                    configurationName: nil,
                    at: storeURL,
                    options: storeOptions
                )
                print("✅ Widget: Persistent store added successfully")
            } catch {
                print("❌ Widget: Failed to add persistent store: \(error.localizedDescription)")
                throw error
            }

            let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
            context.persistentStoreCoordinator = coordinator

            // 1. Identify the target member
            let targetName = (intent?.selectedMemberName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let useDefault = targetName.isEmpty
            
            var targetMemberObj: NSManagedObject? = nil
            
            // Convert results to objects for easier relationship handling
            // We need to re-fetch as objects because we used dictionaryResultType above
            let objectFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FamilyMember")
            objectFetchRequest.returnsObjectsAsFaults = false
            let memberObjects = try context.fetch(objectFetchRequest)
            
            if useDefault {
                // Default to first member alphabetically
                targetMemberObj = memberObjects.sorted {
                    let name1 = ($0.value(forKey: "name") as? String) ?? ""
                    let name2 = ($1.value(forKey: "name") as? String) ?? ""
                    return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
                }.first
            } else {
                targetMemberObj = memberObjects.first {
                    let name = ($0.value(forKey: "name") as? String) ?? ""
                    return name.localizedCaseInsensitiveCompare(targetName) == .orderedSame
                }
            }
            
            guard let member = targetMemberObj else {
                return NextEventEntry(errorMessage: "Member '\(targetName)' not found")
            }
            
            let memberName = (member.value(forKey: "name") as? String) ?? "Unknown"
            let memberId = (member.value(forKey: "id") as? UUID) ?? UUID()
            let memberColorHex = (member.value(forKey: "colorHex") as? String) ?? "#007AFF"
            
            print("✅ Widget: Selected member: \(memberName)")
            
            // Get user preferences for event range
            let defaults = UserDefaults(suiteName: "group.com.markdias.famli") ?? UserDefaults.standard
            print("🔍 DEBUG Widget: Defaults loaded - app group available: \(UserDefaults(suiteName: "group.com.markdias.famli") != nil)")
            let pastDays = defaults.integer(forKey: "eventsPastDays")
            let futureDays = defaults.integer(forKey: "eventsFutureDays")
            print("🔍 DEBUG Widget: Event range - past: \(pastDays), future: \(futureDays)")

            let startDate = Calendar.current.date(byAdding: .day, value: -(pastDays > 0 ? pastDays : 90), to: Date()) ?? Date()
            let endDate = Calendar.current.date(byAdding: .day, value: futureDays > 0 ? futureDays : 180, to: Date()) ?? Date()

            // 2. Collect ALL calendar IDs for this member
            var memberCalendarIDs = Set<String>()

            // A. Personal Linked Calendar
            if let linkedID = member.value(forKey: "linkedCalendarID") as? String, !linkedID.isEmpty {
                memberCalendarIDs.insert(linkedID)
            }

            // B. Shared Calendars (Relationship)
            if let sharedSet = member.value(forKey: "sharedCalendars") as? Set<NSManagedObject> {
                for shared in sharedSet {
                    if let calID = shared.value(forKey: "calendarID") as? String, !calID.isEmpty {
                        memberCalendarIDs.insert(calID)
                    }
                }
            }

            // C. FamilyMemberCalendar Links (Manual Fetch)
            let linksRequest = NSFetchRequest<NSManagedObject>(entityName: "FamilyMemberCalendar")
            linksRequest.predicate = NSPredicate(format: "familyMember == %@", member)
            let links = try context.fetch(linksRequest)
            for link in links {
                if let calID = link.value(forKey: "calendarID") as? String, !calID.isEmpty {
                    memberCalendarIDs.insert(calID)
                }
            }

            // D. Personal Calendars (if this member is the linked user)
            // Personal calendars are tied to the logged-in user, not to a specific family member
            let memberID = (member.value(forKey: "id") as? UUID)?.uuidString ?? ""
            print("🔍 DEBUG Widget: Member ID: \(memberID)")
            if let linkedMemberId = defaults.string(forKey: "linkedFamilyMemberId") {
                print("🔍 DEBUG Widget: Linked member ID: \(linkedMemberId)")
                if linkedMemberId.lowercased() == memberID.lowercased() {
                    let personalCalRequest = NSFetchRequest<NSManagedObject>(entityName: "PersonalCalendar")
                    let personalCals = try context.fetch(personalCalRequest)
                    print("✅ DEBUG Widget: Found \(personalCals.count) personal calendars")

                    // Build maps for calendar lookup by ID and title
                    let eventStore = EKEventStore()
                    let ekCalendars = eventStore.calendars(for: .event)
                    let calendarById = Dictionary(uniqueKeysWithValues: ekCalendars.map { ($0.calendarIdentifier, $0) })
                    var calendarByTitle: [String: EKCalendar] = [:]
                    for cal in ekCalendars {
                        calendarByTitle[cal.title] = cal
                    }
                    print("🔍 DEBUG Widget: Available EK calendars: \(ekCalendars.map { $0.title }.joined(separator: ", "))")

                    for personalCal in personalCals {
                        let calName = (personalCal.value(forKey: "calendarName") as? String) ?? "nil"
                        let calID = (personalCal.value(forKey: "calendarID") as? String) ?? "nil"
                        let showInNext = (personalCal.value(forKey: "showInNext") as? Bool) ?? false
                        let showInSpotlight = (personalCal.value(forKey: "showInSpotlight") as? Bool) ?? false
                        let showInUpcoming = (personalCal.value(forKey: "showInUpcoming") as? Bool) ?? false

                        print("🔍 DEBUG Widget: Personal calendar '\(calName)' - ID: \(calID), showInNext: \(showInNext), showInSpotlight: \(showInSpotlight), showInUpcoming: \(showInUpcoming)")

                        // Include if toggled into at least one view surface
                        if showInNext || showInSpotlight || showInUpcoming {
                            var resolvedID: String?
                            if let storedID = personalCal.value(forKey: "calendarID") as? String, !storedID.isEmpty {
                                resolvedID = storedID
                                print("🔍 DEBUG Widget: Using stored ID: \(storedID)")
                                // If ID not found locally, try to find by name
                                if calendarById[storedID] == nil, let name = personalCal.value(forKey: "calendarName") as? String, let localCal = calendarByTitle[name] {
                                    print("⚠️ DEBUG Widget: Stored ID not found, resolved by name: \(name) -> \(localCal.calendarIdentifier)")
                                    resolvedID = localCal.calendarIdentifier
                                }
                            } else if let calName = personalCal.value(forKey: "calendarName") as? String, let localCal = calendarByTitle[calName] {
                                print("ℹ️ DEBUG Widget: No stored ID, resolved by name: \(calName) -> \(localCal.calendarIdentifier)")
                                resolvedID = localCal.calendarIdentifier
                            }

                            if let resolvedID = resolvedID {
                                print("✅ DEBUG Widget: Added personal calendar with ID: \(resolvedID)")
                                memberCalendarIDs.insert(resolvedID)
                            } else {
                                print("❌ DEBUG Widget: Could not resolve calendar ID for: \(calName)")
                            }
                        } else {
                            print("⚠️ DEBUG Widget: Skipping personal calendar '\(calName)' - not enabled for any view")
                        }
                    }
                }
            } else {
                print("⚠️ DEBUG Widget: No linked member ID found")
            }
            
            guard !memberCalendarIDs.isEmpty else {
                print("❌ DEBUG Widget: memberCalendarIDs is empty! IDs collected: \(memberCalendarIDs.count)")
                return NextEventEntry(errorMessage: "No calendars linked for \(memberName)")
            }

            print("✅ DEBUG Widget: memberCalendarIDs collected: \(memberCalendarIDs.count) IDs: \(memberCalendarIDs.joined(separator: ", "))")

            // 3. Fetch events for these calendars
            let eventStore = EKEventStore()
            let calendarAccess = EKEventStore.authorizationStatus(for: .event)
            if calendarAccess == .denied || calendarAccess == .restricted {
                return NextEventEntry(errorMessage: "Calendar access required")
            }
            
            let calendars = eventStore.calendars(for: .event)
                .filter { memberCalendarIDs.contains($0.calendarIdentifier) }
            
            guard !calendars.isEmpty else {
                // This might happen if the calendar was deleted from the device but still in CoreData
                return NextEventEntry(errorMessage: "Calendars not found on device")
            }
            
            let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
            let events = eventStore.events(matching: predicate)
                .sorted { $0.startDate < $1.startDate }

            // Filter to future events (matching FamilyView logic at line 1276)
            let futureEvents = events.filter { $0.endDate > Date() }

            // Filter to find first non-all-day event (for widget display we want timed events)
            // Also exclude 00:00-23:59 events which are all-day events formatted as timed
            guard let nextEvent = futureEvents.first(where: { event in
                if event.isAllDay {
                    return false
                }
                // Check for 00:00-23:59 pattern (all-day event formatted as timed)
                let calendar = Calendar.current
                let startComponents = calendar.dateComponents([.hour, .minute], from: event.startDate)
                let endComponents = calendar.dateComponents([.hour, .minute], from: event.endDate)
                if startComponents.hour == 0 && startComponents.minute == 0 &&
                   endComponents.hour == 23 && endComponents.minute == 59 {
                    return false
                }
                return true
            }) else {
                // Check if there are only all-day events
                let hasAnyAllDayEvents = futureEvents.contains { event in
                    if event.isAllDay {
                        return true
                    }
                    let calendar = Calendar.current
                    let startComponents = calendar.dateComponents([.hour, .minute], from: event.startDate)
                    let endComponents = calendar.dateComponents([.hour, .minute], from: event.endDate)
                    return startComponents.hour == 0 && startComponents.minute == 0 &&
                           endComponents.hour == 23 && endComponents.minute == 59
                }
                let message = hasAnyAllDayEvents ? "No upcoming events" : "No upcoming events"
                return NextEventEntry(errorMessage: message)
            }
            
            // 4. Return Entry with MEMBER info
            let memberData = FamilyMemberData(
                id: memberId,
                name: memberName,
                colorHex: memberColorHex
            )
            
            // Use the CALENDAR'S color for the event bar, as requested
            // "if the item is in the shared calendar it should be the shared calendars colour"
            // "if its a members event it should be their colour" (which usually matches the personal cal color)
            let calendarColor = nextEvent.calendar.cgColor ?? UIColor.gray.cgColor
            let eventColorHex = UIColor(cgColor: calendarColor).hexString
            
            let eventData = WidgetEventData(
                title: nextEvent.title ?? "Event",
                startDate: nextEvent.startDate,
                endDate: nextEvent.endDate,
                location: nextEvent.location,
                colorHex: eventColorHex // Use calendar color
            )
            
            print("✅ Widget: Returning event '\(eventData.title)' for '\(memberData.name)' with color \(eventColorHex)")
            return NextEventEntry(date: Date(), event: eventData, familyMember: memberData)
            
        } catch {
            let errorMsg = "Error: \(error.localizedDescription)"
            print("❌ Widget Error: \(errorMsg)")
            return NextEventEntry(errorMessage: errorMsg)
        }
    }
}

// Helper function for file-based logging
func logToFile(_ message: String) {
    if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.markdias.famli") {
        let logFileURL = appGroupURL.appendingPathComponent("widget_debug.log")
        let timestamp = DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] \(message)\n"

        if let data = logEntry.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = FileHandle(forWritingAtPath: logFileURL.path) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }
}

// Helper for color conversion
extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb: Int = (Int)(r*255)<<16 | (Int)(g*255)<<8 | (Int)(b*255)<<0

        return String(format: "#%06x", rgb)
    }
}
