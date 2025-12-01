//
//  AppSettingsManager.swift
//  FamCal
//
//  Manages app settings synchronization with Supabase

import Foundation
import Combine
import WidgetKit

class AppSettingsManager: ObservableObject {
    static let shared = AppSettingsManager()

    @Published var autoRefreshInterval: Int = 5
    @Published var defaultMapsApp: String = "Apple Maps"
    @Published var defaultHomeScreenRawValue: String = DefaultHomeScreen.family.rawValue

    @Published var eventsPerPerson: Int = 3
    @Published var spotlightEventsPerPerson: Int = 5
    @Published var nextEventColumns: Int = 2
    @Published var eventsPastDays: Int = 90
    @Published var eventsFutureDays: Int = 180
    @Published var defaultAlertOptionRawValue: String = AlertOption.none.rawValue
    @Published var isProUser: Bool = UserDefaults.standard.bool(forKey: "com.famcal.pro.enabled")

    // Notification Settings
    @Published var notificationsEnabled: Bool = false
    @Published var morningBriefEnabled: Bool = false
    @Published var morningBriefTimeHour: Int = 8
    @Published var morningBriefTimeMinute: Int = 0
    @Published var morningBriefWeekdaysOnly: Bool = false
    @Published var morningBriefSelectedMembers: [String]? // Array of member UUIDs to include (nil = all members)
    @Published var morningBriefNotificationSound: String = "default" // "default", "none", custom sound
    @Published var notificationHistoryEnabled: Bool = true

    // Widget Settings
    @Published var widgetShowEventsCount: Int = 3
    @Published var widgetShowOwnCalendarsOnly: Bool = false
    @Published var widgetShowTime: Bool = true
    @Published var widgetShowLocation: Bool = true
    @Published var widgetShowAttendees: Bool = true

    // Account Link
    @Published var linkedFamilyMemberId: String?

    // Family Member Order
    @Published var familyMemberOrder: [String] = []

    // Family Setup
    @Published var familyName: String = ""
    @Published var hasCompletedFamilySetup: Bool = UserDefaults.standard.bool(forKey: "hasCompletedFamilySetup")
    @Published var familyId: String? = UserDefaults.standard.string(forKey: "com.famcal.familyId")

    let supabaseManager: SupabaseManager
    let authManager: SupabaseAuthManager
    private let settingKeys: Set<String> = [
        "autoRefreshInterval",
        "defaultMapsApp",
        "defaultHomeScreenRawValue",
        "eventsPerPerson",
        "spotlightEventsPerPerson",
        "nextEventColumns",
        "eventsPastDays",
        "eventsFutureDays",
        "defaultAlertOptionRawValue",
        "isProUser",
        "notificationsEnabled",
        "morningBriefEnabled",
        "morningBriefTimeHour",
        "morningBriefTimeMinute",
        "morningBriefWeekdaysOnly",
        "morningBriefSelectedMembers",
        "morningBriefNotificationSound",
        "notificationHistoryEnabled",
        "widgetShowEventsCount",
        "widgetShowOwnCalendarsOnly",
        "widgetShowTime",
        "widgetShowLocation",
        "widgetShowAttendees",
        "linkedFamilyMemberId",
        "familyMemberOrder",
        "familyName",
        "hasCompletedFamilySetup",
        "familyId"
    ]
    private var settingsId: String?
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedForUserId: String?
    private var isLoading = false
    private var refreshCancellable: AnyCancellable?

    init(supabaseManager: SupabaseManager? = nil, authManager: SupabaseAuthManager? = nil) {
        self.supabaseManager = supabaseManager ?? SupabaseManager.shared
        self.authManager = authManager ?? SupabaseAuthManager.shared

        // Automatically sync settings whenever authentication changes
        self.authManager.$isAuthenticated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated in
                guard let self else { return }

                if isAuthenticated, self.authManager.userId != nil {
                    Task { @MainActor in
                        await self.loadSettings()
                    }
                } else {
                    // Reset cache when logging out
                    self.settingsId = nil
                    self.hasLoadedForUserId = nil
                }
            }
            .store(in: &cancellables)

