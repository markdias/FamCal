//
//  SupabaseDataSync.swift
//  FamCal
//
//  Syncs Supabase data to local CoreData for backward compatibility
//

import Foundation
import CoreData
import EventKit

class SupabaseDataSync {
    static let shared = SupabaseDataSync()

    /// Syncs Supabase family members to local CoreData
    /// This bridges the gap during migration from CoreData to Supabase
    func syncFamilyMembersFromSupabase(
        supabaseMembers: [FamilyMemberDTO],
        supabaseCalendars: [FamilyMemberCalendarDTO],
        to context: NSManagedObjectContext
    ) {
        do {
            // Build a set of Supabase member IDs for quick lookup
            let supabaseIds = Set(supabaseMembers.map { $0.id })

            // Fetch existing members
            let fetchRequest: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
            let existingMembers = try context.fetch(fetchRequest)

            // Delete members that no longer exist in Supabase
            for existingMember in existingMembers {
                if let memberId = existingMember.id?.uuidString, !supabaseIds.contains(memberId) {
                    context.delete(existingMember)
                }
            }

            // Sync or update members from Supabase
            var syncedCount = 0
            for supabaseDTO in supabaseMembers {
                // Check if member already exists
                let existingFetch: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
                existingFetch.predicate = NSPredicate(format: "id == %@", supabaseDTO.id as CVarArg)
                let matches = try context.fetch(existingFetch)

                let member: FamilyMember
                if let existingMember = matches.first {
                    // Update existing member
                    member = existingMember
                    member.name = supabaseDTO.name
                    member.colorHex = supabaseDTO.color_hex
                    member.avatarInitials = getInitials(from: supabaseDTO.name)
                } else {
                    // Create new member
                    member = FamilyMember(context: context)
                    member.id = UUID(uuidString: supabaseDTO.id) ?? UUID()
                    member.name = supabaseDTO.name
                    member.colorHex = supabaseDTO.color_hex
                    member.avatarInitials = getInitials(from: supabaseDTO.name)
                    syncedCount += 1
                }

                // Sync calendars - diff approach to avoid deleting objects that are still valid
                let existingCalendars = member.memberCalendars as? Set<FamilyMemberCalendar> ?? []
                let supabaseMemberCalendars = supabaseCalendars.filter { $0.family_member_id == supabaseDTO.id }
                let supabaseCalendarIds = Set(supabaseMemberCalendars.map { $0.id })

                // 1. Delete calendars that are no longer in Supabase
                for calendar in existingCalendars {
                    if let calendarId = calendar.id?.uuidString, !supabaseCalendarIds.contains(calendarId) {
                        context.delete(calendar)
                    }
                }

                // 2. Update existing or create new calendars
                for calendarDTO in supabaseMemberCalendars {
                    let memberCalendar: FamilyMemberCalendar
                    let isNewCalendar: Bool

                    if let existing = existingCalendars.first(where: { $0.id?.uuidString == calendarDTO.id }) {
                        memberCalendar = existing
                        isNewCalendar = false
                    } else {
                        memberCalendar = FamilyMemberCalendar(context: context)
                        memberCalendar.id = UUID(uuidString: calendarDTO.id) ?? UUID()
                        memberCalendar.familyMember = member
                        isNewCalendar = true
                    }

                    memberCalendar.calendarName = calendarDTO.calendar_name
                    memberCalendar.calendarColorHex = calendarDTO.calendar_color_hex
                    memberCalendar.isAutoLinked = calendarDTO.is_auto_linked

                    // For new calendars or calendars without calendarID, try to match by calendar name
                    // This ensures device-specific calendar IDs are populated during sync
                    if isNewCalendar || memberCalendar.calendarID == nil || memberCalendar.calendarID!.isEmpty {
                        if let calendarName = calendarDTO.calendar_name {
                            if let matched = findCalendarIdByName(calendarName) {
                                memberCalendar.calendarID = matched
                            }
                        }
                    }
                }
            }

            try context.save()
            print("✅ Synced family members from Supabase to CoreData")
        } catch {
            print("❌ Error syncing family members: \(error)")
        }
    }

    /// Helper function to find iOS calendar ID by name
    private func findCalendarIdByName(_ calendarName: String) -> String? {
        let eventStore = EKEventStore()
        let calendars = eventStore.calendars(for: .event)
        // Case-insensitive exact match
        if let matched = calendars.first(where: { $0.title.lowercased() == calendarName.lowercased() }) {
            return matched.calendarIdentifier
        }
        return nil
    }

