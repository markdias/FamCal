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
import Network

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
    private var networkMonitor: NWPathMonitor?
    private var wasOffline = false
    private var hasHydratedFromCache = false

    // Persist last authenticated user ID to prevent false "different user" detection on app restart
    private var lastAuthenticatedUserId: String? {
        get {
            UserDefaults.standard.string(forKey: "lastAuthenticatedUserId")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "lastAuthenticatedUserId")
        }
    }

    init() {
        self.supabaseManager = SupabaseManager.shared
        self.authManager = SupabaseAuthManager.shared
        self.appSettingsManager = AppSettingsManager.shared

        // Setup network monitoring to detect offline→online transitions
        setupNetworkMonitoring()

        // Observe authentication changes to fetch data
        // IMPORTANT: Only clear data when there's an ACTUAL user change, not just session restoration
        authManager.$isAuthenticated
            .combineLatest(authManager.$userId)
            .sink { [weak self] (isAuthenticated, userId) in
                if isAuthenticated {
                    Task { @MainActor in
                        // Check if this is a different user than the last one
                        let isDifferentUser = self?.lastAuthenticatedUserId != nil && self?.lastAuthenticatedUserId != userId

                        if isDifferentUser {
                            print("ℹ️ Different user detected, clearing previous user's data...")
                            // Clear previous user's data before fetching new user's data
                            self?.clearData()

                            // Clear CoreData and sync metadata
                            if let context = self?.managedObjectContext {
                                self?.clearAllLocalData()

                                // Clear sync metadata so data is fetched fresh
                                SyncMetadataManager.shared.clearAllMetadata(context: context)
                            }
                        } else {
                            print("ℹ️ Same user session restored, keeping existing data...")
                        }

                        // Update the last authenticated user ID
                        self?.lastAuthenticatedUserId = userId

                        print("ℹ️ Authentication state changed to authenticated, attempting to fetch data...")
                        // Fetch authenticated user's data (with change detection, won't refetch if not needed)
                        await self?.fetchUserData()
                    }
                } else {
                    Task { @MainActor in
                        print("ℹ️ User logged out, clearing data...")
                        self?.clearData()
                        self?.lastAuthenticatedUserId = nil
                    }
                }
            }
            .store(in: &cancellables)
    }

    /// Setup network connectivity monitoring to detect offline→online transitions
    private func setupNetworkMonitoring() {
        let monitor = NWPathMonitor()
        self.networkMonitor = monitor

        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            Task { @MainActor in
                if isConnected && self?.wasOffline == true {
                    print("🔄 Network reconnected - syncing pending changes")
                    self?.wasOffline = false
                    // Phase 5: Sync pending offline changes and refresh all data when coming back online
                    if self?.managedObjectContext != nil {
                        await self?.syncPendingChangesAndRefresh()
                    }
                } else if !isConnected {
                    print("⚠️ Network disconnected - switching to offline mode")
                    self?.wasOffline = true
                }
            }
        }

        let queue = DispatchQueue(label: "com.famcal.network")
        monitor.start(queue: queue)
    }

    deinit {
        networkMonitor?.cancel()
    }

    @MainActor
    func setManagedObjectContext(_ context: NSManagedObjectContext) {
        print("ℹ️ Setting CoreData context, now fetching user data...")
        self.managedObjectContext = context

        // Immediately hydrate in-memory cache from CoreData so the UI never starts empty on app launch/resume
        hydrateFromCoreDataCacheIfNeeded(reason: "context set")

        // First, try to load cached data from CoreData to ensure immediate display
        do {
            let memberFetch = FamilyMember.fetchRequest()
            let cachedCount = try context.fetch(memberFetch).count
            if cachedCount > 0 {
                print("✅ Found \(cachedCount) cached family members in CoreData")
            }
        } catch {
            print("⚠️ Could not check CoreData cache: \(error)")
        }

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

    // MARK: - Data Fetching

    /// Fetch user data only if changes detected or sync interval exceeded
    /// This is the primary method to use for background syncing with change detection
    @MainActor
    func fetchUserDataIfNeeded(force: Bool = false) async {
        guard let context = managedObjectContext else {
            print("⚠️ CoreData context not available for change detection")
            return
        }

        // Always hydrate from CoreData first so cached data shows up even if the network call fails
        hydrateFromCoreDataCacheIfNeeded(reason: "smart fetch", force: force)

        guard authManager.userId != nil else {
            print("❌ Cannot fetch data: User ID is nil")
            return
        }

        let syncIntervalMinutes = appSettingsManager.autoRefreshInterval

        // Phase 4: Detect offline changes and mark as pending
        if !force {
            print("🔍 Phase 4: Detecting offline changes...")
            SyncMetadataManager.shared.detectAndMarkChanges(entityType: .familyMembers, context: context)
            SyncMetadataManager.shared.detectAndMarkChanges(entityType: .drivers, context: context)
            SyncMetadataManager.shared.detectAndMarkChanges(entityType: .savedAddresses, context: context)
            SyncMetadataManager.shared.detectAndMarkChanges(entityType: .personalCalendars, context: context)
        }

        // Check each entity type and only fetch what changed
        let shouldFetchMembers = force || SyncMetadataManager.shared.shouldFetchData(
            entityType: .familyMembers,
            syncIntervalMinutes: syncIntervalMinutes,
            context: context
        )
        let shouldFetchSharedCalendars = force || SyncMetadataManager.shared.shouldFetchData(
            entityType: .sharedCalendars,
            syncIntervalMinutes: syncIntervalMinutes,
            context: context
        )
        let shouldFetchPersonalCalendars = force || SyncMetadataManager.shared.shouldFetchData(
            entityType: .personalCalendars,
            syncIntervalMinutes: syncIntervalMinutes,
            context: context
        )
        let shouldFetchDrivers = force || SyncMetadataManager.shared.shouldFetchData(
            entityType: .drivers,
            syncIntervalMinutes: syncIntervalMinutes,
            context: context
        )
        let shouldFetchAddresses = force || SyncMetadataManager.shared.shouldFetchData(
            entityType: .savedAddresses,
            syncIntervalMinutes: syncIntervalMinutes,
            context: context
        )
        
        // Always fetch metadata if we are fetching anything else, or if it's stale
        let shouldFetchMetadata = shouldFetchMembers || shouldFetchSharedCalendars || SyncMetadataManager.shared.shouldFetchData(
            entityType: .calendarEventMetadata,
            syncIntervalMinutes: syncIntervalMinutes,
            context: context
        )

        // If nothing needs fetching, load from CoreData and return
        if !shouldFetchMembers && !shouldFetchSharedCalendars && !shouldFetchPersonalCalendars &&
           !shouldFetchDrivers && !shouldFetchAddresses && !shouldFetchMetadata {
            print("✅ All data is fresh - loading from CoreData cache")
            loadCachedDataFromCoreData(context)
            return
        }

        print("🔄 Change detection: fetching updated data from Supabase")

        // Execute granular fetches
        isLoading = true
        errorMessage = nil

        // IMPORTANT: Fetch family members FIRST before shared/personal calendars
        // because calendars need to be linked to members
        if shouldFetchMembers {
            await fetchFamilyMembers()
        }

        // Now fetch everything else in parallel
        await withTaskGroup(of: Void.self) { group in
            if shouldFetchSharedCalendars {
                group.addTask { await self.fetchSharedCalendars() }
            }
            if shouldFetchPersonalCalendars {
                group.addTask { await self.fetchPersonalCalendars() }
            }
            if shouldFetchDrivers {
                group.addTask { await self.fetchDrivers() }
            }
            if shouldFetchAddresses {
                group.addTask { await self.fetchSavedAddresses() }
            }
            if shouldFetchMetadata {
                group.addTask { await self.fetchEventMetadata() }
            }
        }
        
        // Refresh local family info if needed
        if !authManager.isGuest, let userId = authManager.userId {
             await refreshLocalFamilyInfo(userId: userId)
        }
        
        isLoading = false
    }

    /// Phase 5: Sync pending offline changes to Supabase, then refresh all data
    @MainActor
    private func syncPendingChangesAndRefresh() async {
        print("📤 Phase 5: Starting sync of pending offline changes...")

        guard let context = managedObjectContext else {
            print("⚠️ CoreData context not available")
            await fetchUserDataIfNeeded(force: true)
            return
        }

        guard authManager.userId != nil else {
            print("⚠️ User not authenticated - skipping pending change sync")
            await fetchUserDataIfNeeded(force: true)
            return
        }

        // Upload pending changes for each entity type
        do {
            try await uploadPendingFamilyMemberChanges(context: context)
            try await uploadPendingDriverChanges(context: context)
            try await uploadPendingSavedAddressChanges(context: context)
            print("✅ Pending changes uploaded successfully")
        } catch {
            print("⚠️ Error uploading pending changes: \(error) - proceeding with refresh anyway")
        }

        // Now refresh all data from Supabase
        await fetchUserDataIfNeeded(force: true)
    }

    /// Upload pending family member changes
    private func uploadPendingFamilyMemberChanges(context: NSManagedObjectContext) async throws {
        let fetchRequest: NSFetchRequest<FamilyMember> = FamilyMember.fetchRequest()
        let allMembers = try context.fetch(fetchRequest)

        for member in allMembers {
            guard let modifiedAt = member.modifiedAt else { continue }
            let metadata = SyncMetadataManager.shared.fetchMetadata(entityType: .familyMembers, context: context)
            guard let lastSync = metadata?.lastSyncTime else { continue }

            // If member was modified after last sync, upload the change
            if modifiedAt > lastSync {
                print("📤 Uploading pending change for family member: \(member.name ?? "Unknown")")
                if let memberId = member.id?.uuidString {
                    try await updateFamilyMember(
                        id: memberId,
                        name: member.name ?? "",
                        colorHex: member.colorHex ?? "#555555"
                    )
                }
            }
        }
    }

    /// Upload pending driver changes
    private func uploadPendingDriverChanges(context: NSManagedObjectContext) async throws {
        let fetchRequest: NSFetchRequest<Driver> = Driver.fetchRequest()
        let allDrivers = try context.fetch(fetchRequest)

        for driver in allDrivers {
            guard let modifiedAt = driver.modifiedAt else { continue }
            let metadata = SyncMetadataManager.shared.fetchMetadata(entityType: .drivers, context: context)
            guard let lastSync = metadata?.lastSyncTime else { continue }

            // If driver was modified after last sync, upload the change
            if modifiedAt > lastSync {
                print("📤 Uploading pending change for driver: \(driver.name ?? "Unknown")")
                if let driverId = driver.id {
                    await updateDriver(
                        id: driverId.uuidString,
                        name: driver.name ?? "",
                        phone: driver.phone,
                        email: driver.email,
                        notes: driver.notes
                    )
                }
            }
        }
    }

    /// Upload pending saved address changes
    private func uploadPendingSavedAddressChanges(context: NSManagedObjectContext) async throws {
        let fetchRequest: NSFetchRequest<SavedAddress> = SavedAddress.fetchRequest()
        let allAddresses = try context.fetch(fetchRequest)

        for address in allAddresses {
            guard let modifiedAt = address.modifiedAt else { continue }
            let metadata = SyncMetadataManager.shared.fetchMetadata(entityType: .savedAddresses, context: context)
            guard let lastSync = metadata?.lastSyncTime else { continue }

            // If address was modified after last sync, upload the change
            if modifiedAt > lastSync {
                print("📤 Uploading pending change for saved address: \(address.name ?? "Unknown")")
                await createSavedAddress(
                    name: address.name ?? "",
                    address: address.address ?? "",
                    latitude: address.latitude,
                    longitude: address.longitude
                )
            }
        }
    }

    @MainActor
    func fetchUserData() async {
        await fetchUserDataIfNeeded(force: true)
    }
    
    // MARK: - Granular Fetch Methods
    
    @MainActor
    func fetchFamilyMembers() async {
        guard let userId = authManager.userId else { return }
        print("ℹ️ Fetching family members from Supabase...")
        
        do {
            self.familyMembers = try await supabaseManager.getFamilyMembers(userId: userId)
            print("✅ Fetched \(self.familyMembers.count) family members from Supabase")
            
            await populateMemberEmails(from: self.familyMembers)
            
            // Auto-select linked family member for current user
            if let authUserId = authManager.userId,
               let linkedMember = self.familyMembers.first(where: { $0.linked_user_id == authUserId }) {
                appSettingsManager.linkedFamilyMemberId = linkedMember.id
                await appSettingsManager.saveSettings()
            }
            
            // Also fetch calendars for these members
            print("ℹ️ Fetching family member calendars from Supabase...")
            var calendarDTOs = try await fetchAllFamilyMemberCalendars()
            self.familyMemberCalendars = calendarDTOs
            
            // If no calendars are linked yet, attempt an auto-link pass
            if calendarDTOs.isEmpty, await autoLinkCalendarsIfEmpty(familyMembers: self.familyMembers) {
                print("ℹ️ Refetching calendars after auto-link...")
                calendarDTOs = try await fetchAllFamilyMemberCalendars()
                self.familyMemberCalendars = calendarDTOs
            }
            
            // Sync to CoreData
            if let context = managedObjectContext {
                SupabaseDataSync.shared.syncFamilyMembersFromSupabase(
                    supabaseMembers: self.familyMembers,
                    supabaseCalendars: calendarDTOs,
                    to: context
                )
                SyncMetadataManager.shared.recordSync(entityType: .familyMembers, context: context)
                SyncMetadataManager.shared.recordSync(entityType: .familyMemberCalendars, context: context)
            }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("ℹ️ Fetching family members cancelled")
            } else {
                print("❌ Error fetching family members: \(error)")
            }
        }
    }
    
    @MainActor
    func fetchSharedCalendars() async {
        guard let userId = authManager.userId else { return }
        print("ℹ️ Fetching shared calendars from Supabase...")
        
        do {
            self.sharedCalendars = try await supabaseManager.getSharedCalendars(userId: userId)
            print("✅ Fetched \(self.sharedCalendars.count) shared calendars from Supabase")
            
            if let context = managedObjectContext {
                SupabaseDataSync.shared.syncSharedCalendarsFromSupabase(
                    supabaseCalendars: self.sharedCalendars,
                    to: context
                )
                SyncMetadataManager.shared.recordSync(entityType: .sharedCalendars, context: context)
            }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("ℹ️ Fetching shared calendars cancelled")
            } else {
                print("❌ Error fetching shared calendars: \(error)")
            }
        }
    }
    
    @MainActor
    func fetchPersonalCalendars() async {
        guard let userId = authManager.userId else { return }
        print("ℹ️ Fetching personal calendars from Supabase...")
        
        do {
            self.personalCalendars = try await supabaseManager.getPersonalCalendars(userId: userId)
            print("✅ Fetched \(self.personalCalendars.count) personal calendars from Supabase")
            
            if let context = managedObjectContext {
                // Ensure linkedFamilyMemberId is loaded
                if appSettingsManager.linkedFamilyMemberId == nil {
                    if let authUserId = authManager.userId,
                       let linkedMember = self.familyMembers.first(where: { $0.linked_user_id == authUserId }) {
                        appSettingsManager.linkedFamilyMemberId = linkedMember.id
                        await appSettingsManager.saveSettings()
                    }
                }
                
                SupabaseDataSync.shared.syncPersonalCalendarsFromSupabase(
                    supabaseCalendars: self.personalCalendars,
                    to: context,
                    linkedFamilyMemberId: appSettingsManager.linkedFamilyMemberId
                )
                SyncMetadataManager.shared.recordSync(entityType: .personalCalendars, context: context)
            }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("ℹ️ Fetching personal calendars cancelled")
            } else {
                print("❌ Error fetching personal calendars: \(error)")
            }
        }
    }
    
    @MainActor
    func fetchDrivers() async {
        guard let userId = authManager.userId else { return }
        print("ℹ️ Fetching drivers from Supabase...")
        
        do {
            self.drivers = try await supabaseManager.getDrivers(userId: userId)
            print("✅ Fetched \(self.drivers.count) drivers from Supabase")
            
            if let context = managedObjectContext {
                SupabaseDataSync.shared.syncDriversFromSupabase(
                    supabaseDrivers: self.drivers,
                    to: context
                )
                SyncMetadataManager.shared.recordSync(entityType: .drivers, context: context)
            }
        } catch {
             if (error as NSError).code == NSURLErrorCancelled {
                 print("ℹ️ Fetching drivers cancelled")
             } else {
                 print("❌ Error fetching drivers: \(error)")
             }
        }
    }
    
    @MainActor
    func fetchSavedAddresses() async {
        guard let userId = authManager.userId else { return }
        print("ℹ️ Fetching saved addresses from Supabase...")
        
        do {
            self.savedAddresses = try await supabaseManager.getSavedAddresses(userId: userId)
            print("✅ Fetched \(self.savedAddresses.count) saved addresses from Supabase")
            
            if let context = managedObjectContext {
                SupabaseDataSync.shared.syncSavedAddressesFromSupabase(
                    supabaseAddresses: self.savedAddresses,
                    to: context
                )
                SyncMetadataManager.shared.recordSync(entityType: .savedAddresses, context: context)
            }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("ℹ️ Fetching saved addresses cancelled")
            } else {
                print("❌ Error fetching saved addresses: \(error)")
            }
        }
    }
    
    @MainActor
    func fetchEventMetadata() async {
        guard let userId = authManager.userId else { return }
        print("ℹ️ Fetching calendar event metadata from Supabase...")
        
        do {
            let metadata = try await supabaseManager.getCalendarEventMetadata(userId: userId)
            print("✅ Fetched \(metadata.count) event metadata records from Supabase")
            
            if let context = managedObjectContext {
                SupabaseDataSync.shared.syncEventMetadataFromSupabase(
                    supabaseMetadata: metadata,
                    self.drivers,
                    to: context
                )
                SyncMetadataManager.shared.recordSync(entityType: .calendarEventMetadata, context: context)
            }
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("ℹ️ Fetching event metadata cancelled")
            } else {
                print("❌ Error fetching event metadata: \(error)")
            }
        }
    }

    /// Load cached data from CoreData when network is unavailable
    /// This restores all relationships including FamilyMemberCalendars and SharedCalendars
    @MainActor
    private func loadCachedDataFromCoreData(_ context: NSManagedObjectContext) {
        do {
            // Fetch family members from CoreData
            let memberFetch = FamilyMember.fetchRequest()
            let cachedMembers = try context.fetch(memberFetch)
            print("📦 Loaded \(cachedMembers.count) family members from CoreData cache")

            // Verify relationships are intact in CoreData
            for member in cachedMembers {
                let calendarCount = member.memberCalendars?.count ?? 0
                print("  └─ \(member.name ?? "Unknown"): \(calendarCount) linked calendars")
            }

            // Convert CoreData FamilyMember to DTO for in-memory cache
            self.familyMembers = cachedMembers.map { member in
                // Ensure name is never nil or empty
                let safeName = (member.name?.isEmpty == false) ? member.name! : "Unknown"
                return FamilyMemberDTO(
                    id: member.id?.uuidString ?? "",
                    user_id: authManager.userId ?? "",
                    family_id: nil,
                    linked_user_id: member.linkedUserId,
                    name: safeName,
                    color_hex: member.colorHex ?? "#007AFF",
                    is_driver: member.isDriver,
                    created_at: nil
                )
            }

            // Fetch shared calendars from CoreData
            let sharedCalendarFetch = SharedCalendar.fetchRequest()
            let cachedSharedCalendars = try context.fetch(sharedCalendarFetch)
            print("📦 Loaded \(cachedSharedCalendars.count) shared calendars from CoreData cache")

            // Verify shared calendar member relationships are intact
            for calendar in cachedSharedCalendars {
                let memberCount = calendar.members?.count ?? 0
                print("  └─ \(calendar.calendarName ?? "Unknown"): linked to \(memberCount) members")
            }

            self.sharedCalendars = cachedSharedCalendars.map { calendar in
                SharedCalendarDTO(
                    id: calendar.id?.uuidString ?? "",
                    user_id: "",
                    calendar_name: calendar.calendarName ?? "Unknown",
                    calendar_color_hex: calendar.calendarColorHex ?? "#007AFF",
                    created_at: nil
                )
            }

            // Fetch family member calendars from CoreData
            var memberCalendars: [FamilyMemberCalendarDTO] = []
            for member in cachedMembers {
                if let calendars = member.memberCalendars as? Set<FamilyMemberCalendar> {
                    for calendar in calendars {
                        memberCalendars.append(FamilyMemberCalendarDTO(
                            id: calendar.id?.uuidString ?? "",
                            family_member_id: member.id?.uuidString ?? "",
                            calendar_name: calendar.calendarName ?? "Unknown",
                            calendar_color_hex: calendar.calendarColorHex ?? "#007AFF",
                            is_auto_linked: calendar.isAutoLinked,
                            created_at: nil
                        ))
                    }
                }
            }
            self.familyMemberCalendars = memberCalendars
            print("📦 Loaded \(memberCalendars.count) family member calendars from CoreData cache")

            // Fetch personal calendars from CoreData
            let personalCalendarFetch = PersonalCalendar.fetchRequest()
            let cachedPersonalCalendars = try context.fetch(personalCalendarFetch)
            self.personalCalendars = cachedPersonalCalendars.map { calendar in
                PersonalCalendarDTO(
                    id: calendar.id?.uuidString ?? "",
                    user_id: authManager.userId ?? "",
                    calendar_name: calendar.calendarName ?? "Unknown",
                    calendar_color_hex: calendar.calendarColorHex ?? "#007AFF",
                    show_in_next: calendar.showInNext,
                    show_in_spotlight: calendar.showInSpotlight,
                    show_in_upcoming: calendar.showInUpcoming,
                    show_in_month: calendar.showInMonth,
                    show_in_day: calendar.showInDay,
                    created_at: nil
                )
            }
            print("📦 Loaded \(cachedPersonalCalendars.count) personal calendars from CoreData cache")

            // Fetch drivers from CoreData
            let driverFetch = Driver.fetchRequest()
            let cachedDrivers = try context.fetch(driverFetch)
            self.drivers = cachedDrivers.map { driver in
                DriverDTO(
                    id: driver.id?.uuidString ?? "",
                    user_id: authManager.userId ?? "",
                    name: driver.name,
                    phone: driver.phone,
                    email: driver.email,
                    notes: driver.notes,
                    travel_time_minutes: driver.travelTimeMinutes > 0 ? Int(driver.travelTimeMinutes) : nil,
                    family_member_id: driver.familyMemberId?.uuidString,
                    travel_event_identifier: driver.travelEventIdentifier,
                    created_at: nil,
                    updated_at: nil
                )
            }
            print("📦 Loaded \(cachedDrivers.count) drivers from CoreData cache")

            // Fetch saved addresses from CoreData
            let addressFetch = SavedAddress.fetchRequest()
            let cachedAddresses = try context.fetch(addressFetch)
            self.savedAddresses = cachedAddresses.map { address in
                SavedAddressDTO(
                    id: address.id?.uuidString ?? "",
                    user_id: authManager.userId ?? "",
                    name: address.name,
                    address: address.address,
                    latitude: address.latitude,
                    longitude: address.longitude,
                    created_at: nil,
                    updated_at: nil
                )
            }
            print("📦 Loaded \(cachedAddresses.count) saved addresses from CoreData cache")

            // Verify all relationships are intact and accessible
            print("📊 Offline cache validation:")
            print("  ✅ Family members: \(cachedMembers.count)")
            print("  ✅ Family members with linked calendars: \(cachedMembers.filter { ($0.memberCalendars?.count ?? 0) > 0 }.count)")
            print("  ✅ Total family member calendars: \(memberCalendars.count)")
            print("  ✅ Shared calendars: \(cachedSharedCalendars.count)")
            print("  ✅ Personal calendars: \(cachedPersonalCalendars.count)")
            print("  ✅ Drivers: \(cachedDrivers.count)")
            print("  ✅ Saved addresses: \(cachedAddresses.count)")

            print("✅ Successfully restored data from CoreData cache for offline support")
            hasHydratedFromCache = true
        } catch {
            print("❌ Error loading cached data from CoreData: \(error)")
            errorMessage = "Unable to load data. No network and no local cache available."
        }
    }

    @MainActor
    private func refreshLocalFamilyInfo(userId: String) async {
        guard let context = managedObjectContext else {
            print("⚠️ CoreData context not available for FamilyInfo sync")
            return
        }

        var fetchedFamily: SupabaseManager.FamilyDTO?

        do {
            fetchedFamily = try await supabaseManager.getFamilyForOwner(userId: userId)
        } catch {
            if (error as NSError).code == NSURLErrorCancelled {
                print("ℹ️ Fetching owner family info cancelled")
            } else {
                print("⚠️ Unable to fetch owner family info: \(error)")
            }
        }

        if fetchedFamily == nil {
            fetchedFamily = try? await supabaseManager.getCurrentFamily()
        }

        guard let family = fetchedFamily else {
            print("ℹ️ No Supabase family row available for FamilyInfo sync")
            return
        }

        do {
            try FamilyInfoStore.upsert(name: family.family_name, familyId: family.id, in: context)
        } catch {
            print("⚠️ Failed to persist family info locally: \(error)")
        }
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
        let createdMember = try await supabaseManager.createFamilyMember(userId: userId, name: name, colorHex: colorHex)
        print("✅ Family member '\(name)' created in Supabase with ID: \(createdMember.id)")

        // Refresh family members list
        await fetchUserData()

        print("✅ Family member '\(createdMember.name)' successfully created")
        return createdMember
    }

    /// Create family member locally (optimistic update)
    @MainActor
    func createFamilyMemberLocal(name: String, colorHex: String) throws -> FamilyMember {
        guard let context = managedObjectContext else {
            throw NSError(domain: "NoContext", code: -1, userInfo: ["message": "CoreData context not available"])
        }

        let member = FamilyMember(context: context)
        member.id = UUID()
        member.name = name
        member.colorHex = colorHex
        member.avatarInitials = getInitials(from: name)
        member.sortOrder = Int16(familyMembers.count)
        member.modifiedAt = Date() // Mark as modified for sync

        do {
            try context.save()
            print("✅ Family member '\(name)' saved locally (optimistic)")
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
        await fetchFamilyMembers()
    }

    /// Update family member locally (optimistic update)
    @MainActor
    func updateFamilyMemberLocal(id: UUID, name: String, colorHex: String) throws {
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
        member.modifiedAt = Date() // Mark as modified for sync

        do {
            try context.save()
            print("✅ Family member '\(name)' updated locally (optimistic)")
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
            // For guests, create shared calendar locally only
            return try addSharedCalendarLocal(calendarName: calendarName, calendarColorHex: calendarColorHex)
        }

        guard let userId = authManager.userId else {
            throw NSError(domain: "NoUserID", code: -1)
        }

        let createdCalendar = try await supabaseManager.addSharedCalendar(userId: userId, calendarName: calendarName, calendarColorHex: calendarColorHex)
        print("✅ Shared calendar created in Supabase (ID: \(createdCalendar.id))")

        // Refresh shared calendars list from Supabase (authenticated users only)
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
        // For guests, create calendar locally only
        if authManager.isGuest {
            return try addPersonalCalendarLocal(calendarName: calendarName, calendarColorHex: calendarColorHex)
        }

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
                to: context,
                linkedFamilyMemberId: appSettingsManager.linkedFamilyMemberId
            )
        } else {
            print("❌ DEBUG: No CoreData context available for sync!")
        }

        // Refresh personal calendars list from Supabase (authenticated users only)
        await fetchUserData()

        return createdCalendar
    }

    /// Add personal calendar locally only (for guest mode - no Supabase sync)
    @MainActor
    private func addPersonalCalendarLocal(calendarName: String, calendarColorHex: String) throws -> PersonalCalendarDTO {
        guard authManager.isGuest else {
            throw NSError(domain: "NotGuestMode", code: -1, userInfo: ["message": "Use addPersonalCalendar for authenticated users"])
        }

        guard let context = managedObjectContext else {
            throw NSError(domain: "NoContext", code: -1, userInfo: ["message": "CoreData context not available"])
        }

        let personalCalendar = PersonalCalendar(context: context)
        personalCalendar.id = UUID()
        personalCalendar.calendarName = calendarName
        personalCalendar.calendarColorHex = calendarColorHex
        personalCalendar.showInNext = true
        personalCalendar.showInSpotlight = true
        personalCalendar.showInUpcoming = true
        personalCalendar.showInMonth = true
        personalCalendar.showInDay = true

        // Link to logged-in member if available
        if let linkedMemberId = appSettingsManager.linkedFamilyMemberId,
           let linkedMemberUUID = UUID(uuidString: linkedMemberId) {
            let fetchRequest = FamilyMember.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "id == %@", linkedMemberUUID as CVarArg)

            if let member = try context.fetch(fetchRequest).first {
                member.addToPersonalCalendars(personalCalendar)
                print("👤 Linked personal calendar to family member")
            }
        }

        do {
            try context.save()
            print("✅ Personal calendar '\(calendarName)' added locally (guest mode)")
            // Return as DTO
            return PersonalCalendarDTO(
                id: personalCalendar.id?.uuidString ?? "",
                user_id: "",
                calendar_name: calendarName,
                calendar_color_hex: calendarColorHex,
                show_in_next: true,
                show_in_spotlight: true,
                show_in_upcoming: true,
                show_in_month: true,
                show_in_day: true,
                created_at: nil
            )
        } catch {
            print("❌ Error adding personal calendar locally: \(error)")
            throw error
        }
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
            // Calendar already deleted from CoreData (likely by view before calling this method)
            print("ℹ️ Shared calendar with ID '\(id)' not found in CoreData (already deleted)")
            return
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
    func createDriver(name: String, phone: String?, email: String?, notes: String?, travelTimeMinutes: Int = 0, familyMemberId: UUID? = nil, id: String? = nil) async {
        guard appSettingsManager.isProUser else {
            print("❌ Drivers are Pro-only. Enable Pro to add drivers.")
            return
        }
        guard let userId = authManager.userId else {
            print("❌ Cannot create driver: userId missing")
            return
        }

        do {
            let familyId = try await supabaseManager.getFamilyIdForUser(userId: userId)
            try await supabaseManager.createDriver(
                userId: userId,
                name: name,
                phone: phone,
                email: email,
                notes: notes,
                travelTimeMinutes: travelTimeMinutes,
                familyMemberId: familyMemberId?.uuidString,
                familyId: familyId,
                id: id
            )
            print("✅ Driver created in Supabase")
            // No full fetch needed, local is already updated
        } catch {
            print("❌ Error creating driver in Supabase: \(error)")
        }
    }

    @MainActor
    func updateDriver(id: String, name: String, phone: String?, email: String?, notes: String?, travelTimeMinutes: Int = 0, familyMemberId: UUID? = nil) async {
        guard appSettingsManager.isProUser else {
            print("❌ Drivers are Pro-only. Enable Pro to edit drivers.")
            return
        }
        do {
            try await supabaseManager.updateDriver(
                id: id,
                name: name,
                phone: phone,
                email: email,
                notes: notes,
                travelTimeMinutes: travelTimeMinutes,
                familyMemberId: familyMemberId?.uuidString
            )
            print("✅ Driver updated in Supabase")
            // No full fetch needed
        } catch {
            print("❌ Error updating driver in Supabase: \(error)")
        }
    }

    @MainActor
    func deleteDriver(id: String) async {
        guard appSettingsManager.isProUser else {
            print("❌ Drivers are Pro-only. Enable Pro to remove drivers.")
            return
        }
        do {
            try await supabaseManager.deleteDriver(id: id)
            print("✅ Driver deleted in Supabase")
            // No full fetch needed
        } catch {
            print("❌ Error deleting driver in Supabase: \(error)")
        }
    }

    // MARK: - Saved Addresses

    @MainActor
    func createSavedAddress(name: String, address: String, latitude: Double, longitude: Double, id: String? = nil) async {
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
                longitude: longitude,
                id: id
            )
            print("✅ Saved address created in Supabase")
            // No full fetch needed
        } catch {
            print("❌ Error creating saved address in Supabase: \(error)")
        }
    }

    @MainActor
    func deleteSavedAddress(id: String) async {
        guard appSettingsManager.isProUser else {
            print("❌ Saved places are Pro-only. Enable Pro to delete saved places.")
            return
        }
        do {
            try await supabaseManager.deleteSavedAddress(id: id)
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
            // Calendar already deleted from CoreData (likely by view before calling this method)
            print("ℹ️ Personal calendar with ID '\(id)' not found in CoreData (already deleted)")
            return
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
        hasHydratedFromCache = false
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

    /// Ensure published data is backed by whatever is in CoreData so the UI never renders empty data after relaunch
    @MainActor
    private func hydrateFromCoreDataCacheIfNeeded(reason: String, force: Bool = false) {
        guard let context = managedObjectContext else {
            print("⚠️ CoreData context not available for hydration (\(reason))")
            return
        }

        // Only hydrate when we are missing any slice of data or when explicitly forced
        let isMissingData = familyMembers.isEmpty ||
            sharedCalendars.isEmpty ||
            personalCalendars.isEmpty ||
            drivers.isEmpty ||
            savedAddresses.isEmpty

        if !force && (!isMissingData && hasHydratedFromCache) {
            return
        }

        print("📦 Hydrating in-memory cache from CoreData (\(reason))")
        loadCachedDataFromCoreData(context)
    }

    // MARK: - Family Setup Detection

    /// Check if the current user is an invited family member
    /// Invited members have a linked_user_id that matches their current auth user ID
    @MainActor
    func isCurrentUserInvitedMember() async -> Bool {
        guard let currentUserId = authManager.userId else {
            return false
        }

        do {
            let memberList = try await supabaseManager.getFamilyMembers(userId: currentUserId)
            for member in memberList {
                if let linkedUserId = member.linked_user_id, linkedUserId == currentUserId {
                    let displayName = member.name.isEmpty ? "Unnamed" : member.name
                    print("✅ Current user is an invited member: \(displayName)")
                    return true
                }
            }
            print("ℹ️ Current user is not an invited member")
            return false
        } catch {
            print("⚠️ Error checking if user is invited member: \(error)")
            return false
        }
    }

    /// Sync family setup data to Supabase
    /// Called after completing the family setup wizard
    @MainActor
    func syncFamilySetup() async {
        guard !authManager.isGuest else {
            print("ℹ️ Guest mode - skipping family setup sync to Supabase")
            return
        }

        guard let userId = authManager.userId else {
            print("⚠️ No user ID available for family setup sync")
            return
        }

        do {
            print("📤 Syncing family setup to Supabase...")
            // Refresh members so local cache stays accurate
            _ = try await supabaseManager.getFamilyMembers(userId: userId)

            let trimmedFamilyName = appSettingsManager.familyName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if !trimmedFamilyName.isEmpty {
                var currentFamily: SupabaseManager.FamilyDTO?
                do {
                    currentFamily = try await supabaseManager.getFamilyForOwner(userId: userId)
                } catch {
                    print("⚠️ Unable to fetch owner family info during setup sync: \(error)")
                }
                if currentFamily == nil {
                    currentFamily = try? await supabaseManager.getCurrentFamily()
                }

                if let currentFamily = currentFamily {
                    let currentName = currentFamily.family_name?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
                    if currentName != trimmedFamilyName {
                        try await supabaseManager.updateFamilyName(familyId: currentFamily.id, name: trimmedFamilyName)
                        print("✅ Synced family name to Supabase: \(trimmedFamilyName)")
                    } else {
                        print("ℹ️ Family name already matches Supabase record")
                    }
                    if let context = managedObjectContext {
                        do {
                            try FamilyInfoStore.upsert(name: trimmedFamilyName, familyId: currentFamily.id, in: context)
                        } catch {
                            print("⚠️ Failed to persist family info locally: \(error)")
                        }
                    }
                } else {
                    print("⚠️ No Supabase family row found to apply the family name")
                }
            } else {
                print("ℹ️ Skipping Supabase family name sync because the name is empty")
            }

            print("✅ Family setup synced successfully")
        } catch {
            print("⚠️ Error syncing family setup: \(error)")
        }
    }
}
