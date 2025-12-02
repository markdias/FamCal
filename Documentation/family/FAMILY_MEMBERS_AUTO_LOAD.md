# Automatic Family Member Loading

## How It Works

When you log in to the app, family members that already exist in the Supabase database are automatically loaded. You should NOT need to add them again.

## The Data Flow

```
User logs in
    ↓
FamCalApp shows MainTabView
    ↓
MainTabView calls: dataManager.setManagedObjectContext()
    ↓
Data manager detects user is authenticated
    ↓
Calls: fetchUserData()
    ↓
Queries Supabase: GET /rest/v1/family_members?user_id=eq.{userId}
    ↓
Gets family members array from Supabase
    ↓
Syncs data to CoreData via SupabaseDataSync
    ↓
FamilySettingsView's @FetchRequest detects CoreData changes
    ↓
View updates and displays family members ✅
```

## How to Verify It's Working

### Check 1: Xcode Console Logging

When you log in and navigate to Family Members, check the Xcode console (Cmd+Shift+Y):

You should see:

```
ℹ️ Setting CoreData context, now fetching user data...
ℹ️ User is authenticated, fetching user data now...
ℹ️ Starting data fetch for user: 1093a943-...
ℹ️ Fetching family members from Supabase...
✅ Fetched 2 family members from Supabase
✅ Fetched 0 family member calendars from Supabase
✅ Fetched 0 shared calendars from Supabase
ℹ️ Syncing data to CoreData...
✅ Synced 2 family members from Supabase to CoreData
✅ Data fetch complete: 2 family members and 0 shared calendars
```

**What this tells you**:
- ✅ Context was set
- ✅ Data fetch was initiated
- ✅ Supabase returned 2 family members
- ✅ Data was synced to CoreData

### Check 2: Family Members Screen

1. Log in
2. Tap Settings (gear icon)
3. Tap "Family Members"
4. You should see all your family members listed

**If members appear**: Great! The automatic loading is working ✅

**If members don't appear**: See troubleshooting section below

## Troubleshooting

### Problem: Family members don't appear on the screen

**Step 1: Check the console logs**
1. Open Xcode console (Cmd+Shift+Y)
2. Log in again
3. Look for error messages
4. Common errors:

```
❌ Error fetching user data: ...
```

This means the fetch failed. Check the error details.

**Step 2: Verify family members exist in Supabase**
1. Go to https://app.supabase.com
2. Open your project (tzkspidmzlipujsnxpzc)
3. Click: **SQL Editor**
4. Run query:
```sql
SELECT id, user_id, name FROM family_members WHERE user_id = 'YOUR_USER_ID';
```

Replace `YOUR_USER_ID` with your actual user ID from the console logs.

If no rows appear, the members don't exist in the database yet.

**Step 3: Check if userId is nil**
In the console, look for:
```
❌ Cannot fetch data: User ID is nil
```

If you see this, the app doesn't have your user ID. This could mean:
- Email confirmation didn't properly set the userId
- Session wasn't restored properly
- User logged in but userId wasn't extracted

**Step 4: Manually add a family member**
If members aren't loading:
1. Tap: Add Family Member (+)
2. Enter a name: "Test Member"
3. Select a color
4. Save

This creates a new member. Then:
1. Go back to Family Members list
2. You should see "Test Member" listed

If the manually-added member appears, the sync to CoreData is working. The issue is with fetching existing members.

## What Should Happen

### Scenario 1: Fresh Login After Email Confirmation

1. User clicks email confirmation link
2. iOS opens FamCal app with `famcal://auth/confirm?access_token=...`
3. User is automatically logged in
4. MainTabView appears
5. DataManager fetches family members from Supabase
6. Family members appear on the Family Members screen

### Scenario 2: Returning User With Persistent Session

1. App launches
2. Session is restored from UserDefaults (user is still logged in)
3. MainTabView appears
4. DataManager fetches family members from Supabase
5. Family members appear on the Family Members screen

### Scenario 3: Adding a New Family Member

1. User is on Family Members screen
2. Taps: Add Family Member
3. Enters name and selects color
4. Taps: Save
5. Member is created in Supabase
6. Data is fetched from Supabase
7. Family members list updates
8. New member appears ✅

## Technical Details

### Files Involved

**Data Loading**:
- `FamCal/SupabaseDataManager.swift` - Orchestrates data fetching
- `FamCal/SupabaseManager.swift` - Makes REST API calls to Supabase
- `FamCal/SupabaseDataSync.swift` - Syncs Supabase data to CoreData

**Data Display**:
- `FamCal/FamilySettingsView.swift` - Uses @FetchRequest to display members from CoreData
- `FamCal/SettingsView.swift` - Opens FamilySettingsView

**Authentication**:
- `FamCal/SupabaseAuthManager.swift` - Manages user login/logout and session
- `FamCal/FamCalApp.swift` - Handles deep links and navigation

### Key Properties

**SupabaseDataManager**:
```swift
@Published var familyMembers: [FamilyMemberDTO] = []  // From Supabase
var managedObjectContext: NSManagedObjectContext?     // Set by FamCalApp
```

**FamilySettingsView**:
```swift
@FetchRequest(
    entity: FamilyMember.entity(),
    sortDescriptors: [...]
)
private var familyMembers: FetchedResults<FamilyMember>  // From CoreData
```

### Fetch Triggers

The app fetches family members in these situations:

1. **On Login**: When user enters email/password
2. **On Email Confirmation**: When user clicks email confirmation link
3. **On App Startup** (if logged in): When user was already logged in and opens app
4. **When CoreData Context is Set**: Always attempts fetch when context becomes available
5. **After Family Member Changes**: When user creates/edits/deletes members

## Expected Console Output Timeline

When a fresh user logs in, you should see this sequence in the console:

```
ℹ️ Session check initialized
ℹ️ Checking for existing session...
ℹ️ No existing session found - user will need to log in
ℹ️ Sign-in request: POST https://tzkspidmzlipujsnxpzc.supabase.co/auth/v1/token?grant_type=password
ℹ️ Response status: 200
ℹ️ Raw response: {"access_token":"eyJ...","user":{"id":"...",...}}
✅ User signed in successfully: mark@mdias.co.uk
ℹ️ Session saved to persistent storage
ℹ️ Setting CoreData context, now fetching user data...
ℹ️ User is authenticated, fetching user data now...
ℹ️ Starting data fetch for user: 1093a943-...
ℹ️ Fetching family members from Supabase...
✅ Fetched 2 family members from Supabase
✅ Fetched 0 family member calendars from Supabase
✅ Fetched 0 shared calendars from Supabase
ℹ️ Syncing data to CoreData...
✅ Synced 2 family members from Supabase to CoreData
✅ Data fetch complete: 2 family members and 0 shared calendars
```

This shows the entire flow from login to family members loading.

## Summary

**Automatic family member loading is fully implemented:**
- ✅ Data manager fetches from Supabase on login
- ✅ Data is synced to CoreData automatically
- ✅ UI updates when CoreData changes
- ✅ Works on app startup if user is logged in
- ✅ Works after email confirmation login
- ✅ Detailed logging to help debug issues

**You should not need to manually add family members if they already exist in Supabase!**

If they're not appearing, check the Xcode console logs for error messages and follow the troubleshooting steps above.
