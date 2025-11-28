//
//  SupabaseDataManager.swift
//  FamCal
//
//  Manages Supabase data fetching and caching for the app
//

import Foundation
import Combine
import CoreData
import EventKit

class SupabaseDataManager: ObservableObject {
    static let shared = SupabaseDataManager()

    @MainActor @Published var familyMembers: [FamilyMemberDTO] = []
    @MainActor @Published var familyMemberCalendars: [FamilyMemberCalendarDTO] = []
    @MainActor @Published var sharedCalendars: [SharedCalendarDTO] = []
    @MainActor @Published var personalCalendars: [PersonalCalendarDTO] = []
    @MainActor @Published var drivers: [DriverDTO] = []
    @MainActor @Published var savedAddresses: [SavedAddressDTO] = []
    @MainActor @Published var memberLinkedEmails: [UUID: String] = [:]
    @MainActor @Published var isLoading = false
    @MainActor @Published var errorMessage: String?

    let supabaseManager: SupabaseManager
    let authManager: SupabaseAuthManager
    let appSettingsManager: AppSettingsManager
    private var cancellables = Set<AnyCancellable>()
    private var managedObjectContext: NSManagedObjectContext?

    init() {
        self.supabaseManager = SupabaseManager.shared
        self.authManager = SupabaseAuthManager.shared
        self.appSettingsManager = AppSettingsManager.shared

        // Observe authentication changes to fetch data
        authManager.$isAuthenticated
            .sink { [weak self] isAuthenticated in
                if isAuthenticated {
                    Task { @MainActor in
                        print("ℹ️ Authentication state changed to authenticated, attempting to fetch data...")
                        // Only fetch if context is available
                        if self?.managedObjectContext != nil {
                            await self?.fetchUserData()
                        } else {
                            print("ℹ️ CoreData context not yet available, deferring fetch...")
                        }
                    }
                } else {
                    Task { @MainActor in
                        self?.clearData()
                    }
                }
            }
            .store(in: &cancellables)
    }

    func setManagedObjectContext(_ context: NSManagedObjectContext) {
        print("ℹ️ Setting CoreData context, now fetching user data...")
        self.managedObjectContext = context

        // Fetch data once context is available (if already authenticated)
        if authManager.isAuthenticated {
            print("ℹ️ User is authenticated, fetching user data now...")
            Task { @MainActor in
                await self.fetchUserData()
            }
        } else {
            print("ℹ️ User not authenticated yet, skipping fetch")
        }
    }

    // MARK: - Data Fetching

