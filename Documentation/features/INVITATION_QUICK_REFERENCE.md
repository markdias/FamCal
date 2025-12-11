# FamCal Invitation System - Quick Reference Guide

## File Locations

### Frontend (SwiftUI)

| File | Purpose | Key Lines |
|------|---------|-----------|
| **FamCalApp.swift** | Deep link handling, setup workflow logic | 526-643, 304-310, 659-667 |
| **FamilySettingsView.swift** | Invite UI, member management | 385-406, 322-336, 544-548 |
| **ResetPasswordSheet.swift** | Password setup with validation | 37-109, 165 |
| **AccountSettingsView.swift** | Link accounts to family members | 134 |
| **EditFamilyMemberView.swift** | Edit and unlink members | 66-70, 73-86, 254-264 |
| **AccountDeletionView.swift** | Show linked account warnings | 295-298, 104-113 |

### Backend (Swift Managers)

| File | Purpose | Key Methods |
|------|---------|------------|
| **SupabaseManager.swift** | API calls for invitation/linking | createFamilyInvitation (793), acceptInvitationForCurrentUserEmail (849), getMemberEmailsForFamily (286), linkCurrentUserToFamilyMember (527), unlinkSpecificMember (579) |
| **SupabaseDataManager.swift** | Data fetching & caching | fetchFamilyMembers (375), populateMemberEmails (803), fetchUserDataIfNeeded (160) |
| **SupabaseAuthManager.swift** | Authentication | applyDeepLinkSession, updatePassword |

### Supabase Edge Functions

| Function | Endpoint | Purpose |
|----------|----------|---------|
| **invite-email** | POST /functions/v1/invite-email | Create invitation, send email |
| **accept-invite** | POST /functions/v1/accept-invite | Accept invitation, link account, create profile |
| **member-emails** | GET /functions/v1/member-emails | Fetch linked member emails |

### Database

| Table | Key Columns | Purpose |
|-------|------------|---------|
| **invitations** | id, family_id, family_member_id, invitee_email, token, status, expires_at, accepted_user_id, accepted_at | Track invitation lifecycle |
| **family_members** | id, family_id, linked_user_id, name | Family member slots, account linking |
| **profiles** | id, family_id, email | User profile with family assignment |
| **auth.users** | id, email, password | Supabase authentication records |

---

## Key Concepts

### Three-Phase System

1. **Invitation Phase**: Create invite → Send email → User receives magic link
2. **Password Setup Phase**: User clicks link → Authenticates → Sets password
3. **Acceptance Phase**: Profile created → Account linked → Family data fetched

### Family Member States

```
UNLINKED (linked_user_id IS NULL)
├─ Can be invited
├─ Can be edited
├─ Can be deleted
└─ Shows edit/driver/calendar/delete buttons

LINKED (linked_user_id IS NOT NULL)
├─ Has associated user account
├─ Shows email address
├─ Can be unlinked
└─ Shows lock/driver/calendar buttons (edit disabled, delete disabled)
```

### Data Flow During Invitation

```
Invite Sent
  ↓ (email + magic link)
User Clicks Link
  ↓ (auth tokens received)
FamCalApp Deep Link Handler
  ↓ (tokens processed)
User Authenticated
  ↓ (password reset shown)
Password Set
  ↓ (callback executes)
acceptInvitationForCurrentUserEmail()
  ├─ Create/update profile
  ├─ Set linked_user_id
  ├─ Mark invitation accepted
  └─ Cache family_id
    ↓
Data Fetched
  ├─ Family members
  ├─ Linked emails
  ├─ Calendars
  └─ Events
    ↓
Calendar View Shown (Setup Skipped)
```

---

## Common Tasks

### Send an Invitation

**Location:** Family Settings → Select Member → Enter Email → Send Invite

**Code Flow:**
```swift
// FamilySettingsView.swift:397
try await supabaseManager.createFamilyInvitation(
    familyMemberId: memberId,
    inviteeEmail: inviteEmail
)
```

**What Happens:**
1. Calls `/functions/v1/invite-email` edge function
2. Backend creates invitation record in DB
3. Supabase sends email with magic link
4. User receives `famcal://invite?invite_token=XXX&type=invite`

---

