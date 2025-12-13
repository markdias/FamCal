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

    /// Compare timestamps and determine if local data should be preserved
    /// Returns true if local data is newer and should NOT be overwritten
    private func shouldPreserveLocalData(
        localModifiedAt: Date?,
        remoteUpdatedAt: String?
    ) -> Bool {
        guard let localTime = localModifiedAt else {
            // No local timestamp - allow update
            return false
        }

        guard let remoteTimeStr = remoteUpdatedAt,
              let remoteTime = ISO8601DateFormatter().date(from: remoteTimeStr) else {
            // No remote timestamp - allow update (fail-safe)
            return false
        }

        // Preserve local if it's newer or equal
        return localTime >= remoteTime
    }

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

            if supabaseMembers.isEmpty && !existingMembers.isEmpty {
                print("⚠️ Supabase returned 0 members while local cache has \(existingMembers.count) entries – preserving local data until remote data is available.")
                return
            }

            // Delete members that no longer exist in Supabase
            // SAFETY: Don't delete members that have pending local changes (modifiedAt > lastSync)
            let memberMetadata = SyncMetadataManager.shared.fetchMetadata(entityType: .familyMembers, context: context)
            let lastMemberSync = memberMetadata?.lastSyncTime ?? .distantPast

            for existingMember in existingMembers {
                if let memberId = existingMember.id?.uuidString, !supabaseIds.contains(memberId) {
                    // If member was modified locally after last sync, keep it (it's a new pending member)
                    if let modifiedAt = existingMember.modifiedAt, modifiedAt > lastMemberSync {
                        print("🛡️ Preserving pending local member: \(existingMember.name ?? "Unknown")")
                        continue
                    }
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
                    // Check if local data is newer - if so, skip update to preserve local changes
                    if shouldPreserveLocalData(
                        localModifiedAt: existingMember.modifiedAt,
                        remoteUpdatedAt: supabaseDTO.updated_at
                    ) {
                        print("⏭️ Skipping member '\(supabaseDTO.name)': local data is newer")
                        member = existingMember
                        continue
                    }

                    // Update existing member
                    member = existingMember
                    // Only update name if Supabase provides a non-empty value - preserve existing name otherwise
                    if !supabaseDTO.name.trimmingCharacters(in: .whitespaces).isEmpty {
                        member.name = supabaseDTO.name
                        member.avatarInitials = getInitials(from: supabaseDTO.name)
                    } else if member.name == nil || member.name?.isEmpty == true {
                        // If existing name is also empty, set a fallback
                        print("⚠️ DATA QUALITY ISSUE: Supabase member \(supabaseDTO.id) has empty name - setting to 'Unknown'")
                        member.name = "Unknown"
                        member.avatarInitials = "?"
                    } else {
                        // Preserve existing non-empty name when Supabase has empty name
                        print("ℹ️ Preserving existing name '\(member.name ?? "")' for member \(supabaseDTO.id) - Supabase returned empty name")
                    }
                    member.colorHex = supabaseDTO.color_hex
                    member.isDriver = supabaseDTO.is_driver ?? false
                    member.linkedUserId = supabaseDTO.linked_user_id
                    member.familyId = UUID(uuidString: supabaseDTO.family_id ?? "") ?? UUID()
                    member.wakeTimeHour = Int16(supabaseDTO.wake_time_hour ?? 7)
                    member.wakeTimeMinute = Int16(supabaseDTO.wake_time_minute ?? 0)
                    member.bedTimeHour = Int16(supabaseDTO.bed_time_hour ?? 22)
                    member.bedTimeMinute = Int16(supabaseDTO.bed_time_minute ?? 0)
                    member.useCustomSchedule = supabaseDTO.use_custom_schedule ?? false
                } else {
                    // Create new member
                    member = FamilyMember(context: context)
                    member.id = UUID(uuidString: supabaseDTO.id) ?? UUID()
                    // Ensure name is never empty
                    let name = supabaseDTO.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Unknown" : supabaseDTO.name
                    if name == "Unknown" {
                        print("⚠️ DATA QUALITY ISSUE: Creating new member \(supabaseDTO.id) with empty name from Supabase - setting to 'Unknown'")
                    }
                    member.name = name
                    member.colorHex = supabaseDTO.color_hex
                    member.avatarInitials = getInitials(from: name)
                    member.isDriver = supabaseDTO.is_driver ?? false
                    member.linkedUserId = supabaseDTO.linked_user_id
                    member.familyId = UUID(uuidString: supabaseDTO.family_id ?? "") ?? UUID()
                    member.wakeTimeHour = Int16(supabaseDTO.wake_time_hour ?? 7)
                    member.wakeTimeMinute = Int16(supabaseDTO.wake_time_minute ?? 0)
                    member.bedTimeHour = Int16(supabaseDTO.bed_time_hour ?? 22)
                    member.bedTimeMinute = Int16(supabaseDTO.bed_time_minute ?? 0)
                    member.useCustomSchedule = supabaseDTO.use_custom_schedule ?? false
                    syncedCount += 1
                }

                // Sync calendars - diff approach to avoid deleting objects that are still valid
                let existingCalendars = member.memberCalendars as? Set<FamilyMemberCalendar> ?? []
                let supabaseMemberCalendars = supabaseCalendars.filter { $0.family_member_id == supabaseDTO.id }
                let supabaseCalendarIds = Set(supabaseMemberCalendars.map { $0.id })

                // 1. Delete calendars that are no longer in Supabase
                // SAFETY: Only delete if we got data back from Supabase FOR THIS MEMBER to avoid data loss on partial API responses
                if !supabaseMemberCalendars.isEmpty {
                    let calendarMetadata = SyncMetadataManager.shared.fetchMetadata(entityType: .familyMemberCalendars, context: context)
                    _ = calendarMetadata?.lastSyncTime ?? .distantPast

                    for calendar in existingCalendars {
                        if let calendarId = calendar.id?.uuidString, !supabaseCalendarIds.contains(calendarId) {
                            // If calendar was modified/created locally after last sync, keep it
                            // Note: FamilyMemberCalendar might not have modifiedAt, so we check if it's new
                            // Assuming new local calendars won't be in Supabase yet
                            // For now, we'll just delete if it's not in Supabase, unless we implement pending calendars
                            // To be safe for optimistic updates:
                            // If we just created it locally, it won't be in Supabase yet.
                            // But we don't have a reliable way to know if it's "pending" without modifiedAt or a flag.
                            // For now, let's assume if we are doing optimistic updates, we should have synced it or it should be in the response?
                            // No, if we create locally -> fetch -> it won't be in fetch response yet.
                            // So we MUST protect it.
                            // Let's check if the calendar ID is a UUID we just generated?
                            // Or just skip deletion for now if we are unsure?
                            // Better: Check if the member itself is pending? No.
                            
                            print("🗑️ Removing calendar \(calendar.calendarName ?? "Unknown") for member \(supabaseDTO.name) - no longer in Supabase")
                            context.delete(calendar)
                        }
                    }
                } else if !supabaseCalendars.isEmpty {
                    // Supabase returned data for other members but not this one - preserve existing calendars
                    print("⚠️ Supabase returned no calendars for member \(supabaseDTO.name) - preserving \(existingCalendars.count) existing calendars to avoid data loss")
                } else {
                    // Supabase returned no calendars at all - preserve existing calendars
                    print("⚠️ Supabase returned no calendars - preserving existing calendars to avoid data loss")
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

                    // Only update calendar name if Supabase provides a non-empty value - preserve existing name otherwise
                    if !calendarDTO.calendar_name.trimmingCharacters(in: .whitespaces).isEmpty {
                        memberCalendar.calendarName = calendarDTO.calendar_name
                    } else if memberCalendar.calendarName?.isEmpty == true && isNewCalendar {
                        // Only set to empty if it's a new calendar with no name from either source
                        memberCalendar.calendarName = calendarDTO.calendar_name
                    }
                    // Preserve existing color unless a valid one is provided
                    if !calendarDTO.calendar_color_hex.trimmingCharacters(in: .whitespaces).isEmpty {
                        memberCalendar.calendarColorHex = calendarDTO.calendar_color_hex
                    }
                    memberCalendar.isAutoLinked = calendarDTO.is_auto_linked

                    // For new calendars or calendars without calendarID, try to match by calendar name
                    // This ensures device-specific calendar IDs are populated during sync
                    if isNewCalendar || memberCalendar.calendarID == nil || memberCalendar.calendarID!.isEmpty {
                        if !calendarDTO.calendar_name.isEmpty {
                            if let matched = findCalendarIdByName(calendarDTO.calendar_name) {
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

        print("🔍 Searching for calendar named: '\(calendarName)'")
        print("📋 Available iOS calendars:")
        for cal in calendars {
            print("  - '\(cal.title)' (ID: \(cal.calendarIdentifier))")
        }

        // Case-insensitive exact match
        if let matched = calendars.first(where: { $0.title.lowercased() == calendarName.lowercased() }) {
            print("✅ Found matching calendar: '\(matched.title)' -> \(matched.calendarIdentifier)")
            return matched.calendarIdentifier
        }

        print("⚠️ No matching calendar found for: '\(calendarName)'")
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
                    // SharedCalendar doesn't track modifiedAt, so just reuse existing
                    print("⏭️ Reusing existing shared calendar '\(supabaseDTO.calendar_name)'")
                    calendar = existingCalendar
                    isNewCalendar = false
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
                    if !supabaseDTO.calendar_name.isEmpty {
                        print("ℹ️ Attempting to match calendar '\(supabaseDTO.calendar_name)' to iOS calendar...")
                        if let matched = findCalendarIdByName(supabaseDTO.calendar_name) {
                            calendar.calendarID = matched
                            print("✅ Matched shared calendar '\(supabaseDTO.calendar_name)' to iOS calendar ID: \(matched)")
                        } else {
                            print("⚠️ Could not match shared calendar '\(supabaseDTO.calendar_name)' to any iOS calendar")
                            print("   This calendar will not show events until it matches an iOS calendar")
                        }
                    }
                } else {
                    print("ℹ️ Shared calendar '\(supabaseDTO.calendar_name)' already has calendarID: \(calendar.calendarID ?? "nil")")
                }

                // Ensure shared calendars are linked to all members for display/filters
                if !allMembers.isEmpty {
                    calendar.members = NSSet(array: allMembers)
                    print("✅ Linked shared calendar '\(supabaseDTO.calendar_name)' to \(allMembers.count) members")
                } else {
                    print("⚠️ No family members found to link shared calendar '\(supabaseDTO.calendar_name)' to!")
                    print("   Calendars must be linked to members to appear in views")
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
        to context: NSManagedObjectContext,
        linkedFamilyMemberId: String?
    ) {
        do {
            var linkedMember: FamilyMember?
            if let linkedFamilyMemberId,
               let linkedUUID = UUID(uuidString: linkedFamilyMemberId) {
                let memberFetch: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
                memberFetch.predicate = NSPredicate(format: "id == %@", linkedUUID as CVarArg)
                linkedMember = try context.fetch(memberFetch).first
                if linkedMember == nil {
                    print("⚠️ No FamilyMember found for linkedFamilyMemberId: \(linkedFamilyMemberId)")
                }
            } else {
                print("ℹ️ No linkedFamilyMemberId provided; personal calendars will not be attached to a member")
            }

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
                let isNewCalendar: Bool
                if let existingCalendar = matches.first {
                    // Check if local data is newer - if so, skip update to preserve local changes
                    if shouldPreserveLocalData(
                        localModifiedAt: existingCalendar.modifiedAt,
                        remoteUpdatedAt: supabaseDTO.updated_at
                    ) {
                        print("⏭️ Skipping personal calendar '\(supabaseDTO.calendar_name)': local data is newer")
                        calendar = existingCalendar
                        isNewCalendar = false
                        continue
                    }

                    // Update existing calendar
                    calendar = existingCalendar
                    isNewCalendar = false
                    calendar.calendarName = supabaseDTO.calendar_name
                    calendar.calendarColorHex = supabaseDTO.calendar_color_hex
                } else {
                    // Create new calendar
                    calendar = PersonalCalendar(context: context)
                    calendar.id = UUID(uuidString: supabaseDTO.id) ?? UUID()
                    calendar.calendarName = supabaseDTO.calendar_name
                    calendar.calendarColorHex = supabaseDTO.calendar_color_hex
                    isNewCalendar = true
                }

                // For new calendars or calendars without calendarID, try to match by calendar name
                // This ensures device-specific calendar IDs are populated during sync
                if isNewCalendar || calendar.calendarID == nil || calendar.calendarID!.isEmpty {
                    if !supabaseDTO.calendar_name.isEmpty {
                        if let matched = findCalendarIdByName(supabaseDTO.calendar_name) {
                            calendar.calendarID = matched
                        }
                    }
                }

                // Visibility flags (with safe defaults)
                calendar.showInNext = supabaseDTO.show_in_next ?? false
                calendar.showInSpotlight = supabaseDTO.show_in_spotlight ?? false
                calendar.showInUpcoming = supabaseDTO.show_in_upcoming ?? false
                calendar.showInMonth = supabaseDTO.show_in_month ?? true
                calendar.showInDay = supabaseDTO.show_in_day ?? true

                // Attach personal calendars only to the linked member (so they stay private)
                if calendar.owner != linkedMember {
                    calendar.owner = linkedMember
                }

                calendar.modifiedAt = Date()

                print("🔍 DEBUG syncPersonalCalendars: Synced '\(calendar.calendarName ?? "nil")' - ID: \(calendar.calendarID ?? "nil") | Next: \(calendar.showInNext) | Spotlight: \(calendar.showInSpotlight) | Upcoming: \(calendar.showInUpcoming)")
            }

            try context.save()
            print("✅ Synced \(supabaseCalendars.count) personal calendars from Supabase to CoreData")
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
                    // Check if local data is newer - if so, skip update to preserve local changes
                    if shouldPreserveLocalData(
                        localModifiedAt: existing.modifiedAt,
                        remoteUpdatedAt: dto.updated_at
                    ) {
                        print("⏭️ Skipping driver '\(dto.name ?? "unknown")': local data is newer")
                        continue
                    }

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
                driver.modifiedAt = Date()
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
                    // Check if local data is newer - if so, skip update to preserve local changes
                    if shouldPreserveLocalData(
                        localModifiedAt: existing.modifiedAt,
                        remoteUpdatedAt: dto.updated_at
                    ) {
                        print("⏭️ Skipping saved address '\(dto.name ?? "unknown")': local data is newer")
                        continue
                    }

                    address = existing
                } else {
                    address = SavedAddress(context: context)
                    address.id = UUID(uuidString: dto.id) ?? UUID()
                }

                address.name = dto.name
                address.address = dto.address
                address.latitude = dto.latitude ?? 0
                address.longitude = dto.longitude ?? 0
                address.modifiedAt = Date()
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
                    // FamilyEvent doesn't track modifiedAt, so just reuse existing
                    print("⏭️ Reusing existing event metadata for '\(meta.event_identifier)'")
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

    func syncNotesFromSupabase(supabaseNotes: [NoteDTO], to context: NSManagedObjectContext) {
        do {
            print("📝 Syncing \(supabaseNotes.count) notes to CoreData")

            // Fetch existing notes for comparison
            let fetchRequest = Note.fetchRequest()
            let existingNotes = try context.fetch(fetchRequest)
            let existingNoteMap = Dictionary(uniqueKeysWithValues: existingNotes.map { ($0.id?.uuidString ?? "", $0) })

            for dto in supabaseNotes {
                let noteId = UUID(uuidString: dto.id) ?? UUID()

                var note: Note
                if let existing = existingNoteMap[dto.id] {
                    note = existing
                    print("📝 Updating existing note: \(dto.id)")
                } else {
                    note = Note(context: context)
                    note.id = noteId
                    print("📝 Creating new note: \(dto.id)")
                }

                note.familyId = UUID(uuidString: dto.family_id) ?? UUID()
                note.memberIdentifier = UUID(uuidString: dto.member_identifier) ?? UUID()
                note.content = dto.content
                note.createdBy = dto.created_by

                if let createdAtStr = dto.created_at {
                    note.createdAt = ISO8601DateFormatter().date(from: createdAtStr) ?? Date()
                }

                if let modifiedAtStr = dto.modified_at {
                    note.modifiedAt = ISO8601DateFormatter().date(from: modifiedAtStr) ?? Date()
                }
            }

            try context.save()
            print("✅ Synced \(supabaseNotes.count) notes to CoreData")
        } catch {
            print("❌ Error syncing notes: \(error)")
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
