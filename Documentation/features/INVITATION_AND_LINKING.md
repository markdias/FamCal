# Family Member Invitation & Account Linking Documentation

## Overview

FamCal has a comprehensive system for inviting family members and linking their accounts. The flow is split into three main phases:

1. **Invitation Phase**: Creating and sending invitations
2. **Password Setup Phase**: Invited user authenticates and sets a password
3. **Acceptance & Linking Phase**: Account is linked to the family member

---

## Phase 1: Invitation Creation & Email Sending

### Entry Point: Family Settings View
**File:** [FamCal/Views/Settings/FamilySettingsView.swift](FamCal/Views/Settings/FamilySettingsView.swift:385-406)

```swift
// Line 397: Send invitation
try await supabaseManager.createFamilyInvitation(familyMemberId: memberId, inviteeEmail: inviteEmail)
```

**User Flow:**
1. Family manager goes to **Settings > Family**
2. Selects an unlinked family member from the dropdown
3. Enters the member's email address
4. Taps "Send Invite" button
5. Email is sent to the invitee

---

### Swift Client: Create Invitation
**File:** [FamCal/Managers/SupabaseManager.swift:793-820](FamCal/Managers/SupabaseManager.swift:793-820)

```swift
func createFamilyInvitation(familyMemberId: UUID, inviteeEmail: String) async throws {
    // Call /functions/v1/invite-email edge function
    // Passes family_member_id and invitee_email
}
```

**Request:**
- Method: POST
- Endpoint: `functions/v1/invite-email`
- Body: `{ family_member_id: UUID, invitee_email: String }`
- Auth: User's access token (requires family ownership)

---

### Backend: Invite Email Edge Function
**File:** [supabase/functions/invite-email/index.ts](supabase/functions/invite-email/index.ts)

#### Step 1: Create Invitation (Line 62-74)
```typescript
const { data: inv, error: invErr } = await supabaseUser.rpc("create_family_invitation", {
    family_member: family_member_id,
    invitee_email,
});
```

**RPC Function:** `create_family_invitation`
- **Input:** family_member ID, invitee email
- **Output:** Invitation record with token
- **Database:** Creates row in `invitations` table with:
  - `family_member_id`: Links to the family member
  - `invitee_email`: Email address to send to
  - `token`: Secure unique token for acceptance
  - `status`: Set to "pending"
  - `expires_at`: Valid for configured duration

#### Step 2: Send Supabase Auth Invite Email (Line 84-91)
```typescript
const redirectUrl = new URL("famcal://invite");
redirectUrl.searchParams.set("invite_token", inv.token);
redirectUrl.searchParams.set("type", "invite");
redirectUrl.searchParams.set("email", invitee_email);

const { error: emailErr } = await supabaseAdmin.auth.admin.inviteUserByEmail(invitee_email, {
    redirectTo: redirect,
});
```

**What happens:**
- Supabase creates invitation email with magic link
- Link format: `famcal://invite?invite_token=<token>&type=invite&email=<email>`
- User receives email and clicks link

---

## Phase 2: Password Setup

### Deep Link Handling
**File:** [FamCal/FamCalApp.swift:526-643](FamCal/FamCalApp.swift:526-643)

When user clicks the invite link:

```swift
// Line 555-584: Parse deep link
if components.scheme == "famcal" {
    // Extract tokens from URL
    let accessToken = queryItems.first { $0.name == "access_token" }?.value ?? fragmentItems["access_token"]
    let inviteToken = queryItems.first { $0.name == "invite_token" }?.value
    let linkType = fragmentItems["type"] ?? queryItems.first { $0.name == "type" }?.value

    // Authenticate user via magic link
    authManager.applyDeepLinkSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        userId: userId,
        email: email,
        linkType: linkType
    )
}
```

### Password Reset Sheet
**File:** [FamCal/Views/Shared/ResetPasswordSheet.swift](FamCal/Views/Shared/ResetPasswordSheet.swift)

**Display:** After magic link auth, user sees password reset screen with:
- Password validation checklist (10+ chars, uppercase, lowercase, number, special char)
- Real-time visual feedback with green checkmarks
- Auto-fill: Password manager fills both password fields automatically

