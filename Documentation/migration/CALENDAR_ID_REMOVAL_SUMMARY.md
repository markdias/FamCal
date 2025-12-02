# Calendar ID Removal Refactor - Summary

## Overview
Removed all `calendar_id` (device-specific iOS Calendar identifier) from FamCal and replaced with `calendar_name` (user-friendly, device-portable identifier).

## Completed Changes

### 1. SQL Migration (✅ Created)
**File:** `supabase_remove_calendar_id.sql`

Removes `calendar_id` column from:
- `family_member_calendars` table
- `shared_calendars` table
- `personal_calendars` table
- `calendar_event_metadata` table

> The migration no longer touches `family_events`; in this schema the table either does not exist or already lacks a `calendar_id` column.

Updates unique constraints:
- `family_member_calendars`: `(family_member_id, calendar_name)` instead of `(family_member_id, calendar_id)`
- `shared_calendars`: `(user_id, calendar_name)` instead of `(user_id, calendar_id)`
- `personal_calendars`: `(user_id, calendar_name)` instead of `(user_id, calendar_id)`
- `calendar_event_metadata`: `(user_id, event_identifier)` - no longer needs calendar_id in unique constraint

### 2. SupabaseManager.swift (✅ Updated)

#### DTOs Updated - Removed calendar_id field:
- `FamilyMemberCalendarDTO`
- `SharedCalendarDTO`
- `PersonalCalendarDTO`
- `CalendarEventMetadataDTO`

#### API Functions Updated - Removed calendarId parameter:
1. **`addFamilyMemberCalendar()`**
   - Old: `(memberId, calendarId, calendarName, ...)`
   - New: `(memberId, calendarName, calendarColorHex, ...)`

2. **`addSharedCalendar()`**
   - Old: `(userId, calendarId, calendarName, ...)`
   - New: `(userId, calendarName, calendarColorHex, ...)`
   - Matches calendar by `calendar_name` instead of `calendar_id`

3. **`updateSharedCalendar()`**
   - Old: `(id, calendarId, calendarName, ...)`
   - New: `(id, calendarName, calendarColorHex, ...)`

4. **`addPersonalCalendar()`**
   - Old: `(userId, calendarId, calendarName, ...)`
   - New: `(userId, calendarName, calendarColorHex, ...)`
   - Matches calendar by `calendar_name` instead of `calendar_id`

5. **`upsertCalendarEventMetadata()`**
   - Old: `(userId, calendarId, eventIdentifier, ...)`
   - New: `(userId, eventIdentifier, ...)`
   - Query filters now: `(user_id, event_identifier)` instead of `(user_id, calendar_id, event_identifier)`

6. **`updateFamilyMemberCalendarId()`** - ❌ DELETED (no longer needed)
   - This function was used to update device-specific calendar IDs on new devices
   - No longer necessary since we use calendar_name for matching

---

## Remaining Changes Required

### 3. SupabaseDataSync.swift (🔄 TODO)
**File:** `/Users/markdias/project/FamCal/FamCal/SupabaseDataSync.swift`

Need to remove calendar_id mapping in:
- `syncFamilyMembersFromSupabase()` - Remove: `memberCalendar.calendarID = calendarDTO.calendar_id`
- `syncSharedCalendarsFromSupabase()` - Remove: `calendar.calendarID = supabaseDTO.calendar_id`
- `syncPersonalCalendarsFromSupabase()` - Remove: `calendar.calendarID = supabaseDTO.calendar_id`
- `syncEventMetadataFromSupabase()` - Remove: `familyEvent.calendarId = meta.calendar_id`

### 4. SupabaseDataManager.swift (🔄 TODO)
**File:** `/Users/markdias/project/FamCal/FamCal/SupabaseDataManager.swift`

#### Remove calendar ID remapping logic:
- `remapMissingSharedCalendars()` - Lines 274-324
  - Removes logic that tried to match missing calendar_ids by name
  - No longer needed since calendar_name is primary

