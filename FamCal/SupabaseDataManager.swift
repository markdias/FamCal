//
//  SupabaseDataManager.swift
//  FamCal
//
//  Manages Supabase data fetching and caching for the app
//

import Foundation
import Combine
import CoreData

class SupabaseDataManager: ObservableObject {
    static let shared = SupabaseDataManager()

    @MainActor @Published var familyMembers: [FamilyMemberDTO] = []
    @MainActor @Published var sharedCalendars: [SharedCalendarDTO] = []
    @MainActor @Published var drivers: [DriverDTO] = []
    @MainActor @Published var savedAddresses: [SavedAddressDTO] = []
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
            async let drivers = supabaseManager.getDrivers(userId: userId)
            async let savedAddresses = supabaseManager.getSavedAddresses(userId: userId)
            async let eventMetadata = supabaseManager.getCalendarEventMetadata(userId: userId)

            self.familyMembers = try await familyMembers
            print("✅ Fetched \(self.familyMembers.count) family members from Supabase")

            print("ℹ️ Fetching family member calendars from Supabase...")
            let calendarDTOs = try await fetchAllFamilyMemberCalendars()
            print("✅ Fetched \(calendarDTOs.count) family member calendars from Supabase")

            self.sharedCalendars = try await sharedCalendars
            print("✅ Fetched \(self.sharedCalendars.count) shared calendars from Supabase")

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
    func addSharedCalendar(calendarId: String, calendarName: String, calendarColorHex: String) async throws -> SharedCalendarDTO {
        if authManager.isGuest {
            // For guests, create shared calendar locally
            return try addSharedCalendarLocal(calendarId: calendarId, calendarName: calendarName, calendarColorHex: calendarColorHex)
        }

        guard let userId = authManager.userId else {
            throw NSError(domain: "NoUserID", code: -1)
        }

        let createdCalendar = try await supabaseManager.addSharedCalendar(userId: userId, calendarId: calendarId, calendarName: calendarName, calendarColorHex: calendarColorHex)
        print("✅ Shared calendar created in Supabase (ID: \(createdCalendar.id))")

        // Refresh shared calendars list
        await fetchUserData()

        // Return the newly created shared calendar
        guard let newCalendar = sharedCalendars.first(where: { $0.calendar_id == calendarId }) else {
            throw NSError(domain: "CalendarNotFound", code: -1)
        }
        return newCalendar
    }

    /// Add shared calendar locally only (for guest mode - no Supabase sync)
    @MainActor
    private func addSharedCalendarLocal(calendarId: String, calendarName: String, calendarColorHex: String) throws -> SharedCalendarDTO {
        guard authManager.isGuest else {
            throw NSError(domain: "NotGuestMode", code: -1, userInfo: ["message": "Use addSharedCalendar for authenticated users"])
        }

        guard let context = managedObjectContext else {
            throw NSError(domain: "NoContext", code: -1, userInfo: ["message": "CoreData context not available"])
        }

        let sharedCalendar = SharedCalendar(context: context)
        sharedCalendar.id = UUID()
        sharedCalendar.calendarID = calendarId
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
                calendar_id: calendarId,
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

        // Refresh shared calendars list
        await fetchUserData()
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
        do {
            try await supabaseManager.deleteSavedAddress(id: id.uuidString)
            print("✅ Saved address deleted in Supabase")
            await fetchUserData()
        } catch {
            print("❌ Error deleting saved address in Supabase: \(error)")
        }
    }

    // MARK: - Data Management

    @MainActor
    func clearData() {
        familyMembers = []
        sharedCalendars = []
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
