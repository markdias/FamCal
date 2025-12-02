# Login Issue - How to Create Users Correctly

## The Problem

You can create users in Supabase, but they can't log in to the app.

## Root Cause

**Most likely**: When you created the user in Supabase, you did NOT toggle "Confirm email" to ON.

Supabase requires email confirmation by default - users cannot log in until their email is confirmed.

## The Solution

### Step 1: Understand What You Need

When creating a user in Supabase for testing, you MUST:

1. ✅ Set a valid email
2. ✅ Set a password
3. **✅ Toggle "Confirm email" to ON** ← THIS IS THE KEY

Without step 3, the user cannot log in no matter what.

### Step 2: Create a Test User Correctly

1. Go to https://app.supabase.com
2. Open your project (tzkspidmzlipujsnxpzc)
3. Click: **Authentication** (left sidebar)
4. Click: **Users** tab
5. Click: **Create new user** (top right button)
6. Fill in the form:
   ```
   Email: test@example.com
   Password: Test123456
   ☑ Confirm email  ← TURN THIS ON!
   ```
7. Click: **Create user**

That's it! The user is now ready to log in.

### Step 3: Test Login in the App

1. Build and run the app (Cmd+B, then Cmd+R in Xcode)
2. On the login screen, enter:
   ```
   Email: test@example.com
   Password: Test123456
   ```
3. Tap: **Sign In**
4. Check the Xcode console - you should see:
   ```
   ℹ️ Sign-in request: POST https://...
   ℹ️ Response status: 200
   ✅ User signed in successfully: test@example.com
   ✅ Session saved to persistent storage
   ```
5. App navigates to MainTabView and you're logged in! ✅

## How Password Works (No Special Setup Needed)

You asked: "Do we need to do something in the app for password handling?"

**Answer: No, nothing special needed in the app!**

Here's how it works:

1. **In Supabase Dashboard** (what you do):
   - Enter email and password when creating user
   - Supabase automatically hashes the password with bcrypt (industry standard)
   - Original password is never stored

2. **In Your App** (what happens automatically):
   - User enters email and password
   - App sends them to Supabase
   - Supabase verifies password matches the stored hash
   - If correct → Returns access token
   - If wrong → Returns "invalid_credentials" error

**The app code is already correct** - no changes needed!

## If Login Still Fails

Use the **Test Login Credentials Script** to diagnose the exact problem:

```bash
cd /Users/markdias/project/FamCal
./TEST_LOGIN_CREDENTIALS.sh
```

Enter your email and password, and the script will tell you exactly:
- ✅ Login successful (credentials are correct)
- ❌ Email not confirmed (need to turn on "Confirm email")
- ❌ Invalid credentials (email or password wrong)
- ❌ User not found (user doesn't exist)
- ❌ Other errors (specific issue description)

## Common Mistakes and How to Fix

### Mistake 1: Creating User Without Confirming Email

**Problem**:
- User created without "Confirm email" toggled ON
- User cannot log in
- Error: "Email not confirmed"

**Fix**:
- Option A: Delete user and create again with "Confirm email" ON
- Option B: Go to Users list → Click user → Toggle "Email confirmed" ON

### Mistake 2: Typo in Email or Password

**Problem**:
- Email or password entered incorrectly when creating user
- Can't log in even with correct attempt
- Error: "Invalid login credentials"

**Fix**:
- Delete the user
- Create new user with correct email/password
- Make sure "Confirm email" is ON

### Mistake 3: Using Confirmation Email

**Note**: Supabase can be configured to send confirmation emails. This is good for production but annoying for testing. For now:
- We're using "Confirm email" toggle in dashboard
- This skips the email confirmation step
- Users can log in immediately

## Checklist for Successful Login

- [ ] User created in Supabase with correct email
- [ ] User created with correct password
- [ ] "Confirm email" was toggled ON when creating user
- [ ] Email is exactly correct (no typos, exact casing)
- [ ] Password is exactly correct (including spaces and special chars)
- [ ] Test script confirms access_token in response
- [ ] App login works with same credentials

## Testing Now

### Quick Test
1. Create a test user with:
   - Email: `test@example.com`
   - Password: `Test123456`
   - Confirm email: ON
2. Build app: `Cmd+B`
3. Run app: `Cmd+R`
4. Log in with those credentials
5. Should see MainTabView immediately

## Important Note About Session Persistence

Once you log in successfully:
1. Session is saved to your device
2. You stay logged in even after closing the app
3. You only need to log in once (unless you manually log out)
4. This is the normal iOS app behavior

To log out, go to Settings → Logout

## Summary

- ✅ Password handling is automatic (Supabase handles it)
- ✅ No special app code needed for passwords
- ✅ Key is toggling "Confirm email" ON when creating users
- ✅ Test script helps diagnose any issues
- ✅ App code is correct and ready to use

Try creating a user again with "Confirm email" ON, and login should work immediately! 🎉
