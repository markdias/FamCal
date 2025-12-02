# Quick Start: Complete the Migration

## ✅ What's Already Done

All Swift code updates are complete:
- ✅ SupabaseManager.swift updated
- ✅ SupabaseDataSync.swift updated
- ✅ SupabaseDataManager.swift updated
- ✅ FamCalApp.swift updated

## 🚀 What You Need to Do Now (2 Steps)

### Step 1: Run the SQL Migration (5 minutes)

1. Open Supabase Dashboard: https://app.supabase.com
2. Go to: **SQL Editor** (left sidebar)
3. Click: **New Query**
4. Copy ALL text from: **`supabase_remove_calendar_id.sql`** (current dedup script)
5. Paste into the editor
6. Click: **Run** button (green play icon)

**Expected result:**
```
Query succeeded
```

If you see errors, message me with the error text.

### Step 2: Update CoreData Model (5 minutes)

1. Open Xcode: `FamCal.xcworkspace`
2. Navigate to: `FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel`
3. Double-click to open
4. Select entity: `FamilyMemberCalendar`
5. Find attribute: `calendarID`
6. Delete it (press Delete key)
7. Repeat for:
   - `SharedCalendar` entity
   - `PersonalCalendar` entity
   - `FamilyEvent` entity (if it has `calendarID`)
8. Save: **Command+S**

## ✨ That's It!

- [ ] SQL migration ran successfully
- [ ] CoreData model updated
- [ ] Ready to test

## 🧪 Testing

```bash
# In Xcode:
1. Product → Clean Build Folder (Command+Shift+K)
2. Product → Build (Command+B)
3. Product → Run (Command+R)
```

**Test these:**
- [ ] App launches
- [ ] Login works
- [ ] Family members appear
- [ ] Calendars load
- [ ] No console errors

---

## 📝 Documentation

If you need details:
- **Why it failed?** → Read `MIGRATION_ISSUE_RESOLVED.md`
- **What changed?** → Read `REFACTOR_COMPLETE.md`
- **Detailed steps?** → Read `DEPLOYMENT_STEPS.md`
- **SQL comparison?** → Read `SQL_MIGRATION_COMPARISON.md`

---

## ❓ Need Help?

If migration fails:
1. Check the error message
2. Run this query to see duplicates:
   ```sql
   SELECT family_member_id, calendar_name, COUNT(*) as count
   FROM public.family_member_calendars
   GROUP BY family_member_id, calendar_name
   HAVING COUNT(*) > 1;
   ```
3. Message me with results

## ✅ Completion Checklist

```
Database:
  [ ] Canonical dedup migration (`supabase_remove_calendar_id.sql`) executed successfully
  [ ] No calendar_id column in any table
  [ ] Unique constraints created

CoreData:
  [ ] calendarID removed from FamilyMemberCalendar
  [ ] calendarID removed from SharedCalendar
  [ ] calendarID removed from PersonalCalendar
  [ ] calendarID removed from FamilyEvent
  [ ] Model saved

App:
  [ ] Builds without errors
  [ ] Builds without warnings
  [ ] Launches successfully
  [ ] Login works
  [ ] Family members display
  [ ] Calendars load
  [ ] No console errors
```

---

**Status:** 99% complete. Just need those 2 steps above!
