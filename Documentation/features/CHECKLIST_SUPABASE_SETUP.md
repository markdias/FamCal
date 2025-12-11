# Checklist Supabase Setup Guide

## Problem: 403 Error When Syncing Checklists

When you try to sync checklists to Supabase, you might see this error:

```
❌ [upsertChecklistItem] HTTP 403: {"code":"42501","message":"new row violates row-level security policy for table \"checklist_items\""}
```

This means the Supabase tables haven't been deployed to your database yet.

## Solution: Deploy the Checklist Migration

The checklist feature requires Supabase tables to be created with proper Row-Level Security (RLS) policies. Here's how to set it up:

### Step 1: Access Your Supabase Console

1. Go to [https://supabase.com](https://supabase.com)
2. Sign in to your account
3. Select your FamCal project
4. Click **SQL Editor** in the left sidebar

### Step 2: Run the Migration

1. Click **New Query**
2. Copy the entire contents of this file:
   ```
   Documentation/supabase/migration_event_checklists.sql
   ```
3. Paste it into the SQL editor
4. Click **Run** (or press Cmd+Enter)

Expected output: Queries should complete without errors

### Step 3: Verify the Tables Were Created

Run these verification queries to confirm:

```sql
-- Check if tables exist
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN ('event_checklists', 'checklist_items');

-- Check if RLS is enabled
SELECT tablename, rowsecurity FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('event_checklists', 'checklist_items');

-- Check if policies were created
SELECT tablename, policyname FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('event_checklists', 'checklist_items');
```

All three queries should return results confirming the tables, RLS, and policies are in place.

## What Gets Created

The migration creates:

### Tables
- **event_checklists** - Stores checklists linked to calendar events
- **checklist_items** - Individual items within a checklist

### Row-Level Security (RLS) Policies
- ✅ SELECT: Users can view checklists for their family's events
- ✅ INSERT: Users can create checklists and items
- ✅ UPDATE: Users can modify checklists and items
- ✅ DELETE: Users can soft delete (mark as deleted)

All policies require:
1. User to be authenticated (`auth.uid() IS NOT NULL`)
2. User to be a family member (exists in `family_members` table)
3. Checklist/item to be accessible to their family

### Indexes
- Fast lookup by event identifier
- Fast lookup by event group (for recurring events)
- Fast lookup by due date
- Optimized sorting by item order

## Troubleshooting

### Still getting 403 errors?

**Check 1: Are you logged in?**
- The app requires authentication to sync
- Guest mode skips sync (see console logs)
- Make sure you're logged in with the same account used to set up the family

**Check 2: Are you a family member?**
- Your user account must exist in the `family_members` table
- Check in Supabase > SQL Editor:
  ```sql
  SELECT * FROM family_members WHERE user_id = auth.uid();
  ```
- If empty, you haven't completed family setup yet

**Check 3: Did the tables deploy correctly?**
- Run the verification queries above
- All three should return results
- If not, rerun the migration

### Tables created but still getting errors?

This might be a **timing issue** - the RLS policy checks might be running before the checklist table has been inserted.

**Solution**:
1. Try adding the checklist item again
2. Check the console output for detailed error messages
3. If it still fails, try:
   - Closing the event detail view
   - Reopening it
   - Adding the item again

The first sync attempt might fail if there's a race condition, but subsequent attempts usually succeed.

## Data Flow

```
1. User adds checklist item in the app
   ↓
2. Saved to Core Data (local, offline-first)
   ↓
3. Background sync triggered
   ↓
4. ChecklistManager.syncChecklistsToSupabase()
   ↓
5. SupabaseDataManager converts Core Data → DTOs
   ↓
6. SupabaseManager makes REST API calls
   ↓
7. Supabase RLS policies verify user access
   ↓
8. If verified: ✅ Inserted to Supabase tables
   If not verified: ❌ 403 error
```

## What This Enables

Once deployed, checklists will:
- ✅ Sync bidirectionally with Supabase
- ✅ Appear on other family members' devices
- ✅ Persist even if the app is uninstalled
- ✅ Be accessible from web/other clients
- ✅ Have full audit trail (soft deletes, timestamps)

## Questions or Issues?

See the main checklist documentation: `Documentation/features/CHECKLISTS_IMPLEMENTATION_SUMMARY.md`
