# Deployment Steps - Event Checklists Feature

## Overview
This deployment adds a shared checklist feature to events, allowing family members to create, view, and check off checklist items associated with calendar events.

## Phase 1: Database Migration ⚠️ CRITICAL - Do First

### Step 1: Run SQL Migration on Supabase

1. Go to: https://app.supabase.com/project/[YOUR_PROJECT_ID]/sql
2. Create a new query
3. Copy and paste the entire contents of: `Documentation/supabase/migration_event_checklists.sql`
4. **Review the SQL** to verify:
   - Creates `event_checklists` table
   - Creates `checklist_items` table
   - Enables Row Level Security (RLS)
   - Creates appropriate indexes
   - Sets up triggers for `modified_at` auto-update
5. Click "Run" to execute

**Expected Results:**
```
✅ CREATE TABLE event_checklists
✅ CREATE TABLE checklist_items
✅ CREATE INDEX (multiple indexes)
✅ ALTER TABLE ... ENABLE ROW LEVEL SECURITY
✅ CREATE POLICY (multiple policies)
✅ CREATE TRIGGER (auto-update triggers)
✅ GRANT permissions to authenticated users
```

**Verification:**
1. Go to Supabase → Database → Tables
2. Verify new tables exist:
   - ✅ `event_checklists` with columns: id, event_identifier, event_group_id, created_at, modified_at, deleted_at, deletion_reason
   - ✅ `checklist_items` with columns: id, checklist_id, title, due_date, completed, completed_at, completed_by, sort_order, created_at, modified_at, deleted_at, notification_id

3. Verify RLS is enabled:
```sql
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('event_checklists', 'checklist_items');
```
Expected: Both tables should show `rowsecurity = true`

4. Verify policies exist:
```sql
SELECT tablename, policyname
FROM pg_policies
WHERE schemaname = 'public'
AND tablename IN ('event_checklists', 'checklist_items');
```
Expected: Multiple policies for SELECT, INSERT, UPDATE, DELETE on both tables

---

## Phase 2: CoreData Model Update (Already Done)

The Core Data schema has been updated with the following entities:

### Checklist Entity
- **id**: UUID
- **eventIdentifier**: String (links to EventKit event)
- **eventGroupId**: UUID (groups recurring event checklists)
- **createdAt**: Date
- **modifiedAt**: Date
- **deletedAt**: Date (soft delete)
- **deletionReason**: String
- **Relationship**: items (one-to-many with ChecklistItem)

### ChecklistItem Entity
- **id**: UUID
- **title**: String
- **dueDate**: Date (optional)
- **completed**: Boolean
- **completedAt**: Date
- **completedBy**: UUID (family member ID)
- **sortOrder**: Int16
- **createdAt**: Date
- **modifiedAt**: Date
- **deletedAt**: Date (soft delete)
- **notificationId**: String (comma-separated notification IDs)
- **Relationship**: checklist (many-to-one with Checklist)

**Files Modified:**
- `FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel/contents`

---

## Phase 3: Code Deployment (Already Done)

### New Files Created:
1. **Models:**
   - `FamCal/Models/ChecklistModels.swift` - DTOs and view models

2. **Managers:**
   - `FamCal/Managers/ChecklistManager.swift` - Core business logic

3. **Views:**
   - `FamCal/Views/Checklist/ChecklistSectionView.swift` - Main checklist display
   - `FamCal/Views/Checklist/ChecklistItemRow.swift` - Individual item row
   - `FamCal/Views/Checklist/ChecklistEditorView.swift` - Add/edit sheets

### Files Modified:
1. `FamCal/Views/Events/EventDetailView.swift` - Integrated checklist display

### Files To Be Modified (In Progress):
1. `FamCal/Views/Events/AddEventView.swift` - Checklist creation
2. `FamCal/Views/Events/EditEventView.swift` - Checklist editing
3. `FamCal/Views/Calendar/CalendarView.swift` - Show indicators
4. `FamCal/Views/Calendar/DailyEventsView.swift` - Show badges
5. `FamCal/Managers/NotificationManager.swift` - Include checklists
6. `FamCal/Managers/SupabaseManager.swift` - API endpoints
7. `FamCal/Managers/SupabaseDataManager.swift` - Sync methods