### Handle Invitation (Invited User)

**Triggered By:** User clicks email link

**Code Flow:**
```swift
// FamCalApp.swift:526
handleDeepLink(_ url: URL) {
    // Parse famcal://invite?invite_token=XXX
    // Extract tokens and authenticate
    authManager.applyDeepLinkSession(...)

    // Show password reset
    showResetPasswordSheet = true

    // After password update:
    onPasswordUpdated: {
        await dataManager.fetchUserDataIfNeeded(force: true)
        checkFamilySetupNeeded()
    }
}
```

**What Happens:**
1. Deep link parsed
2. User authenticated via tokens
3. Password reset sheet shown
4. Password updated
5. `accept-invite` edge function called automatically
6. Profile created, account linked
7. Family data fetched
8. Calendar shown (setup skipped)

---

### Fetch Linked Member Emails

**Manual Trigger:** Pull down to refresh on calendar

**Code Flow:**
```swift
// CalendarView.swift:190
.refreshable {
    await reloadEvents()  // Calls fetchUserDataIfNeeded(force: true)
}

// SupabaseDataManager.swift:375
func fetchFamilyMembers() {
    // ... fetch members ...
    await populateMemberEmails(from: familyMembers)
}

// SupabaseDataManager.swift:803
func populateMemberEmails() {
    let emails = try await supabaseManager.getMemberEmailsForFamily()
    memberLinkedEmails = map  // @Published, triggers UI update
}
```

**What Happens:**
1. User pulls down on calendar
2. Force refresh initiated
3. Family members fetched
4. `member-emails` edge function called
5. Backend finds members with `linked_user_id != null`
6. Email fetched from auth.users for each linked member
7. Dictionary updated: `[UUID: String]`
8. SwiftUI views automatically refresh
9. Email shows in Family Settings view

---

### Link Account to Family Member

**Location:** Settings → Account → Select Member → Link

**Code Flow:**
```swift
// SupabaseManager.swift:527
func linkCurrentUserToFamilyMember(id: String) async throws {
    // RPC: link_user_to_family_member
    // Sets family_members.linked_user_id = current_user.id
}
```

---

### Unlink Account from Family Member

**Location:** Family Settings → Locked Member → Tap Lock → Confirm

**Code Flow:**
```swift
// SupabaseManager.swift:579
func unlinkSpecificMember(memberId: String) async throws {
    // RPC: unlink_user_from_family_member
    // Sets family_members.linked_user_id = NULL
}
```

---

## Important State Variables

### AppSettingsManager

```swift
@Published var hasCompletedFamilySetup: Bool = false
// Set to true after invitation accepted
// If false, setup workflow is shown instead of calendar

@Published var familyId: String?
// Cached from invitation acceptance
// Used as backup if profile query fails

@Published var linkedFamilyMemberId: UUID?
// Which family member is linked to current user's account
```

### SupabaseDataManager

```swift
@Published var familyMembers: [FamilyMemberDTO] = []
// Array of family members with linked_user_id

@Published var memberLinkedEmails: [UUID: String] = [:]
// Maps family_member.id → user's email
// Populated from member-emails edge function
// Used to display emails in Family Settings
```

### SupabaseAuthManager

```swift
@Published var isLoggedIn: Bool = false
// Set after deep link authentication

@Published var userId: String?
// User's auth.users.id

@Published var userEmail: String?
// User's email
```

---

## URL Schemes

### Invitation Link (From Email)

```
famcal://invite?invite_token=<JWT>&type=invite&email=<email>
```

- `invite_token`: Created by invitation RPC
- `type`: "invite" to trigger password reset
- `email`: Invited email address

### Authentication Redirect (From Supabase)

```
famcal://auth/confirm?access_token=<JWT>&refresh_token=<JWT>&type=invite&email=<email>
```

- `access_token`: Session token
- `refresh_token`: Token for refreshing session
- `type`: "invite" or "recovery"
- `email`: User's email

---

## Edge Function Responses

### invite-email Success

```json
{
  "invitation_id": "abc-123-def",
  "status": "sent"
}
```

### accept-invite Success

```json
{
  "invitation_id": "abc-123-def",
  "family_id": "fam-456-ghi",
  "status": "accepted"
}
```

### member-emails Success