    @MainActor
    func fetchUserData() async {
        guard let userId = authManager.userId else {
            errorMessage = "User ID not available"
            print("❌ Cannot fetch data: User ID is nil")
            return
        }

            print("ℹ️ Starting data fetch for user: \(userId)")
            isLoading = true
            errorMessage = nil

            do {
                print("ℹ️ Fetching family members from Supabase...")
            async let familyMembers = supabaseManager.getFamilyMembers(userId: userId)
            async let sharedCalendars = supabaseManager.getSharedCalendars(userId: userId)
            async let personalCalendars = supabaseManager.getPersonalCalendars(userId: userId)
            async let drivers = supabaseManager.getDrivers(userId: userId)
            async let savedAddresses = supabaseManager.getSavedAddresses(userId: userId)
            async let eventMetadata = supabaseManager.getCalendarEventMetadata(userId: userId)

            self.familyMembers = try await familyMembers
            print("✅ Fetched \(self.familyMembers.count) family members from Supabase")
            await populateMemberEmails(from: self.familyMembers)
            // Auto-select linked family member for current user
            if let authUserId = authManager.userId,
               let linkedMember = self.familyMembers.first(where: { $0.linked_user_id == authUserId }) {
                appSettingsManager.linkedFamilyMemberId = linkedMember.id
                await appSettingsManager.saveSettings()
                print("✅ Linked current user to family member: \(linkedMember.name)")
            }

            print("ℹ️ Fetching family member calendars from Supabase...")
            var calendarDTOs = try await fetchAllFamilyMemberCalendars()
            self.familyMemberCalendars = calendarDTOs
            print("✅ Fetched \(calendarDTOs.count) family member calendars from Supabase")

            // If no calendars are linked yet, attempt an auto-link pass by matching calendar names on device
            if calendarDTOs.isEmpty, await autoLinkCalendarsIfEmpty(familyMembers: self.familyMembers) {
                print("ℹ️ Refetching calendars after auto-link...")
                calendarDTOs = try await fetchAllFamilyMemberCalendars()
                self.familyMemberCalendars = calendarDTOs
                print("✅ Fetched \(calendarDTOs.count) family member calendars after auto-link")
            }

            self.sharedCalendars = try await sharedCalendars
            print("✅ Fetched \(self.sharedCalendars.count) shared calendars from Supabase")

            self.personalCalendars = try await personalCalendars
            print("✅ Fetched \(self.personalCalendars.count) personal calendars from Supabase")

            if let fetchedDrivers = try? await drivers {
                self.drivers = fetchedDrivers
                print("✅ Fetched \(self.drivers.count) drivers from Supabase")
            } else {
                self.drivers = []
                print("⚠️ Failed to fetch drivers from Supabase, continuing with empty list")
            }

            if let fetchedAddresses = try? await savedAddresses {
                self.savedAddresses = fetchedAddresses
                print("✅ Fetched \(self.savedAddresses.count) saved addresses from Supabase")
            } else {
                self.savedAddresses = []
                print("⚠️ Failed to fetch saved addresses from Supabase, continuing with empty list")
            }

            let calendarEventMetadata = (try? await eventMetadata) ?? []
            print("✅ Fetched \(calendarEventMetadata.count) calendar event metadata records from Supabase")

            // Load app settings
            print("ℹ️ Loading app settings from Supabase...")
            await appSettingsManager.loadSettings()

            // Sync to CoreData for backward compatibility with existing views
            if let context = managedObjectContext {
                print("ℹ️ Syncing data to CoreData...")
                SupabaseDataSync.shared.syncFamilyMembersFromSupabase(
                    supabaseMembers: self.familyMembers,
                    supabaseCalendars: calendarDTOs,
                    to: context
                )
                SupabaseDataSync.shared.syncSharedCalendarsFromSupabase(
                    supabaseCalendars: self.sharedCalendars,
                    to: context
                )
                SupabaseDataSync.shared.syncPersonalCalendarsFromSupabase(
                    supabaseCalendars: self.personalCalendars,
                    to: context
                )
                SupabaseDataSync.shared.syncDriversFromSupabase(
                    supabaseDrivers: self.drivers,
                    to: context
                )
                SupabaseDataSync.shared.syncSavedAddressesFromSupabase(
                    supabaseAddresses: self.savedAddresses,
                    to: context
                )
                SupabaseDataSync.shared.syncEventMetadataFromSupabase(
                    supabaseMetadata: calendarEventMetadata,
                    self.drivers,
                    to: context
                )
            } else {
                print("⚠️ CoreData context not available - skipping sync")
            }

            print("✅ Data fetch complete: \(self.familyMembers.count) family members and \(self.sharedCalendars.count) shared calendars")
        } catch {
            if let urlError = error as? URLError, urlError.code == .cancelled {
                print("ℹ️ Data fetch cancelled (likely superseded by a newer request)")
                return
            }
            errorMessage = "Failed to fetch data: \(error.localizedDescription)"
            print("❌ Error fetching user data: \(error)")
        }

        isLoading = false
    }

    private func fetchAllFamilyMemberCalendars() async throws -> [FamilyMemberCalendarDTO] {
        var allCalendars: [FamilyMemberCalendarDTO] = []
        for member in familyMembers {
            let calendars = try await supabaseManager.getFamilyMemberCalendars(memberId: member.id)
            allCalendars.append(contentsOf: calendars)
        }
        return allCalendars
    }

    private func autoLinkCalendarsIfEmpty(familyMembers: [FamilyMemberDTO]) async -> Bool {
        // Only attempt if the app can see calendars
        let calendarStatus = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            guard calendarStatus == .fullAccess || calendarStatus == .writeOnly else {
                print("ℹ️ Skipping auto-link: calendar permission not granted")
                return false
            }
        } else {
            guard calendarStatus == .authorized else {
                print("ℹ️ Skipping auto-link: calendar permission not granted")
                return false
            }
        }