**On Password Update:**
- Line 165: Callback `onPasswordUpdated?()` is invoked
- File: [FamCal/FamCalApp.swift:304-310](FamCal/FamCalApp.swift:304-310)
  ```swift
  .sheet(isPresented: $showResetPasswordSheet) {
      ResetPasswordSheet(email: resetPasswordEmail, onPasswordUpdated: {
          Task { @MainActor in
              // Force refresh to get latest data
              await dataManager.fetchUserDataIfNeeded(force: true)
              checkFamilySetupNeeded()
          }
      })
  }
  ```

---

## Phase 3: Invitation Acceptance & Account Linking

### Step 1: Accept Invitation via Email
**File:** [FamCal/FamCalApp.swift:600-609](FamCal/FamCalApp.swift:600-609)

```swift
// After user is authenticated
let familyId = try await SupabaseManager.shared.acceptInvitationForCurrentUserEmail()
if let familyId {
    completeFamilySetupForInvitedUser(familyId: familyId)
}
await SupabaseDataManager.shared.fetchUserDataIfNeeded()
```

### Step 2: Accept Invite Backend Function
**File:** [supabase/functions/accept-invite/index.ts](supabase/functions/accept-invite/index.ts)

**Endpoint:** `POST /functions/v1/accept-invite`

#### What It Does:

**1. Find Pending Invitation (Line 64-81)**
```typescript
const { data: invitations } = await supabaseAdmin
    .from("invitations")
    .select("id,family_id,family_member_id,token")
    .eq("invitee_email", email)
    .eq("status", "pending")
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false })
    .limit(1);
```
- Finds most recent pending invitation for the user's email
- Checks it hasn't expired

**2. Create/Update Profile (Line 85-109)**
```typescript
const { error: insertErr } = await supabaseAdmin
    .from("profiles")
    .insert({ id: userId, family_id: invite.family_id, email });

// If profile exists, update it instead
if (insertErr) {
    await supabaseAdmin
        .from("profiles")
        .update({ family_id: invite.family_id, email })
        .eq("id", userId);
}
```
- Creates user profile with their assigned `family_id`
- If profile already exists, updates it with correct family_id
- This is critical for RLS policies

**3. Link Family Member (Line 114-132)**
```typescript
if (invite.family_member_id) {
    const { error: fmErr } = await supabaseAdmin
        .from("family_members")
        .update({ linked_user_id: userId })
        .eq("id", invite.family_member_id);
}
```
- Sets `linked_user_id` on the family_member record
- Links the invited person to their family member entry
- This completes the connection between user account and family member

**4. Mark Invitation Accepted (Line 135-149)**
```typescript
const { data: updatedInv, error: invErr } = await supabaseAdmin
    .from("invitations")
    .update({
        status: "accepted",
        accepted_user_id: userId,
        accepted_at: new Date().toISOString(),
    })
    .eq("id", invite.id);
```
- Updates invitation status to "accepted"
- Records which user accepted it and when
- Prevents re-acceptance of same invitation

**5. Return Family ID (Line 150)**
```typescript
return json({ invitation_id: invite.id, family_id: invite.family_id, status: "accepted" });
```
- Returns family_id to the app for caching

### Step 3: Cache Family ID
**File:** [FamCal/FamCalApp.swift:659-667](FamCal/FamCalApp.swift:659-667)

```swift
private func completeFamilySetupForInvitedUser(familyId: String?) {
    if let familyId {
        appSettingsManager.familyId = familyId
        UserDefaults.standard.set(familyId, forKey: "com.famcal.familyId")
    }
    appSettingsManager.hasCompletedFamilySetup = true
    UserDefaults.standard.set(true, forKey: "hasCompletedFamilySetup")
}
```

- Caches family_id in AppSettingsManager
- Sets flag indicating invited user is setup
- Prevents setup workflow from showing

### Step 4: Fetch Data
**File:** [FamCal/FamCalApp.swift:605-606](FamCal/FamCalApp.swift:605-606)

```swift
await SupabaseDataManager.shared.fetchUserDataIfNeeded()
```

- Force-fetches family members, calendars, and events
- All data loads because user now has proper profile and family_id
- RLS policies allow access

---

## Data Model: Invitation Flow

### Database Tables Involved

#### 1. `invitations` Table
```
id (UUID)
family_id (TEXT) - Which family
family_member_id (UUID) - Which member slot
invitee_email (TEXT) - Invitation target
token (TEXT) - Unique token for acceptance
status (TEXT) - 'pending', 'accepted', 'expired'
created_at (TIMESTAMP)
expires_at (TIMESTAMP)
accepted_user_id (UUID) - User who accepted
accepted_at (TIMESTAMP)
```

