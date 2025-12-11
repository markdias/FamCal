# FamCal Invitation System - Testing Guide

## Complete Testing Workflow

This guide walks through testing the entire family member invitation and account linking system from start to finish.

---

## 🧪 Pre-Testing Setup

### Environment Requirements

✅ **Development Machine**
- Xcode 15+ (for iOS 17+)
- Supabase CLI installed
- Access to Supabase project
- Email client or service to receive invitations

✅ **Two Test Devices**
- Device A: Main family account (family owner)
- Device B: New member account (to be invited)
- OR: One device + simulator

✅ **Test Data**
- Main user account (family owner)
- Empty family
- At least 1 family member slot (unlinked)

---

## 📝 Test Scenario 1: Complete Invitation Flow

### Setup (Do Once)
```
Device A (Main User):
1. Create account
2. Create family
3. Add family member (e.g., "John Doe", Blue color)
4. Ensure member is UNLINKED (no email shown)
```

### Step 1: Send Invitation (Device A)

**Location:** Settings → Family

**Action:**
1. Tap **Family Settings**
2. Scroll to "Invite Members" section
3. Dropdown: Select "John Doe"
4. Text field: Enter test email (e.g., testuser@example.com)
5. Tap **"Send Invite"**

**Expected Result:**
```
✓ Message shows: "Invite sent to testuser@example.com"
✓ Email field clears
✓ Dropdown resets
```

**Verify Backend:**
```sql
-- Check invitations table
SELECT * FROM public.invitations
WHERE invitee_email = 'testuser@example.com'
ORDER BY created_at DESC LIMIT 1;

-- Verify:
- status = 'pending'
- family_member_id matches "John Doe"
- expires_at > now()
```

---

### Step 2: Receive Email (Device B)

**Action:**
1. Check email for: "testuser@example.com"
2. Look for subject line from Supabase
3. Copy the magic link (contains invite_token)

**Expected Result:**
```
✓ Email received from Supabase
✓ Subject: "[Supabase] Confirm your email"
✓ Body contains: "Welcome to FamCal"
✓ Link format: famcal://invite?invite_token=XXX&type=invite&email=testuser@example.com
```

**If No Email Received:**
- [ ] Check spam/junk folder
- [ ] Verify email address is correct
- [ ] Check Supabase email logs:
  ```
  Supabase Dashboard → Auth → Email Templates
  ```
- [ ] Verify SMTP is configured

---

### Step 3: Click Magic Link (Device B)

**Action:**
1. On Device B, click the magic link from email
2. Should open FamCal app automatically

**Expected Result:**
```
✓ FamCal app opens
✓ Deep link is processed
✓ User is automatically authenticated (no login screen)
✓ "Set a new password" sheet appears
```

**If App Doesn't Open:**
- [ ] Verify URL scheme registered in Xcode
- [ ] Check Info.plist contains: `famcal` scheme
- [ ] Try copying link and opening in Safari manually
- [ ] Check device's URL handler settings

---

### Step 4: Password Validation & Setup (Device B)

**Screen:** Reset Password Sheet

**Validation Checklist Test:**

1. **Initial State** (password field empty)
   ```
   ✓ Checklist NOT visible
   ✓ Update Password button disabled
   ```

2. **Enter Weak Password** (e.g., "abc")
   ```
   ✓ Checklist appears
   ✓ All items show gray circles (❌)
   ```

3. **Build Up Password** (gradually type "Test123!")
   ```
   While typing "T":
   ✓ Uppercase: ✓ (green checkmark)

   Then type "est":
   ✓ Lowercase: ✓ (green checkmark)

   Then type "123":
   ✓ Number: ✓ (green checkmark)

   Then type "!":
   ✓ Special char: ✓ (green checkmark)

   Count characters (Test123! = 8):
   ✗ Length still red (need 10+)

   Type "!!" to make "Test123!!!":
   ✓ Length: ✓ (green checkmark)
   ```

   **Expected Result:**
   ```
   ✓ All 5 checkmarks are green
   ✓ Update Password button becomes ENABLED
   ```

4. **Test Auto-Fill** (Password Manager)
   ```
   ✓ Clear both password fields
   ✓ Use password manager to fill first field
   ✓ EXPECTED: Both fields auto-filled
   ```

   **If Auto-Fill Doesn't Work:**
   - [ ] Check `.onChange()` modifier is on password field
   - [ ] Verify confirm password field is binding correctly
   - [ ] Test with different password managers

