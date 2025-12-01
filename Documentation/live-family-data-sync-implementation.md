# Live Family Data Sync - Implementation Plan

## Overview
Enable real-time synchronization of family data changes across all family members' devices using Supabase Realtime. When one family member adds/edits another member, updates drivers, or modifies addresses, all logged-in family members see changes instantly without manual refresh.

**Problem Solved:** Currently family data syncs only on app launch or manual refresh. Changes made by family members require other members to restart or manually trigger refresh to see updates.

**End Result:** Modern, collaborative experience where family data feels instantly synchronized across all devices.

---

## Phase 1: Analyze Current Data Structure

### Entities to Sync:
1. **family_members** - Core family roster
   - name, color_hex, is_driver, linked_user_id, memberCalendars relationship

2. **family_member_calendars** - Multi-calendar per member
   - calendar_name, calendar_color_hex, is_auto_linked

3. **drivers** - Transportation info
   - name, phone, email, notes, travel_time_minutes

4. **saved_addresses** - Location reference
   - name, address, latitude, longitude

5. **shared_calendars** - Family calendars (many-to-many with members)
   - calendar_name, calendar_color_hex, members relationship

### Current Sync Mechanism:
```
SupabaseDataManager.fetchUserData()
    ├─ getFamilyMembers() - REST call
    ├─ getSharedCalendars() - REST call
    ├─ getDrivers() - REST call
    ├─ getSavedAddresses() - REST call
    └─ Synced to CoreData for UI consumption

Triggers:
├─ App launch
├─ Manual refresh (pull-to-refresh)
├─ Authentication change
└─ Every N minutes (configurable)
```

---

## Phase 2: Realtime Subscription Architecture

### Create RealtimeFamilyDataSubscription.swift (NEW)
**Location:** `FamCal/FamCal/RealtimeFamilyDataSubscription.swift`

Manages subscriptions to all family data tables:

```swift
class RealtimeFamilyDataSubscription: ObservableObject {
    // Subscribe to changes
    func subscribeToFamilyData(
        familyId: String,
        userId: String
    ) async throws

    // Callbacks for different entity types
    var onFamilyMembersChanged: (([FamilyMemberDTO]) -> Void)?
    var onFamilyMemberCalendarsChanged: (([FamilyMemberCalendarDTO]) -> Void)?
    var onSharedCalendarsChanged: (([SharedCalendarDTO]) -> Void)?
    var onDriversChanged: (([DriverDTO]) -> Void)?
    var onSavedAddressesChanged: (([SavedAddressDTO]) -> Void)?

    // Sync status
    var syncStatus: RealtimeSyncStatus = .disconnected
    enum RealtimeSyncStatus {
        case connected
        case disconnected
        case error(String)
        case syncing
    }

    // Cleanup
    func unsubscribeFromFamilyData()
}
```

### Subscription Details:

**Tables to Monitor:**
1. `family_members` (all columns) - INSERT, UPDATE, DELETE
2. `family_member_calendars` - INSERT, UPDATE, DELETE
3. `drivers` - INSERT, UPDATE, DELETE
4. `saved_addresses` - INSERT, UPDATE, DELETE
5. `shared_calendars` - INSERT, UPDATE, DELETE

**Event Handling:**
```
Realtime Event Received (for family_members INSERT/UPDATE/DELETE)
    ↓
Decode new/updated record
    ↓
Update local SupabaseDataManager state
    ↓
Sync to CoreData
    ↓
Trigger UI refresh via @Published properties
    ↓
Show subtle animation/toast for significant changes
```

---

## Phase 3: Manager Enhancement

### Update SupabaseDataManager.swift

**New Properties:**
```swift
@Published var realtimeSyncStatus: RealtimeSyncStatus = .disconnected
@Published var lastFamilyDataSyncAt: Date?

private var familyDataSubscription: RealtimeFamilyDataSubscription?
private var familyId: String?
```

