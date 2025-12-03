import Foundation
import WatchConnectivity
import EventKit
import CoreData
import Combine

/// Bridges the phone's CoreData/EventKit state to WatchConnectivity requests.
final class WatchSessionManager: NSObject, ObservableObject {
    nonisolated private let session: WCSession?
    nonisolated private let persistenceController = PersistenceController.shared
    let objectWillChange = ObservableObjectPublisher()

    override init() {
        if WCSession.isSupported() {
            session = .default
        } else {
            session = nil
        }
        super.init()

        session?.delegate = self
        session?.activate()

        if let session = session {
            print("📱 WCSession initialized:")
            print("  - isSupported: true")
            print("  - activationState: \(session.activationState.rawValue)")
            print("  - isReachable: \(session.isReachable)")
        } else {
            print("📱 WCSession not supported on this device")
        }
    }

    nonisolated private func handleMessage(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let action = message["action"] as? String, action == "getMembers" else {
            print("⚠️ Invalid action: \(message["action"] ?? "nil")")
            replyHandler([:])
            return
        }

        print("📱 Watch requested members")

        // Perform directly on the background context
        persistenceController.container.performBackgroundTask { context in
            do {
                let memberRequest = NSFetchRequest<NSManagedObject>(entityName: "FamilyMember")
                memberRequest.returnsObjectsAsFaults = false
                let members = try context.fetch(memberRequest)

                print("✅ Fetched \(members.count) members")

                // Build simple array of member names
                var memberNames: [String] = []
                for member in members {
                    if let name = member.value(forKey: "name") as? String {
                        memberNames.append(name)
                    }
                }

                let response: [String: Any] = [
                    "ok": "yes",
                    "members": memberNames.joined(separator: ",")
                ]

                print("📤 Sending \(memberNames.count) member names")
                replyHandler(response)
                print("✔️ Response sent to watch")

            } catch {
                print("⚠️ Error: \(error.localizedDescription)")
                replyHandler(["ok": "no", "error": error.localizedDescription])
            }
        }
    }