```json
{
  "emails": [
    {
      "family_member_id": "member-1",
      "email": "user1@example.com"
    },
    {
      "family_member_id": "member-2",
      "email": "user2@example.com"
    }
  ]
}
```

---

## Error Messages Users See

| Error | Cause | Solution |
|-------|-------|----------|
| "Select a member to invite." | No member selected | Choose member from dropdown |
| "Enter an email address." | Email field empty | Type email address |
| "Invite sent to [email]" | Success | Email sent |
| "Failed to send invite: [error]" | Various backend issues | Check permissions, email validity |
| "Passwords must match." | Confirm doesn't match | Re-enter both passwords |
| "Password could not be updated. Please choose a different one." | Same password as before | Use new password |
| "Password could not be updated. Please try again." | Network or service error | Retry |

---

## Debugging Checklist

### User Invited but Didn't Receive Email
- [ ] Check Supabase email logs
- [ ] Verify invitee_email is correct
- [ ] Check spam folder
- [ ] Verify SMTP is configured in Supabase

### Invited User Sees Setup Workflow Instead of Calendar
- [ ] Check if `hasCompletedFamilySetup` is true
- [ ] Check if `familyId` is cached
- [ ] Verify `completeFamilySetupForInvitedUser()` was called
- [ ] Check UserDefaults for these keys

### Invited User's Email Not Showing in Main User's View
- [ ] Pull down to refresh (force fetch)
- [ ] Check `memberLinkedEmails` dictionary is populated
- [ ] Verify `member-emails` edge function is deployed
- [ ] Check `family_members.linked_user_id` is set
- [ ] Check auth.users record exists for linked user

### Audit Log Constraint Error on Linking
- [ ] Check Supabase function logs for error 23502
- [ ] Verify `family_activity_log.action_by_user_id` allows NULL
- [ ] Run migration to fix: `ALTER TABLE family_activity_log ALTER COLUMN action_by_user_id DROP NOT NULL;`

### Deep Link Not Opening App
- [ ] Verify URL scheme registered in Xcode
- [ ] Check Info.plist has famcal:// scheme
- [ ] Test in physical device (simulators sometimes have issues)
- [ ] Check Supabase redirect URL matches scheme

---

## Related Documentation

- **INVITE_AND_LINK_DOCUMENTATION.md**: Complete flow documentation with code
- **INVITE_ARCHITECTURE.md**: System architecture, diagrams, error handling
- **FamCal Codebase**: See file locations section above

---

## Quick Fixes

### "Family not found" Error

**Cause:** Profile not created with correct family_id

**Fix:** Run this manually in accept-invite function (should be automatic):
```typescript
const { error } = await supabaseAdmin
    .from("profiles")
    .insert({ id: userId, family_id: invite.family_id, email })
    .select()
    .single();

if (error) {
    // Profile exists, update instead
    await supabaseAdmin
        .from("profiles")
        .update({ family_id: invite.family_id, email })
        .eq("id", userId);
}
```

### Member Email Not Updating

**Cause:** Cache not invalidated

**Fix:**
```swift
// In SupabaseDataManager
memberLinkedEmails.removeAll()  // Clear cache
await populateMemberEmails(from: familyMembers)  // Re-fetch
```

### Setup Workflow Appears Instead of Calendar

**Cause:** Setup flag not set

**Fix:**
```swift
// In FamCalApp
appSettingsManager.hasCompletedFamilySetup = true
UserDefaults.standard.set(true, forKey: "hasCompletedFamilySetup")
checkFamilySetupNeeded()  // Force re-check
```

---

## Performance Tips

1. **Cache Family ID**: Prevents "family not found" on each launch
2. **Force Refresh After Password**: Ensures data is fresh from backend
3. **Batch Email Fetches**: member-emails gets all emails in one call
4. **Parallel Fetches**: Calendars fetched in parallel after members
5. **Skip Setup if Invited**: Prevents unnecessary workflow screens

---

## Security Notes

- Invitation tokens are secure JWTs with expiration
- Email must match invitee_email to accept invitation
- RLS policies prevent cross-family access
- Service role required for auth.users queries
- Deep links are app-specific (famcal:// scheme)
- Passwords validated on backend (Supabase)