        let availableCalendars = CalendarManager.shared.fetchAvailableCalendars()
        guard !availableCalendars.isEmpty else {
            print("ℹ️ Skipping auto-link: no local calendars available")
            return false
        }

        var usedIds = Set<String>()
        var linked = false

        for member in familyMembers {
            let targetName = member.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !targetName.isEmpty else { continue }
            // Exact match first, then contains
            let match = availableCalendars.first(where: { cal in
                !usedIds.contains(cal.id) && cal.title.lowercased() == targetName
            }) ?? availableCalendars.first(where: { cal in
                !usedIds.contains(cal.id) && cal.title.lowercased().contains(targetName)
            })
            guard let match else { continue }

            do {
                try await supabaseManager.addFamilyMemberCalendar(
                    memberId: member.id,
                    calendarName: match.title,
                    calendarColorHex: match.color.hex(),
                    isAutoLinked: true,
                    familyId: member.family_id
                )
                usedIds.insert(match.id)
                linked = true
                print("✅ Auto-linked calendar '\(match.title)' to member \(member.name)")
            } catch {
                print("⚠️ Failed to auto-link calendar '\(match.title)' for \(member.name): \(error.localizedDescription)")
            }
        }

        return linked
    }

    @MainActor
    private func populateMemberEmails(from members: [FamilyMemberDTO]) async {
        do {
            let emails = try await supabaseManager.getMemberEmailsForFamily()
            var map: [UUID: String] = [:]
            for row in emails {
                if let uuid = UUID(uuidString: row.family_member_id), let email = row.email {
                    map[uuid] = email
                }
            }
            memberLinkedEmails = map
            print("✅ Populated linked emails for \(map.count) members")
        } catch {
            print("⚠️ Failed to populate member emails: \(error.localizedDescription)")
            memberLinkedEmails = [:]
        }
    }

    @MainActor
    func createFamilyMember(name: String, colorHex: String) async throws -> FamilyMemberDTO {
        guard let userId = authManager.userId else {
            throw NSError(domain: "NoUserID", code: -1)
        }

        print("ℹ️ Creating family member: \(name)")
        try await supabaseManager.createFamilyMember(userId: userId, name: name, colorHex: colorHex)
        print("✅ Family member created in Supabase, refreshing data...")

        // Refresh family members list
        await fetchUserData()

        // Return the newly created member (it will be in the familyMembers array)
        guard let newMember = familyMembers.first(where: { $0.name == name }) else {
            print("❌ Family member '\(name)' not found after creation")
            print("ℹ️ Current family members: \(familyMembers.map { $0.name }.joined(separator: ", "))")
            throw NSError(domain: "MemberNotFound", code: -1, userInfo: ["message": "Family member was created but not found in the list. Please check your data."])
        }
        print("✅ Family member '\(newMember.name)' successfully created with ID: \(newMember.id)")
        return newMember
    }

    /// Create family member locally only (for guest mode - no Supabase sync)
    @MainActor
    func createFamilyMemberLocal(name: String, colorHex: String) throws -> FamilyMember {
        guard authManager.isGuest else {
            throw NSError(domain: "NotGuestMode", code: -1, userInfo: ["message": "Use createFamilyMember for authenticated users"])
        }

        guard let context = managedObjectContext else {
            throw NSError(domain: "NoContext", code: -1, userInfo: ["message": "CoreData context not available"])
        }

        let member = FamilyMember(context: context)
        member.id = UUID()
        member.name = name
        member.colorHex = colorHex
        member.avatarInitials = getInitials(from: name)
        member.sortOrder = Int16(familyMembers.count)

        do {
            try context.save()
            print("✅ Family member '\(name)' saved locally (guest mode)")
            return member
        } catch {
            print("❌ Error saving family member locally: \(error)")
            throw error
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

    @MainActor
    func updateFamilyMember(id: String, name: String, colorHex: String) async throws {
        try await supabaseManager.updateFamilyMember(id: id, name: name, colorHex: colorHex)

        // Refresh family members list
        await fetchUserData()
    }

    /// Update family member locally only (for guest mode - no Supabase sync)
    @MainActor
    func updateFamilyMemberLocal(id: UUID, name: String, colorHex: String) throws {
        guard authManager.isGuest else {
            throw NSError(domain: "NotGuestMode", code: -1, userInfo: ["message": "Use updateFamilyMember for authenticated users"])
        }

        guard let context = managedObjectContext else {
            throw NSError(domain: "NoContext", code: -1, userInfo: ["message": "CoreData context not available"])
        }

        let fetchRequest = FamilyMember.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let member = try context.fetch(fetchRequest).first else {
            throw NSError(domain: "MemberNotFound", code: -1, userInfo: ["message": "Family member not found"])
        }

        member.name = name
        member.colorHex = colorHex
        member.avatarInitials = getInitials(from: name)

        do {
            try context.save()
            print("✅ Family member '\(name)' updated locally (guest mode)")
        } catch {
            print("❌ Error updating family member locally: \(error)")
            throw error
        }
    }

    @MainActor
    func deleteFamilyMember(id: String) async throws {
        try await supabaseManager.deleteFamilyMember(id: id)

        // Refresh family members list
        await fetchUserData()
    }

    /// Delete family member locally only (for guest mode - no Supabase sync)
    @MainActor
    func deleteFamilyMemberLocal(id: UUID) throws {
        guard authManager.isGuest else {
            throw NSError(domain: "NotGuestMode", code: -1, userInfo: ["message": "Use deleteFamilyMember for authenticated users"])
        }

        guard let context = managedObjectContext else {
            throw NSError(domain: "NoContext", code: -1, userInfo: ["message": "CoreData context not available"])
        }

        let fetchRequest = FamilyMember.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let member = try context.fetch(fetchRequest).first else {
            throw NSError(domain: "MemberNotFound", code: -1, userInfo: ["message": "Family member not found"])
        }

        context.delete(member)

        do {
            try context.save()
            print("✅ Family member '\(member.name ?? "Unknown")' deleted locally (guest mode)")
        } catch {
            print("❌ Error deleting family member locally: \(error)")
            throw error
        }
    }

    @MainActor
    func addSharedCalendar(calendarName: String, calendarColorHex: String) async throws -> SharedCalendarDTO {
        if !appSettingsManager.isProUser && sharedCalendars.count >= appSettingsManager.maxSharedCalendarsAllowed {
            print("❌ Shared calendar limit reached for Free plan. Enable Pro to add more.")
            throw NSError(domain: "ProLimit", code: -1, userInfo: [NSLocalizedDescriptionKey: "Free plan allows 1 shared calendar. Enable Pro to add more."])
        }

        if authManager.isGuest {
            // For guests, create shared calendar locally
            return try addSharedCalendarLocal(calendarName: calendarName, calendarColorHex: calendarColorHex)
        }

        guard let userId = authManager.userId else {
            throw NSError(domain: "NoUserID", code: -1)
        }

        let createdCalendar = try await supabaseManager.addSharedCalendar(userId: userId, calendarName: calendarName, calendarColorHex: calendarColorHex)
        print("✅ Shared calendar created in Supabase (ID: \(createdCalendar.id))")

        // Refresh shared calendars list
        await fetchUserData()

        // Return the newly created shared calendar
        guard let newCalendar = sharedCalendars.first(where: { $0.calendar_name == calendarName }) else {
            throw NSError(domain: "CalendarNotFound", code: -1)
        }
        return newCalendar
    }

    /// Add shared calendar locally only (for guest mode - no Supabase sync)
    @MainActor
    private func addSharedCalendarLocal(calendarName: String, calendarColorHex: String) throws -> SharedCalendarDTO {
        guard authManager.isGuest else {
            throw NSError(domain: "NotGuestMode", code: -1, userInfo: ["message": "Use addSharedCalendar for authenticated users"])
        }

        guard let context = managedObjectContext else {
            throw NSError(domain: "NoContext", code: -1, userInfo: ["message": "CoreData context not available"])
        }

        let sharedCalendar = SharedCalendar(context: context)
        sharedCalendar.id = UUID()
        sharedCalendar.calendarName = calendarName
        sharedCalendar.calendarColorHex = calendarColorHex

        // Link to all existing family members
        let fetchRequest = FamilyMember.fetchRequest()
        let allMembers = try context.fetch(fetchRequest)
        for member in allMembers {
            sharedCalendar.addToMembers(member)
        }

        do {
            try context.save()
            print("✅ Shared calendar '\(calendarName)' added locally (guest mode)")
            // Return as DTO
            return SharedCalendarDTO(
                id: sharedCalendar.id?.uuidString ?? "",
                user_id: "",
                calendar_name: calendarName,
                calendar_color_hex: calendarColorHex,
                created_at: nil
            )
        } catch {
            print("❌ Error adding shared calendar locally: \(error)")
            throw error
        }
    }

    @MainActor
    func deleteSharedCalendar(id: String) async throws {
        if authManager.isGuest {
            // For guests, delete shared calendar locally
            try deleteSharedCalendarLocal(id: id)
            return
        }

        let userId = authManager.userId ?? ""
        try await supabaseManager.deleteSharedCalendar(id: id, userId: userId)

        // Remove from in-memory list immediately
        sharedCalendars.removeAll { $0.id == id }

        // Remove from CoreData immediately
        if let context = managedObjectContext {
            let fetchRequest = SharedCalendar.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let calendar = try context.fetch(fetchRequest).first {
                context.delete(calendar)
                try context.save()
            }
        }

        print("✅ Removed shared calendar from Supabase and CoreData")
    }

    @MainActor
    func addPersonalCalendar(calendarName: String, calendarColorHex: String) async throws -> PersonalCalendarDTO {
        guard let userId = authManager.userId else {
            throw NSError(domain: "NoUserID", code: -1)
        }

        let createdCalendar = try await supabaseManager.addPersonalCalendar(userId: userId, calendarName: calendarName, calendarColorHex: calendarColorHex)
        print("✅ Personal calendar created in Supabase:")
        print("   - ID: \(createdCalendar.id)")
        print("   - Name: \(createdCalendar.calendar_name)")
        print("   - Next: \(createdCalendar.show_in_next ?? false)")
        print("   - Spotlight: \(createdCalendar.show_in_spotlight ?? false)")
        print("   - Upcoming: \(createdCalendar.show_in_upcoming ?? false)")
        print("   - Month: \(createdCalendar.show_in_month ?? false)")
        print("   - Day: \(createdCalendar.show_in_day ?? false)")

        // Add to in-memory list immediately
        personalCalendars.append(createdCalendar)
        print("🔍 DEBUG: Added to in-memory list. Total personal calendars: \(personalCalendars.count)")

        // Sync to CoreData
        if let context = managedObjectContext {
            print("🔍 DEBUG: Syncing to CoreData...")
            SupabaseDataSync.shared.syncPersonalCalendarsFromSupabase(
                supabaseCalendars: personalCalendars,
                to: context
            )
        } else {
            print("❌ DEBUG: No CoreData context available for sync!")
        }

        return createdCalendar
    }

    @MainActor
    func updatePersonalCalendarVisibility(
        id: String,
        showInNext: Bool,
        showInSpotlight: Bool,
        showInUpcoming: Bool,
        showInMonth: Bool,
        showInDay: Bool
    ) async throws {
        guard let userId = authManager.userId else {
            throw NSError(domain: "NoUserID", code: -1)
        }

        try await supabaseManager.updatePersonalCalendarVisibility(
            id: id,
            userId: userId,
            showInNext: showInNext,
            showInSpotlight: showInSpotlight,
            showInUpcoming: showInUpcoming,
            showInMonth: showInMonth,
            showInDay: showInDay
        )

        // Update in-memory list
        if let index = personalCalendars.firstIndex(where: { $0.id == id }) {
            var updated = personalCalendars[index]
            updated = PersonalCalendarDTO(
                id: updated.id,
                user_id: updated.user_id,
                calendar_name: updated.calendar_name,
                calendar_color_hex: updated.calendar_color_hex,
                show_in_next: showInNext,
                show_in_spotlight: showInSpotlight,
                show_in_upcoming: showInUpcoming,
                show_in_month: showInMonth,
                show_in_day: showInDay,
                created_at: updated.created_at
            )
            personalCalendars[index] = updated

            print("🔍 DEBUG: Updated in-memory calendar '\(updated.calendar_name)': Next=\(showInNext), Spotlight=\(showInSpotlight), Upcoming=\(showInUpcoming), Month=\(showInMonth), Day=\(showInDay)")
        }

        // Don't sync back to CoreData here - it's already been updated in PersonalCalendarsView
        // Syncing here causes a race condition where stale in-memory data overwrites the fresh CoreData changes
        print("ℹ️ Skipping CoreData sync after visibility update (already updated in UI)")
    }

    @MainActor
    func deletePersonalCalendar(id: String) async throws {
        if authManager.isGuest {
            try deletePersonalCalendarLocal(id: id)
            return
        }

        let userId = authManager.userId ?? ""
        try await supabaseManager.deletePersonalCalendar(id: id, userId: userId)

        // Remove from in-memory list immediately
        personalCalendars.removeAll { $0.id == id }

        // Remove from CoreData immediately
        if let context = managedObjectContext {
            let fetchRequest = PersonalCalendar.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            if let calendar = try context.fetch(fetchRequest).first {
                context.delete(calendar)
                try context.save()
            }
        }

        print("✅ Removed personal calendar from Supabase and CoreData")
    }

    /// Delete shared calendar locally only (for guest mode - no Supabase sync)
    @MainActor
    private func deleteSharedCalendarLocal(id: String) throws {
        guard authManager.isGuest else {
            throw NSError(domain: "NotGuestMode", code: -1, userInfo: ["message": "Use deleteSharedCalendar for authenticated users"])
        }

        guard let context = managedObjectContext else {
            throw NSError(domain: "NoContext", code: -1, userInfo: ["message": "CoreData context not available"])
        }

        let fetchRequest = SharedCalendar.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let sharedCalendar = try context.fetch(fetchRequest).first else {
            throw NSError(domain: "CalendarNotFound", code: -1, userInfo: ["message": "Shared calendar not found"])
        }

        // Remove from all members
        if let members = sharedCalendar.members?.allObjects as? [FamilyMember] {
            for member in members {
                sharedCalendar.removeFromMembers(member)
            }
        }

        context.delete(sharedCalendar)

        do {
            try context.save()
            print("✅ Shared calendar '\(sharedCalendar.calendarName ?? "Unknown")' deleted locally (guest mode)")
        } catch {
            print("❌ Error deleting shared calendar locally: \(error)")
            throw error
        }
    }

    // MARK: - Drivers

    @MainActor
    func createDriver(name: String, phone: String?, email: String?, notes: String?, travelTimeMinutes: Int = 0, familyMemberId: UUID? = nil) async {
        guard appSettingsManager.isProUser else {
            print("❌ Drivers are Pro-only. Enable Pro to add drivers.")
            return
        }
        guard let userId = authManager.userId else {
            print("❌ Cannot create driver: userId missing")
            return
        }

        do {
            try await supabaseManager.createDriver(
                userId: userId,
                name: name,
                phone: phone,
                email: email,
                notes: notes,
                travelTimeMinutes: travelTimeMinutes,
                familyMemberId: familyMemberId?.uuidString
            )
            print("✅ Driver created in Supabase")
            await fetchUserData()
        } catch {
            print("❌ Error creating driver in Supabase: \(error)")
        }
    }

    @MainActor
    func updateDriver(id: UUID, name: String, phone: String?, email: String?, notes: String?, travelTimeMinutes: Int = 0, familyMemberId: UUID? = nil) async {
        guard appSettingsManager.isProUser else {
            print("❌ Drivers are Pro-only. Enable Pro to edit drivers.")
            return
        }
        do {
            try await supabaseManager.updateDriver(
                id: id.uuidString,
                name: name,
                phone: phone,
                email: email,
                notes: notes,
                travelTimeMinutes: travelTimeMinutes,
                familyMemberId: familyMemberId?.uuidString
            )
            print("✅ Driver updated in Supabase")
            await fetchUserData()
        } catch {
            print("❌ Error updating driver in Supabase: \(error)")
        }
    }

    @MainActor
    func deleteDriver(id: UUID) async {
        guard appSettingsManager.isProUser else {
            print("❌ Drivers are Pro-only. Enable Pro to remove drivers.")
            return
        }
        do {
            try await supabaseManager.deleteDriver(id: id.uuidString)
            print("✅ Driver deleted in Supabase")
            await fetchUserData()
        } catch {
            print("❌ Error deleting driver in Supabase: \(error)")
        }
    }

    // MARK: - Saved Addresses

    @MainActor
    func createSavedAddress(name: String, address: String, latitude: Double, longitude: Double) async {
        guard appSettingsManager.isProUser else {
            print("❌ Saved places are Pro-only. Enable Pro to add saved places.")
            return
        }
        guard let userId = authManager.userId else {
            print("❌ Cannot create saved address: userId missing")
            return
        }

        do {
            try await supabaseManager.createSavedAddress(
                userId: userId,
                name: name,
                address: address,
                latitude: latitude,
                longitude: longitude
            )
            print("✅ Saved address created in Supabase")
            await fetchUserData()
        } catch {
            print("❌ Error creating saved address in Supabase: \(error)")
        }
    }

    @MainActor
    func deleteSavedAddress(id: UUID) async {
        guard appSettingsManager.isProUser else {
            print("❌ Saved places are Pro-only. Enable Pro to delete saved places.")
            return
        }
        do {
            try await supabaseManager.deleteSavedAddress(id: id.uuidString)
            print("✅ Saved address deleted in Supabase")
            await fetchUserData()
        } catch {
            print("❌ Error deleting saved address in Supabase: \(error)")
        }
    }

    // MARK: - Data Management

    /// Delete personal calendar locally only (for guest mode - no Supabase sync)
    @MainActor
    private func deletePersonalCalendarLocal(id: String) throws {
        guard authManager.isGuest else {
            throw NSError(domain: "NotGuestMode", code: -1, userInfo: ["message": "Use deletePersonalCalendar for authenticated users"])
        }

        guard let context = managedObjectContext else {
            throw NSError(domain: "NoContext", code: -1, userInfo: ["message": "CoreData context not available"])
        }

        let fetchRequest = PersonalCalendar.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let personalCalendar = try context.fetch(fetchRequest).first else {
            throw NSError(domain: "CalendarNotFound", code: -1, userInfo: ["message": "Personal calendar not found"])
        }

        context.delete(personalCalendar)

        do {
            try context.save()
            print("✅ Personal calendar '\(personalCalendar.calendarName ?? "Unknown")' deleted locally (guest mode)")
        } catch {
            print("❌ Error deleting personal calendar locally: \(error)")
            throw error
        }
    }

    @MainActor
    func clearData() {
        familyMembers = []
        sharedCalendars = []
        personalCalendars = []
        drivers = []
        savedAddresses = []
        errorMessage = nil
    }

    @MainActor
    func clearUserData() {
        clearData()
    }

    /// Clear all local CoreData (family members, shared calendars, drivers, addresses)
    @MainActor
    func clearAllLocalData() {
        guard let context = managedObjectContext else {
            print("⚠️ CoreData context not available, skipping local data clear")
            return
        }

        do {
            // Delete all family members
            let familyMemberFetch = FamilyMember.fetchRequest()
            let familyMembers = try context.fetch(familyMemberFetch)
            for member in familyMembers {
                context.delete(member)
            }

            // Delete all shared calendars
            let sharedCalendarFetch = SharedCalendar.fetchRequest()
            let sharedCalendars = try context.fetch(sharedCalendarFetch)
            for calendar in sharedCalendars {
                context.delete(calendar)
            }

            // Delete all personal calendars
            let personalCalendarFetch = PersonalCalendar.fetchRequest()
            let personalCalendars = try context.fetch(personalCalendarFetch)
            for calendar in personalCalendars {
                context.delete(calendar)
            }

            // Delete all drivers
            let driverFetch = Driver.fetchRequest()
            let drivers = try context.fetch(driverFetch)
            for driver in drivers {
                context.delete(driver)
            }

            // Delete all saved addresses
            let addressFetch = SavedAddress.fetchRequest()
            let addresses = try context.fetch(addressFetch)
            for address in addresses {
                context.delete(address)
            }

            try context.save()
            print("✅ All local CoreData cleared")

            // Also clear in-memory data
            clearData()
        } catch {
            print("❌ Error clearing local CoreData: \(error)")
        }
    }
}
