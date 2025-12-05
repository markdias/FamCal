# Auth Transition Fixes - Data Persistence Improvements

## Problem Identified

When transitioning between authentication states (logout → guest → login), users experienced:
1. **UI Flicker** - Seeing guest data briefly before auth user data loads
2. **"Unknown" Names** - Members showing as "Unknown" during data fetch
3. **Data Loss Risk** - Aggressive clearing could cause data loss if sync failed

## Root Causes

### 1. Aggressive Data Clearing ([SupabaseDataManager.swift:44-68](FamCal/SupabaseDataManager.swift#L44-L68))
**Before:**
```swift
authManager.$isAuthenticated.sink { isAuthenticated in
    if isAuthenticated {
        self?.clearData()              // ❌ Clears in-memory cache
        self?.clearAllLocalData()      // ❌ DELETES ALL CoreData
        await self?.fetchUserData()    // Then fetches new data
    }
}
```

**Problem:** CoreData was wiped **before** new data arrived, causing views to show empty/stale data.

**After:**
```swift
authManager.$isAuthenticated.sink { isAuthenticated in
    if isAuthenticated {
        // ✅ NO clearing - just fetch and merge
        await self?.fetchUserData()    // Fetches and overwrites via sync
    } else {
        self?.clearData()              // Only clear in-memory on logout
    }
}
```

**Fix:** "Fetch-then-swap" instead of "clear-then-fetch"

---

### 2. Non-Atomic CoreData Sync ([SupabaseDataManager.swift:387-431](FamCal/SupabaseDataManager.swift#L387-L431))
**Before:**
```swift
SupabaseDataSync.shared.syncFamilyMembersFromSupabase(...)
SyncMetadataManager.shared.recordSync(...)
SupabaseDataSync.shared.syncSharedCalendarsFromSupabase(...)
// ... multiple sequential saves
```

**Problem:** Each sync method saved individually, causing views to see partial/intermediate states.

**After:**
```swift
context.perform {
    // All sync operations happen in one batch
    SupabaseDataSync.shared.syncFamilyMembersFromSupabase(...)
    SupabaseDataSync.shared.syncSharedCalendarsFromSupabase(...)
    // ... all syncs together
    // Views only refresh after entire batch saves
}
```

**Fix:** Wrapped all sync operations in `context.perform {}` for atomic batch updates

---

### 3. Hard Deletes Without Validation ([SupabaseDataSync.swift:35-40](FamCal/SupabaseDataSync.swift#L35-L40))
**Before:**
```swift
for existingMember in existingMembers {
    if !supabaseIds.contains(memberId) {
        context.delete(existingMember)  // ❌ Hard delete immediately
    }
}
```

**Problem:** If Supabase returned empty response due to network error, all local data would be deleted.

**After:**
```swift
// SAFETY: Validate response before applying any deletes
if !IncrementalSyncService.shared.validateResponse(
    entities: supabaseMembers,
    entityType: "family members",
    existingCount: existingMembers.count
) {
    print("⚠️ Response validation failed - aborting sync")
    return  // ✅ Preserves local data
}

// Soft delete (mark as deleted, don't remove from DB)
for existingMember in existingMembers {
    if !supabaseIds.contains(memberId) {
        IncrementalSyncService.shared.softDelete(existingMember, reason: "removed from Supabase")
    }
}
```

**Fix:** Added response validation + soft delete pattern

---

### 4. Views Showing Soft-Deleted Data ([FamilyView.swift:31-67](FamCal/FamilyView.swift#L31-L67))
**Before:**
```swift
@FetchRequest(
    entity: FamilyMember.entity(),
    sortDescriptors: [...]
)
private var familyMembers: FetchedResults<FamilyMember>
```

**Problem:** Views would show soft-deleted entities (marked as deleted but still in DB).

**After:**
```swift
@FetchRequest(
    entity: FamilyMember.entity(),
    sortDescriptors: [...],
    predicate: NSPredicate(format: "isSoftDeleted == NO OR isSoftDeleted == nil")
)
private var familyMembers: FetchedResults<FamilyMember>
```

**Fix:** Added predicate to filter out soft-deleted entities

---

## Changes Summary

### Files Modified

1. **[SupabaseDataManager.swift](FamCal/SupabaseDataManager.swift)**
   - Lines 44-68: Removed aggressive clearing on auth change
   - Lines 387-431: Made CoreData sync atomic with `context.perform {}`

2. **[SupabaseDataSync.swift](FamCal/SupabaseDataSync.swift)**
   - Lines 26-47: Added response validation + soft delete for members
   - Predicate now filters out already-soft-deleted entities

3. **[FamilyView.swift](FamCal/FamilyView.swift)**
   - Lines 31-67: Added `isSoftDeleted` predicates to all @FetchRequest

4. **[IncrementalSyncService.swift](FamCal/IncrementalSyncService.swift)** (New)
   - Provides `validateResponse()` to prevent data loss
   - Provides `softDelete()` to mark entities as deleted
   - Provides `mergeEntity()` for timestamp-based conflict resolution

