//
//  AppSettingsManager.swift
//  FamCal
//
//  Manages app settings synchronization with Supabase

import Foundation
import Combine

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

    // Notification Settings
    @Published var notificationsEnabled: Bool = false
    @Published var morningBriefEnabled: Bool = false
    @Published var morningBriefTimeHour: Int = 8
    @Published var morningBriefTimeMinute: Int = 0

    // Widget Settings
    @Published var widgetShowEventsCount: Int = 3
    @Published var widgetShowOwnCalendarsOnly: Bool = false

    // Account Link
    @Published var linkedFamilyMemberId: String?

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
        "notificationsEnabled",
        "morningBriefEnabled",
        "morningBriefTimeHour",
        "morningBriefTimeMinute",
        "widgetShowEventsCount",
        "widgetShowOwnCalendarsOnly",
        "linkedFamilyMemberId"
    ]
    private var settingsId: String?
    private var cancellables = Set<AnyCancellable>()
    private var hasLoadedForUserId: String?
    private var isLoading = false

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
    }

    @MainActor
    func loadSettings() async {
        guard !isLoading else { return }

        // Skip cloud sync for guests - use local defaults only
        if authManager.isGuest {
            print("ℹ️ Guest mode detected - using local settings only")
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
            await syncMissingSettingsIfNeeded(remoteSettings: settingsDTO.settings)
            print("✅ App settings loaded from Supabase")
            self.hasLoadedForUserId = userId
        } catch {
            print("⚠️ Error loading app settings: \(error)")
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
                await syncMissingSettingsIfNeeded(remoteSettings: settingsDTO.settings)
                print("✅ App settings loaded from Supabase (post-create)")
                self.hasLoadedForUserId = userId
            } catch {
                print("⚠️ Error creating initial settings: \(error)")
                // Continue with default settings if creation also fails
                self.hasLoadedForUserId = nil
            }
        }
    }

    @MainActor
    func saveSettings() async {
        // Skip cloud sync for guests - settings stay local only
        if authManager.isGuest {
            print("ℹ️ Guest mode: settings saved locally only (not synced to cloud)")
            return
        }

        guard let userId = authManager.userId else {
            print("❌ User ID not available for saving settings")
            return
        }

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
        } catch {
            print("❌ Error saving app settings: \(error)")
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
        
        // Account Link
        if case .string(let value) = dict["linkedFamilyMemberId"] {
            linkedFamilyMemberId = value
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

        notificationsEnabled = false
        morningBriefEnabled = false
        morningBriefTimeHour = 8
        morningBriefTimeMinute = 0

        widgetShowEventsCount = 3
        widgetShowOwnCalendarsOnly = false
        
        linkedFamilyMemberId = nil

        settingsId = nil
        hasLoadedForUserId = nil

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
            "spotlightEventsPerPerson": .int(spotlightEventsPerPerson),
            "nextEventColumns": .int(nextEventColumns),
            "eventsPastDays": .int(eventsPastDays),
            "eventsFutureDays": .int(eventsFutureDays),
            "defaultAlertOptionRawValue": .string(defaultAlertOptionRawValue),

            // Notification Settings
            "notificationsEnabled": .bool(notificationsEnabled),
            "morningBriefEnabled": .bool(morningBriefEnabled),
            "morningBriefTimeHour": .int(morningBriefTimeHour),
            "morningBriefTimeMinute": .int(morningBriefTimeMinute),

            // Widget Settings
            "widgetShowEventsCount": .int(widgetShowEventsCount),
            "widgetShowOwnCalendarsOnly": .bool(widgetShowOwnCalendarsOnly),
            
            // Account Link
            "linkedFamilyMemberId": linkedFamilyMemberId != nil ? .string(linkedFamilyMemberId!) : .null
        ]
    }
}