**New Methods:**
```swift
// Initialize Realtime subscriptions
func setupRealtimeFamilyDataSync(familyId: String, userId: String) async

// Handle incoming family member changes
func applyRemoteFamilyMemberChange(_ member: FamilyMemberDTO)

// Handle calendar changes
func applyRemoteCalendarChange(_ calendar: FamilyMemberCalendarDTO)

// Handle driver updates
func applyRemoteDriverChange(_ driver: DriverDTO)

// Handle address updates
func applyRemoteSavedAddressChange(_ address: SavedAddressDTO)

// Bulk apply changes from Realtime event
func applyRemoteFamilyDataChanges(changeType: ChangeType, data: Any) async

// Cleanup
func cleanupRealtimeFamilyDataSync()

enum ChangeType {
    case familyMemberAdded(FamilyMemberDTO)
    case familyMemberUpdated(FamilyMemberDTO)
    case familyMemberDeleted(String) // member ID
    case calendarAdded(FamilyMemberCalendarDTO)
    case calendarUpdated(FamilyMemberCalendarDTO)
    case calendarDeleted(String) // calendar ID
    case driverAdded(DriverDTO)
    case driverUpdated(DriverDTO)
    case driverDeleted(String) // driver ID
    case addressAdded(SavedAddressDTO)
    case addressUpdated(SavedAddressDTO)
    case addressDeleted(String) // address ID
}
```

**Integration with CoreData:**
```swift
// When Realtime event arrives, sync to CoreData
private func syncToLocalCoreData(_ change: ChangeType) {
    DispatchQueue.main.async {
        // Use managed object context to update local data
        // FamilyMember, Driver, SavedAddress entities

        try? self.managedObjectContext?.save()

        // Notify UI of changes
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}
```

---

## Phase 4: UI Update Strategy

### Toast Notifications for Family Changes
Add subtle in-app notifications when family data changes:

```swift
// In FamilyView
@State private var showDataChangeToast: Bool = false
@State private var dataChangeMessage: String = ""

.onChange(of: dataManager.realtimeSyncStatus) { _, newStatus in
    if case .syncing = newStatus {
        // Show that data is syncing
        dataChangeMessage = "Family data updated"
        showDataChangeToast = true
    }
}

// Toast overlay
.overlay(alignment: .top) {
    if showDataChangeToast {
        Text(dataChangeMessage)
            .font(.caption)
            .foregroundColor(.white)
            .padding(12)
            .background(Color.green)
            .cornerRadius(8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showDataChangeToast = false
                }
            }
    }
}
```

### Animated List Updates
Enable smooth animations when family members list changes:

```swift
// In FamilyView list rendering
ForEach(familyMembers, id: \.id) { member in
    // Member row with data
}
.animation(.easeInOut(duration: 0.3), value: familyMembers)
```

### Status Indicator
Show Realtime connection status:

```swift
// In settings or top of FamilyView
HStack(spacing: 4) {
    Circle()
        .fill(
            dataManager.realtimeSyncStatus == .connected
                ? Color.green
                : Color.gray
        )
        .frame(width: 8, height: 8)

    Text(
        dataManager.realtimeSyncStatus == .connected
            ? "Live sync enabled"
            : "Sync offline"
    )
    .font(.caption)
    .foregroundColor(.gray)
}
```

---

## Phase 5: Conflict Resolution

### Update vs Delete Conflicts:
```
Scenario: Family member deleted on Device A while Device B updating them

Device A: DELETE family_member where id = 123
Device B: UPDATE family_member set name = "John" where id = 123

Resolution: DELETE wins (last operation in Supabase)
Result: Device B receives DELETE event, removes member from UI
```

### Optimistic Updates (optional enhancement):
```swift
// When user creates/edits family member, update UI immediately
// Then sync with Supabase and receive confirmation via Realtime
// If conflict, rollback and show error
```

### Cascade Handling:
```
When family_member deleted:
├─ All family_member_calendars deleted (FK cascade)
├─ All shared_calendar_members references removed (many-to-many)
└─ Realtime sends multiple DELETE events (one per calendar)

App receives 3 DELETE events:
├─ family_member DELETE
├─ family_member_calendar DELETE (x multiple)
└─ Updates UI accordingly
```

---

## Phase 6: App Lifecycle Integration

### Update FamCalApp.swift

```swift
@EnvironmentObject private var dataManager: SupabaseDataManager
@EnvironmentObject private var authManager: SupabaseAuthManager

.onChange(of: authManager.isAuthenticated) { _, newValue in
    if newValue {
        // Setup Realtime when authenticated
        Task { @MainActor in
            await dataManager.setupRealtimeFamilyDataSync(
                familyId: dataManager.familyId ?? "",
                userId: authManager.userId ?? ""
            )
        }
    } else {
        // Cleanup when logging out
        dataManager.cleanupRealtimeFamilyDataSync()
    }
}

.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active {
        // Re-subscribe to Realtime on foreground
        Task { @MainActor in
            await dataManager.setupRealtimeFamilyDataSync(...)
        }
    } else if newPhase == .background {
        // May keep subscribed (uses minimal battery)
        // Or unsubscribe to save resources
    }
}
```

