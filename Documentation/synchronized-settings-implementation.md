# Synchronized Settings Across Devices - Implementation Plan

## Overview
Enable real-time settings synchronization across all user's devices using Supabase Realtime. When a user changes a setting on iPhone, it instantly updates on iPad and other connected devices.

**Problem Solved:** Currently settings sync only on app launch or manual refresh. Users changing settings on one device don't see those changes on another device until restart.

---

## Phase 1: Database Enhancement

### Create `settings_sync_metadata` table (NEW)
**File:** `supabase/migrations/2025-12-01_create_settings_sync_metadata.sql`

**Purpose:** Track settings version/timestamp for efficient sync detection

Structure:
- `id` (UUID, PRIMARY KEY)
- `user_id` (UUID, FK to auth.users)
- `family_id` (UUID, FK to families) - for RLS scoping
- `settings_version` (BIGINT, incrementing version number)
- `last_modified_at` (TIMESTAMP WITH TIME ZONE)
- `last_modified_by_device` (TEXT, device identifier)
- `created_at` (TIMESTAMP WITH TIME ZONE)
- `updated_at` (TIMESTAMP WITH TIME ZONE)

**RLS Policies:**
- Users can only view/update their own settings metadata
- Automatic update of timestamps on modification

### Extend `app_settings` table
No schema changes needed. Existing `app_settings` table structure is sufficient:
- `settings` (JSONB) - flexible key-value storage
- `updated_at` (TIMESTAMP) - already exists

---

## Phase 2: Backend Infrastructure

### Update SupabaseManager.swift
Add settings sync methods:

```swift
// Fetch latest settings version for change detection
func getSettingsSyncVersion(
    userId: String,
    token: String?
) async throws -> SettingsSyncMetadataDTO

// Update settings version after local change
func updateSettingsSyncVersion(
    userId: String,
    familyId: String,
    version: Int,
    deviceId: String,
    token: String?
) async throws -> SettingsSyncMetadataDTO
```

Define DTO:
```swift
struct SettingsSyncMetadataDTO: Codable {
    let id: String
    let user_id: String
    let family_id: String
    let settings_version: Int
    let last_modified_at: String // ISO8601
    let last_modified_by_device: String
    let updated_at: String
}
```

---

## Phase 3: Manager Enhancement

### Update AppSettingsManager.swift
Add Realtime subscription and sync detection:

**New Properties:**
```swift
@Published var settingsSyncVersion: Int = 0
@Published var lastSyncedAt: Date?
@Published var pendingRemoteChanges: Bool = false

private var realtimeSubscription: RealtimeSettingsSubscription?
private var deviceId: String // unique device identifier
```

**New Methods:**
```swift
// Initialize Realtime subscription for settings changes
func setupRealtimeSettingsSync(familyId: String, userId: String)

// Handle incoming settings changes from other devices
func applyRemoteSettingsChange(_ newSettings: [String: AnyCodable])

// Increment version on local change
func markSettingsModified()

// Cleanup on logout
func cleanupRealtimeSubscription()
```

**Auto-Sync Logic:**
1. On app launch: fetch latest settings + version
2. When user changes setting: increment version, save to Supabase
3. When Realtime event received: compare version, merge if newer
4. Conflict resolution: last-write-wins with timestamp

---

## Phase 4: Realtime Integration

### Create RealtimeSettingsSubscription.swift (NEW)
**Location:** `FamCal/FamCal/RealtimeSettingsSubscription.swift`

Responsibilities:
- Subscribe to `settings_sync_metadata` changes for current user
- Listen to `app_settings` JSONB updates
- Detect setting modifications from other devices
- Handle connection events
- Notify AppSettingsManager of remote changes

Key Features:
```swift
class RealtimeSettingsSubscription: ObservableObject {
    // Listen for:
    // 1. UPDATE on settings_sync_metadata (version increment = remote change)
    // 2. Fetch full app_settings when version newer than local

    var onRemoteSettingsChanged: (([String: AnyCodable]) -> Void)?
    var onSyncStatusChanged: ((SyncStatus) -> Void)?
}

enum SyncStatus {
    case synced
    case syncing
    case conflicted(localVersion: Int, remoteVersion: Int)
    case error(String)
}
```

---

## Phase 5: UI Integration

### Update NotificationSettingsView.swift
Add sync status indicator:

```swift
// Show sync status with cloud icon
HStack {
    Text("Notification Settings")
    Spacer()

    // Sync status indicator
    if appSettingsManager.pendingRemoteChanges {
        HStack(spacing: 4) {
            Image(systemName: "cloud.and.arrow.down")
                .foregroundColor(.blue)
            Text("Syncing...")
                .font(.caption)
                .foregroundColor(.gray)
        }
    } else if let lastSynced = appSettingsManager.lastSyncedAt {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Synced")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
}
```

