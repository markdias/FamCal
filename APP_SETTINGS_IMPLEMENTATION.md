# App Settings Persistence Implementation Guide

## Overview
This document outlines the implementation of persistent app settings that are stored in the Supabase database and automatically loaded for each user when they log in.

## Architecture

### 1. Data Layer (SupabaseManager.swift)

#### New Structures
- **AppSettingsDTO**: Data transfer object representing app settings from Supabase
- **AppSettingsCreateRequest**: Request body for creating new settings
- **AppSettingsUpdateRequest**: Request body for updating existing settings
- **AnyCodable**: Enum to handle dynamic JSON encoding/decoding of settings values

#### New Methods
- `getAppSettings(userId:)` - Retrieves user's settings from Supabase
- `createOrUpdateAppSettings(userId:settings:)` - Creates new settings record
- `updateAppSettings(id:settings:)` - Updates existing settings record

### 2. Business Logic Layer (AppSettingsManager.swift - NEW)

A centralized manager class that handles all app settings synchronization with Supabase.

**Published Properties:**

General Settings:
- `autoRefreshInterval: Int` (default: 5 minutes)
- `defaultMapsApp: String` (default: "Apple Maps")
- `defaultHomeScreenRawValue: String` (default: family)

Event Settings:
- `eventsPerPerson: Int` (default: 3)
- `spotlightEventsPerPerson: Int` (default: 5)
- `nextEventColumns: Int` (default: 2)
- `eventsPastDays: Int` (default: 90)
- `eventsFutureDays: Int` (default: 180)
- `defaultAlertOptionRawValue: String` (default: none)

Notification Settings:
- `notificationsEnabled: Bool` (default: false)
- `morningBriefEnabled: Bool` (default: false)
- `morningBriefTimeHour: Int` (default: 8)
- `morningBriefTimeMinute: Int` (default: 0)

Widget Settings:
- `widgetShowEventsCount: Int` (default: 3)
- `widgetShowOwnCalendarsOnly: Bool` (default: false)

**Key Methods:**

- `loadSettings()` - Fetches user's settings from Supabase and applies them
- `saveSettings()` - Persists current settings state to Supabase
- `applySettings(from:)` - Applies settings from Supabase response (private)
- `buildSettingsDictionary()` - Converts @Published properties to dictionary (private)

### 3. Data Synchronization (SupabaseDataManager.swift)

Integration with the main data manager:

```swift
// Added property
let appSettingsManager: AppSettingsManager

// During initialization
init() {
    self.appSettingsManager = AppSettingsManager.shared
}

// During data fetch
func fetchUserData() async {
    // ... existing code ...

    // Load app settings
    print("ℹ️ Loading app settings from Supabase...")
    await appSettingsManager.loadSettings()
}
```

## Data Flow

### Loading Settings (On App Startup)
1. User authenticates successfully
2. `SupabaseDataManager.fetchUserData()` is called
3. Calls `AppSettingsManager.loadSettings()`
4. Fetches settings for user from Supabase `app_settings` table
5. `applySettings()` method populates all @Published properties
6. UI automatically updates through SwiftUI binding

### Saving Settings (On User Action)
1. User changes a setting in UI (e.g., toggles notification)
2. `AppSettingsManager` property is updated (@Published)
3. View calls `await appSettingsManager.saveSettings()`
4. `buildSettingsDictionary()` converts all properties to dictionary
5. Either creates new settings record or updates existing one
6. Settings persisted to Supabase

## Supabase Table Schema

**Table: `app_settings`**

```sql
CREATE TABLE app_settings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    settings JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- Row Level Security
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own settings"
    ON app_settings FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own settings"
    ON app_settings FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own settings"
    ON app_settings FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own settings"
    ON app_settings FOR DELETE
    USING (auth.uid() = user_id);
```

## Implementation Checklist

### Completed ✅
- [x] Created AppSettingsDTO and request structures
- [x] Added AnyCodable enum for dynamic JSON handling
- [x] Created AppSettingsManager class with all published properties
- [x] Implemented loadSettings() and saveSettings() methods
- [x] Integrated with SupabaseDataManager
- [x] Settings auto-load on app startup
- [x] Fixed Swift 6 compilation errors

### Remaining (To be completed by user in UI views)
- [ ] Update AppSettingsView to use AppSettingsManager instead of @AppStorage
- [ ] Update NotificationSettingsView to sync with AppSettingsManager
- [ ] Update WidgetSettingsView to use AppSettingsManager
- [ ] Add save calls to each settings view (await appSettingsManager.saveSettings())
- [ ] Test end-to-end settings persistence

## Example Usage in Views

### In AppSettingsView
```swift
@EnvironmentObject private var appSettingsManager: AppSettingsManager

// Replace @AppStorage with direct binding
var autoRefreshBinding: Binding<Int> {
    Binding(
        get: { appSettingsManager.autoRefreshInterval },
        set: {
            appSettingsManager.autoRefreshInterval = $0
            Task { await appSettingsManager.saveSettings() }
        }
    )
}
```

### In NotificationSettingsView
```swift
@EnvironmentObject private var appSettingsManager: AppSettingsManager

// Replace NotificationManager properties with AppSettingsManager
Toggle("", isOn: Binding(
    get: { appSettingsManager.notificationsEnabled },
    set: {
        appSettingsManager.notificationsEnabled = $0
        Task { await appSettingsManager.saveSettings() }
    }
))
```

## Error Handling

The implementation includes proper error logging:

- `loadSettings()`: If settings don't exist (first time user), defaults are used
- `saveSettings()`: Logs errors but continues gracefully if save fails
- All operations are async/await with proper error messages

Example logs:
```
ℹ️ Loading app settings for user: [userId]
✅ App settings loaded from Supabase
❌ Error loading app settings (using defaults): [error]
✅ App settings updated in Supabase
```

## Future Enhancements

1. **Settings Versioning**: Add version number to detect breaking changes
2. **Selective Sync**: Only sync changed settings instead of all
3. **Offline Support**: Cache settings locally and sync when online
4. **Settings Validation**: Validate settings before saving
5. **Settings Export/Import**: Allow users to backup/restore settings

## Troubleshooting

### Settings Not Loading
1. Check if `app_settings` table exists in Supabase
2. Verify Row Level Security policies allow user access
3. Check console logs for error messages during `loadSettings()`
4. Ensure `SupabaseDataManager.setManagedObjectContext()` is called

### Settings Not Saving
1. Verify user is authenticated and has valid userId
2. Check Supabase database for `app_settings` table
3. Look for error logs from `saveSettings()`
4. Ensure `@MainActor` annotation allows UI updates

### Stale Settings
1. Call `await appSettingsManager.loadSettings()` to refresh
2. Check if multiple devices are syncing settings
3. Look for concurrent save conflicts in Supabase logs
