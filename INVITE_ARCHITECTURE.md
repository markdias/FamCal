# FamCal Invitation & Linking Architecture

## System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FamCal Application                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ UI Layer (SwiftUI)                                                │  │
│  │                                                                   │  │
│  │  FamilySettingsView ──► Invite Member Form                       │  │
│  │  ResetPasswordSheet ──► Password Validation                      │  │
│  │  EditFamilyMemberView ──► Link/Unlink UI                        │  │
│  │  FamCalApp ──► Deep Link Handling                               │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                            │                                           │
│                            ▼                                           │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │ Business Logic (Swift Managers)                                   │  │
│  │                                                                   │  │
│  │  SupabaseManager                                                  │  │
│  │    ├─ createFamilyInvitation()                                   │  │
│  │    ├─ acceptInvitationForCurrentUserEmail()                      │  │
│  │    ├─ getMemberEmailsForFamily()                                 │  │
│  │    ├─ linkCurrentUserToFamilyMember()                            │  │
│  │    ├─ unlinkSpecificMember()                                     │  │
│  │    └─ getFamilyMembers()                                         │  │
│  │                                                                   │  │
│  │  SupabaseDataManager                                              │  │
│  │    ├─ fetchFamilyMembers()                                       │  │
│  │    ├─ populateMemberEmails()                                     │  │
│  │    └─ fetchUserDataIfNeeded(force:)                              │  │
│  │                                                                   │  │
│  │  SupabaseAuthManager                                              │  │
│  │    ├─ applyDeepLinkSession()                                     │  │
│  │    ├─ updatePassword()                                           │  │
│  │    └─ Session Management                                         │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                            │                                           │
└────────────────────────────┼───────────────────────────────────────────┘
                             │
                             ▼
         ┌───────────────────────────────────────┐
         │  Supabase API Client (supabase-js)    │
         │                                       │
         │  HTTP Requests to:                    │
         │  - Edge Functions                     │
         │  - PostgREST API                      │
         │  - Auth API                           │
         └───────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
    ┌─────────┐        ┌─────────────┐      ┌──────────┐
    │ Edge    │        │ PostgREST   │      │ Auth API │
    │Functions│        │ API         │      │          │
    └─────────┘        └─────────────┘      └──────────┘
        │                    │                    │
        │                    ▼                    │
        │           ┌─────────────────┐          │
        │           │   Database      │          │
        │           │   (PostgreSQL)  │          │
        │           └─────────────────┘          │
        │                    │                    │
        └────────────────────┼────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        │                    │                    │
        ▼                    ▼                    ▼
    ┌─────────┐        ┌──────────┐         ┌───────────┐
    │invitations   │        │family_members│         │auth.users  │
    │              │        │              │         │            │
    │ id           │        │ id           │         │ id         │
    │family_id     │        │family_id     │         │email       │
    │family_member_id       │linked_user_id◄──┐      │password    │
    │invitee_email │        │name          │    │      │           │
    │token         │        │              │    │      │           │
    │status        │        └──────────────┘    │      └───────────┘
    │expires_at    │                           │
    │accepted_at   │                           │
    │              │                           │
    │              ├───────────────────────────┘
    └─────────────┘

```

---

## Database Schema Relationships

### Invitation Flow Data Model

```
Invitations Table
┌─────────────────────────────────────┐
│ id (UUID)                           │  ◄─── Unique invitation record
│ family_id (TEXT) ───────────────┐   │
│ family_member_id (UUID) ─────┐  │   │
│ invitee_email (TEXT)         │  │   │
│ token (TEXT)                 │  │   │
│ status ('pending'/'accepted')│  │   │
│ expires_at (TIMESTAMP)       │  │   │
│ accepted_user_id (UUID) ──┐  │  │   │
│ accepted_at (TIMESTAMP)   │  │  │   │
└──────────────────────────┼──┼──┼───┘
                           │  │  │
                           │  │  └───────────────┐
                           │  │                  ▼
                           │  │      ┌─────────────────────────┐
                           │  │      │ Family Members Table    │
                           │  │      │                         │
                           │  │      │ id (UUID)               │
                           │  └──────┤ family_id (TEXT)        │
                           │         │ linked_user_id ◄────┐   │
                           │         │ (UUID, nullable)    │   │
                           │         │ name (TEXT)         │   │
                           │         │ color (TEXT)        │   │
                           │         │ is_invited (BOOL)   │   │
                           │         └─────────────────────┘   │
                           │                                   │
                           │         ┌──────────────────────┐  │
                           │         │ Auth Users Table     │  │
                           │         │                      │  │
                           │         │ id (UUID)            │  │
                           └────────►│ email (TEXT)         │  │
                                     │ password (encrypted) │  │
                                     │ confirmed_at         │  │
                                     └──────────────────────┘  │
                                                                │
                    ┌───────────────────────────────────────────┘
                    │
                    ▼
        ┌─────────────────────────┐
        │ Profiles Table          │
        │                         │
        │ id (UUID) ◄─────────────┤ (Same as auth.users.id)
        │ family_id (TEXT)        │
        │ email (TEXT)            │
        └─────────────────────────┘