    /// Syncs Supabase shared calendars to local CoreData
    func syncSharedCalendarsFromSupabase(
        supabaseCalendars: [SharedCalendarDTO],
        to context: NSManagedObjectContext
    ) {
        do {
            // Build a set of Supabase calendar IDs for quick lookup
            let supabaseIds = Set(supabaseCalendars.map { $0.id })

            // Fetch existing shared calendars
            let fetchRequest: NSFetchRequest<SharedCalendar> = SharedCalendar.fetchRequest()
            let existingCalendars = try context.fetch(fetchRequest)
            let allMembers: [FamilyMember] = try context.fetch(FamilyMember.fetchRequest())

            // Delete calendars that no longer exist in Supabase
            for existingCalendar in existingCalendars {
                if let calendarId = existingCalendar.id?.uuidString, !supabaseIds.contains(calendarId) {
                    context.delete(existingCalendar)
                }
            }

            // Sync or update calendars from Supabase
            for supabaseDTO in supabaseCalendars {
                // Check if calendar already exists
                let existingFetch: NSFetchRequest<SharedCalendar> = SharedCalendar.fetchRequest()
                existingFetch.predicate = NSPredicate(format: "id == %@", supabaseDTO.id as CVarArg)
                let matches = try context.fetch(existingFetch)

                let calendar: SharedCalendar
                let isNewCalendar: Bool
                if let existingCalendar = matches.first {
                    // Update existing calendar
                    calendar = existingCalendar
                    isNewCalendar = false
                    calendar.calendarName = supabaseDTO.calendar_name
                    calendar.calendarColorHex = supabaseDTO.calendar_color_hex
                } else {
                    // Create new calendar
                    calendar = SharedCalendar(context: context)
                    calendar.id = UUID(uuidString: supabaseDTO.id) ?? UUID()
                    calendar.calendarName = supabaseDTO.calendar_name
                    calendar.calendarColorHex = supabaseDTO.calendar_color_hex
                    isNewCalendar = true
                }

                // For new calendars or calendars without calendarID, try to match by calendar name
                // This ensures device-specific calendar IDs are populated during sync
                if isNewCalendar || calendar.calendarID == nil || calendar.calendarID!.isEmpty {
                    if let calendarName = supabaseDTO.calendar_name {
                        if let matched = findCalendarIdByName(calendarName) {
                            calendar.calendarID = matched
                        }
                    }
                }

                // Ensure shared calendars are linked to all members for display/filters
                if !allMembers.isEmpty {
                    calendar.members = NSSet(array: allMembers)
                }
            }

            try context.save()
            print("✅ Synced shared calendars from Supabase to CoreData")
        } catch {
            print("❌ Error syncing shared calendars: \(error)")
        }
    }

    /// Syncs Supabase personal calendars to local CoreData
    func syncPersonalCalendarsFromSupabase(
        supabaseCalendars: [PersonalCalendarDTO],
        to context: NSManagedObjectContext
    ) {
        do {
            // Build a set of Supabase calendar IDs for quick lookup
            let supabaseIds = Set(supabaseCalendars.map { $0.id })

            // Fetch existing personal calendars
            let fetchRequest: NSFetchRequest<PersonalCalendar> = PersonalCalendar.fetchRequest()
            let existingCalendars = try context.fetch(fetchRequest)

            // Delete calendars that no longer exist in Supabase
            for existingCalendar in existingCalendars {
                if let calendarId = existingCalendar.id?.uuidString, !supabaseIds.contains(calendarId) {
                    context.delete(existingCalendar)
                }
            }

            // Sync or update calendars from Supabase
            for supabaseDTO in supabaseCalendars {
                // Check if calendar already exists
                let existingFetch: NSFetchRequest<PersonalCalendar> = PersonalCalendar.fetchRequest()
                existingFetch.predicate = NSPredicate(format: "id == %@", supabaseDTO.id as CVarArg)
                let matches = try context.fetch(existingFetch)

                let calendar: PersonalCalendar
                if let existingCalendar = matches.first {
                    // Update existing calendar
                    calendar = existingCalendar
                    calendar.calendarName = supabaseDTO.calendar_name
                    calendar.calendarColorHex = supabaseDTO.calendar_color_hex
                } else {
                    // Create new calendar
                    calendar = PersonalCalendar(context: context)
                    calendar.id = UUID(uuidString: supabaseDTO.id) ?? UUID()
                    calendar.calendarName = supabaseDTO.calendar_name
                    calendar.calendarColorHex = supabaseDTO.calendar_color_hex
                }
            }

            try context.save()
            print("✅ Synced personal calendars from Supabase to CoreData")
        } catch {
            print("❌ Error syncing personal calendars: \(error)")
        }
    }