---

## Phase 7: Performance Optimization

### Smart Subscription Management:
```swift
// Only subscribe when:
// 1. User is authenticated
// 2. Family ID is known
// 3. App is in foreground (or background if allowed)

// Unsubscribe when:
// 1. User logs out
// 2. Family context changes
// 3. App killed
```

### Batch Processing:
```swift
// If multiple Realtime events arrive rapidly (burst):
// ├─ Collect events over 500ms window
// └─ Apply all at once (single UI refresh)
// Instead of refreshing for each event
```

### Caching Strategy:
```
Realtime Event Received
    ↓
Check if data already in memory (SupabaseDataManager)
    ├─ If different: update + UI refresh
    └─ If same: skip (silent duplicate)
```

---

## Phase 8: Error Handling & Fallback

### Connection Loss Handling:
```swift
// If Realtime connection drops:
// 1. Show "Sync offline" indicator
// 2. Continue functioning with last known data
// 3. Auto-reconnect when network available
// 4. On reconnect, full refresh to catch up on missed changes

.onChange(of: dataManager.realtimeSyncStatus) { _, newStatus in
    if case .error(let message) = newStatus {
        print("Realtime error: \(message)")
        // Auto-retry or fall back to polling
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            Task {
                await dataManager.setupRealtimeFamilyDataSync(...)
            }
        }
    }
}
```

### Fallback to Polling:
If Realtime unavailable, fall back to existing refresh mechanism:
```swift
// Keep existing auto-refresh timer running
// It will catch up on changes if Realtime fails
// User won't notice any difference
```

---

## Implementation Order

1. ✅ Create RealtimeFamilyDataSubscription.swift
2. ✅ Update SupabaseDataManager with sync methods
3. ✅ Add Realtime event handlers (family members, calendars, drivers, addresses)
4. ✅ Sync changes to CoreData
5. ✅ Add toast/animation UI feedback
6. ✅ Add sync status indicator
7. ✅ Update FamCalApp lifecycle integration
8. ✅ Test multi-device sync across all entity types
9. ✅ Implement fallback to polling if needed

---

## Non-Breaking Changes

- ✅ No database schema changes
- ✅ No CoreData model changes
- ✅ Realtime optional - app works without it
- ✅ Graceful fallback to existing refresh mechanism
- ✅ Backward compatible with guest mode (no sync)
- ✅ Existing REST API calls still work
- ✅ No changes to Supabase Manager (just additions)

---

## Multi-Device Testing Checklist

- [ ] Device A adds family member → appears on Device B instantly
- [ ] Device A edits member name → Device B shows update instantly
- [ ] Device A deletes member → Device B removes instantly
- [ ] Device A adds driver → Device B sees it instantly
- [ ] Device A saves new address → Device B fetches it instantly
- [ ] Connection drops → shows "Sync offline" indicator
- [ ] Reconnects → auto-syncs missed changes
- [ ] Both devices modify different members simultaneously → no conflicts
- [ ] Guest mode: no Realtime subscriptions active
- [ ] Realtime unavailable → falls back to polling

---

## Real-World Scenarios

### Scenario 1: Planning a Trip
```
Mom (Device A): Adds new family member "Coach"
Mom (Device A): Adds driver "Coach" with phone/email
Dad (Device B): Sees new member and driver instantly
Dad (Device B): Updates Driver's travel time
Mom (Device A): Sees updated travel time
```
**Result:** No refresh needed, collaborative real-time experience

### Scenario 2: Updating Contact Info
```
Sarah (Device A): Adds saved address "Soccer Field"
John (Device B): Working offline, doesn't see it yet
John (Device B): Comes back online
John (Device B): Realtime reconnects, catches up on missed change
John (Device B): Sees "Soccer Field" address
```
**Result:** Graceful offline handling, catch-up on reconnect

### Scenario 3: Delete Conflict
```
Mom (Device A): Deletes old member "Coach"
Dad (Device B): Still editing Coach's details
Dad (Device B): Press save
```
**Result:** Server rejects update (member deleted), shows error to Dad

---

## Performance Metrics

- **Latency:** <100ms from change on Device A to update on Device B
- **Bandwidth:** Minimal (small JSON records only)
- **CPU:** Negligible (event-driven, not polling)
- **Memory:** Small subscription overhead (~50KB)
- **Battery:** Efficient (WebSocket, not HTTP polling)

