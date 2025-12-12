# Checklist RLS 403 Error Troubleshooting Guide

## Error Message
```
❌ [upsertChecklistItem] HTTP 403: {"code":"42501","message":"new row violates row-level security policy for table \"checklist_items\""}
```

## What This Error Means

The Supabase Row-Level Security (RLS) policy is rejecting the checklist item INSERT because one of these conditions is not met:

1. **User is not authenticated** - The current user session is invalid
2. **User is not a family member** - The user doesn't exist in the `family_members` table
3. **Parent checklist doesn't exist** - The `checklist_id` references a checklist that doesn't exist in Supabase
4. **Parent checklist is deleted** - The parent checklist has `deleted_at IS NOT NULL`
5. **Item has empty checklist_id** - The item wasn't properly linked to a parent checklist

## Diagnostic Steps

### Step 1: Check Console Logs

When syncing, look for these logs:

```
📤 Syncing checklists to Supabase...
📋 Found X checklists to sync
  ↑ Syncing checklist: [UUID] for event: [eventIdentifier]
     Checklist has deletedAt: [true/false]
    ✅ Checklist synced successfully to Supabase
    📝 Found X items to sync
      ↑ Syncing item: [UUID] - [title]
         Item checklist_id: [UUID]
         Parent checklist ID: [UUID]
```

**What to look for:**
- ✅ Does the checklist sync successfully before items?
- ❌ Is there a warning: "ChecklistItem [UUID] has no parent checklist!"?
- Does the `checklist_id` match the `Parent checklist ID`?

### Step 2: Verify Authentication

Check that you're logged in with a valid account:

```
// In console, look for:
// ✅ User authenticated
// ✅ User is family member
```

If not authenticated, the RLS policy will reject all operations.

### Step 3: Verify Parent Checklist Synced

The checklist must be synced to Supabase BEFORE items can reference it.

Check the logs:
- Did you see "✅ Checklist synced successfully"?
- Or did the checklist sync fail silently?

### Step 4: Check Checklist Relationship in Core Data

Items MUST have a parent checklist assigned. Look for warnings like:

```
⚠️ WARNING: ChecklistItem [UUID] has no parent checklist!
   This will fail RLS validation in Supabase
```

If you see this, the item will definitely fail.

## Common Causes and Fixes

### Issue 1: Item Has No Parent Checklist

**Cause:** Item's `checklist` relationship is null

**Evidence:** Console shows:
```
⚠️ WARNING: ChecklistItem [UUID] has no parent checklist!
```

**Fix:**
1. Verify item was created with `addItem(to: checklist, ...)`
2. Check that the checklist relationship is set before saving
3. Manually verify in Xcode debugger: `item.checklist != nil`

### Issue 2: Checklist Didn't Sync Before Item

**Cause:** Timing issue - item tries to sync before checklist exists in Supabase

**Evidence:** Console shows:
- Checklist sync fails or is skipped
- But item still tries to sync
- Item gets 403 error

**Fix:**
- The code has a 0.5 second delay between checklist and item sync
- If still failing, increase delay in `syncChecklistsToSupabase()`
- Current delay: `try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second`
- Try: `try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second`

### Issue 3: Deleted Checklist

**Cause:** Item is linked to a deleted checklist (`deletedAt IS NOT NULL`)

**Evidence:** Console shows:
```
     Checklist has deletedAt: true
    ⏭️  Skipping deleted checklist
```

**Fix:**
- Don't create items for deleted checklists
- If checklist is soft-deleted, items should be deleted too
- Check that deleteItem() cascades properly

### Issue 4: User Not a Family Member

**Cause:** User account exists but not added to this family

**Evidence:**
- Any user who hasn't been invited to the family
- RLS policy requires: `EXISTS (SELECT 1 FROM family_members WHERE user_id = auth.uid())`

**Fix:**
- Ensure user is a family member in Supabase
- Run this query in Supabase SQL Editor:
  ```sql
  SELECT * FROM family_members WHERE user_id = auth.uid();
  ```
- If empty result, user needs to be added to the family first

## Testing Cross-Device Sync

### On Phone A (Create Item):
1. Create a checklist item in an event
2. Check console logs for:
   - Item created and saved locally
   - Sync triggered
   - Checklist synced successfully
   - Item synced successfully

### On Phone B (Verify):
1. Open the same event
2. Check if item appears immediately
3. If not, pull-to-refresh or reopen event detail
4. Item should appear from Supabase sync

## If Still Getting 403

1. **Increase delay** between checklist and item sync (in syncChecklistsToSupabase)
2. **Clear and retry** - Force refresh the view
3. **Check Supabase directly**:
   ```sql
   -- Verify checklist exists
   SELECT * FROM event_checklists WHERE id = '[UUID]';

   -- Verify user is family member
   SELECT * FROM family_members WHERE user_id = auth.uid();

   -- Check RLS policies
   SELECT tablename, policyname FROM pg_policies
   WHERE schemaname = 'public' AND tablename = 'checklist_items';
   ```

## Advanced: Manual Supabase Testing

To test if RLS is the issue:

1. Go to Supabase SQL Editor
2. Create a test checklist:
   ```sql
   INSERT INTO event_checklists (id, event_identifier)
   VALUES ('[UUID]', 'test-event');
   ```
3. Try to insert an item:
   ```sql
   INSERT INTO checklist_items (id, checklist_id, title)
   VALUES ('[UUID]', '[PARENT-UUID]', 'test');
   ```
4. If this fails with 403, the RLS policy is rejecting the operation
5. If it succeeds, the issue is in how the app is sending data

## See Also

- [Checklist Supabase Setup](./CHECKLIST_SUPABASE_SETUP.md)
- [Checklist Implementation Summary](./CHECKLISTS_IMPLEMENTATION_SUMMARY.md)