    /// Syncs Supabase drivers to local CoreData
    func syncDriversFromSupabase(
        supabaseDrivers: [DriverDTO],
        to context: NSManagedObjectContext
    ) {
        do {
            let supabaseIds = Set(supabaseDrivers.map { $0.id })

            // Delete drivers no longer present remotely
            let fetchRequest: NSFetchRequest<Driver> = Driver.fetchRequest()
            let existingDrivers = try context.fetch(fetchRequest)
            for driver in existingDrivers {
                if let driverId = driver.id?.uuidString, !supabaseIds.contains(driverId) {
                    context.delete(driver)
                }
            }

            for dto in supabaseDrivers {
                let fetch: NSFetchRequest<Driver> = Driver.fetchRequest()
                fetch.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                let matches = try context.fetch(fetch)

                let driver: Driver
                if let existing = matches.first {
                    driver = existing
                } else {
                    driver = Driver(context: context)
                    driver.id = UUID(uuidString: dto.id) ?? UUID()
                }

                driver.name = dto.name
                driver.phone = dto.phone
                driver.email = dto.email
                driver.notes = dto.notes
                if let travel = dto.travel_time_minutes {
                    driver.travelTimeMinutes = Int16(travel)
                }
                if let famId = dto.family_member_id {
                    driver.familyMemberId = UUID(uuidString: famId)
                }
                driver.travelEventIdentifier = dto.travel_event_identifier
            }

            try context.save()
            print("✅ Synced drivers from Supabase to CoreData")
        } catch {
            print("❌ Error syncing drivers: \(error)")
        }
    }

    /// Syncs Supabase saved addresses to local CoreData
    func syncSavedAddressesFromSupabase(
        supabaseAddresses: [SavedAddressDTO],
        to context: NSManagedObjectContext
    ) {
        do {
            let supabaseIds = Set(supabaseAddresses.map { $0.id })

            let fetchRequest: NSFetchRequest<SavedAddress> = SavedAddress.fetchRequest()
            let existingAddresses = try context.fetch(fetchRequest)

            for address in existingAddresses {
                if let id = address.id?.uuidString, !supabaseIds.contains(id) {
                    context.delete(address)
                }
            }

            for dto in supabaseAddresses {
                let fetch: NSFetchRequest<SavedAddress> = SavedAddress.fetchRequest()
                fetch.predicate = NSPredicate(format: "id == %@", dto.id as CVarArg)
                let matches = try context.fetch(fetch)

                let address: SavedAddress
                if let existing = matches.first {
                    address = existing
                } else {
                    address = SavedAddress(context: context)
                    address.id = UUID(uuidString: dto.id) ?? UUID()
                }

                address.name = dto.name
                address.address = dto.address
                address.latitude = dto.latitude ?? 0
                address.longitude = dto.longitude ?? 0
            }

            try context.save()
            print("✅ Synced saved addresses from Supabase to CoreData")
        } catch {
            print("❌ Error syncing saved addresses: \(error)")
        }
    }

    /// Syncs Supabase calendar event metadata (app-only fields) to local CoreData FamilyEvent records
    func syncEventMetadataFromSupabase(
        supabaseMetadata: [CalendarEventMetadataDTO],
        _ supabaseDrivers: [DriverDTO],
        to context: NSManagedObjectContext
    ) {
        do {
            // Build a lookup for drivers already saved in CoreData
            let driverFetch: NSFetchRequest<Driver> = Driver.fetchRequest()
            let existingDrivers = try context.fetch(driverFetch)
            var driverMap: [UUID: Driver] = [:]
            for driver in existingDrivers {
                if let id = driver.id {
                    driverMap[id] = driver
                }
            }

            for meta in supabaseMetadata {
                let fetchRequest: NSFetchRequest<FamilyEvent> = FamilyEvent.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "eventIdentifier == %@", meta.event_identifier)
                let matches = try context.fetch(fetchRequest)

                let familyEvent: FamilyEvent
                if let existing = matches.first {
                    familyEvent = existing
                } else {
                    familyEvent = FamilyEvent(context: context)
                    familyEvent.id = UUID()
                    familyEvent.eventGroupId = UUID()
                    familyEvent.eventIdentifier = meta.event_identifier
                    familyEvent.createdAt = Date()
                }

                // Driver: prefer driver_family_member_id, otherwise fall back to driver_id in extra
                if let famIdString = meta.driver_family_member_id, let famId = UUID(uuidString: famIdString) {
                    familyEvent.driverFamilyMemberId = famId
                    familyEvent.driver = nil
                } else if let driverIdValue = meta.extra?["driver_id"], case let .string(driverIdString) = driverIdValue,
                          let driverUUID = UUID(uuidString: driverIdString),
                          let driver = driverMap[driverUUID] {
                    familyEvent.driver = driver
                    familyEvent.driverFamilyMemberId = nil
                } else {
                    familyEvent.driver = nil
                    familyEvent.driverFamilyMemberId = nil
                }
            }

            try context.save()
            print("✅ Synced \(supabaseMetadata.count) calendar event metadata records to CoreData")
        } catch {
            print("❌ Error syncing calendar event metadata: \(error)")
        }
    }

    private func getInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].first ?? "?") + String(components[1].first ?? "?")
        } else {
            return String(name.prefix(2)).uppercased()
        }
    }
}