---

## Phase 4: Build and Test

### Step 1: Clean Build

```bash
# In Terminal at project root
cd /Users/markdias/project/FamCal
xcodebuild clean -workspace FamCal.xcworkspace -scheme FamCal
```

### Step 2: Build

```bash
# Build the app
xcodebuild build -workspace FamCal.xcworkspace -scheme FamCal -destination 'generic/platform=iOS Simulator'
```

**Expected:** No build errors

### Step 3: Run in Simulator

Open `FamCal.xcworkspace` in Xcode and click the Run button (▶)

---

## Phase 5: Feature Testing

### Test 1: View Event with Checklist
- [ ] Open an existing event in EventDetailView
- [ ] Verify "Checklist" section appears (currently empty)
- [ ] Section should show "Add Item" button

### Test 2: Create Checklist Item
- [ ] In event detail, tap "Add Item"
- [ ] Enter title: "Test Item 1"
- [ ] Set due date (optional)
- [ ] Tap "Add"
- [ ] Item should appear in checklist

### Test 3: Check Off Item
- [ ] Tap checkbox next to checklist item
- [ ] Item should show as checked (green checkmark)
- [ ] Item title should have strikethrough
- [ ] Tap again to uncheck

### Test 4: Edit Checklist Item
- [ ] Tap on a checklist item
- [ ] Edit sheet should appear
- [ ] Modify title or due date
- [ ] Tap "Save"
- [ ] Changes should persist

### Test 5: Checklist Progress
- [ ] Create multiple items
- [ ] Check some items off
- [ ] Progress badge should show "2/5" format
- [ ] Badge color should reflect completion percentage

### Test 6: Soft Delete
- [ ] Items should soft delete (not physically removed)
- [ ] Verify in database that deleted_at is set
- [ ] Deleted items should not appear in UI

### Test 7: Multi-User Sync (After Supabase Integration)
- [ ] Device A: Create checklist item
- [ ] Device B: Refresh/reload event
- [ ] Item should appear on Device B
- [ ] Device B: Check off item
- [ ] Device A: Refresh to see checked state

### Test 8: Recurring Events (Future)
- [ ] Create recurring event with checklist
- [ ] Each occurrence should have independent checklist
- [ ] Verify event_group_id links them

### Test 9: Notifications (Future)
- [ ] Create item with due date different from event
- [ ] Verify notification scheduled 24 hours before
- [ ] Verify notification at due time
- [ ] Check off item - notifications should cancel

---

## Phase 6: Database Verification

### Verify Data in Supabase

```sql
-- Check if checklists are being created
SELECT * FROM public.event_checklists
WHERE deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 10;

-- Check if items are being created
SELECT * FROM public.checklist_items
WHERE deleted_at IS NULL
ORDER BY created_at DESC
LIMIT 10;

-- Verify relationships
SELECT
    ec.event_identifier,
    COUNT(ci.id) as item_count,
    SUM(CASE WHEN ci.completed THEN 1 ELSE 0 END) as completed_count
FROM public.event_checklists ec
LEFT JOIN public.checklist_items ci ON ci.checklist_id = ec.id AND ci.deleted_at IS NULL
WHERE ec.deleted_at IS NULL
GROUP BY ec.event_identifier;
```

---

## Phase 7: Rollback Plan (If Issues)

### If Database Migration Fails:

```sql
-- Drop tables in correct order (items first due to foreign key)
DROP TABLE IF EXISTS public.checklist_items CASCADE;
DROP TABLE IF EXISTS public.event_checklists CASCADE;

-- Drop function if needed
DROP FUNCTION IF EXISTS public.update_modified_at_column() CASCADE;
```

### If App Build Fails:

1. Revert Core Data model changes:
   - Open `FamCal.xcdatamodeld/FamCal.xcdatamodel`
   - Delete `Checklist` entity
   - Delete `ChecklistItem` entity
   - Save model
   - Clean build

2. Comment out new code:
   - Comment out checklist section in `EventDetailView.swift`
   - Remove import statements if needed