#### 2. `family_members` Table
```
id (UUID)
family_id (TEXT) - Parent family
name (TEXT)
color (TEXT)
linked_user_id (UUID) - Connected auth user (NULL = unlinked)
is_invited (BOOLEAN)
...
```

#### 3. `profiles` Table
```
id (UUID) - Same as auth.users.id
family_id (TEXT) - User's family assignment
email (TEXT)
```

#### 4. `auth.users` Table (Supabase Built-in)
```
id (UUID)
email (TEXT)
encrypted_password (TEXT)
confirmed_at (TIMESTAMP)
```

---

## Complete User Journey Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│ STEP 1: INVITE CREATION (Main User's Device)                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. Family Settings → Add Member                                     │
│  2. Select Unlinked Member                                          │
│  3. Enter Email Address                                             │
│  4. Tap "Send Invite"                                               │
│     ↓                                                                │
│     createFamilyInvitation() - Swift Call                           │
│     ↓                                                                │
│     POST /functions/v1/invite-email                                 │
│     ↓                                                                │
│     RPC: create_family_invitation()                                 │
│     ↓                                                                │
│     Insert into invitations table                                   │
│     ↓                                                                │
│     Supabase.auth.admin.inviteUserByEmail()                         │
│     ↓                                                                │
│  5. Email sent with magic link                                      │
│     famcal://invite?invite_token=XXX&type=invite&email=user@ex.com │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ STEP 2: EMAIL & AUTHENTICATION (Invited User's Device)              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. User receives email                                             │
│  2. Clicks magic link                                               │
│     ↓                                                                │
│     Deep link opens FamCal                                          │
│     famcal://invite?access_token=XXX&refresh_token=YYY             │
│     ↓                                                                │
│     handleDeepLink() parses tokens                                  │
│     ↓                                                                │
│     applyDeepLinkSession() authenticates user                       │
│     ↓                                                                │
│  3. User is now authenticated (auth.users record created)           │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ STEP 3: PASSWORD SETUP (Invited User's Device)                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. ResetPasswordSheet displayed                                    │
│  2. User sees password validation checklist                         │
│  3. Password manager auto-fills both password fields                │
│  4. User taps "Update Password"                                     │
│     ↓                                                                │
│     authManager.updatePassword()                                    │
│     ↓                                                                │
│     Password updated in auth.users                                  │
│     ↓                                                                │
│     onPasswordUpdated callback invoked                              │
│     ↓                                                                │
│  5. Sheet dismissed                                                 │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ STEP 4: ACCEPTANCE & LINKING (App Logic)                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  1. After password update, callback runs:                           │
│     - fetchUserDataIfNeeded(force: true)                            │
│     - checkFamilySetupNeeded()                                      │
│     ↓                                                                │
│     acceptInvitationForCurrentUserEmail()                           │
│     ↓                                                                │
│     POST /functions/v1/accept-invite                                │
│     ↓                                                                │
│  2. Backend Edge Function:                                          │
│     - Find pending invitation for user's email                      │
│     - Create/update profile with family_id                          │
│     - Link family_member.linked_user_id = user.id                   │
│     - Mark invitation as accepted                                   │
│     - Return family_id                                              │
│     ↓                                                                │
│  3. App caches family_id:                                           │
│     - AppSettingsManager.familyId = family_id                       │
│     - UserDefaults.set(familyId, ...)                               │
│     - hasCompletedFamilySetup = true                                │
│     ↓                                                                │
│  4. Fetch all data:                                                 │
│     - Family members (now can see linked status)                    │
│     - Shared calendars                                              │
│     - Personal calendars                                            │
│     - Events                                                        │
│     ↓                                                                │
│  5. UI Logic:                                                       │
│     - checkFamilySetupNeeded() returns false                        │
│     - Skip setup workflow                                           │
│     - Show calendar view directly                                   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│ STEP 5: DATA VISIBILITY (Main User's Device)                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  When main user pulls down to refresh:                              │
│                                                                      │
│  1. CalendarView.refreshable → reloadEvents()                       │
│     ↓                                                                │
│     fetchUserDataIfNeeded(force: true)                              │
│     ↓                                                                │
│  2. Fetch Family Members:                                           │
│     - Query family_members for this family                          │
│     - Get all member details                                        │
│     ↓                                                                │
│  3. Populate Linked Emails:                                         │
│     - Call /functions/v1/member-emails                              │
│     - Find all members with linked_user_id != null                  │
│     - Fetch emails from auth.users                                  │
│     ↓                                                                │
│  4. Update UI:                                                      │
│     - FamilySettingsView.memberLinkedEmails dictionary updated      │
│     - Member cards show email address                               │
│     - Display lock icon for linked members                          │
│     - Action buttons change (unlink available, edit disabled)       │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Account Linking: Existing Members

### Scenario: Member who already has a FamCal account links to family

**File:** [FamCal/Views/Settings/AccountSettingsView.swift](FamCal/Views/Settings/AccountSettingsView.swift)

```swift
// User selects unlinked family member to link to their account
// Calls: linkCurrentUserToFamilyMember()
```

**File:** [FamCal/Managers/SupabaseManager.swift:527-544](FamCal/Managers/SupabaseManager.swift:527-544)

```swift
func linkCurrentUserToFamilyMember(id: String, token: String? = nil) async throws {
    // RPC call to link_user_to_family_member
    // Sets family_members.linked_user_id = current_user.id
}
```

---

## Account Unlinking: Remove Account Connection

### Scenario: Unlink a member's account from the family

**File:** [FamCal/Managers/SupabaseManager.swift:579-591](FamCal/Managers/SupabaseManager.swift:579-591)

```swift
func unlinkSpecificMember(memberId: String, token: String? = nil) async throws {
    // RPC call to unlink_user_from_family_member
    // Sets family_members.linked_user_id = NULL
    // User account continues to exist, just no longer linked
}
```

**File:** [FamCal/Views/Settings/EditFamilyMemberView.swift](FamCal/Views/Settings/EditFamilyMemberView.swift:254-264)

```swift
// "Unlink Account" button appears only for linked members
// Shows orange warning button
// Confirmation required before unlinking
```

---

## Email Fetching for Display

### Getting Linked Member Emails

**File:** [supabase/functions/member-emails/index.ts](supabase/functions/member-emails/index.ts)

**Endpoint:** `GET /functions/v1/member-emails`

```typescript
// 1. Resolve user's family_id
// 2. Query family_members for members with linked_user_id != null
// 3. For each linked member, fetch email from auth.users
// 4. Return mapping: { family_member_id, email }
```

**Swift Client:**

**File:** [FamCal/Managers/SupabaseManager.swift:286-311](FamCal/Managers/SupabaseManager.swift:286-311)

```swift
func getMemberEmailsForFamily() async throws -> [MemberEmailDTO] {
    // Calls /functions/v1/member-emails
    // Returns array of {family_member_id, email}
}
```

**Display in UI:**

**File:** [FamCal/Views/Settings/FamilySettingsView.swift:322-336](FamCal/Views/Settings/FamilySettingsView.swift:322-336)

```swift
private func linkedEmail(for member: FamilyMember) -> String? {
    guard let id = member.id else { return nil }
    // Lookup in dataManager.memberLinkedEmails dictionary
    if let email = dataManager.memberLinkedEmails[id] {
        return email
    }
    return nil
}
```

**Display:**

**File:** [FamCal/Views/Settings/FamilySettingsView.swift:544-548](FamCal/Views/Settings/FamilySettingsView.swift:544-548)

```swift
if let email = linkedEmail(for: member) {
    Text(email)
        .font(.system(size: 11))
        .foregroundColor(theme.accentColor)
}
```

---

## Database Constraints & Security

### Row-Level Security (RLS) Policies

**Key Principle:** Users can only see/modify data for their own family

```
profiles table:
  - SELECT: owner can read own profile
  - UPDATE: owner can update own profile

family_members table:
  - SELECT: can see members of own family (via profile.family_id)
  - UPDATE: family owner can update members

invitations table:
  - SELECT/INSERT: can see invitations for own family
  - UPDATE: service role only (backend functions)
```

### Audit Log Considerations

**File:** [supabase/migrations/20251211120000_add_trigger_management_rpcs.sql](supabase/migrations/20251211120000_add_trigger_management_rpcs.sql)

Note: The `accept-invite` function handles audit log constraints when `action_by_user_id` is null (lines 122-126 of accept-invite/index.ts). The database constraint on `family_activity_log` should allow NULL values for `action_by_user_id`.

**Required SQL (if not already applied):**
```sql
ALTER TABLE public.family_activity_log
ALTER COLUMN action_by_user_id DROP NOT NULL;
```

---

## Testing Checklist

### Invitation Flow
- [ ] Family manager can create invitation for unlinked member
- [ ] Invitation email is received with correct magic link
- [ ] Link contains invite_token and email parameters
- [ ] Clicking link opens app and authenticates user

### Password Setup
- [ ] Password validation checklist displays all 5 requirements
- [ ] Checkmarks turn green as requirements are met
- [ ] Password manager auto-fills both password fields
- [ ] User can update password successfully

### Acceptance & Linking
- [ ] Backend creates/updates profile with family_id
- [ ] Backend links family_member.linked_user_id
- [ ] Backend marks invitation as accepted
- [ ] Family_id is cached in AppSettingsManager
- [ ] Setup workflow is skipped

### Data Visibility
- [ ] Invited user sees their family's data immediately
- [ ] Main user pulls down to refresh
- [ ] Newly linked member's email appears in Family Settings
- [ ] Member shows lock icon and linked status
- [ ] Unlink button is available for linked members

### Account Unlinking
- [ ] Unlock confirmation required
- [ ] linked_user_id set to NULL
- [ ] Member becomes "unlinked" state
- [ ] Can be linked again to different account

---

## Troubleshooting

### Issue: Invited user sees setup workflow instead of calendar

**Cause:** `hasCompletedFamilySetup` not being set or family_id not cached

**Solution:** Verify `completeFamilySetupForInvitedUser()` is called and both flags are set:
- `appSettingsManager.hasCompletedFamilySetup = true`
- `appSettingsManager.familyId = familyId`

### Issue: Main user doesn't see newly linked member's email

**Cause:** Pull-to-refresh not fetching latest data

**Solution:** Force refresh with `fetchUserDataIfNeeded(force: true)` to bypass cache

### Issue: Audit log constraint error on linking

**Cause:** family_activity_log has NOT NULL constraint on action_by_user_id

**Solution:** Run migration to allow NULL:
```sql
ALTER TABLE public.family_activity_log
ALTER COLUMN action_by_user_id DROP NOT NULL;
```

### Issue: Profile not created for invited user

**Cause:** accept-invite function didn't run or failed silently

**Solution:** Check Supabase function logs. Verify profiles table insert/update logic in accept-invite/index.ts

---

## Related Files Summary

| File | Purpose |
|------|---------|
| [FamCal/Views/Settings/FamilySettingsView.swift](FamCal/Views/Settings/FamilySettingsView.swift) | UI for inviting members, viewing linked status, managing invitations |
| [FamCal/Views/Shared/ResetPasswordSheet.swift](FamCal/Views/Shared/ResetPasswordSheet.swift) | Password setup screen with validation checklist |
| [FamCal/FamCalApp.swift](FamCal/FamCalApp.swift) | Deep link handling, invitation acceptance, setup workflow logic |
| [FamCal/Managers/SupabaseManager.swift](FamCal/Managers/SupabaseManager.swift) | Swift API client for all invitation/linking functions |
| [FamCal/Managers/SupabaseDataManager.swift](FamCal/Managers/SupabaseDataManager.swift) | Data fetching and caching, email population |
| [supabase/functions/invite-email/index.ts](supabase/functions/invite-email/index.ts) | Send invitation email with magic link |
| [supabase/functions/accept-invite/index.ts](supabase/functions/accept-invite/index.ts) | Accept invitation, link account, create profile |
| [supabase/functions/member-emails/index.ts](supabase/functions/member-emails/index.ts) | Fetch emails for linked members |

---

## Key Design Decisions

### Why 3-Phase Flow?
1. **Invitation Phase**: Creates invitation slot before user has account
2. **Password Setup Phase**: User authenticates via magic link and sets password
3. **Linking Phase**: Account is linked to pre-created family member slot

### Why Cache Family ID?
- Prevents "no family found" errors on first load
- Improves offline experience
- Reduces database queries for family resolution

### Why Force Refresh After Password?
- Ensures data is fresh after authentication
- Bypasses cache timestamp checks
- Guarantees user sees current family state

### Why Member Emails Fetched Separately?
- Decouples member data from auth.users data
- Allows flexible display of linked email status
- Supports RLS policies (service role needed to read auth.users)

---

## Future Improvements

- [ ] Resend invitation functionality for expired invitations
- [ ] Batch invite multiple members at once
- [ ] Invite management UI (view pending, resend, revoke)
- [ ] Account linking requests (member requests to link existing account)
- [ ] Audit logging of invitation events
- [ ] Notifications when invitation is accepted