- `remapMissingPersonalCalendars()` - Lines 326-366
  - Similar removal

- `remapMissingCalendarsToDevice()` - Lines 394-452
  - Similar removal

- `matchCalendar()` - Lines 454-473
  - Helper function for remapping, can be deleted

#### Update function signatures:
- `autoLinkCalendarsIfEmpty()` - Already uses calendar_name, no changes needed
- `updateFamilyMemberCalendarId()` - Delete the entire function (moved from SupabaseManager)

#### Update API calls:
- `autoLinkCalendarsIfEmpty()` line 255:
  - Old: `addFamilyMemberCalendar(memberId, calendarId: match.id, calendarName: match.title, ...)`
  - New: `addFamilyMemberCalendar(memberId, calendarName: match.title, ...)`

- `addSharedCalendar()` calls: Remove `calendarId` parameter
- `addPersonalCalendar()` calls: Remove `calendarId` parameter

### 5. FamCalApp.swift (🔄 TODO)
**File:** `/Users/markdias/project/FamCal/FamCal/FamCalApp.swift`

#### Remove device migration logic:
- Lines 416-500 (approximate)
- The entire calendar remapping logic when user switches devices
- This was needed because calendar_ids were device-specific
- No longer needed with calendar_name as primary identifier

#### Remove API calls:
- `updateFamilyMemberCalendarId()` calls - delete these

### 6. CoreData Model (🔄 TODO)
**File:** `/Users/markdias/project/FamCal/FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel/contents`

#### Remove `calendarID` attribute from:
- `FamilyMemberCalendar` entity
- `SharedCalendar` entity
- `PersonalCalendar` entity
- `FamilyEvent` entity (if exists)

### 7. All Views & Controllers (🔄 TODO)

Search for and remove references to `calendarID`:

```bash
grep -r "\.calendarID\|calendarID" /Users/markdias/project/FamCal/FamCal --include="*.swift"
```

Common locations:
- Any view showing calendar details
- Calendar matching/selection views
- Calendar display logic

---

## Testing Checklist

- [ ] Run SQL migration on development Supabase
- [ ] App builds without errors
- [ ] Login flow works
- [ ] Family members load correctly
- [ ] Calendars display by name (not ID)
- [ ] Adding shared calendars works
- [ ] Adding personal calendars works
- [ ] Adding family member calendars works
- [ ] Calendar matching by name works on same device
- [ ] Create new user on different device - calendars should match by name
- [ ] Test with multiple calendars per family member
- [ ] Event creation with metadata works (without calendar_id)
- [ ] Driver assignment still works with metadata

---

## Before & After Comparison

### Before (with calendar_id)
```
User has "Work" calendar on Device A (ID: ABC123)
User has "Work" calendar on Device B (ID: XYZ789)

Problem: Stored both calendar_id values, showed duplicate "Work" in UI
Solution: Update calendar_id on each device with complex remapping logic
```

### After (without calendar_id)
```
User has "Work" calendar on Device A
User has "Work" calendar on Device B

Solution: One record with calendar_name="Work" - same across all devices
No remapping needed, app just matches by name at runtime
```

---

## Files Modified
1. ✅ `supabase_remove_calendar_id.sql` (NEW)
2. ✅ `FamCal/SupabaseManager.swift`
3. 🔄 `FamCal/SupabaseDataSync.swift`
4. 🔄 `FamCal/SupabaseDataManager.swift`
5. 🔄 `FamCal/FamCalApp.swift`
6. 🔄 `FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel/contents`
7. 🔄 Various view files (TBD)

---

## Key Benefits
✅ Simplified data model - no device-specific identifiers
✅ Calendars are now truly portable across devices
✅ Removed complex remapping logic in FamCalApp.swift
✅ Consistent calendar names across the entire family
✅ Reduced database complexity (smaller unique constraints)
✅ Easier to understand and maintain code
