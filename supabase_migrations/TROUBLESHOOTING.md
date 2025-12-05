# Troubleshooting: "calendar_id" Error

## Still Getting the Error After Running COMPLETE_MIGRATION.sql?

If you ran the migration but still see:
```
"record 'new' has no field 'calendar_id'"
```

There's likely a trigger we didn't catch. Follow these steps:

---

## Step 1: Run Diagnostic Check

**Copy and run this in Supabase SQL Editor:**

```sql
-- File: DIAGNOSTIC_CHECK.sql
```

Copy the entire contents of [DIAGNOSTIC_CHECK.sql](DIAGNOSTIC_CHECK.sql)

**What to look for in results:**
- Any trigger names that contain "calendar_id"
- Any function names that contain "calendar_id"
- Any columns named "calendar_id" (should be NONE)

---

## Step 2: Nuclear Cleanup (Recommended)

If diagnostic shows old triggers still exist, run the nuclear cleanup:

**Copy and run this in Supabase SQL Editor:**

```sql
-- File: NUCLEAR_CLEANUP.sql
```

Copy the entire contents of [NUCLEAR_CLEANUP.sql](NUCLEAR_CLEANUP.sql)

**What this does:**
- Drops **ALL** triggers on calendar tables
- Drops **ALL** functions that mention "calendar_id"
- Recreates **only** the correct `updated_at` triggers
- Safe to run multiple times

---

## Step 3: Verify the Fix

After running NUCLEAR_CLEANUP.sql, check the results table at the bottom.

**You should see:**
```
trigger_name                              | event_object_table
-----------------------------------------|--------------------
set_updated_at_families                  | families
set_updated_at_family_member_calendars   | family_member_calendars
set_updated_at_shared_calendars          | shared_calendars
```

**Only 3 triggers, all named `set_updated_at_*`**

If you see ANY other triggers, they need to be dropped manually.

---

## Step 4: Test in App

1. **Delete the app** from simulator/device
2. **Rebuild** in Xcode (clean build folder first)
3. **Install and run**
4. **Go through setup** - create family and shared calendars
5. **Should complete without error!**

---

## Still Having Issues?

### Error Persists After Nuclear Cleanup

If you still get the error, check if `calendar_id` column actually exists:

```sql
SELECT table_name, column_name
FROM information_schema.columns
WHERE table_schema = 'public'
AND column_name = 'calendar_id';
```

**Expected result:** 0 rows

If it shows rows, that means the `calendar_id` column still exists and needs to be removed:

```sql
ALTER TABLE shared_calendars DROP COLUMN IF EXISTS calendar_id CASCADE;
ALTER TABLE family_member_calendars DROP COLUMN IF EXISTS calendar_id CASCADE;
ALTER TABLE personal_calendars DROP COLUMN IF EXISTS calendar_id CASCADE;
```

### Error is Coming from Different Table

Check the full error message to see which table:
```
"record 'new' has no field 'calendar_id'"
```

Look at the iOS console for the full error - it should say which API endpoint failed:
- `/rest/v1/shared_calendars` → error in `shared_calendars` table
- `/rest/v1/family_member_calendars` → error in `family_member_calendars` table
- `/rest/v1/personal_calendars` → error in `personal_calendars` table

Then run NUCLEAR_CLEANUP.sql which handles all three.

---

## Manual Trigger Investigation

If you want to see the exact trigger causing the issue:

```sql
-- Show trigger definition
SELECT
    t.trigger_name,
    t.event_object_table,
    t.action_statement,
    p.prosrc as function_source
FROM information_schema.triggers t
LEFT JOIN pg_proc p ON p.proname = substring(t.action_statement from 'EXECUTE FUNCTION ([^(]+)')
WHERE t.event_object_table = 'shared_calendars'
AND t.event_object_schema = 'public';
```

This will show you the actual trigger code. Look for any references to `calendar_id`.

---

## Last Resort: Full Table Rebuild

If nothing works, you can rebuild the problematic table:

⚠️ **WARNING: This will delete all data in the table!**

```sql
-- Backup data first
CREATE TABLE shared_calendars_backup AS SELECT * FROM shared_calendars;

-- Drop and recreate table (adjust schema as needed)
DROP TABLE shared_calendars CASCADE;

CREATE TABLE shared_calendars (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id TEXT NOT NULL,
    calendar_name TEXT NOT NULL,
    calendar_color_hex TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_shared_calendars_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_shared_calendars
    BEFORE INSERT OR UPDATE ON shared_calendars
    FOR EACH ROW
    EXECUTE FUNCTION update_shared_calendars_updated_at();

-- Restore data (excluding calendar_id column)
INSERT INTO shared_calendars (id, family_id, calendar_name, calendar_color_hex, created_at)
SELECT id, family_id, calendar_name, calendar_color_hex, created_at
FROM shared_calendars_backup;
```

---

## Getting Help

If none of these work, provide:
1. Results from DIAGNOSTIC_CHECK.sql
2. Full error message from iOS console
3. Which migration scripts you've run