### If Runtime Errors:

1. Check console for error messages
2. Verify database migration completed successfully
3. Verify Core Data model matches database schema
4. Clear app data and rebuild:
   ```bash
   # Delete app from simulator
   # Clean build folder
   rm -rf ~/Library/Developer/Xcode/DerivedData/FamCal-*
   ```

---

## Quick Checklist

```
[ ] Phase 1: Database Migration
    [ ] SQL migration executed on Supabase
    [ ] event_checklists table created
    [ ] checklist_items table created
    [ ] RLS enabled and policies created
    [ ] Indexes created
    [ ] Triggers created
    [ ] Verified with SQL queries

[ ] Phase 2: CoreData (Already Done)
    [ ] Checklist entity exists
    [ ] ChecklistItem entity exists
    [ ] Relationships configured

[ ] Phase 3: Code (Partially Done)
    [ ] ChecklistModels.swift exists
    [ ] ChecklistManager.swift exists
    [ ] Checklist views created
    [ ] EventDetailView updated
    [ ] AddEventView updated (TODO)
    [ ] Other views updated (TODO)

[ ] Phase 4: Build
    [ ] Clean build successful
    [ ] No build errors
    [ ] No warnings
    [ ] App launches

[ ] Phase 5: Testing
    [ ] Can view checklist section
    [ ] Can add items
    [ ] Can check/uncheck items
    [ ] Progress shows correctly
    [ ] Soft delete works

[ ] Phase 6: Supabase Sync (TODO)
    [ ] API endpoints implemented
    [ ] Sync methods working
    [ ] Multi-device sync verified

[ ] Phase 7: Advanced Features (TODO)
    [ ] Calendar indicators
    [ ] Notifications integration
    [ ] Recurring events support
```

---

## Expected User Experience

### New Features:
- ✅ View checklists on event detail screen
- ✅ Add checklist items with optional due dates
- ✅ Check off items as completed
- ✅ See progress (3/5 tasks)
- ✅ Edit existing items
- 🔄 Share checklists with family (after Supabase sync)
- 🔄 Get notifications for items with due dates
- 🔄 See checklist indicators in calendar views
- 🔄 Copy checklists to recurring event occurrences

### Data Persistence:
- ✅ Checklists stored in Core Data locally
- 🔄 Synced to Supabase across devices
- ✅ Soft delete preserves history
- ✅ Offline-first (works without internet)

---

## Support

If you encounter issues:

1. Check error messages in Xcode console
2. Review this deployment guide
3. Verify database migration with verification queries
4. Verify Core Data entities exist
5. Check network requests in Charles Proxy or similar
6. Review Supabase logs for API errors

**Key Files for Reference:**
- `Documentation/supabase/migration_event_checklists.sql` - Database schema
- `FamCal/Models/ChecklistModels.swift` - Data models
- `FamCal/Managers/ChecklistManager.swift` - Business logic
- `FamCal/Views/Checklist/` - UI components
- `FamCal.xcdatamodeld/FamCal.xcdatamodel/contents` - Core Data schema

**Implementation Plan:**
- See `~/.claude/plans/wobbly-sprouting-barto.md` for complete feature plan

---

## Next Steps (Post-Deployment)

1. **Implement Supabase Sync:**
   - Add endpoints in `SupabaseManager.swift`
   - Implement sync in `SupabaseDataManager.swift`
   - Test multi-device synchronization

2. **Add to Event Creation:**
   - Update `AddEventView.swift`
   - Support checklist creation during event creation

3. **Calendar View Indicators:**
   - Show ☑️ icon in month view
   - Show progress in day view
   - Update `CalendarView.swift` and `DailyEventsView.swift`

4. **Notifications Integration:**
   - Update `NotificationManager.swift`
   - Include checklist in event notifications
   - Schedule separate notifications for items with due dates

5. **Recurring Events:**
   - Implement "apply to all occurrences" prompt
   - Handle checklist copying across occurrences
   - Update `EditEventView.swift`

6. **Testing & Polish:**
   - Comprehensive testing
   - Performance optimization
   - UI/UX refinements
   - Error handling