        // Auto-save on local changes (debounced)
        self.objectWillChange
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                Task { await self.saveSettings() }
            }
            .store(in: &cancellables)

        // Restart auto-refresh timer when interval changes
        $autoRefreshInterval
            .dropFirst()
            .sink { [weak self] _ in
                self?.startAutoRefreshTimer()
            }
            .store(in: &cancellables)
    }

    @MainActor
    func loadSettings() async {
        guard !isLoading else { return }

        // Skip cloud sync for guests - use local defaults only
        if authManager.isGuest {
            print("ℹ️ Guest mode detected - loading local settings only")
            loadSettingsLocally()
            enforcePlanConstraints()
            persistProFlag()
            syncWidgetPreferencesToAppGroup()
            return
        }

        guard let userId = authManager.userId else {
            print("⚠️ User ID not available for loading settings")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            print("ℹ️ Loading app settings for user: \(userId)")
            let settingsDTO = try await supabaseManager.getAppSettings(userId: userId)
            self.settingsId = settingsDTO.id
            applySettings(from: settingsDTO.settings)
            enforcePlanConstraints()
            persistProFlag()
            await syncMissingSettingsIfNeeded(remoteSettings: settingsDTO.settings)
            syncWidgetPreferencesToAppGroup()
            print("✅ App settings loaded from Supabase")
            self.hasLoadedForUserId = userId
            startAutoRefreshTimer()
        } catch {
            print("⚠️ Error loading app settings: \(error)")

            // Note: We don't logout on 401 errors anymore - user can continue using the app
            // and will be prompted to re-authenticate on next app launch if needed

            print("ℹ️ Creating initial settings record for user...")

            // Try to create initial settings if they don't exist
            do {
                let initialSettings = buildSettingsDictionary()
                try await supabaseManager.createOrUpdateAppSettings(userId: userId, settings: initialSettings)
                print("✅ Initial app settings created in Supabase")

                // Now fetch them to get the ID
                let settingsDTO = try await supabaseManager.getAppSettings(userId: userId)
                self.settingsId = settingsDTO.id
                applySettings(from: settingsDTO.settings)
                enforcePlanConstraints()
                persistProFlag()
                await syncMissingSettingsIfNeeded(remoteSettings: settingsDTO.settings)
                syncWidgetPreferencesToAppGroup()
                print("✅ App settings loaded from Supabase (post-create)")
                self.hasLoadedForUserId = userId
                startAutoRefreshTimer()
            } catch {
                print("⚠️ Error creating initial settings: \(error)")
                // Continue with default settings if creation also fails
                self.hasLoadedForUserId = nil
            }
            enforcePlanConstraints()
            persistProFlag()
            syncWidgetPreferencesToAppGroup()
        }
    }

    private func enforcePlanConstraints() {
        let spotlightLimit = currentSpotlightLimit
        if spotlightEventsPerPerson > spotlightLimit {
            spotlightEventsPerPerson = spotlightLimit
        }
    }

    private func loadSettingsLocally() {
        let defaults = AppGroupDefaults.shared

        // Load all settings from UserDefaults (via app group so widgets can access)
        if defaults.object(forKey: "autoRefreshInterval") != nil {
            autoRefreshInterval = defaults.integer(forKey: "autoRefreshInterval")
        }
        if let value = defaults.string(forKey: "defaultMapsApp") {
            defaultMapsApp = value
        }
        if let value = defaults.string(forKey: "defaultHomeScreenRawValue") {
            defaultHomeScreenRawValue = value
        }
        if defaults.object(forKey: "eventsPerPerson") != nil {
            eventsPerPerson = defaults.integer(forKey: "eventsPerPerson")
        }
        if defaults.object(forKey: "spotlightEventsPerPerson") != nil {
            spotlightEventsPerPerson = defaults.integer(forKey: "spotlightEventsPerPerson")
        }
        if defaults.object(forKey: "nextEventColumns") != nil {
            nextEventColumns = defaults.integer(forKey: "nextEventColumns")
        }
        if defaults.object(forKey: "eventsPastDays") != nil {
            eventsPastDays = defaults.integer(forKey: "eventsPastDays")
        }
        if defaults.object(forKey: "eventsFutureDays") != nil {
            eventsFutureDays = defaults.integer(forKey: "eventsFutureDays")
        }
        if let value = defaults.string(forKey: "defaultAlertOptionRawValue") {
            defaultAlertOptionRawValue = value
        }
        if defaults.object(forKey: "notificationsEnabled") != nil {
            notificationsEnabled = defaults.bool(forKey: "notificationsEnabled")
        }
        if defaults.object(forKey: "morningBriefEnabled") != nil {
            morningBriefEnabled = defaults.bool(forKey: "morningBriefEnabled")
        }
        if defaults.object(forKey: "morningBriefTimeHour") != nil {
            morningBriefTimeHour = defaults.integer(forKey: "morningBriefTimeHour")
        }
        if defaults.object(forKey: "morningBriefTimeMinute") != nil {
            morningBriefTimeMinute = defaults.integer(forKey: "morningBriefTimeMinute")
        }
        if defaults.object(forKey: "morningBriefWeekdaysOnly") != nil {
            morningBriefWeekdaysOnly = defaults.bool(forKey: "morningBriefWeekdaysOnly")
        }
        if let value = defaults.array(forKey: "morningBriefSelectedMembers") as? [String] {
            morningBriefSelectedMembers = value
        }
        if let value = defaults.string(forKey: "morningBriefNotificationSound") {
            morningBriefNotificationSound = value
        }
        if defaults.object(forKey: "notificationHistoryEnabled") != nil {
            notificationHistoryEnabled = defaults.bool(forKey: "notificationHistoryEnabled")
        }
        if defaults.object(forKey: "widgetShowEventsCount") != nil {
            widgetShowEventsCount = defaults.integer(forKey: "widgetShowEventsCount")
        }
        if defaults.object(forKey: "widgetShowOwnCalendarsOnly") != nil {
            widgetShowOwnCalendarsOnly = defaults.bool(forKey: "widgetShowOwnCalendarsOnly")
        }
        if defaults.object(forKey: "widgetShowTime") != nil {
            widgetShowTime = defaults.bool(forKey: "widgetShowTime")
        }
        if defaults.object(forKey: "widgetShowLocation") != nil {
            widgetShowLocation = defaults.bool(forKey: "widgetShowLocation")
        }
        if defaults.object(forKey: "widgetShowAttendees") != nil {
            widgetShowAttendees = defaults.bool(forKey: "widgetShowAttendees")
        }
        if let value = defaults.string(forKey: "linkedFamilyMemberId") {
            linkedFamilyMemberId = value
        }
        if let value = defaults.array(forKey: "familyMemberOrder") as? [String] {
            familyMemberOrder = value
        }
    }

    private func persistProFlag() {
        UserDefaults.standard.set(isProUser, forKey: "com.famcal.pro.enabled")
    }

    private func persistSettingsLocally() {
        let defaults = AppGroupDefaults.shared

        // Persist all settings to UserDefaults for local access (via app group so widgets can access)
        defaults.set(autoRefreshInterval, forKey: "autoRefreshInterval")
        defaults.set(defaultMapsApp, forKey: "defaultMapsApp")
        defaults.set(defaultHomeScreenRawValue, forKey: "defaultHomeScreenRawValue")
        defaults.set(eventsPerPerson, forKey: "eventsPerPerson")
        defaults.set(spotlightEventsPerPerson, forKey: "spotlightEventsPerPerson")
        defaults.set(nextEventColumns, forKey: "nextEventColumns")
        defaults.set(eventsPastDays, forKey: "eventsPastDays")
        defaults.set(eventsFutureDays, forKey: "eventsFutureDays")
        defaults.set(defaultAlertOptionRawValue, forKey: "defaultAlertOptionRawValue")
        defaults.set(notificationsEnabled, forKey: "notificationsEnabled")
        defaults.set(morningBriefEnabled, forKey: "morningBriefEnabled")
        defaults.set(morningBriefTimeHour, forKey: "morningBriefTimeHour")
        defaults.set(morningBriefTimeMinute, forKey: "morningBriefTimeMinute")
        defaults.set(morningBriefWeekdaysOnly, forKey: "morningBriefWeekdaysOnly")
        if let members = morningBriefSelectedMembers {
            defaults.set(members, forKey: "morningBriefSelectedMembers")
        } else {
            defaults.removeObject(forKey: "morningBriefSelectedMembers")
        }
        defaults.set(morningBriefNotificationSound, forKey: "morningBriefNotificationSound")
        defaults.set(notificationHistoryEnabled, forKey: "notificationHistoryEnabled")
        defaults.set(widgetShowEventsCount, forKey: "widgetShowEventsCount")
        defaults.set(widgetShowOwnCalendarsOnly, forKey: "widgetShowOwnCalendarsOnly")
        defaults.set(widgetShowTime, forKey: "widgetShowTime")
        defaults.set(widgetShowLocation, forKey: "widgetShowLocation")
        defaults.set(widgetShowAttendees, forKey: "widgetShowAttendees")

        if let linkedId = linkedFamilyMemberId {
            defaults.set(linkedId, forKey: "linkedFamilyMemberId")
        } else {
            defaults.removeObject(forKey: "linkedFamilyMemberId")
        }

        defaults.set(familyMemberOrder, forKey: "familyMemberOrder")
    }

    private func startAutoRefreshTimer() {
        refreshCancellable?.cancel()
        guard authManager.isAuthenticated, !authManager.isGuest else { return }
        let intervalMinutes = max(autoRefreshInterval, 1)
        refreshCancellable = Timer.publish(every: TimeInterval(intervalMinutes * 60), on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.loadSettings() }
            }
    }

    @MainActor
    func saveSettings() async {
        enforcePlanConstraints()
        persistProFlag()

        // Skip cloud sync for guests - settings stay local only
        if authManager.isGuest {
            print("ℹ️ Guest mode: settings saved locally only (not synced to cloud)")
            persistSettingsLocally()
            syncWidgetPreferencesToAppGroup()
            return
        }

        guard let userId = authManager.userId else {
            print("❌ User ID not available for saving settings")
            syncWidgetPreferencesToAppGroup()
            return
        }

        syncWidgetPreferencesToAppGroup()
        let settingsDict = buildSettingsDictionary()

        do {
            // Ensure we have an ID; if not, try to fetch existing settings first to avoid duplicate insert attempts
            if settingsId == nil {
                if let existing = try? await supabaseManager.getAppSettings(userId: userId) {
                    settingsId = existing.id
                }
            }

            if let id = settingsId {
                // Update existing settings
                try await supabaseManager.updateAppSettings(id: id, settings: settingsDict)
                print("✅ App settings updated in Supabase")
            } else {
                // Create new settings
                try await supabaseManager.createOrUpdateAppSettings(userId: userId, settings: settingsDict)
                print("✅ App settings saved to Supabase")
                // Load again to get the ID
                let settingsDTO = try await supabaseManager.getAppSettings(userId: userId)
                self.settingsId = settingsDTO.id
            }

            // Persist to local UserDefaults for offline access and reliability
            persistSettingsLocally()
        } catch {
            print("❌ Error saving app settings: \(error)")
            // Still persist to local UserDefaults as fallback even if cloud sync fails
            persistSettingsLocally()
        }
    }

    private func applySettings(from dict: [String: AnyCodable]) {
        // General Settings
        if case .int(let value) = dict["autoRefreshInterval"] {
            autoRefreshInterval = value
        }
        if case .string(let value) = dict["defaultMapsApp"] {
            defaultMapsApp = value
        }
        if case .string(let value) = dict["defaultHomeScreenRawValue"] {
            defaultHomeScreenRawValue = value
        }

        // Event Settings
        if case .int(let value) = dict["eventsPerPerson"] {
            eventsPerPerson = value
        }
        if case .int(let value) = dict["spotlightEventsPerPerson"] {
            spotlightEventsPerPerson = value
        }
        if case .int(let value) = dict["nextEventColumns"] {
            nextEventColumns = value
        }
        if case .int(let value) = dict["eventsPastDays"] {
            eventsPastDays = value
        }
        if case .int(let value) = dict["eventsFutureDays"] {
            eventsFutureDays = value
        }
        if case .string(let value) = dict["defaultAlertOptionRawValue"] {
            defaultAlertOptionRawValue = value
        }
        if case .bool(let value) = dict["isProUser"] {
            isProUser = value
        }

        // Notification Settings
        if case .bool(let value) = dict["notificationsEnabled"] {
            notificationsEnabled = value
        }
        if case .bool(let value) = dict["morningBriefEnabled"] {
            morningBriefEnabled = value
        }
        if case .int(let value) = dict["morningBriefTimeHour"] {
            morningBriefTimeHour = value
        }
        if case .int(let value) = dict["morningBriefTimeMinute"] {
            morningBriefTimeMinute = value
        }

        // Widget Settings
        if case .int(let value) = dict["widgetShowEventsCount"] {
            widgetShowEventsCount = value
        }
        if case .bool(let value) = dict["widgetShowOwnCalendarsOnly"] {
            widgetShowOwnCalendarsOnly = value
        }
        if case .bool(let value) = dict["widgetShowTime"] {
            widgetShowTime = value
        }
        if case .bool(let value) = dict["widgetShowLocation"] {
            widgetShowLocation = value
        }
        if case .bool(let value) = dict["widgetShowAttendees"] {
            widgetShowAttendees = value
        }

        // Account Link
        if case .string(let value) = dict["linkedFamilyMemberId"] {
            linkedFamilyMemberId = value
        }

        // Family Member Order
        if case .array(let value) = dict["familyMemberOrder"] {
            familyMemberOrder = value.compactMap { item in
                if case .string(let str) = item { return str }
                return nil
            }
        }

        // Family Setup (restore from Supabase)
        if case .string(let value) = dict["familyId"] {
            familyId = value
            UserDefaults.standard.set(value, forKey: "com.famcal.familyId")
        }
        if case .string(let value) = dict["familyName"] {
            familyName = value
        }
        if case .bool(let value) = dict["hasCompletedFamilySetup"] {
            hasCompletedFamilySetup = value
            UserDefaults.standard.set(value, forKey: "hasCompletedFamilySetup")
        }
    }

    @MainActor
    private func syncMissingSettingsIfNeeded(remoteSettings: [String: AnyCodable]) async {
        let remoteKeys = Set(remoteSettings.keys)
        guard remoteKeys.isSuperset(of: settingKeys) == false else { return }

        print("ℹ️ Supabase settings missing keys (\(settingKeys.subtracting(remoteKeys))). Syncing defaults...")

        // Push full dictionary so Supabase always holds the complete settings payload
        do {
            if let id = settingsId {
                try await supabaseManager.updateAppSettings(id: id, settings: buildSettingsDictionary())
                print("✅ Missing settings keys synced to Supabase")
            } else {
                // Fallback: create if somehow missing
                guard let userId = authManager.userId else { return }
                try await supabaseManager.createOrUpdateAppSettings(userId: userId, settings: buildSettingsDictionary())
                print("✅ Created settings in Supabase while syncing missing keys")
                let settingsDTO = try await supabaseManager.getAppSettings(userId: userId)
                self.settingsId = settingsDTO.id
            }
        } catch {
            print("⚠️ Failed to sync missing settings keys: \(error)")
        }
    }

    @MainActor
    func resetToDefaults() {
        print("ℹ️ Resetting app settings to defaults")
        autoRefreshInterval = 5
        defaultMapsApp = "Apple Maps"
        defaultHomeScreenRawValue = DefaultHomeScreen.family.rawValue

        eventsPerPerson = 3
        spotlightEventsPerPerson = 5
        nextEventColumns = 2
        eventsPastDays = 90
        eventsFutureDays = 180
        defaultAlertOptionRawValue = AlertOption.none.rawValue
        isProUser = false

        notificationsEnabled = false
        morningBriefEnabled = false
        morningBriefTimeHour = 8
        morningBriefTimeMinute = 0

        widgetShowEventsCount = 3
        widgetShowOwnCalendarsOnly = false
        widgetShowTime = true
        widgetShowLocation = true
        widgetShowAttendees = true

        linkedFamilyMemberId = nil
        familyMemberOrder = []

        settingsId = nil
        hasLoadedForUserId = nil
        enforcePlanConstraints()
        persistProFlag()
        syncWidgetPreferencesToAppGroup()

        print("✅ App settings reset to defaults")
    }

    private func buildSettingsDictionary() -> [String: AnyCodable] {
        return [
            // General
            "autoRefreshInterval": .int(autoRefreshInterval),
            "defaultMapsApp": .string(defaultMapsApp),
            "defaultHomeScreenRawValue": .string(defaultHomeScreenRawValue),

            // Event Settings
            "eventsPerPerson": .int(eventsPerPerson),
            "spotlightEventsPerPerson": .int(min(spotlightEventsPerPerson, currentSpotlightLimit)),
            "nextEventColumns": .int(nextEventColumns),
            "eventsPastDays": .int(eventsPastDays),
            "eventsFutureDays": .int(eventsFutureDays),
            "defaultAlertOptionRawValue": .string(defaultAlertOptionRawValue),
            "isProUser": .bool(isProUser),

            // Notification Settings
            "notificationsEnabled": .bool(notificationsEnabled),
            "morningBriefEnabled": .bool(morningBriefEnabled),
            "morningBriefTimeHour": .int(morningBriefTimeHour),
            "morningBriefTimeMinute": .int(morningBriefTimeMinute),

            // Widget Settings
            "widgetShowEventsCount": .int(widgetShowEventsCount),
            "widgetShowOwnCalendarsOnly": .bool(widgetShowOwnCalendarsOnly),
            "widgetShowTime": .bool(widgetShowTime),
            "widgetShowLocation": .bool(widgetShowLocation),
            "widgetShowAttendees": .bool(widgetShowAttendees),

            // Account Link
            "linkedFamilyMemberId": linkedFamilyMemberId != nil ? .string(linkedFamilyMemberId!) : .null,

            // Family Member Order
            "familyMemberOrder": .array(familyMemberOrder.map { .string($0) }),

            // Family Setup
            "familyId": familyId != nil ? .string(familyId!) : .null,
            "familyName": .string(familyName),
            "hasCompletedFamilySetup": .bool(hasCompletedFamilySetup)
        ]
    }

    private func syncWidgetPreferencesToAppGroup() {
        let defaults = AppGroupDefaults.shared
        let clampedEvents = isProUser ? min(max(widgetShowEventsCount, 1), 5) : 0
        defaults.set(clampedEvents, forKey: "widgetMaxEvents")
        defaults.set(false, forKey: "widgetShowOwnCalendarsOnly")
        defaults.set(widgetShowTime, forKey: "widgetShowTime")
        defaults.set(widgetShowLocation, forKey: "widgetShowLocation")
        defaults.set(widgetShowAttendees, forKey: "widgetShowAttendees")
        defaults.set(eventsPastDays, forKey: "eventsPastDays")
        defaults.set(eventsFutureDays, forKey: "eventsFutureDays")
        defaults.set(isProUser, forKey: "proEnabled")
        defaults.set(isProUser, forKey: "widgetsEnabled")
        defaults.synchronize()

        DispatchQueue.main.async {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    var currentSpotlightLimit: Int {
        isProUser ? 15 : 5
    }

    var maxFamilyMembersAllowed: Int {
        isProUser ? Int.max : 2
    }

    var maxSharedCalendarsAllowed: Int {
        isProUser ? Int.max : 1
    }
}
