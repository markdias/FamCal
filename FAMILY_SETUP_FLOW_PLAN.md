# Family Setup Flow Implementation Plan

## Overview
Create a comprehensive family setup wizard that appears for all new users (Google, regular email, or guest signup) to guide them through:
1. Creating/naming their family
2. Adding family members and linking calendars
3. Setting up shared calendars
4. Selecting which family member they are in the system

**Excludes:** Invited family members (who already have linked calendars from the inviter)

---

## Core Requirements

### 1. Detect New Users vs Invited Members
- **New User**: No family members exist in CoreData + first authentication
- **Invited Member**: Has family members in CoreData + has a `linked_user_id` on Supabase that matches their current auth user
- **Implementation**: Add flag `hasCompletedFamilySetup` to UserDefaults (similar to `hasCompletedOnboarding`)

### 2. Routing Decision Tree
```
After Successful Authentication (Google, Email, or Guest)
    ↓
Check if hasCompletedFamilySetup (UserDefaults)
    ├─ YES → Go directly to MainTabView
    │
    └─ NO → Check if this is an invited member
        ├─ YES (linked_user_id matches current user) → Go directly to MainTabView
        │
        └─ NO (brand new user) → Show FamilySetupFlow
                                    ↓
                                [Screen 1] Family Name
                                [Screen 2] Add Members (with calendar linking)
                                [Screen 3] Shared Calendars
                                [Screen 4] Select Your Member
                                    ↓
                                Go to MainTabView
```

### 3. Added Data Model Fields
The CoreData model needs one addition:
- Add `isInvited` (Boolean) attribute to FamilyMember to mark members created via invitation
  - Default: NO
  - Invited members: YES
  - Purpose: Helps distinguish how member was added (automatically via invite vs manually via setup)

---

## Screen-by-Screen Implementation

### Screen 1: Family Name Setup
**File**: `FamilyNameSetupView.swift` (NEW)

**UI Elements**:
- Title: "Name Your Family"
- Subtitle: "This helps organize your calendar"
- Text input field for family name
- Submit button (disabled if empty)

**Logic**:
- Stores family name in AppSettingsManager as new property `familyName`
- Next button advances to Screen 2

**Data Changes**:
- AppSettingsManager: Add `@Published var familyName: String = ""` property
- Include in settings sync to Supabase (for consistency across devices)

---

### Screen 2: Add Family Members & Link Calendars
**File**: `AddMembersSetupView.swift` (NEW)

**UI Elements**:
- Title: "Add Family Members"
- Subtitle: "Link their calendars as you add them"
- List of added members with:
  - Member name
  - Color indicator
  - Linked calendar status (✓ or ⚠️)
  - "X" button to remove (during setup only)
- Add Member button (blue)
- Skip button (secondary)
- Next button (only enabled if at least 1 member + at least 1 linked calendar)

**Logic**:
- Displays inline form to add members:
  - Name input field
  - Color picker (9 preset colors)
  - Driver checkbox
  - "Auto-match Calendar" button (searches for matching calendar by name)
  - Calendar linking modal (SelectMemberCalendarsView or simplified version)
  - Save/Cancel buttons
- Reuses `AddFamilyMemberView.swift` logic or creates simplified embedded version
- Creates FamilyMember CoreData records with:
  - `name`: from input
  - `colorHex`: from picker
  - `isDriver`: from checkbox
  - `id`: UUID (auto-generated)
  - `memberCalendars`: linked via FamilyMemberCalendar entities
  - `isInvited`: NO (these are manually added, not invited)

**Validation**:
- At least 1 member required
- At least 1 member must have a linked calendar
- All members require a name

---

### Screen 3: Shared Calendars Setup
**File**: `SharedCalendarsSetupView.swift` (NEW)

**UI Elements**:
- Title: "Shared Calendars"
- Subtitle: "Select calendars everyone in the family can see"
- List of available calendars grouped by source (iCloud, Gmail, Exchange, etc.)
- Checkboxes for selection
- Skip button (secondary)
- Next button

**Logic**:
- Fetches available iOS calendars via CalendarManager
- User selects calendars to share with all members
- Creates SharedCalendar CoreData records for selected calendars
- Links them to ALL existing family members via the many-to-many relationship
- If no calendars selected, that's okay (can be done later in settings)

**Data Changes**:
- Creates SharedCalendar entities with selected calendars
- Links via `members` relationship to each FamilyMember created in Screen 2

---

### Screen 4: Select Your Member
**File**: `SelectYourMemberSetupView.swift` (NEW)

**UI Elements**:
- Title: "Which member are you?"
- Subtitle: "This helps personalize your view"
- Grid or list of member cards showing:
  - Avatar with initials (color from member)
  - Member name
  - "Selected" checkmark overlay when tapped
- Selection is exclusive (one at a time)
- Confirm button

**Logic**:
- User taps to select which family member they represent
- Stores selection in AppSettingsManager as `linkedFamilyMemberId`
- Saves to Supabase AppSettings table for cloud sync
- Advances to final confirmation or MainTabView

**Data Changes**:
- AppSettingsManager: `linkedFamilyMemberId` is already present (no change needed)
- Just use it to track which member was selected

---

### Screen 5: Confirmation / Welcome
**File**: `FamilySetupCompleteView.swift` (NEW) - Optional

**UI Elements**:
- Title: "You're All Set!"
- Family name displayed
- Count: "X members ready"
- Checkmark animation
- Start button → goes to MainTabView

**Logic**:
- Marks setup as complete: `UserDefaults.standard.set(true, forKey: "hasCompletedFamilySetup")`
- Calls `dataManager.syncFamilySetup()` to push all data to Supabase
- Navigates to MainTabView