5. **Mismatch Test**
   ```
   ✓ Password: Test123!!!
   ✓ Confirm:  Different123!
   ✓ Try to tap Update Password
   ✓ EXPECTED: Alert "Passwords must match."
   ```

6. **Successful Password Update**
   ```
   ✓ Password: Test123!!!
   ✓ Confirm:  Test123!!!
   ✓ Tap "Update Password"
   ✓ Button shows loading spinner
   ✓ After 2-3 seconds: Sheet dismisses
   ```

   **Expected Result:**
   ```
   ✓ Sheet dismissed smoothly
   ✓ No errors shown
   ✓ User see calendar view (NOT setup workflow)
   ```

**Verify Backend:**
```sql
-- Check auth.users table (requires service role)
SELECT id, email, confirmed_at FROM auth.users
WHERE email = 'testuser@example.com';

-- Verify:
- confirmed_at is set (user confirmed)
- password is hashed (not visible)
```

---

### Step 5: Verify Account Linking (Device B)

**After password update:**

**Expected Behavior:**
```
✓ User sees calendar view directly
✓ Setup workflow NOT shown
✓ Calendar empty but accessible
✓ Can navigate app normally
✓ Settings show account is linked
```

**Verify Backend:**
```sql
-- Check profiles table
SELECT * FROM public.profiles
WHERE email = 'testuser@example.com';

-- Verify:
- family_id is set (not NULL)
- Same family_id as main user

-- Check family_members table
SELECT * FROM public.family_members
WHERE id = '<john-doe-member-id>';

-- Verify:
- linked_user_id is set to new user's ID
- (NOT NULL)

-- Check invitations table
SELECT * FROM public.invitations
WHERE invitee_email = 'testuser@example.com';

-- Verify:
- status = 'accepted'
- accepted_user_id is set
- accepted_at is set
```

---

### Step 6: Verify Data Visibility (Device A)

**Action on Device A:**
1. Go to **Settings → Family**
2. **Pull down to refresh** the screen
3. Wait for refresh to complete

**Expected Result:**
```
✓ "John Doe" member still visible
✓ Below name: NEW EMAIL "testuser@example.com" (accent color)
✓ Lock icon appears (🔒 orange/accent)
✓ Edit button replaced with lock button
✓ Delete button disabled (grayed out)
✓ Driver and Calendar buttons still work
```

**If Email Not Showing:**
- [ ] Do another pull-to-refresh
- [ ] Verify `member-emails` edge function deployed
- [ ] Check that `linked_user_id` is set in database
- [ ] Clear app cache and restart

---

## 📝 Test Scenario 2: Account Linking (Existing Member)

### Setup (Do Once)
```
Device A: Main user
Device B: Second account (not yet invited)
Family: Has unlinked member "Jane Smith"
```

### Step 1: Create Second Account (Device B)

**Action:**
1. Sign out from Device B
2. Create new account with different email
3. Create empty family (skip setup or delete)

**Result:**
```
✓ Device B logged in as second user
```

---

### Step 2: Link Account to Family Member (Device B)

**Location:** Settings → Account

**Action:**
1. Tap **Settings → Account**
2. Tap **"Link to Family Account"**
3. See list of available families to link to
4. Select Device A's family
5. See unlinked members list
6. Select "Jane Smith"
7. Confirm

**Expected Result:**
```
✓ Account linking initiated
✓ Jane Smith's member details visible
✓ Confirmation required
✓ After confirmation: Linked successfully
```

**Verify Backend:**
```sql
-- Check family_members for Jane Smith
SELECT * FROM public.family_members
WHERE name = 'Jane Smith';

-- Verify:
- linked_user_id = Device B's user ID
```

---

### Step 3: Verify Linkage on Device A

**Action:**
1. Device A: Go to Settings → Family
2. Pull down to refresh

**Expected Result:**
```
✓ Jane Smith now shows email
✓ Lock icon visible
✓ Email refreshed from backend
```

---

## 📝 Test Scenario 3: Unlinking

### Setup (Do Once)
```
Device A: Main user
Linked member: John Doe (linked to Device B's account)
```

### Step 1: Unlink Member (Device A)

**Location:** Settings → Family