```

### Linking Relationships

```
When invitation is ACCEPTED:

Invitations
  ├─ family_id = "fam-123"
  ├─ family_member_id = "member-456"
  ├─ invitee_email = "user@example.com"
  └─ accepted_user_id = "user-789"
       │
       ├──────────────────────────┐
       │                          │
       ▼                          ▼
  Family Members          Profiles
  ├─ id = "member-456"    ├─ id = "user-789"
  ├─ family_id = "fam-123"├─ family_id = "fam-123"
  └─ linked_user_id ────┐ └─ email = "user@example.com"
       "user-789" ◄──────┘
           │
           ▼
      Auth Users
      ├─ id = "user-789"
      └─ email = "user@example.com"
```

---

## API Flow Diagrams

### 1. CREATE INVITATION FLOW

```
┌─────────────────────────────────────────────────────────┐
│ INVITE CREATION FLOW                                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ FamilySettingsView                                      │
│ ├─ User selects unlinked family member                 │
│ ├─ User enters invitee email                           │
│ └─ Taps "Send Invite"                                  │
│    │                                                    │
│    ▼                                                    │
│ sendInvitation() {                                      │
│    await supabaseManager.createFamilyInvitation(       │
│       familyMemberId: UUID,                            │
│       inviteeEmail: String                             │
│    )                                                    │
│ }                                                       │
│    │                                                    │
│    ▼                                                    │
│ ┌──────────────────────────────────────────────────┐   │
│ │ HTTP POST /functions/v1/invite-email             │   │
│ │                                                  │   │
│ │ Headers:                                         │   │
│ │   Authorization: Bearer <access_token>           │   │
│ │   x-invite-fn-key: <function_key>                │   │
│ │                                                  │   │
│ │ Body:                                            │   │
│ │ {                                                │   │
│ │   "family_member_id": "abc-123",                 │   │
│ │   "invitee_email": "user@example.com"            │   │
│ │ }                                                │   │
│ └──────────────────────────────────────────────────┘   │
│    │                                                    │
│    ▼                                                    │
│ BACKEND: invite-email/index.ts                         │
│ ├─ Authenticate user via Authorization header          │
│ ├─ Extract family_member_id and invitee_email         │
│ ├─ RPC: create_family_invitation()                     │
│ │  ├─ Create invitation record                         │
│ │  ├─ Generate secure token                           │
│ │  ├─ Set status = "pending"                          │
│ │  └─ Set expires_at = now + 7 days                   │
│ ├─ Supabase.auth.admin.inviteUserByEmail()            │
│ │  ├─ Create email invitation                         │
│ │  ├─ Generate magic link with token                  │
│ │  ├─ Send Supabase invite email template             │
│ │  └─ Include: famcal://invite?token=XXX              │
│ └─ Return { invitation_id, status: "sent" }           │
│    │                                                    │
│    ▼                                                    │
│ EMAIL SENT                                              │
│ ├─ From: Supabase Auth System                          │
│ ├─ To: invitee_email                                   │
│ ├─ Subject: [Supabase] Confirm your email              │
│ ├─ Body: Contains magic link                           │
│ └─ Link: famcal://invite?invite_token=XXX             │
│       &type=invite&email=user@example.com              │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 2. DEEP LINK & AUTHENTICATION FLOW

