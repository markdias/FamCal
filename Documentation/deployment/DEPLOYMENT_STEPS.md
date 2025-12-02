# Deployment Steps - Calendar ID Removal

## Phase 1: Database Migration ⚠️ CRITICAL - Do First

### Step 1: Run SQL Migration on Supabase

1. Go to: https://app.supabase.com/project/[YOUR_PROJECT_ID]/sql
2. Create a new query
3. Copy and paste the entire contents of: `supabase_remove_calendar_id.sql` (canonical dedup script)
4. **Review the SQL** to make sure it's dropping the right tables
5. Click "Run" to execute

**Note:** Run the canonical dedup script (`supabase_remove_calendar_id.sql`). `supabase_remove_calendar_id_v2.sql` is retained for reference, while `supabase_remove_calendar_id_v1.sql` still fails on duplicate calendars.

**Expected Results:**
```
✅ DROP INDEX idx_family_member_calendars_calendar_id
✅ ALTER TABLE family_member_calendars DROP COLUMN calendar_id
✅ ALTER TABLE family_member_calendars ADD CONSTRAINT unique_calendar_name_per_member
✅ (similar for shared_calendars, personal_calendars, calendar_event_metadata)
```

**Verification:**
1. Go to Supabase → Database → Tables
2. Inspect each table:
   - ❌ `family_member_calendars` should NOT have `calendar_id` column
   - ❌ `shared_calendars` should NOT have `calendar_id` column
   - ❌ `personal_calendars` should NOT have `calendar_id` column
   - ❌ `calendar_event_metadata` should NOT have `calendar_id` column

---

## Phase 2: Update CoreData Model (Required for app to build)

### Step 1: Open CoreData Model in Xcode

1. In Xcode, click on `FamCal.xcworkspace` in Project Navigator
2. Navigate to: `FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel`
3. Double-click to open in editor

### Step 2: Remove calendarID from FamilyMemberCalendar Entity

1. Select `FamilyMemberCalendar` entity (left panel)
2. In the Attributes section (right panel), find `calendarID`
3. Click to select it
4. Press **Delete** key
5. Confirm deletion

### Step 3: Remove calendarID from SharedCalendar Entity

1. Select `SharedCalendar` entity (left panel)
2. In the Attributes section, find `calendarID`
3. Click to select it
4. Press **Delete** key

### Step 4: Remove calendarID from PersonalCalendar Entity

1. Select `PersonalCalendar` entity (left panel)
2. In the Attributes section, find `calendarID`
3. Click to select it
4. Press **Delete** key

### Step 5: Check FamilyEvent Entity

1. Select `FamilyEvent` entity (left panel)
2. Check if it has `calendarId` or `calendarID` attribute
3. If yes, delete it (same process)

### Step 6: Save

- Command+S or File → Save

---

## Phase 3: Build and Test

### Step 1: Clean Build

```bash
# In Terminal at project root
xcodebuild clean
```

### Step 2: Build

```bash
# Build the app
xcodebuild build -workspace FamCal.xcworkspace -scheme FamCal
```

**Expected:** No build errors or warnings about `calendarID`

### Step 3: Run Simulator

```bash
# Run on simulator
xcodebuild -workspace FamCal.xcworkspace -scheme FamCal -derivedDataPath build -destination 'generic/platform=iOS Simulator'
```

Or simply: Open `FamCal.xcworkspace` in Xcode and click the Run button (▶)

---

## Phase 4: Feature Testing

### Test 1: Login Flow
- [ ] Launch app
- [ ] Login with test account
- [ ] Family members load successfully
- [ ] No errors in console

### Test 2: Add Family Member
- [ ] Click "Add Family Member"
- [ ] Enter name: "Test Member"
- [ ] Select color
- [ ] Click Add
- [ ] Should appear in list
- [ ] Check that calendar matching still works (match by name)

### Test 3: Calendar Display
- [ ] Calendars should display by name only
- [ ] No calendar_id values should be visible
- [ ] All calendars should show correctly

### Test 4: Shared Calendar Addition
- [ ] Click "Add Shared Calendar"
- [ ] Select a calendar from the list
- [ ] Should add successfully
- [ ] Display by calendar name

### Test 5: Multi-Device Simulation
- [ ] On Device A: Create family member "John"
- [ ] On Device B: Delete and reinstall app
- [ ] Login with same account on Device B
- [ ] "John" calendar should appear automatically (matched by name)
- [ ] No remapping needed

---

## Phase 5: Rollback Plan (If Issues)

### If Database Migration Fails:
```sql
-- Reverse migration (if needed)
-- Add calendar_id column back to each table
ALTER TABLE public.family_member_calendars
ADD COLUMN calendar_id text;

-- Restore old unique constraints
ALTER TABLE public.family_member_calendars
DROP CONSTRAINT unique_calendar_name_per_member;

ALTER TABLE public.family_member_calendars
ADD CONSTRAINT unique_calendar_per_member
UNIQUE(family_member_id, calendar_id);
```

### If App Build Fails:
1. Revert CoreData model changes:
   - Undo CoreData attribute deletions
   - Restore `calendarID` to entities
2. The app should build again

### If Runtime Errors:
1. Check console for error messages
2. Verify database migration completed successfully
3. Verify CoreData model matches database schema
4. Clear app data and rebuild

---

## Quick Checklist

```
[ ] Database Migration
    [ ] SQL executed on Supabase
    [ ] calendar_id columns removed from all tables
    [ ] New unique constraints verified

[ ] CoreData Update
    [ ] calendarID removed from FamilyMemberCalendar
    [ ] calendarID removed from SharedCalendar
    [ ] calendarID removed from PersonalCalendar
    [ ] calendarID removed from FamilyEvent (if applicable)
    [ ] Model saved

[ ] Build
    [ ] No build errors
    [ ] No warnings about calendarID
    [ ] App launches successfully

[ ] Testing
    [ ] Login works
    [ ] Family members display
    [ ] Calendar matching works
    [ ] Multi-device test passes
    [ ] No console errors
```

---

## Expected Changes User Won't Notice

- ✅ Calendar matching still works (by name instead of ID)
- ✅ All functionality identical
- ✅ No data loss
- ✅ App faster (less remapping logic)
- ✅ More reliable across devices

## Expected Changes Developer Will Notice

- ✅ No `calendar_id` in API responses
- ✅ No calendar ID remapping logic
- ✅ Simpler SupabaseDataManager (266 fewer lines)
- ✅ CoreData models smaller
- ✅ Easier to understand calendar matching

---

## Support

If you encounter issues:

1. Check the error message in console
2. Review REFACTOR_COMPLETE.md for what changed
3. Verify database migration completed
4. Verify CoreData model matches
5. Clean build (xcodebuild clean)

**Key Files for Reference:**
- `supabase_remove_calendar_id.sql` - Database changes
- `REFACTOR_COMPLETE.md` - Summary of all code changes
- `SupabaseManager.swift` - Updated API functions
- `SupabaseDataSync.swift` - Removed calendar_id mappings
- `SupabaseDataManager.swift` - Deleted remapping functions
- `FamCalApp.swift` - Removed device migration logic