---

## Implementation Steps

### Phase 1: Data Model & State Management

**1.1 Update CoreData Model**
- [ ] Add `isInvited` (Boolean, default: NO) attribute to FamilyMember entity
- [ ] Increment model version for migration

**1.2 Update AppSettingsManager**
- [ ] Add `@Published var familyName: String = ""`
- [ ] Add `@Published var hasCompletedFamilySetup: Bool = false`
- [ ] Add both to `settingKeys` set for Supabase sync
- [ ] Update init to load from UserDefaults

**1.3 Update SupabaseDataManager**
- [ ] Add `syncFamilySetup()` method to push new family data to cloud
- [ ] Ensure invited member detection logic is in place (checking `linked_user_id`)

---

### Phase 2: Create Setup Flow Screens

**2.1 Create FamilySetupFlow.swift** (Container view)
- Manages navigation between 5 screens
- Tracks current step via enum: `.familyName` → `.addMembers` → `.sharedCalendars` → `.selectMember` → `.complete`
- Handles back/forward navigation
- Persists temporary data in @State during setup

**2.2 Create Individual Screen Views**
- `FamilyNameSetupView.swift` - Family name input
- `AddMembersSetupView.swift` - Member creation with calendar linking
- `SharedCalendarsSetupView.swift` - Select shared calendars
- `SelectYourMemberSetupView.swift` - Pick which member you are
- `FamilySetupCompleteView.swift` - Confirmation screen (optional)

---

### Phase 3: Integration with App Navigation

**3.1 Update FamCalApp.swift**
- After auth success, check:
  1. Is this user an invited member? (check Supabase `linked_user_id` on family members)
  2. Has user completed family setup? (check UserDefaults `hasCompletedFamilySetup`)
- If both NO → show FamilySetupFlow instead of MainTabView
- If either YES → show MainTabView

**3.2 Update OnboardingView.swift** (if needed)
- Family setup flow is NEW, separate from onboarding
- Onboarding (permissions) happens FIRST
- Family setup happens SECOND after authentication
- Both must complete before MainTabView

**3.3 Update LoginView.swift**
- Add "Continue as Guest" button handling
- Guest users still need to complete family setup
- Works same as email/Google signup

---

### Phase 4: Invited Member Detection

**4.1 Add Invited Member Check to SupabaseDataManager**
```swift
func isCurrentUserInvitedMember() async -> Bool {
    // Check if any FamilyMember has linked_user_id == currentUserId
    // Return true if match found, false otherwise
}
```

**4.2 Update FamCalApp.swift Routing**
- Call this check in app init/when auth completes
- Set state variable `needsFamilySetup` based on result
- Skip family setup if user is invited member

---

## Data Flow During Setup

```
User Signs Up / Logs In (Google, Email, or Guest)
    ↓
Auth Success
    ↓
FamCalApp checks: hasCompletedFamilySetup?
    ├─ NO → Check: Is invited member?
    │   ├─ YES → Skip to MainTabView
    │   └─ NO → Show FamilySetupFlow
    │
    └─ YES → Show MainTabView
```

**During Setup (Temporary State)**:
- Screen 1: familyName (appSettingsManager)
- Screen 2: tempMembers: [FamilyMember] (CoreData create)
- Screen 3: tempSharedCalendars: [SharedCalendar] (CoreData create, link to members)
- Screen 4: linkedFamilyMemberId (appSettingsManager)
- Screen 5: Set hasCompletedFamilySetup = true, push to Supabase

---

## Key Design Decisions

1. **No Going Back**: Setup wizard is linear; once complete, can't re-run (but can edit members in Settings)
2. **At Least 1 Calendar**: Require at least 1 member with a linked calendar to prevent empty family
3. **Automatic Shared Linking**: Shared calendars automatically linked to ALL members (consistent with current design)
4. **Guest Support**: Guest mode works same as email/Google (local data only, no Supabase sync on setup)
5. **Backward Compatibility**: Invited members skip setup entirely; existing data structure handles them
6. **Data Persistence**: Setup data persists to CoreData immediately; Supabase sync happens on completion
7. **Member Selection**: User MUST select which member they are before entering main app

---

## Testing Scenarios

1. **New Email Signup** → Onboarding → Family Setup → Main App
2. **New Google Signup** → Onboarding → Family Setup → Main App
3. **New Guest Login** → Onboarding → Family Setup → Main App
4. **Invited Member Email Signup** → Onboarding → Main App (skips family setup)
5. **Invited Member Google Signup** → Onboarding → Main App (skips family setup)
6. **Returning User** → Main App directly (skips onboarding + setup)

---

## Files to Create
1. `FamilySetupFlow.swift` - Container/navigator
2. `FamilyNameSetupView.swift` - Step 1
3. `AddMembersSetupView.swift` - Step 2
4. `SharedCalendarsSetupView.swift` - Step 3
5. `SelectYourMemberSetupView.swift` - Step 4
6. `FamilySetupCompleteView.swift` - Step 5 (optional)

## Files to Modify
1. `FamCalApp.swift` - Routing logic
2. `AppSettingsManager.swift` - Add familyName, hasCompletedFamilySetup
3. `SupabaseDataManager.swift` - Add invited member detection
4. `FamCal.xcdatamodel` - Add isInvited to FamilyMember
5. `LoginView.swift` - Guest mode flow (minimal changes)

---

## Estimated Implementation Size
- **Views**: 5 new files (~800-1000 lines total)
- **Modifications**: 3-4 existing files (~200-300 lines changes)
- **Data Model**: 1 small migration
- **Logic**: Invited member detection, setup completion flag management