```
┌─────────────────────────────────────────────────────────┐
│ DEEP LINK & AUTHENTICATION FLOW                         │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ 1. User clicks email link                              │
│    URL: famcal://invite?invite_token=XXX              │
│                                                         │
│    ▼                                                    │
│                                                         │
│ 2. FamCalApp.onOpenURL(_:)                             │
│    ├─ Triggered by OS with URL                         │
│    ├─ handleDeepLink(_ url: URL)                       │
│    └─ Parse URL components                             │
│                                                         │
│    ▼                                                    │
│                                                         │
│ 3. Supabase receives magic link request                │
│    POST /auth/v1/verify?invite_token=XXX               │
│    ├─ Verifies token signature                         │
│    ├─ Checks token hasn't expired                      │
│    ├─ Creates or activates auth.users record           │
│    └─ Returns access_token, refresh_token              │
│                                                         │
│    ▼                                                    │
│                                                         │
│ 4. Supabase redirects to app with tokens               │
│    famcal://auth/confirm?access_token=JWT&             │
│                           refresh_token=JWT&           │
│                           type=invite&                 │
│                           email=user@example.com        │
│                                                         │
│    ▼                                                    │
│                                                         │
│ 5. FamCalApp.handleDeepLink() processes tokens         │
│    ├─ Extract access_token                             │
│    ├─ Extract refresh_token                            │
│    ├─ Extract email                                    │
│    ├─ Extract type = "invite"                          │
│    └─ Call applyDeepLinkSession()                      │
│                                                         │
│    ▼                                                    │
│                                                         │
│ 6. SupabaseAuthManager.applyDeepLinkSession()          │
│    ├─ Save accessToken                                 │
│    ├─ Save refreshToken                                │
│    ├─ Save userEmail                                   │
│    ├─ Emit authenticated state change                  │
│    └─ User is now logged in                            │
│                                                         │
│    ▼                                                    │
│                                                         │
│ 7. Check if password reset needed (type = "invite")    │
│    ├─ If linkType == "recovery" or "invite"           │
│    ├─ Set showResetPasswordSheet = true                │
│    └─ ResetPasswordSheet displayed                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 3. PASSWORD RESET & VALIDATION FLOW

```
┌─────────────────────────────────────────────────────────┐
│ PASSWORD RESET & VALIDATION FLOW                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ResetPasswordSheet {                                    │
│                                                         │
│   Password Input with @State variable                  │
│   ├─ @State var password: String = ""                  │
│   │                                                    │
│   └─ .onChange(of: password) { _, newPassword in      │
│       │                                                 │
│       ▼                                                 │
│       if !newPassword.isEmpty && confirmPassword...  │
│           confirmPassword = newPassword // Auto-fill   │
│       }                                                 │
│                                                         │
│   Validation Checklist (displayed when password ≠ "") │
│   ├─ Length >= 10 chars ──┬─► Image(systemName:...)  │
│   │  if password.count >= 10                           │
│   │    ├─ "checkmark.circle.fill" ◄─ green            │
│   │    └─ "circle" ◄─ gray                             │
│   │                                                    │
│   ├─ Has uppercase ──┬─► Image(systemName:...)        │
│   │  if password.contains(where: { $0.isUppercase })   │
│   │    ├─ "checkmark.circle.fill" ◄─ green            │
│   │    └─ "circle" ◄─ gray                             │
│   │                                                    │
│   ├─ Has lowercase ──┬─► Image(systemName:...)        │
│   │  if password.contains(where: { $0.isLowercase })   │
│   │    ├─ "checkmark.circle.fill" ◄─ green            │
│   │    └─ "circle" ◄─ gray                             │
│   │                                                    │
│   ├─ Has number ──┬─► Image(systemName:...)           │
│   │  if password.contains(where: { $0.isNumber })      │
│   │    ├─ "checkmark.circle.fill" ◄─ green            │
│   │    └─ "circle" ◄─ gray                             │
│   │                                                    │
│   ├─ Has special char ──┬─► Image(systemName:...)    │
│   │  if password.contains(where: {                     │
│   │    !$0.isLetter && !$0.isNumber })                 │
│   │    ├─ "checkmark.circle.fill" ◄─ green            │
│   │    └─ "circle" ◄─ gray                             │
│   │                                                    │
│   Update Button                                        │
│   ├─ Enabled if:                                       │
│   │  ├─ password.isEmpty == false                     │
│   │  ├─ password == confirmPassword                    │
│   │  └─ !isUpdating                                    │
│   │                                                    │
│   └─ On tap:                                            │
│      │                                                  │
│      ▼                                                  │
│      authManager.updatePassword(newPassword: password) │
│      │                                                  │
│      ▼                                                  │
│      Supabase.auth.updateUser(password: String)        │
│      │                                                  │
│      ▼                                                  │
│      If successful:                                    │
│      │ successMessage = "Password updated..."          │
│      │ onPasswordUpdated?() ◄─── CALLBACK INVOKED      │
│      │ dismiss()                                        │
│      │                                                  │
│      └─ If failed:                                      │
│        └─ errorMessage = "Password could not be..."    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 4. INVITATION ACCEPTANCE & LINKING FLOW

```
┌──────────────────────────────────────────────────────────────┐
│ INVITATION ACCEPTANCE & ACCOUNT LINKING FLOW                 │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│ ResetPasswordSheet.onPasswordUpdated callback:               │
│                                                              │
│ Task { @MainActor in                                         │
│   // Force refresh of data                                  │
│   await dataManager.fetchUserDataIfNeeded(force: true)       │
│   checkFamilySetupNeeded()                                   │
│ }                                                            │
│                                                              │
│   ▼                                                           │
│                                                              │
│ fetchUserDataIfNeeded(force: true)                           │
│ ├─ Bypasses cache timestamp checks (force = true)           │
│ ├─ Calls fetchFamilyMembers()                               │
│ │                                                            │
│ │   ▼                                                         │
│ │                                                            │
│ │ SupabaseManager.getFamilyMembers()                         │
│ │ ├─ Query /rest/v1/family_members                          │
│ │ │  POST body contains SQL filter                          │
│ │ │  SELECT * FROM family_members                           │
│ │ │  WHERE family_id = (FROM profiles WHERE id = user_id)   │
│ │ │                                                          │
│ │ └─ Returns [FamilyMemberDTO]                              │
│ │                                                            │
│ │    ▼                                                        │
│ │                                                            │
│ │ populateMemberEmails(from: familyMembers)                 │
│ │ ├─ Call getMemberEmailsForFamily()                        │
│ │ │                                                          │
│ │ │   ▼                                                       │
│ │ │                                                          │
│ │ │ ┌────────────────────────────────────────────────────┐   │
│ │ │ │ GET /functions/v1/member-emails                   │   │
│ │ │ │                                                    │   │
│ │ │ │ Backend Logic:                                    │   │
│ │ │ │ ├─ Get user's family_id from profile             │   │
│ │ │ │ ├─ Query family_members                          │   │
│ │ │ │ │  WHERE family_id = X AND linked_user_id != null│   │
│ │ │ │ ├─ For each member:                              │   │
│ │ │ │ │  ├─ linked_id = member.linked_user_id          │   │
│ │ │ │ │  ├─ User = auth.users[linked_id]               │   │
│ │ │ │ │  └─ Add { family_member_id, email } to result  │   │
│ │ │ │ └─ Return { emails: [MemberEmailDTO] }           │   │
│ │ │ │                                                    │   │
│ │ │ │ Response:                                         │   │
│ │ │ │ {                                                 │   │
│ │ │ │   "emails": [                                     │   │
│ │ │ │     {                                             │   │
│ │ │ │       "family_member_id": "abc-123",              │   │
│ │ │ │       "email": "newmember@example.com"            │   │
│ │ │ │     }                                             │   │
│ │ │ │   ]                                               │   │
│ │ │ │ }                                                 │   │
│ │ │ └────────────────────────────────────────────────────┘   │
│ │ │                                                          │
│ │ │    ▼                                                      │
│ │ │                                                          │
│ │ └─ Update @Published memberLinkedEmails: [UUID: String]   │
│ │    └─ dataManager.memberLinkedEmails[uuid] = email        │
│ │                                                            │
│ │    ▼                                                        │
│ │                                                            │
│ │ SwiftUI reacts to @Published property change              │
│ │ └─ All views subscribed to dataManager update              │
│ │                                                            │
│ └─ Sync to CoreData                                          │
│    └─ SupabaseDataSync.syncFamilyMembersFromSupabase()      │
│                                                              │
│   ▼                                                           │
│                                                              │
│ checkFamilySetupNeeded()                                     │
│ ├─ Check appSettingsManager.hasCompletedFamilySetup         │
│ ├─ If true:                                                 │
│ │  ├─ showSetupWorkflow = false                             │
│ │  └─ Show calendar view                                    │
│ └─ If false:                                                │
│    ├─ showSetupWorkflow = true                              │
│    └─ Show family setup screen                              │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 5. BACKGROUND: ACCEPT-INVITE FUNCTION (During Password Change)

```
IMPORTANT: This happens in the background during password reset

┌──────────────────────────────────────────────────────────┐
│ BACKGROUND: ACCEPT INVITATION VIA EMAIL                 │
├──────────────────────────────────────────────────────────┤
│                                                          │
│ When: FamCalApp handles deep link with type="invite"    │
│                                                          │
│ Call: acceptInvitationForCurrentUserEmail()             │
│                                                          │
│ ┌────────────────────────────────────────────────────┐   │
│ │ POST /functions/v1/accept-invite                   │   │
│ │                                                    │   │
│ │ Headers:                                           │   │
│ │   Authorization: Bearer <access_token>             │   │
│ │   x-invite-fn-key: <function_key>                  │   │
│ │                                                    │   │
│ │ No body (uses Authorization header to get user)    │   │
│ └────────────────────────────────────────────────────┘   │
│                                                          │
│    ▼                                                     │
│                                                          │
│ BACKEND: accept-invite/index.ts                         │
│                                                          │
│ Step 1: Get authenticated user                          │
│ ├─ auth.getUser() via Authorization header              │
│ ├─ userId = user.id                                     │
│ └─ email = user.email                                   │
│                                                          │
│    ▼                                                     │
│                                                          │
│ Step 2: Find pending invitation                         │
│ ├─ SELECT from invitations WHERE                        │
│ │  ├─ invitee_email = user.email                       │
│ │  ├─ status = 'pending'                               │
│ │  ├─ expires_at > now()                               │
│ │  └─ ORDER BY created_at DESC LIMIT 1                 │
│ └─ Returns: { id, family_id, family_member_id, token } │
│                                                          │
│    ▼                                                     │
│                                                          │
│ Step 3: Create or update profile                        │
│ ├─ TRY INSERT into profiles:                            │
│ │  ├─ id = userId                                      │
│ │  ├─ family_id = invite.family_id                     │
│ │  └─ email = user.email                               │
│ │                                                       │
│ │  CATCH (if profile exists):                          │
│ │  └─ UPDATE profiles SET:                             │
│ │     ├─ family_id = invite.family_id                  │
│ │     └─ email = user.email                            │
│ │                                                       │
│ │  WHERE id = userId                                   │
│ └─ Result: Profile now has correct family_id           │
│                                                          │
│    ▼                                                     │
│                                                          │
│ Step 4: Link family member to user                      │
│ ├─ IF invite.family_member_id exists:                  │
│ │  ├─ UPDATE family_members SET                        │
│ │  │  └─ linked_user_id = userId                      │
│ │  │  WHERE id = invite.family_member_id               │
│ │  │                                                    │
│ │  └─ Note: May trigger audit log constraint error     │
│ │           if action_by_user_id is NULL.              │
│ │           This is handled gracefully - linking still  │
│ │           succeeds despite trigger error.            │
│ │                                                       │
│ └─ Result: Family member now linked to auth user       │
│                                                          │
│    ▼                                                     │
│                                                          │
│ Step 5: Mark invitation accepted                        │
│ ├─ UPDATE invitations SET                              │
│ │  ├─ status = 'accepted'                              │
│ │  ├─ accepted_user_id = userId                        │
│ │  └─ accepted_at = now()                              │
│ │  WHERE id = invite.id                                │
│ └─ Result: Prevents re-acceptance                      │
│                                                          │
│    ▼                                                     │
│                                                          │
│ Return Response:                                        │
│ {                                                       │
│   "invitation_id": "<id>",                              │
│   "family_id": "<family_id>",                           │
│   "status": "accepted"                                  │
│ }                                                       │
│                                                          │
│    ▼                                                     │
│                                                          │
│ Swift receives family_id and caches it                  │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## State Management

### App State During Invitation Flow

```
1. BEFORE INVITATION
   ├─ isLoggedIn: false
   ├─ familyMembers: [] (empty)
   ├─ hasCompletedFamilySetup: false
   └─ appSettingsManager.familyId: nil

2. EMAIL RECEIVED (no change in app state yet)
   ├─ isLoggedIn: false
   ├─ familyMembers: [] (empty)
   ├─ hasCompletedFamilySetup: false
   └─ appSettingsManager.familyId: nil

3. LINK CLICKED → Deep link handled
   ├─ isLoggedIn: true ✓ (auth applied)
   ├─ familyMembers: [] (not fetched yet)
   ├─ hasCompletedFamilySetup: false
   ├─ appSettingsManager.familyId: nil
   └─ showResetPasswordSheet: true ✓ (password reset displayed)

4. PASSWORD UPDATED
   ├─ isLoggedIn: true
   ├─ familyMembers: [FamilyMemberDTO] ✓ (fetched in callback)
   ├─ memberLinkedEmails: {uuid: "user@example.com"} ✓ (populated)
   ├─ hasCompletedFamilySetup: true ✓ (set in callback)
   ├─ appSettingsManager.familyId: "fam-123" ✓ (cached)
   └─ showResetPasswordSheet: false ✓ (dismissed)

5. APP READY
   ├─ isLoggedIn: true
   ├─ familyMembers: [FamilyMemberDTO] with linked status
   ├─ memberLinkedEmails: {uuid: "user@example.com"}
   ├─ hasCompletedFamilySetup: true
   ├─ appSettingsManager.familyId: "fam-123" (cached)
   └─ Show calendar view ✓
```

### Publishing & Observation Pattern

```
@Published properties in Managers:
│
├─ SupabaseAuthManager
│  ├─ @Published isLoggedIn: Bool
│  ├─ @Published userId: String?
│  ├─ @Published userEmail: String?
│  └─ @Published accessToken: String?
│
├─ SupabaseDataManager
│  ├─ @Published familyMembers: [FamilyMemberDTO]
│  ├─ @Published memberLinkedEmails: [UUID: String]
│  ├─ @Published sharedCalendars: [SharedCalendarDTO]
│  ├─ @Published personalCalendars: [PersonalCalendarDTO]
│  └─ @Published isLoading: Bool
│
└─ AppSettingsManager
   ├─ @Published hasCompletedFamilySetup: Bool
   ├─ @Published familyId: String?
   ├─ @Published linkedFamilyMemberId: UUID?
   └─ @Published autoRefreshInterval: Int

Observers:
│
├─ FamilySettingsView observes:
│  ├─ dataManager.familyMembers
│  ├─ dataManager.memberLinkedEmails
│  └─ appSettingsManager.hasCompletedFamilySetup
│
├─ CalendarView observes:
│  ├─ dataManager.familyMembers
│  └─ appSettingsManager.familyId
│
└─ FamCalApp observes:
   ├─ authManager.isLoggedIn
   ├─ appSettingsManager.hasCompletedFamilySetup
   └─ dataManager.familyMembers
```

---

## Error Handling Strategy

### Invitation Phase

```
Error Scenarios:

1. Family member not found
   └─ Response: 404 "member not found"
   └─ UI: "Could not find that family member"

2. Email already invited
   └─ Response: May not be explicitly handled
   └─ Fallback: Will create another invitation (could improve)

3. Email service down
   └─ Response: Supabase invitation fails
   └─ UI: "Failed to send invite: <error message>"

4. User not authorized (non-family-owner)
   └─ Response: RLS policy blocks request
   └─ UI: "Failed to send invite: Unauthorized"
```

### Acceptance Phase

```
Error Scenarios:

1. No pending invitation found
   └─ Response: 404 "no pending invite found for this email"
   └─ App: Invitation acceptance skipped, user still logs in
   └─ Result: User authenticated but not linked to family

2. Profile creation fails
   └─ Response: 400 with error message
   └─ Handling: Try update instead, continue if that fails
   └─ Result: User may not have correct family_id

3. Family member linking fails (audit log error)
   └─ Response: 23502 constraint error from trigger
   └─ Handling: Logged as warning, acceptance continues
   └─ Result: Family member may not be fully linked

4. Invitation update fails
   └─ Response: 400 with error message
   └─ UI: "Failed to accept invitation: <error>"
   └─ Result: Invitation not marked accepted (can be accepted again)
```

### Recovery Strategies

```
If user gets stuck in "setup workflow" instead of calendar:
├─ hasCompletedFamilySetup not set properly
├─ Solution: Force manual call to completeFamilySetupForInvitedUser()
└─ Or: Logout and login again to retry

If invited user's email not showing in main user's view:
├─ member-emails function not returning data
├─ memberLinkedEmails not populated
├─ Solution: Pull down to refresh (force fetch)
└─ Or: Restart app to clear stale cache

If audit log constraint error blocks linking:
├─ Constraint: family_activity_log.action_by_user_id NOT NULL
├─ Solution: Run SQL migration to allow NULL
└─ Or: Disable trigger temporarily during acceptance
```

---

## Performance Considerations

### Cache Management

```
Caching Layers:

1. AppSettingsManager (In-memory + UserDefaults)
   ├─ familyId: Persisted, checked before API call
   ├─ hasCompletedFamilySetup: Persisted
   └─ linkedFamilyMemberId: Persisted

2. SupabaseDataManager (In-memory with sync metadata)
   ├─ familyMembers: Cached with SyncMetadata
   ├─ memberLinkedEmails: In-memory [UUID: String]
   └─ lastSyncTime: Checked before refetch

3. CoreData (Local SQL database)
   ├─ FamilyMember entity
   ├─ PersonalCalendar entity
   └─ Synced from Supabase

Cache Invalidation:
│
├─ Manual refresh: fetchUserDataIfNeeded(force: true)
├─ Automatic: SyncMetadata.shouldFetchData() checks time
└─ On app foreground: refresh timer runs
```

### Network Optimization

```
Parallel Fetches:

When fetchUserDataIfNeeded() called:

Sequential (dependency order):
1. fetchFamilyMembers() - MUST be first
   └─ Needed for calendar linking
   │
   └─► Then parallel:
       ├─ fetchSharedCalendars()
       ├─ fetchPersonalCalendars()
       ├─ fetchDrivers()
       ├─ fetchAddresses()
       └─ populateMemberEmails() (called from fetchFamilyMembers)

Batch Operations:
├─ member-emails function fetches multiple emails in one call
├─ Reduces number of auth.users lookups
└─ Single HTTP request instead of N requests
```

---

## Testing Considerations

### Unit Tests

```
SupabaseManager.createFamilyInvitation()
├─ Mock HTTP responses
├─ Verify correct endpoint called
├─ Verify request body structure
└─ Verify error handling

SupabaseManager.acceptInvitationForCurrentUserEmail()
├─ Mock successful acceptance
├─ Verify family_id extraction
├─ Verify error on "no pending invite"
└─ Verify timeout handling

SupabaseDataManager.populateMemberEmails()
├─ Mock edge function responses
├─ Verify memberLinkedEmails populated
├─ Verify @Published update triggers
└─ Verify error logging
```

### Integration Tests

```
Full Invitation Flow:
├─ Create family and member (setup)
├─ Send invitation
├─ Simulate deep link
├─ Accept invitation
├─ Verify family_id cached
├─ Verify linked_user_id set
├─ Verify emails fetched
└─ Verify setup workflow skipped

Data Visibility:
├─ Main user invites new member
├─ Invited user accepts and sets password
├─ Main user refreshes
├─ Verify new member visible
└─ Verify email address shown
```

### Manual Testing

```
1. Create new family
2. Add family member (name + color)
3. Send invitation email
4. Receive email and click link
5. App opens and authenticates
6. Password reset form displays
7. Validation checklist shows
8. Password manager auto-fills
9. Set password successfully
10. Sheet dismisses
11. Calendar view appears (not setup)
12. Go back to main user
13. Pull down to refresh
14. New member visible with email
15. Lock icon shows linked status
```

