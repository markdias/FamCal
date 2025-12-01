# Live Family Member Presence Implementation Plan

## Overview
Add real-time presence tracking for family members using Supabase Realtime subscriptions. Small colored dot next to family member names indicates online (green) or offline (gray) status.

## Phase 1: Database Setup
### Create `user_presence` table migration
**File:** `supabase/migrations/2025-12-01_create_user_presence_table.sql`

Structure:
- `id` (UUID, PRIMARY KEY)
- `user_id` (UUID, FK to auth.users)
- `family_id` (UUID, FK to families) - for RLS scoping
- `family_member_id` (UUID, FK to family_members, nullable)
- `is_online` (BOOLEAN, default false)
- `last_heartbeat` (TIMESTAMP WITH TIME ZONE, auto-updated)
- `last_seen` (TIMESTAMP WITH TIME ZONE, nullable)
- `created_at` (TIMESTAMP WITH TIME ZONE, auto-set)
- `updated_at` (TIMESTAMP WITH TIME ZONE, auto-updated)

Indices:
- `(user_id, family_id)` for quick lookups
- `(family_id, is_online)` for filtering online members

RLS Policies:
- Users can view presence records for families they're part of
- Users can insert/update their own presence record
- System function for stale record cleanup

---

## Phase 2: Backend Managers

### PresenceManager.swift (NEW)
**Location:** `FamCal/FamCal/PresenceManager.swift`

Responsibilities:
- Track current user's presence state
- Update presence on app lifecycle changes (foreground/background)
- Periodic heartbeat updates (every 30 seconds when active)
- Mark user offline when app goes to background
- Mark user online when app comes to foreground
- Clean up on sign out

Properties:
- `@Published var isOnline: Bool` - current user's online status
- `familyId: String?` - current family context
- `familyMemberId: String?` - linked family member ID
- Timer for heartbeat mechanism

Methods:
- `setupPresence(userId:, familyId:, familyMemberId:)` - Initialize presence
- `updatePresenceOnline()` - Mark user as online
- `updatePresenceOffline()` - Mark user as offline
- `startHeartbeat()` - Begin periodic updates
- `stopHeartbeat()` - Stop periodic updates
- `cleanup()` - Clean up on logout

---

### Update SupabaseManager.swift
Add presence-related methods:

```swift
// Create/update user presence
func updateUserPresence(
    userId: String,
    familyId: String,
    familyMemberId: String?,
    isOnline: Bool,
    token: String?
) async throws -> UserPresenceDTO

// Fetch presence for all family members
func getFamilyPresence(
    familyId: String,
    token: String?
) async throws -> [UserPresenceDTO]

// Clear presence on logout
func clearUserPresence(
    userId: String,
    token: String?
) async throws
```

Define DTO:
```swift
struct UserPresenceDTO: Codable {
    let id: String
    let user_id: String
    let family_id: String
    let family_member_id: String?
    let is_online: Bool
    let last_heartbeat: String // ISO8601 timestamp
    let updated_at: String
}
```

---

## Phase 3: Realtime Subscriptions

### RealtimePresenceSubscription.swift (NEW)
**Location:** `FamCal/FamCal/RealtimePresenceSubscription.swift`

Responsibilities:
- Manage Supabase Realtime subscriptions for presence changes
- Handle INSERT, UPDATE events on user_presence table
- Notify PresenceManager of changes
- Handle connection errors gracefully

Key features:
- Subscribe to family-scoped presence updates
- Decode incoming presence data
- Call completion handler with updated presence list
- Auto-reconnect on connection loss
- Clean up subscriptions on deinit

---

## Phase 4: UI Integration

### Update FamilyView.swift
**Location:** `FamCal/FamCal/FamilyView.swift`

Changes:
- Add `@StateObject private var presenceManager = PresenceManager.shared`
- Add state variable: `@State private var familyPresenceMap: [String: Bool] = [:]`
- Subscribe to presence updates in `.onAppear`
- Update presence map when Realtime events arrive
- Modify family member display row to show presence indicator

New modifier/component:
```swift
// Add presence indicator dot next to member name
HStack(spacing: 8) {
    // Green or gray dot based on presence
    Circle()
        .fill(presenceMap[memberId] ?? false ? Color.green : Color.gray)
        .frame(width: 8, height: 8)

    Text(member.name)
}
```

---

## Phase 5: App Lifecycle Integration

### Update FamCalApp.swift
**Location:** `FamCal/FamCal/FamCalApp.swift`

Changes:
- Add `@StateObject private var presenceManager = PresenceManager.shared`
- In `FamilyView` initialization, set up presence tracking
- Observe `scenePhase` to call presence manager methods
- Handle authentication state changes

Key additions:
```swift
.onChange(of: scenePhase) { oldPhase, newPhase in
    if newPhase == .active {
        presenceManager.updatePresenceOnline()
    } else {
        presenceManager.updatePresenceOffline()
    }
}

.onChange(of: authManager.isAuthenticated) { _, newValue in
    if !newValue {
        presenceManager.cleanup()
    }
}
```

---

## Implementation Order

1. ✅ Create database migration (user_presence table)
2. ✅ Update SupabaseManager with presence methods
3. ✅ Create PresenceManager
4. ✅ Create RealtimePresenceSubscription
5. ✅ Update FamilyView with presence indicator UI
6. ✅ Update FamCalApp with lifecycle integration
7. ✅ Testing & refinement

---

## Settings & Timing

- **Heartbeat interval:** 30 seconds (when app is active)
- **Stale timeout:** 2 minutes (user marked offline if no heartbeat)
- **Indicator style:** Small (8pt) colored circle
  - Green: User online
  - Gray: User offline
- **Animation:** Smooth color transition

---

## Non-Breaking Changes Summary

- ✅ New table only (no existing table modifications)
- ✅ New Swift files (no deletions)
- ✅ Minimal updates to FamCalApp & FamilyView (only additions)
- ✅ Graceful degradation if Realtime unavailable
- ✅ Backward compatible - existing features unaffected
- ✅ Optional feature - can be disabled per user if needed

---

## Testing Checklist

- [ ] User comes online → green dot appears
- [ ] User goes to background → gray dot after 30 seconds
- [ ] User returns to foreground → green dot appears
- [ ] User logs out → presence cleaned up
- [ ] Multiple family members show correct status
- [ ] Realtime updates work cross-device
- [ ] No crashes or data corruption
- [ ] App performance unaffected