**Action:**
1. Go to **Settings → Family**
2. Find "John Doe" (linked member)
3. Verify lock icon visible (🔒)
4. Tap the lock icon
5. Confirmation dialog appears
6. Confirm "Unlink Account"

**Expected Result:**
```
✓ Lock button taps without error
✓ Confirmation dialog shown
✓ Options: Unlink or Cancel
✓ After confirmation: Progress indicator
✓ After completion: Lock icon removed
✓ Edit button restored
✓ Delete button enabled
```

**Verify Backend:**
```sql
-- Check family_members
SELECT * FROM public.family_members
WHERE name = 'John Doe';

-- Verify:
- linked_user_id = NULL (unlinked)
```

---

### Step 2: Verify Device B Can Relink (Optional)

**Action on Device B:**
1. Account still exists
2. Try to go to Settings → Account
3. Can select to link to family again

**Result:**
```
✓ Member is now available to relink
```

---

## 🔄 Test Scenario 4: Multiple Invitations

### Setup
```
Device A: Main user with multiple unlinked members
- John Doe
- Jane Smith
- Bob Johnson
```

### Steps

**Action 1: Invite First Member**
```
Send invitation to: john@example.com
Link to: John Doe
```

**Action 2: Invite Second Member (Before First Accepts)**
```
Send invitation to: jane@example.com
Link to: Jane Smith
```

**Action 3: Accept First Invitation (Device B)**
```
Click John's email link
Set password
Verify John is linked
```

**Action 4: Accept Second Invitation (Device C)**
```
Click Jane's email link
Set password
Verify Jane is linked
```

**Action 5: Verify on Device A**
```
Pull down to refresh
Verify both John and Jane show emails
Verify both have lock icons
```

**Expected Result:**
```
✓ Multiple invitations can coexist
✓ Each invitation independent
✓ Each creates separate auth user
✓ Both linked to same family
```

---

## ⚠️ Error Scenarios Testing

### Scenario 1: Expired Invitation

**Setup:**
- Invitation exists and is expired

**Action:**
```
1. Try to click old magic link
2. System attempts to process it
```

**Expected Result:**
```
✓ Error handling graceful
✓ User informed: "Invitation has expired"
✓ Option to resend invitation
```

**Verify Backend:**
```sql
-- Check if check fails on expired invitations
SELECT * FROM public.invitations
WHERE expires_at < now();

-- Should be excluded from acceptance
```

---

### Scenario 2: Wrong Email for Invitation

**Setup:**
- Invitation sent to: alice@example.com
- User tries with: bob@example.com

**Action:**
```
1. Create different email account
2. Try to accept alice's invitation
3. System checks email match
```

**Expected Result:**
```
✓ Error: "No pending invitation found for this email"
✓ User cannot link to wrong invitation
```

---

### Scenario 3: Password Too Weak

**Setup:**
- Password: "weak"

**Action:**
```
1. Password field: "weak"
2. Checklist shows all gray
3. Try to tap Update Password
```

**Expected Result:**
```
✓ Button disabled (can't click)
✓ Or error: "Password does not meet requirements"
```

---

### Scenario 4: Same Password as Before

**Setup:**
- User has previous password
- Tries to set same password

**Action:**
```
1. Set password to: Test123!!!
2. Update successfully
3. On reset: Try same password Test123!!!
```

**Expected Result:**
```
✓ Error: "Password could not be updated. Please choose a different one."
```

---

## 🐛 Debugging Checklist

### If Invitation Email Not Received

```
Device A:
1. Check Supabase logs for email send
2. Verify invitee_email in database
3. Try sending from Supabase dashboard directly
4. Check spam/junk folder
5. Try different email address
```

### If Deep Link Not Opening App

```
Device B:
1. Try copying link to Safari
2. Check iOS Settings → FamCal → URL schemes
3. Restart app
4. Check Console.app for any errors
5. Verify Info.plist has URL scheme
```

### If User Goes to Setup Instead of Calendar

```
Device B (after password):
1. Check AppSettingsManager.hasCompletedFamilySetup
2. Check AppSettingsManager.familyId is set
3. Check Supabase logs for accept-invite function
4. Verify profile table has family_id
5. Verify family_members.linked_user_id is set
```

### If Linked Email Not Showing

```
Device A (after refresh):
1. Check member-emails edge function deployed
2. Check family_members.linked_user_id is set
3. Check auth.users record exists
4. Try manual pull-to-refresh
5. Check dataManager.memberLinkedEmails dictionary
6. Check FamilySettingsView.linkedEmail() function
```