    nonisolated private static func buildMemberNextEvents(in context: NSManagedObjectContext) throws -> [WatchMemberEvent] {
        // Initialize EKEventStore once for the entire operation
        let eventStore = EKEventStore()
        
        let calendarAccess = EKEventStore.authorizationStatus(for: .event)
        if calendarAccess == .denied || calendarAccess == .restricted {
            throw WatchSessionError.calendarAccessDenied
        }
        
        // Fetch all calendars once to use for both linking and event fetching
        let ekCalendars = eventStore.calendars(for: .event)
        let calendarsById = Dictionary(uniqueKeysWithValues: ekCalendars.map { ($0.calendarIdentifier, $0) })
        let calendarsByTitle = Dictionary(uniqueKeysWithValues: ekCalendars.map { ($0.title, $0) })

        let memberRequest = NSFetchRequest<NSManagedObject>(entityName: "FamilyMember")
        memberRequest.returnsObjectsAsFaults = false
        let members = try context.fetch(memberRequest)

        var memberInfos: [UUID: MemberInfo] = [:]

        for member in members {
            guard let id = member.value(forKey: "id") as? UUID else {
                continue
            }
            let name = (member.value(forKey: "name") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Member"
            let colorHex = (member.value(forKey: "colorHex") as? String) ?? "#007AFF"
            let sortOrder = Int(member.value(forKey: "sortOrder") as? Int16 ?? 0)
            var calendarIDs: Set<String> = []

            if let linkedCalendarID = (member.value(forKey: "linkedCalendarID") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !linkedCalendarID.isEmpty {
                calendarIDs.insert(linkedCalendarID)
            }

            if let calendars = member.value(forKey: "memberCalendars") as? NSSet {
                for case let calendar as NSManagedObject in calendars {
                    if let calendarID = (calendar.value(forKey: "calendarID") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !calendarID.isEmpty {
                        calendarIDs.insert(calendarID)
                    }
                }
            }

            memberInfos[id] = MemberInfo(id: id, name: name, colorHex: colorHex, sortOrder: sortOrder, calendarIDs: calendarIDs)
        }

        guard !memberInfos.isEmpty else {
            throw WatchSessionError.noMembersFound
        }

        if let linkedMemberString = UserDefaults.standard.string(forKey: "linkedFamilyMemberId"),
           let linkedMemberId = UUID(uuidString: linkedMemberString),
           var linkedInfo = memberInfos[linkedMemberId] {
            
            // Use the already fetched calendars
            let personalRequest = NSFetchRequest<NSManagedObject>(entityName: "PersonalCalendar")
            personalRequest.returnsObjectsAsFaults = false
            let personalCalendars = try context.fetch(personalRequest)

            for personal in personalCalendars {
                let calName = personal.value(forKey: "calendarName") as? String
                var resolvedID: String?
                if let storedID = personal.value(forKey: "calendarID") as? String, !storedID.isEmpty {
                    resolvedID = storedID
                    if calendarsById[storedID] == nil, let name = calName, let fallback = calendarsByTitle[name] {
                        resolvedID = fallback.calendarIdentifier
                    }
                } else if let name = calName, let fallback = calendarsByTitle[name] {
                    resolvedID = fallback.calendarIdentifier
                }

                let showInNext = (personal.value(forKey: "showInNext") as? Bool) ?? false
                let showInSpotlight = (personal.value(forKey: "showInSpotlight") as? Bool) ?? false
                let showInUpcoming = (personal.value(forKey: "showInUpcoming") as? Bool) ?? false

                if (showInNext || showInSpotlight || showInUpcoming),
                   let resolved = resolvedID?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !resolved.isEmpty {
                    linkedInfo.calendarIDs.insert(resolved)
                }
            }

            memberInfos[linkedMemberId] = linkedInfo
        }

        let calendarToMember = memberInfos.values.reduce(into: [String: UUID]()) { partial, info in
            for calendarID in info.calendarIDs {
                partial[calendarID] = info.id
            }
        }

        let allCalendarIDs = Set(calendarToMember.keys)

        guard !allCalendarIDs.isEmpty else {
            throw WatchSessionError.noCalendarsConfigured
        }

        let now = Date()
        let futureDays = UserDefaults.standard.integer(forKey: "eventsFutureDays")
        let daysAhead = futureDays > 0 ? futureDays : 180
        guard let endDate = Calendar.current.date(byAdding: .day, value: daysAhead, to: now) else {
            throw WatchSessionError.invalidDateRange
        }

        // Use the same eventStore and filtered calendars
        let calendars = ekCalendars.filter { allCalendarIDs.contains($0.calendarIdentifier) }

        guard !calendars.isEmpty else {
            throw WatchSessionError.noCalendarsConfigured
        }

        let predicate = eventStore.predicateForEvents(withStart: now, end: endDate, calendars: calendars)
        let ekEvents = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        var nextEventByMember: [UUID: EKEvent] = [:]
        for event in ekEvents where event.endDate > now && !event.isAllDay {
            if let memberId = calendarToMember[event.calendar.calendarIdentifier], nextEventByMember[memberId] == nil {
                nextEventByMember[memberId] = event
            }
        }

        let sortedInfos = memberInfos.values.sorted {
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        return sortedInfos.map { info in
            let event = nextEventByMember[info.id]
            let calendarColorHex = Self.hexString(from: event?.calendar.cgColor) ?? info.colorHex
            let attendees = event?.attendees?.compactMap { $0.name } ?? []

            return WatchMemberEvent(
                memberId: info.id,
                memberName: info.name,
                memberColorHex: info.colorHex,
                calendarColorHex: calendarColorHex,
                calendarTitle: event?.calendar.title,
                eventTitle: event?.title,
                eventIdentifier: event?.eventIdentifier,
                startDate: event?.startDate,
                endDate: event?.endDate,
                location: event?.location,
                attendees: attendees
            )
        }
    }

    nonisolated private static func hexString(from cgColor: CGColor?) -> String? {
        guard let components = cgColor?.components else {
            return nil
        }

        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat

        if components.count >= 3 {
            red = components[0]
            green = components[1]
            blue = components[2]
        } else if let grayscale = components.first {
            red = grayscale
            green = grayscale
            blue = grayscale
        } else {
            return nil
        }

        return String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }
}

private struct MemberInfo {
    let id: UUID
    let name: String
    let colorHex: String
    let sortOrder: Int
    var calendarIDs: Set<String>
}

private enum WatchSessionError: LocalizedError {
    case noMembersFound
    case noCalendarsConfigured
    case calendarAccessDenied
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .noMembersFound:
            return "No family members configured yet."
        case .noCalendarsConfigured:
            return "No calendars are linked to your family members."
        case .calendarAccessDenied:
            return "Calendar access is restricted. Please grant permission in Settings."
        case .invalidDateRange:
            return "Unable to compute the future range for events."
        }
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("📱 WatchSession activation callback received")
        if let error {
            print("⚠️ WatchSession activation failed: \(error.localizedDescription)")
        } else {
            print("📱 WatchSession activation state: \(activationState.rawValue)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("📱 WatchSession became inactive")
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("📱 WatchSession deactivated, reactivating...")
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        print("📱 Received message from watch: \(message)")
        handleMessage(message, replyHandler: replyHandler)
    }
}
