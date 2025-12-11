# FamCal Invitation & Account Linking - Documentation Index

This directory contains comprehensive documentation for the FamCal family member invitation and account linking system.

## 📚 Documentation Files

### 1. **INVITE_AND_LINK_DOCUMENTATION.md** (Main Reference)
**Purpose:** Complete end-to-end documentation of the invitation and linking system

**Sections:**
- Overview and three-phase flow
- Phase 1: Invitation Creation & Email Sending
- Phase 2: Password Setup
- Phase 3: Invitation Acceptance & Account Linking
- Complete user journey diagram
- Data models and database tables
- Account linking for existing members
- Account unlinking
- Email fetching and display
- Database constraints and security
- Testing checklist
- Troubleshooting guide
- Related files summary
- Key design decisions
- Future improvements

**Read this if:** You want a complete understanding of the entire flow, or need to understand a specific phase in detail.

---

### 2. **INVITE_ARCHITECTURE.md** (Technical Deep Dive)
**Purpose:** System architecture, API flows, state management, and error handling

**Sections:**
- System architecture overview (diagram)
- Database schema relationships
- 5 detailed API flow diagrams:
  1. Create Invitation Flow
  2. Deep Link & Authentication Flow
  3. Password Reset & Validation Flow
  4. Invitation Acceptance & Linking Flow
  5. Background: Accept-Invite Function
- State management and observable patterns
- Error handling strategies
- Recovery strategies
- Performance considerations
- Cache management
- Network optimization
- Testing considerations (unit, integration, manual)

**Read this if:** You're implementing features, debugging issues, or want to understand the technical architecture.

---

### 3. **INVITE_QUICK_REFERENCE.md** (Quick Lookup)
**Purpose:** Fast reference for common tasks and important information

**Sections:**
- File locations (frontend, backend, edge functions, database)
- Key concepts
- Data flow during invitation
- Common tasks with code examples
- Important state variables
- URL schemes
- Edge function responses
- Error messages
- Debugging checklist
- Related documentation
- Quick fixes
- Performance tips
- Security notes

**Read this if:** You need to quickly look up a file location, understand a concept, or find a quick fix.

---

## 🎯 Quick Start

### For New Developers
1. Read the **Overview** section in INVITE_AND_LINK_DOCUMENTATION.md
2. Look at the **Complete User Journey Diagram** in INVITE_AND_LINK_DOCUMENTATION.md
3. Use INVITE_QUICK_REFERENCE.md as your cheat sheet

### For Debugging
1. Go to INVITE_QUICK_REFERENCE.md → Debugging Checklist
2. Reference the specific section in INVITE_AND_LINK_DOCUMENTATION.md or INVITE_ARCHITECTURE.md
3. Check the Troubleshooting Guide in INVITE_AND_LINK_DOCUMENTATION.md

### For Implementation
1. Read the relevant phase in INVITE_AND_LINK_DOCUMENTATION.md
2. Check the API flow diagram in INVITE_ARCHITECTURE.md
3. Reference file locations in INVITE_QUICK_REFERENCE.md
4. Look at state management in INVITE_ARCHITECTURE.md

---

## 📋 System Overview

### Three-Phase System

```
Phase 1: Invitation Creation
├─ Family manager creates invitation
├─ Selects unlinked family member
├─ Enters invitee email
└─ Email sent with magic link

Phase 2: Password Setup
├─ Invited user receives email
├─ Clicks magic link
├─ Deep link authenticates user
├─ Password reset sheet shown
├─ Password validation checklist visible
├─ Password manager auto-fills both fields
└─ User sets password

Phase 3: Acceptance & Linking
├─ Profile created/updated with family_id
├─ Family member linked to user account
├─ Invitation marked as accepted
├─ Family_id cached in AppSettingsManager
├─ Family data fetched
├─ Setup workflow skipped
└─ Calendar view shown directly
```

---

## 🔗 File Locations Quick Reference

