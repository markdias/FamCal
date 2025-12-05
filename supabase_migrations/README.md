# Supabase Database Migrations

## Quick Fix for "calendar_id" Error

If you're seeing this error during setup:
```
"record 'new' has no field 'calendar_id'"
```

**Solution:** Run the complete migration to drop old triggers and add updated_at timestamps.

---

## How to Run the Migration

### ⚠️ STILL GETTING "calendar_id" ERROR?

If you already ran `COMPLETE_MIGRATION.sql` but still see the error, use the **NUCLEAR_CLEANUP.sql** instead:

1. Open Supabase Dashboard → SQL Editor
2. Copy **entire contents** of `NUCLEAR_CLEANUP.sql`
3. Paste and click **Run**
4. This drops ALL triggers and recreates only the correct ones

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed steps.

---

### Option 1: Nuclear Cleanup (USE THIS IF ERROR PERSISTS)

1. Open your Supabase project dashboard
2. Go to **SQL Editor** (left sidebar)
3. Create a new query
4. Copy the **entire contents** of `NUCLEAR_CLEANUP.sql`
5. Paste into the SQL Editor
6. Click **Run** (bottom right)
7. Check the results - should see only 3 triggers (all `set_updated_at_*`)

### Option 2: Standard Migration (for fresh database)

1. Open your Supabase project dashboard
2. Go to **SQL Editor** (left sidebar)
3. Create a new query
4. Copy the **entire contents** of `COMPLETE_MIGRATION.sql`
5. Paste into the SQL Editor
6. Click **Run** (bottom right)
7. Check the results - should see "✅ Migration complete!" message

### Option 2: Use Supabase CLI

If you have the Supabase CLI installed:

```bash
cd /Users/markdias/project/FamCal/supabase_migrations
supabase db push --file COMPLETE_MIGRATION.sql
```

---

## What This Migration Does

### Part 1: Cleanup Old Triggers
- Drops old database triggers that reference the removed `calendar_id` column
- This fixes the error: `"record 'new' has no field 'calendar_id'"`

### Part 2-4: Add Timestamp Tracking
- Adds `updated_at TIMESTAMPTZ` column to:
  - `shared_calendars`
  - `family_member_calendars`
  - `families`
- Creates auto-update triggers for each table
- Backfills existing rows with current timestamp

---

## After Running the Migration

1. **Verify Success**: Check the verification query results at the bottom
   - Should show 0 rows with NULL `updated_at`
   - Should list 3 triggers: one for each table

2. **Rebuild iOS App**: The migration changes database schema, so rebuild
   ```bash
   # Clean build in Xcode
   Product → Clean Build Folder
   Product → Build
   ```

3. **Test Setup Flow**:
   - Delete app from simulator/device
   - Fresh install and run through family setup
   - Should no longer see "calendar_id" error

---

## File Descriptions

| File | Purpose |
|------|---------|
| `COMPLETE_MIGRATION.sql` | **START HERE** - All migrations in one file for copy-paste |
| `drop_old_calendar_id_triggers.sql` | Part 1: Drop old triggers (standalone) |
| `add_updated_at_timestamps.sql` | Part 2-4: Add timestamps (standalone) |
| `RUN_THIS_FIRST.sql` | Optional: Master script using `\i` includes |

---

## Troubleshooting

### "Permission denied" error
- Make sure you're logged into Supabase with admin/owner role
- Try running from the Supabase dashboard SQL Editor instead of CLI

### "Trigger already exists" error
- This is safe to ignore - the migration uses `CREATE OR REPLACE` and `DROP IF EXISTS`
- The migration is idempotent (safe to run multiple times)

### Still seeing "calendar_id" error after migration
1. Verify the triggers were actually dropped:
   ```sql
   SELECT trigger_name, event_object_table
   FROM information_schema.triggers
   WHERE trigger_name LIKE '%calendar_id%';
   ```
   Should return 0 rows.

2. Clear your app's local data:
   - Delete app from device/simulator
   - Reinstall fresh

---

## Next Steps After Migration

Once the migration completes successfully:

1. ✅ Database schema updated with `updated_at` columns
2. ✅ Old `calendar_id` triggers removed
3. 🔄 Ready for **Phase 3: Incremental Sync** (future)
   - The `IncrementalSyncService.swift` is already implemented
   - Will use `updated_at` timestamps for efficient change detection
   - Can be integrated when needed

---

## Need Help?

If you encounter issues:
1. Check Supabase logs in the dashboard
2. Run the verification queries at the bottom of `COMPLETE_MIGRATION.sql`
3. Check iOS app console for detailed error messages
