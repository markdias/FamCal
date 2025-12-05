# Phase 1 & 2 Testing Checklist

## Quick Start Guide

### Phase 1: Supabase Migration (5 minutes)

1. **Open Supabase Dashboard** → SQL Editor
2. **Copy & Paste:** `supabase_migrations/add_updated_at_timestamps.sql`
3. **Click Run**
4. **Verify:** Run these queries:
   ```sql
   SELECT COUNT(*) FROM shared_calendars WHERE updated_at IS NULL;
   SELECT COUNT(*) FROM family_member_calendars WHERE updated_at IS NULL;
   SELECT COUNT(*) FROM families WHERE updated_at IS NULL;
   ```
   All should return `0`

**✅ Phase 1 Done** when all 3 queries return 0

---

### Phase 2: CoreData Schema (2 minutes)

1. **Open Xcode**
2. **Clean:** ⇧⌘K (Shift-Cmd-K)
3. **Build:** ⌘B (Cmd-B)
4. **Run:** ⌘R (Cmd-R)

**Expected on first launch:**
```
✅ Persistence: Configured store URL in description with auto-migration enabled
✅ Store migration completed and marked (v2 - incremental sync schema)
✅ CoreData store loaded successfully
```

**✅ Phase 2 Done** when:
- App builds without errors
- App launches successfully
- Console shows "v2 - incremental sync schema" message

---

## Important Notes

### ⚠️ What Will Happen on First Launch

The app will **delete and recreate** the CoreData database because of the version marker change (`v1` → `v2`). This is intentional and safe because:
- Data will be re-synced from Supabase
- Users won't lose data (it's in Supabase)
- This only happens ONCE

### ✅ Automatic Migration Enabled

The following settings ensure smooth schema updates:
```swift
description.shouldMigrateStoreAutomatically = true
description.shouldInferMappingModelAutomatically = true
```

This means:
- CoreData will auto-add new attributes (updatedAt, isDeleted, deletedAt)
- No manual migration code needed
- Safe for production

---

## What to Report

**If Successful:**
```
Phase 1: ✅ Migration ran, all queries return 0
Phase 2: ✅ App builds and runs, console shows v2 message
```

**If Errors:**
- Screenshot of SQL error (if Phase 1 fails)
- Copy/paste Xcode console output (if Phase 2 fails)
- Full error message

---

## Next Steps (After Successful Testing)

Once you confirm both phases work, I'll proceed with:

1. **Remove aggressive data clearing** from SupabaseDataManager
2. **Integrate IncrementalSyncService** for safe sync
3. **Add response validation** to prevent empty-response data loss
4. **Implement soft delete** throughout the app
5. **Add integrity checker** in settings UI

This will complete the data persistence fix.
