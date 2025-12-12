# Checklist Feature - Setup Verification

## Prerequisites

Before testing the checklist feature, ensure these steps are completed:

### 1. Supabase Table Setup

The following tables must exist in your Supabase `public` schema:

#### `event_checklists`
```sql
CREATE TABLE IF NOT EXISTS public.event_checklists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_identifier TEXT NOT NULL,
    event_group_id UUID,
    event_title TEXT,  -- IMPORTANT: This column is required
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    deletion_reason TEXT,
    CONSTRAINT event_checklists_event_identifier_check CHECK (char_length(event_identifier) > 0)
);
```

**Key Column: `event_title`**
- Must be present in the table
- Used to display event names in ChecklistsView
- Synced bidirectionally between Core Data and Supabase

#### `checklist_items`
```sql
CREATE TABLE IF NOT EXISTS public.checklist_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    checklist_id UUID NOT NULL REFERENCES public.event_checklists(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    due_date TIMESTAMPTZ,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMPTZ,
    completed_by UUID,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    modified_at TIMESTAMPTZ,
    deleted_at TIMESTAMPTZ,
    notification_id TEXT,
    CONSTRAINT checklist_items_title_check CHECK (char_length(title) > 0),
    CONSTRAINT checklist_items_sort_order_check CHECK (sort_order >= 0)
);
```

### 2. RLS Policies

Both tables must have Row-Level Security (RLS) enabled with appropriate policies:

- Users can SELECT/INSERT/UPDATE/DELETE checklists for their family
- Users can SELECT/INSERT/UPDATE/DELETE items in checklists they have access to
- See `migration_event_checklists.sql` for full RLS policy definitions

### 3. Verify Column Exists

Run this query in Supabase SQL Editor to verify:

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'event_checklists'
ORDER BY ordinal_position;
```

Expected columns:
- `id` (UUID, NOT NULL)
- `event_identifier` (TEXT, NOT NULL)
- `event_group_id` (UUID, nullable)
- `event_title` (TEXT, nullable) ← **CRITICAL**
- `created_at` (TIMESTAMPTZ, NOT NULL)
- `modified_at` (TIMESTAMPTZ, nullable)
- `deleted_at` (TIMESTAMPTZ, nullable)
- `deletion_reason` (TEXT, nullable)

## Common Issues

### Issue: Checklist items don't sync to Supabase

**Cause:** Missing `event_title` column in Supabase table

**Fix:** Run migration to add column:
```sql
ALTER TABLE public.event_checklists
ADD COLUMN IF NOT EXISTS event_title TEXT;
```

### Issue: Event names are blank in ChecklistsView

**Cause:** `eventTitle` not synced to/from Supabase, or Supabase column missing

**Fix:**
1. Ensure `event_title` column exists in Supabase (see above)
2. Re-sync items after migration

### Issue: 403 RLS Errors

**Cause:** RLS policies not properly configured

**Fix:**
1. Ensure user is authenticated
2. Ensure user is in `family_members` table
3. Verify RLS policies are enabled on both tables
4. Check that checklist parent exists before syncing items

## Verification Steps

1. **Check Supabase Tables**
   ```sql
   SELECT table_name FROM information_schema.tables
   WHERE table_schema = 'public' AND table_name IN ('event_checklists', 'checklist_items');
   ```
   Should return both tables

2. **Check Columns**
   ```sql
   \d event_checklists
   ```
   Should show `event_title` column

3. **Check RLS is Enabled**
   ```sql
   SELECT tablename, rowsecurity FROM pg_tables
   WHERE schemaname = 'public' AND tablename IN ('event_checklists', 'checklist_items');
   ```
   Both should show `rowsecurity = true`

4. **Check RLS Policies**
   ```sql
   SELECT tablename, policyname FROM pg_policies
   WHERE schemaname = 'public' AND tablename IN ('event_checklists', 'checklist_items');
   ```
   Should show multiple policies for each table

## Migration Files

- `migration_event_checklists.sql` - Initial table and RLS policy setup
- `migration_add_event_title_to_checklists.sql` - Adds missing `event_title` column

## Testing Checklist

After running migrations:

- [ ] Table columns verified with query above
- [ ] Can add checklist item in EventDetailView
- [ ] Item appears in Supabase `checklist_items` table
- [ ] Checklist appears in Supabase `event_checklists` table with `event_title` populated
- [ ] Event name appears in ChecklistsView
- [ ] Progress badge (0/1) appears immediately
- [ ] Cross-device sync works without 403 errors
