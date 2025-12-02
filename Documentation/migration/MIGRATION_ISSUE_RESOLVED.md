# Migration Issue & Solution

## The Problem

When you tried to run the SQL migration, you got this error:

```
ERROR: 23505: could not create unique index "unique_calendar_name_per_member"
DETAIL: Key (family_member_id, calendar_name)=(d51c111a-0b0f-4b15-806c-d9c7932a29a7, Verity) is duplicated.
```

### Why This Happened

In your database, you have the same family member with the same calendar name stored **multiple times**. This happened because:

1. You added a family member "Verity" to your account
2. You logged into the app on Device A and linked the "Verity" calendar
3. You logged into the app on Device B and linked the "Verity" calendar again
4. Both entries were stored in the database (differentiated by `calendar_id` which was device-specific)

**Example of duplicates in your data:**
```
family_member_id: d51c111a...   calendar_name: Verity   calendar_id: ABC123 (Device A)
family_member_id: d51c111a...   calendar_name: Verity   calendar_id: XYZ789 (Device B)
```

When we try to create a unique constraint on `(family_member_id, calendar_name)`, the database sees two rows with the same values and rejects it.

---

## The Solution

**Use `supabase_remove_calendar_id.sql`** instead of the original migration.

The canonical dedup migration (v3):
1. **Identifies** all duplicate calendar names per family member
2. **Keeps** the most recent one (based on `created_at`)
3. **Deletes** the older duplicates
4. **Then** creates the unique constraint

> The `supabase_remove_calendar_id_v2.sql` file is retained here for reference, but `supabase_remove_calendar_id.sql` is the updated script you should execute.

### What Gets Deleted

For "Verity" example above:
- ❌ Older entry (Device A): `calendar_id: ABC123` - DELETED
- ✅ Newer entry (Device B): `calendar_id: XYZ789` - KEPT

The app will use the kept entry. Since it only uses `calendar_name` for matching anyway, losing the device-specific `calendar_id` doesn't matter.

---

## How to Deploy (Corrected Steps)

### Step 1: Run the canonical dedup migration

1. Go to Supabase SQL Editor
2. Copy the entire contents of: **`supabase_remove_calendar_id.sql`**
3. Run the query

**Expected output:**
```
DELETE 0  (or number of duplicates that were removed)
ALTER TABLE
ALTER TABLE
... (all DDL operations succeed)
```

### Step 2: Verify

In Supabase → Database → Tables:
- ✅ `family_member_calendars` has NO `calendar_id` column
- ✅ `shared_calendars` has NO `calendar_id` column
- ✅ `personal_calendars` has NO `calendar_id` column
- ✅ Unique constraints created successfully

### Step 3: Continue with CoreData Update

Proceed with the CoreData model update as normal.

---

## What This Means for Your Data

| Before | After |
|--------|-------|
| Multiple "Verity" entries (one per device) | One "Verity" entry |
| 3 calendar_ids stored per person | 0 calendar_ids stored |
| Complex remapping logic | Simple name-based matching |

**User Impact:** None. Functionally identical, but simpler and more reliable.

---

## Files Reference

- ✅ `supabase_remove_calendar_id.sql` - **Run this** (current dedup migration, removes duplicates before constraints)
- ℹ️ `supabase_remove_calendar_id_v2.sql` - Previous dedup version (identical logic, kept for reference)
- ❌ `supabase_remove_calendar_id_v1.sql` - Original migration (fails on duplicate data)

---

## If Something Goes Wrong

### Scenario 1: Migration Still Fails

Check for edge cases:
- Are there other duplicate calendar entries?
- Run a test query to see all duplicates:

```sql
SELECT family_member_id, calendar_name, COUNT(*) as count
FROM public.family_member_calendars
GROUP BY family_member_id, calendar_name
HAVING COUNT(*) > 1;
```

### Scenario 2: Duplicate Issue After Running the Migration

If the canonical migration deleted records and you see issues:
1. The data should still be fine (we kept the most recent)
2. Just rebuild the app and test
3. If needed, you have backups (Supabase keeps point-in-time recovery)

### Scenario 3: Need to Rollback

Use Supabase's point-in-time recovery feature:
1. Go to Supabase Dashboard → Database → Backups
2. Restore to before you ran the migration
3. Try again with `supabase_remove_calendar_id.sql`

---

## Summary

✅ **Problem:** Duplicate calendars per family member (from multiple devices)
✅ **Solution:** The canonical dedup migration (`supabase_remove_calendar_id.sql`) removes duplicates before adding constraints
✅ **Action:** Run `supabase_remove_calendar_id.sql` (older versions are kept only for reference)
✅ **Result:** Clean database, app works as before, but simpler internally
