# SQL Migration Comparison: v1 vs the current dedup migration

## Quick Comparison

| Aspect | v1 (Original) | Current dedup migration |
|--------|---------------|--------------------------|
| **Handles duplicates?** | ❌ No | ✅ Yes |
| **Deletes old entries?** | ❌ No | ✅ Yes (keeps newest) |
| **Works with your data?** | ❌ Fails | ✅ Succeeds |
| **Code length** | Shorter | Longer (more careful) |
| **Risk level** | ⚠️ High | ✅ Low |

---

## What v1 Does (Failed ❌)

### family_member_calendars Example

**Before:**
```
id: 111   family_member_id: ABC   calendar_name: Verity   calendar_id: DEV1ID   created_at: 2025-11-20
id: 222   family_member_id: ABC   calendar_name: Verity   calendar_id: DEV2ID   created_at: 2025-11-25
```

**v1 Migration Steps:**
1. DROP INDEX `idx_family_member_calendars_calendar_id`
2. DROP CONSTRAINT `unique_calendar_per_member`
3. DROP COLUMN `calendar_id` ← leaves both rows
4. CREATE CONSTRAINT `unique(family_member_id, calendar_name)` ← **FAILS HERE!**

**Why it fails:**
```
ERROR: Row 111 and Row 222 both have (ABC, Verity)
Cannot create unique constraint!
```

---

## What the current dedup migration does (Works ✅)

### family_member_calendars Example

**Before:**
```
id: 111   family_member_id: ABC   calendar_name: Verity   calendar_id: DEV1ID   created_at: 2025-11-20
id: 222   family_member_id: ABC   calendar_name: Verity   calendar_id: DEV2ID   created_at: 2025-11-25
```

**Current dedup migration steps:**
1. **DELETE duplicates** (keep only newest):
   ```sql
   DELETE FROM family_member_calendars
   WHERE id NOT IN (
       SELECT DISTINCT ON (family_member_id, calendar_name) id
       FROM family_member_calendars
       ORDER BY family_member_id, calendar_name, created_at DESC
   );
   ```

   Result after DELETE:
   ```
   id: 222   family_member_id: ABC   calendar_name: Verity   calendar_id: DEV2ID   created_at: 2025-11-25
   (Row 111 is deleted)
   ```

2. DROP INDEX `idx_family_member_calendars_calendar_id`
3. DROP CONSTRAINT `unique_calendar_per_member`
4. DROP COLUMN `calendar_id`
5. CREATE CONSTRAINT `unique(family_member_id, calendar_name)` ← **SUCCEEDS!**

**Final Result:**
```
id: 222   family_member_id: ABC   calendar_name: Verity   created_at: 2025-11-25
```

---

## Data Loss?

### What Gets Deleted
- ❌ Duplicate calendar entries (older ones)
- ❌ Associated `calendar_id` values (which are device-specific anyway)

### What's Preserved
- ✅ Most recent calendar entry for each person
- ✅ Calendar name, color, and other metadata
- ✅ All event data (unaffected)
- ✅ All family members (unaffected)
- ✅ All user data (unaffected)

### Will Users Notice?
- ❌ No. The app only uses `calendar_name` for matching
- ✅ User experience identical
- ✅ All calendars still appear
- ✅ No data loss from user perspective

---

## The Key Difference

### v1: "Just remove calendar_id"
```sql
ALTER TABLE family_member_calendars DROP COLUMN calendar_id;
ADD CONSTRAINT unique(family_member_id, calendar_name);
```
Assumes: Each (family_member_id, calendar_name) pair is unique
Reality: Your data has duplicates! ❌

### Current migration: "Clean up first, then remove calendar_id"
```sql
DELETE FROM family_member_calendars
WHERE id NOT IN (
    SELECT DISTINCT ON (family_member_id, calendar_name) id
    FROM family_member_calendars
    ORDER BY family_member_id, calendar_name, created_at DESC
);
ALTER TABLE family_member_calendars DROP COLUMN calendar_id;
ADD CONSTRAINT unique(family_member_id, calendar_name);
```
Handles: Duplicate entries automatically ✅

---

## SQL Deduplication Logic Explained

### The DELETE Query:
```sql
DELETE FROM family_member_calendars
WHERE id NOT IN (
    SELECT DISTINCT ON (family_member_id, calendar_name) id
    FROM family_member_calendars
    ORDER BY family_member_id, calendar_name, created_at DESC
);
```

**What it does:**
1. `SELECT DISTINCT ON (family_member_id, calendar_name)`
   - For each unique combo of (family_member_id, calendar_name)

2. `ORDER BY ... created_at DESC`
   - Sort by creation date, newest first

3. Result: Gets ONE row per (family_member_id, calendar_name) - the newest one

4. `WHERE id NOT IN (result above)`
   - Delete all OTHER rows with that combo

**Result:** Only the newest entry for each calendar per member remains

---

## Applied to All Tables

The current dedup migration applies the same deduplication logic to:

| Table | Deduped By | Result |
|-------|-----------|--------|
| `family_member_calendars` | `(family_member_id, calendar_name)` | One entry per member-calendar pair |
| `shared_calendars` | `(user_id, calendar_name)` | One entry per user-calendar pair |
| `personal_calendars` | `(user_id, calendar_name)` | One entry per user-calendar pair |
| `calendar_event_metadata` | `(user_id, event_identifier)` | One entry per user-event |

---

## Bottom Line

- **v1:** Fails because it doesn't handle duplicates
- **Current dedup migration:** Succeeds because it removes duplicates first
- **Both:** Result in the same clean database structure
- **Difference:** The current dedup migration actually works with your real data

✅ **Use the current dedup migration (`supabase_remove_calendar_id.sql`).**