### Update other settings views similarly
- WidgetSettingsView
- ThemeSettingsView
- AccountSettingsView
- SystemSettingsView

### Add SettingsSyncDebugView (optional)
For testing/debugging:
- Show current device ID
- Show settings version
- Show last sync timestamp
- Manual sync trigger button
- Sync history log

---

## Phase 6: App Lifecycle Integration

### Update FamCalApp.swift
Initialize Realtime settings sync:

```swift
@StateObject private var appSettingsManager = AppSettingsManager.shared
@EnvironmentObject private var authManager: SupabaseAuthManager

.onChange(of: authManager.isAuthenticated) { _, newValue in
    if newValue {
        // Setup Realtime when authenticated
        appSettingsManager.setupRealtimeSettingsSync(
            familyId: appSettingsManager.familyId ?? "",
            userId: authManager.userId ?? ""
        )
    } else {
        // Cleanup when logging out
        appSettingsManager.cleanupRealtimeSubscription()
    }
}

.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active {
        // Refresh settings on foreground
        Task {
            await appSettingsManager.refreshSettingsIfNeeded()
        }
    }
}
```

---

## Phase 7: Conflict Resolution Strategy

### Version-Based Conflict Handling
```
Scenario: Settings changed on Device A, also locally on Device B

Device A:
├─ User changes notification time → version 5, saves to Supabase
└─ SettingsSyncMetadata.last_modified_by_device = "device-a-id"

Device B:
├─ Realtime event: version 5 > local version 4
├─ Compare timestamps: remote newer
├─ Apply remote settings (notification time from A)
├─ Show toast: "Settings updated from Device A"
└─ Version bumped to 5
```

### User Experience:
- **Last-write-wins:** If both devices change same setting within seconds, latest timestamp wins
- **Non-blocking:** Sync happens in background, doesn't interrupt user
- **Toast notification:** "Settings updated from another device" (optional, dismissible)
- **Visual indicator:** Cloud icon shows sync status

---

## Implementation Order

1. ✅ Create `settings_sync_metadata` table
2. ✅ Update SupabaseManager with sync methods
3. ✅ Update AppSettingsManager with Realtime setup
4. ✅ Create RealtimeSettingsSubscription
5. ✅ Add sync status UI indicators
6. ✅ Update FamCalApp lifecycle integration
7. ✅ Test multi-device sync
8. ✅ Optional: Add SettingsSyncDebugView

---

## Sync Timing & Behavior

**Periodic Refresh:**
- App foreground: fetch latest settings version
- Every 5 minutes (configurable): background refresh if enabled
- On authentication: initial full settings load

**Debouncing:**
- User changes setting → 1 second debounce (existing)
- Then save to Supabase + increment version
- Realtime event fires → apply if version newer

**Conflict Resolution:**
- Timestamp-based (last write wins)
- Device ID logged for debugging
- User can force re-sync via settings menu

---

## Non-Breaking Changes

- ✅ New table only (`settings_sync_metadata`)
- ✅ No existing `app_settings` schema changes
- ✅ Backward compatible - works with existing settings
- ✅ Realtime optional - app works without it
- ✅ Graceful fallback - uses UserDefaults if Realtime unavailable
- ✅ No CoreData model changes

---

## Multi-Device Testing Checklist

- [ ] Change setting on Device A
- [ ] Within 2 seconds, Device B shows updated setting
- [ ] Sync status indicator shows cloud icon → checkmark
- [ ] Change same setting on both devices simultaneously
- [ ] Last-write-wins resolution works correctly
- [ ] App survives Realtime disconnection gracefully
- [ ] Manual refresh button works if Realtime disabled
- [ ] Settings persist across app kills/relaunches
- [ ] Guest mode: no cloud sync (local only)
- [ ] Widget reflects synced settings

---

## Performance Considerations

- **Realtime Payload:** Only metadata changes (small, <1KB)
- **Full Settings Fetch:** Only when version mismatch detected
- **Bandwidth:** Minimal - only JSONB changes transmitted
- **Battery:** Uses Realtime subscriptions (more efficient than polling)
- **Storage:** No additional local storage beyond current

---

## Security & Privacy

- RLS policies ensure user can only sync own settings
- Device ID used for audit trail (not transmitted off-device)
- Settings remain in app group + UserDefaults (same as now)
- Tokens required for all Supabase operations
- Conflict logs available only in debug view