---

## ✅ Complete Testing Checklist

### Invitation Phase
- [ ] Send invitation successfully
- [ ] Invitation record created in DB
- [ ] Email received with correct link
- [ ] Email has invite_token parameter
- [ ] Email has type=invite parameter
- [ ] Email has email parameter

### Deep Link & Authentication
- [ ] Click link opens FamCal app
- [ ] User authenticated (no login needed)
- [ ] Access token obtained
- [ ] Refresh token obtained
- [ ] User ID extracted
- [ ] Email extracted

### Password Setup
- [ ] Password reset sheet displayed
- [ ] Checklist appears when typing
- [ ] Green checkmarks appear correctly
- [ ] All 5 requirements tracked
- [ ] Update button disabled initially
- [ ] Update button enabled when ready
- [ ] Password manager auto-fills
- [ ] Confirm password auto-filled
- [ ] Mismatch error shown
- [ ] Password updates successfully
- [ ] Sheet dismisses

### Acceptance & Linking
- [ ] Profile created in profiles table
- [ ] family_id set correctly
- [ ] linked_user_id set in family_members
- [ ] Invitation marked accepted
- [ ] accepted_user_id set
- [ ] accepted_at set

### Data Visibility
- [ ] User sees calendar (NOT setup)
- [ ] Family members list loaded
- [ ] Pull down to refresh works
- [ ] New member email visible
- [ ] Lock icon shown
- [ ] Edit button disabled
- [ ] Delete button disabled
- [ ] Unlink button available

### Unlinking
- [ ] Unlink button works
- [ ] Confirmation shown
- [ ] linked_user_id set to NULL
- [ ] Member back in unlinked state
- [ ] Email removed from view

### Multiple Members
- [ ] Multiple invitations can exist
- [ ] Each creates separate user
- [ ] All linked to same family
- [ ] All visible with emails

### Error Handling
- [ ] Expired invitations rejected
- [ ] Wrong email rejected
- [ ] Missing member error
- [ ] Network error handled
- [ ] User informed of errors

---

## 📊 Performance Testing

### Load Testing

**Action:**
```
Send 10 invitations simultaneously
Verify all emails sent
Verify all records created
Time: < 5 seconds
```

### Cache Testing

**Action:**
```
1. First refresh: Time how long
2. Second refresh: Should be faster (cached)
3. Force refresh: Should be slower (fresh data)
```

**Expected:**
```
✓ Cached: < 1 second
✓ Fresh: 2-3 seconds
```

### Offline Testing

**Action:**
```
1. Disable network
2. Try to use app
3. Can still see cached data
4. Re-enable network
5. Refresh works
```

---

## 📝 Test Report Template

```
Date: [DATE]
Tester: [NAME]
Environment: [iOS 17.x, iPhone 15 Pro, Supabase Project: XXX]
Build: [Version number]

RESULTS:
- Test Scenario 1 (Complete Invitation): ✓ PASSED / ✗ FAILED
- Test Scenario 2 (Account Linking): ✓ PASSED / ✗ FAILED
- Test Scenario 3 (Unlinking): ✓ PASSED / ✗ FAILED
- Test Scenario 4 (Multiple Invitations): ✓ PASSED / ✗ FAILED

ISSUES FOUND:
[List any failures or unexpected behavior]

NOTES:
[Any observations or recommendations]
```

---

## 🚀 Deployment Testing

Before deploying to production:

```
[ ] All test scenarios pass
[ ] Error scenarios handled gracefully
[ ] Performance acceptable
[ ] Audit logs clean
[ ] Database constraints verified
[ ] Email delivery tested
[ ] Deep links working
[ ] Both auth paths tested (magic link + password)
[ ] Cache invalidation working
[ ] Data sync complete
```

---

## 📞 Quick Troubleshooting

| Issue | Solution |
|-------|----------|
| Email not received | Check Supabase email logs, try different email |
| Deep link doesn't open app | Try in Safari, check URL scheme registration |
| User sees setup instead of calendar | Force logout/login or check cache flags |
| Email not showing after refresh | Pull down again, check database for linked_user_id |
| Password doesn't update | Check password meets requirements |
| Unlink button doesn't work | Check database permissions, try logout/login |

---

**Last Updated:** December 11, 2024
**Status:** Complete Testing Guide