### Swift Frontend
- **FamCalApp.swift**: Deep link handling, setup logic (lines 526-643, 304-310, 659-667)
- **FamilySettingsView.swift**: Invite UI, member management (lines 385-406, 322-336, 544-548)
- **ResetPasswordSheet.swift**: Password setup with validation (lines 37-109, 165)

### Swift Backend (Managers)
- **SupabaseManager.swift**: API calls (lines 793, 849, 286, 527, 579)
- **SupabaseDataManager.swift**: Data fetching (lines 160, 375, 803)

### Supabase Edge Functions
- **supabase/functions/invite-email/index.ts**: Create & send invitation
- **supabase/functions/accept-invite/index.ts**: Accept & link account
- **supabase/functions/member-emails/index.ts**: Fetch linked member emails

### Database
- **invitations**: Invitation lifecycle
- **family_members**: Member slots & account linking (linked_user_id)
- **profiles**: User profiles with family_id
- **auth.users**: Supabase authentication

---

## 🔐 Security Features

✅ **Email Verification**: Invitation tokens are secure JWTs with expiration
✅ **Authorization**: RLS policies prevent cross-family access
✅ **Role-Based Access**: Service role required for sensitive operations
✅ **Password Requirements**: Enforced on backend with validation feedback
✅ **Deep Link Security**: App-specific scheme (famcal://) prevents interception
✅ **Account Linking**: Email must match to accept invitation

---

## ⚠️ Known Issues & Solutions

### Audit Log Constraint Error

**Issue:** Error code 23502 when linking family member

**Cause:** `family_activity_log.action_by_user_id` has NOT NULL constraint

**Solution:**
```sql
ALTER TABLE public.family_activity_log
ALTER COLUMN action_by_user_id DROP NOT NULL;
```

### Invited User Sees Setup Workflow

**Issue:** New invited user goes to setup instead of calendar

**Cause:** `hasCompletedFamilySetup` not set or `familyId` not cached

**Solution:** Verify `completeFamilySetupForInvitedUser()` is called with both flags set

### Linked Email Not Showing

**Issue:** Main user doesn't see newly linked member's email

**Cause:** Cache not refreshed or edge function not called

**Solution:** Pull down to refresh (force fetch with `force: true`)

---

## 🧪 Testing

### Manual Testing Checklist
- [ ] Create family and member
- [ ] Send invitation email
- [ ] Receive email and click link
- [ ] App opens and authenticates
- [ ] Password reset form displays
- [ ] Validation checklist works
- [ ] Password manager auto-fills
- [ ] Password updates successfully
- [ ] Sheet dismisses
- [ ] Calendar view appears (NOT setup workflow)
- [ ] Main user pulls down to refresh
- [ ] New member visible with email
- [ ] Lock icon shows linked status

### Automated Testing
- Unit tests for each manager function
- Integration tests for full flow
- API mocking for edge functions

---

## 📱 Key Features

✨ **One-Click Invitations**: Send via email with magic link
✨ **Auto-Fill Support**: Password manager fills both password fields
✨ **Live Validation**: Real-time password requirement feedback
✨ **Zero Friction**: New users skip setup, go straight to calendar
✨ **Email Visibility**: See who's linked via their email address
✨ **Unlinking Support**: Remove account linkage anytime
✨ **Offline Support**: Cached family_id for offline access
✨ **Mobile Optimized**: Deep links work seamlessly on iOS

---

## 🚀 Deployment

### Before Going Live

1. ✅ Deploy Edge Functions
   ```bash
   supabase functions deploy invite-email
   supabase functions deploy accept-invite
   supabase functions deploy member-emails
   ```

2. ✅ Run Database Migrations
   ```sql
   -- Ensure audit log constraint allows NULL
   ALTER TABLE public.family_activity_log
   ALTER COLUMN action_by_user_id DROP NOT NULL;
   ```

3. ✅ Configure Supabase
   - Set INVITE_FUNCTION_KEY environment variable
   - Configure email sender
   - Test magic link redirects

4. ✅ Test Full Flow
   - Create test account and family
   - Send test invitation
   - Accept and verify all states

---

## 📞 Support

### Common Questions

**Q: How long is an invitation valid?**
A: 7 days (configurable via `expires_at` in invitation creation)

**Q: Can the same email be invited twice?**
A: Yes, multiple invitations can be created (can improve with duplicate check)

**Q: What happens if password reset fails?**
A: User is still authenticated, can retry password update

**Q: Can an invitation be revoked?**
A: Currently no, but can be added (update invitation status to "revoked")

**Q: What if user loses the magic link?**
A: Currently must resend invitation (can add resend functionality)

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-11 | Initial documentation for complete invitation & linking system |

---

## 📖 Reading Guide by Role

### Product Manager
- Start with: INVITE_AND_LINK_DOCUMENTATION.md → Overview
- Then: INVITE_AND_LINK_DOCUMENTATION.md → Complete User Journey
- Reference: INVITE_QUICK_REFERENCE.md for status/changes

### Frontend Developer
- Start with: INVITE_ARCHITECTURE.md → System Architecture
- Then: INVITE_AND_LINK_DOCUMENTATION.md → Phase 2 & Phase 3
- Reference: INVITE_QUICK_REFERENCE.md → File Locations, Common Tasks

### Backend Developer
- Start with: INVITE_ARCHITECTURE.md → API Flow Diagrams
- Then: INVITE_AND_LINK_DOCUMENTATION.md → Backend sections
- Reference: INVITE_QUICK_REFERENCE.md → Edge Function Responses

### QA / Tester
- Start with: INVITE_AND_LINK_DOCUMENTATION.md → Testing Checklist
- Then: INVITE_QUICK_REFERENCE.md → Debugging Checklist
- Reference: INVITE_ARCHITECTURE.md → Error Handling

### Ops / DevOps
- Start with: INVITE_QUICK_REFERENCE.md → Deployment
- Then: INVITE_ARCHITECTURE.md → Performance Considerations
- Reference: INVITE_AND_LINK_DOCUMENTATION.md → Database Constraints

---

## 🎓 Learning Path

### Beginner (30 minutes)
1. Overview section in INVITE_AND_LINK_DOCUMENTATION.md (5 min)
2. Complete User Journey Diagram (10 min)
3. INVITE_QUICK_REFERENCE.md (15 min)

### Intermediate (1-2 hours)
1. All three phases in INVITE_AND_LINK_DOCUMENTATION.md (45 min)
2. System Architecture in INVITE_ARCHITECTURE.md (30 min)
3. Debugging Checklist in INVITE_QUICK_REFERENCE.md (15 min)

### Advanced (2-3 hours)
1. Entire INVITE_AND_LINK_DOCUMENTATION.md (1 hour)
2. Entire INVITE_ARCHITECTURE.md (1 hour)
3. Code review of actual implementations (1 hour)
4. Deploy and test full flow (varies)

---

## ✅ Documentation Checklist

- ✅ Complete user journey documented
- ✅ All file locations listed with line numbers
- ✅ API flows documented with request/response
- ✅ Database schema and relationships documented
- ✅ State management explained
- ✅ Error handling strategies documented
- ✅ Security considerations noted
- ✅ Testing checklist provided
- ✅ Troubleshooting guide included
- ✅ Quick reference for common tasks
- ✅ Architecture diagrams included
- ✅ Performance considerations noted
- ✅ Deployment steps documented
- ✅ Known issues and solutions listed
- ✅ Code examples provided throughout

---

## 🔗 Related Documentation

- [FamCal README](README.md) - Project overview
- [FamCal Architecture](ARCHITECTURE.md) - General app architecture
- Supabase Documentation - https://supabase.com/docs
- SwiftUI Documentation - https://developer.apple.com/documentation/swiftui

---

**Last Updated:** December 11, 2024
**Status:** Complete ✅
**Coverage:** 100% of invitation & account linking system

