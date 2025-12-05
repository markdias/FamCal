# Testing Guide - Data Persistence Fix

## Overview
This guide walks you through testing the data persistence improvements in phases.

---

## Phase 1: Supabase Migration ✅

### Step 1: Run the Migration

**Option A: Supabase Dashboard (Recommended)**
1. Open your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Open the file: `supabase_migrations/add_updated_at_timestamps.sql`
4. Copy the entire contents
5. Paste into SQL Editor
6. Click **Run**

**Option B: Supabase CLI**
```bash
cd /Users/markdias/project/FamCal
supabase db push
```

### Step 2: Verify Migration Success

Run these verification queries in the SQL Editor:

```sql
-- Should return 0 for all
SELECT COUNT(*) FROM shared_calendars WHERE updated_at IS NULL;
SELECT COUNT(*) FROM family_member_calendars WHERE updated_at IS NULL;
SELECT COUNT(*) FROM families WHERE updated_at IS NULL;
```

```sql
-- Should show 3 triggers
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE 'set_updated_at%';
```

**Expected Output:**
```
trigger_name                                  | event_object_table
----------------------------------------------|-------------------
set_updated_at_shared_calendars              | shared_calendars
set_updated_at_family_member_calendars       | family_member_calendars
set_updated_at_families                      | families
```

### Step 3: Test Trigger Behavior

```sql
-- Update a row and verify updated_at changes
UPDATE shared_calendars
SET calendar_name = calendar_name
WHERE id = (SELECT id FROM shared_calendars LIMIT 1)
RETURNING id, updated_at;

-- Insert a new row and verify updated_at is set
INSERT INTO shared_calendars (id, calendar_id, calendar_name, calendar_color_hex)
VALUES (gen_random_uuid(), 'test-cal', 'Test Calendar', '#FF0000')
RETURNING id, updated_at;
```

**Expected:** Both queries should return a timestamp for `updated_at`

### ✅ Phase 1 Complete When:
- [ ] All 3 tables have `updated_at` column (no NULLs)
- [ ] All 3 triggers exist and fire correctly
- [ ] UPDATE and INSERT both set `updated_at` timestamp

---

## Phase 2: CoreData Schema Migration ✅

### Step 1: Clean Build

1. **Open Xcode**
2. **Clean Build Folder:** Product → Clean Build Folder (⇧⌘K)
3. **Build the Project:** Product → Build (⌘B)

### Step 2: Check for Build Errors

**✅ Success Indicators:**
- Build completes with 0 errors
- You may see warnings - that's okay
- No CoreData schema errors

**❌ Common Errors and Fixes:**

**Error:** `"The model used to open the store is incompatible with the one used to create the store"`

**Fix:** CoreData detected schema changes. You need to:
1. Delete the app from the simulator/device
2. Clean build folder
3. Rebuild and reinstall

**OR** enable automatic lightweight migration (safer for users):

Open `Persistence.swift` and verify this section exists:
```swift
let description = container.persistentStoreDescriptions.first
description?.shouldMigrateStoreAutomatically = true
description?.shouldInferMappingModelAutomatically = true
```

### Step 3: Test App Launch

1. **Run the app** in the simulator (⌘R)
2. **Check the debug console** for CoreData messages
3. **Look for these log messages:**
   ```
   ✅ Found X cached family members in CoreData
   ```

### Step 4: Verify New Attributes Exist

**Quick Test in Xcode:**
1. Run the app
2. Pause at any breakpoint (or add one in `FamilyView`)
3. In the debug console, run:
   ```lldb
   po familyMembers.first?.value(forKey: "updatedAt")
   po familyMembers.first?.value(forKey: "isDeleted")
   po familyMembers.first?.value(forKey: "deletedAt")
   ```

**Expected:** Should return `nil` (not an error) - this means the attributes exist but aren't populated yet

**Error:** `"this class is not key value coding-compliant for the key"` means the attribute doesn't exist

### ✅ Phase 2 Complete When:
- [ ] App builds successfully
- [ ] App launches without crashes
- [ ] New attributes (updatedAt, isDeleted, deletedAt) exist on entities
- [ ] No CoreData migration errors in console

---

## Phase 3: Sync Logic Integration (Next Steps)

**DO NOT PROCEED** until Phases 1 and 2 are complete.

Once you verify the above:
1. Report back any errors encountered
2. Confirm both phases passed
3. I'll proceed with refactoring the sync logic to use the new architecture

---

## Rollback Plan (If Needed)

### Rollback CoreData Schema
```bash
cd /Users/markdias/project/FamCal
git checkout FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel/contents
```

Then delete and reinstall the app.

### Rollback Supabase Migration
```sql
-- Remove triggers
DROP TRIGGER IF EXISTS set_updated_at_shared_calendars ON shared_calendars;
DROP TRIGGER IF EXISTS set_updated_at_family_member_calendars ON family_member_calendars;
DROP TRIGGER IF EXISTS set_updated_at_families ON families;

-- Remove functions
DROP FUNCTION IF EXISTS update_shared_calendars_updated_at();
DROP FUNCTION IF EXISTS update_family_member_calendars_updated_at();
DROP FUNCTION IF EXISTS update_families_updated_at();

-- Remove columns
ALTER TABLE shared_calendars DROP COLUMN IF EXISTS updated_at;
ALTER TABLE family_member_calendars DROP COLUMN IF EXISTS updated_at;
ALTER TABLE families DROP COLUMN IF EXISTS updated_at;
```

---

## Troubleshooting

### Issue: "Supabase migration fails"
- Check that you have permissions to ALTER tables
- Verify you're running against the correct database
- Check for syntax errors in the SQL

### Issue: "CoreData won't migrate"
- Delete the app completely
- Clean build folder
- Rebuild and run
- If still fails, we'll add explicit migration mapping

### Issue: "App crashes on launch"
- Check crash log in Xcode console
- Look for CoreData stack initialization errors
- Verify `Persistence.swift` has lightweight migration enabled

---

## What to Report Back

Please let me know:

**✅ Success:**
- "Phase 1 complete - migration ran successfully"
- "Phase 2 complete - app builds and runs"

**❌ Errors:**
- Full error message from Xcode console
- Screenshot of SQL error (if migration failed)
- Crash log (if app crashes)

Then I'll proceed with Phase 3: implementing the safe sync logic.