5. **[Persistence.swift](FamCal/Persistence.swift)**
   - Lines 74-76: Added automatic lightweight migration flags
   - Line 103: Updated version marker to v2 (triggers one-time DB reset)

6. **[FamCal.xcdatamodel/contents](FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel/contents)**
   - Added `updatedAt: Date?` to all synced entities
   - Added `isSoftDeleted: Bool` to all synced entities
   - Added `deletedAt: Date?` to all synced entities

---

## Expected Behavior After Fix

### Logout → Guest → Login Flow

**Before (Buggy):**
```
1. User logs out
2. CoreData wiped → Views show empty state
3. Guest mode → Creates guest data
4. User logs back in
5. CoreData wiped again → Views briefly show guest data
6. Auth data fetched → Sync happens piecemeal
7. Views show "Unknown" during intermediate saves
8. Finally shows correct auth data (flickering)
```

**After (Fixed):**
```
1. User logs out
2. In-memory cache cleared → CoreData preserved
3. Guest mode → Creates guest data in CoreData
4. User logs back in
5. NO clearing → Guest data stays visible during fetch
6. Auth data fetched in background
7. Atomic batch sync → All changes applied at once
8. Views refresh smoothly to show auth data (no flicker)
```

---

## How It Works Now

### 1. CoreData as Cache
- CoreData is treated as a **cache** that persists between sessions
- Data is **never deleted** unless explicitly validated
- Old data remains visible until new data replaces it

### 2. Soft Delete Pattern
- Entities are marked `isSoftDeleted = true` instead of hard deletion
- Views filter out soft-deleted entities with predicates
- Data can be recovered if sync was incorrect

### 3. Response Validation
- Before applying any deletes, responses are validated:
  - Empty response + existing data = **reject** (likely network error)
  - Dramatic reduction (>80%) = **reject** (likely API issue)
  - Normal response = **accept** and proceed

### 4. Atomic Sync
- All CoreData changes happen in one `context.perform {}` block
- Views only see the final state, not intermediate states
- Prevents flickering and partial data visibility

---

## Testing the Fix

### Test Case 1: Auth Transition
1. Log in with authenticated user
2. Verify members load correctly
3. Log out
4. Switch to guest mode
5. Log back in with auth user
6. **Expected:** No flicker, no "Unknown" names, smooth transition

### Test Case 2: Network Error During Sync
1. Have data in CoreData
2. Disconnect from network
3. Trigger a sync (pull-to-refresh)
4. **Expected:** Validation fails, local data preserved

### Test Case 3: Soft Delete
1. Have members in CoreData
2. Delete a member in Supabase directly
3. Trigger sync
4. **Expected:** Member marked as soft-deleted, not shown in views, but data still in DB

---

## Migration Notes

### First Launch After Update
The app will:
1. Detect version marker change (v1 → v2)
2. Delete existing CoreData database (one-time only)
3. Re-sync all data from Supabase
4. Create marker file to prevent future resets

This is intentional and safe because:
- Data lives in Supabase (source of truth)
- Only happens once per device
- Automatic lightweight migration adds new schema fields

### Supabase Schema
You must run the SQL migration to add `updated_at` columns:
```bash
supabase_migrations/add_updated_at_timestamps.sql
```

This adds timestamps to:
- `shared_calendars`
- `family_member_calendars`
- `families`

---

## Future Improvements (Phase 3)

These fixes address the immediate issues. Future enhancements:

1. **Incremental Sync** - Only fetch changed entities (not full refresh)
2. **Conflict Resolution** - Handle simultaneous changes from multiple devices
3. **Integrity Checker** - Manual UI to verify/repair data
4. **Sync Audit Log** - Track what changed and when
5. **Offline Queue** - Queue changes made offline for later sync

These are implemented in [IncrementalSyncService.swift](FamCal/IncrementalSyncService.swift) but not yet integrated into the sync flow.

---

## Debugging

### Console Messages to Look For

**Good (Fixed):**
```
ℹ️ Authentication state changed to authenticated
ℹ️ Using fetch-then-swap strategy to prevent UI flicker
ℹ️ Syncing data to CoreData (atomic batch)...
✅ CoreData sync batch complete - views will refresh automatically
✅ Authentication transition complete - new user data loaded
```

**Bad (If Still Broken):**
```
⚠️ Response validation failed - aborting sync to prevent data loss
⚠️ Supabase returned 0 members while local cache has X entries
❌ Error clearing local CoreData
```

### Checking Soft Deletes

In lldb debugger:
```lldb
po familyMembers.filter { $0.value(forKey: "isSoftDeleted") as? Bool == true }
```

Should return empty array (all soft-deleted entities filtered out).

---

## Rollback

If issues occur, revert these files:
```bash
git checkout HEAD -- FamCal/SupabaseDataManager.swift
git checkout HEAD -- FamCal/SupabaseDataSync.swift
git checkout HEAD -- FamCal/FamilyView.swift
git checkout HEAD -- FamCal/Persistence.swift
```

Then delete and reinstall the app.
