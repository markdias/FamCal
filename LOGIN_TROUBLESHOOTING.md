# Login Troubleshooting Guide

## Problem
You created a user in Supabase but cannot log in with those credentials.

## Most Common Issue: Email Not Confirmed

**Important**: By default, Supabase requires users to confirm their email before they can log in. This is a security feature.

When you created the user in Supabase, you likely saw an option like this:

```
☑ Confirm email
```

**If this checkbox was OFF when you created the user:**
- ❌ User cannot log in
- ❌ Even with correct password, you'll get "Email not confirmed" error
- ✅ Solution: See "How to Fix" section below

**If this checkbox was ON:**
- ✅ User should be able to log in
- If still can't, see troubleshooting steps

## How to Fix

### Option 1: Create a New User with Confirm Email ON (Recommended)

1. Go to https://app.supabase.com
2. Open your project (tzkspidmzlipujsnxpzc)
3. Click: **Authentication** → **Users**
4. Delete the old user (if you want to clean up)
5. Click: **Create new user**
6. Fill in:
   - Email: `your-email@example.com`
   - Password: `YourPassword123`
   - **Toggle "Confirm email" to ON** ← THIS IS IMPORTANT
7. Click: **Create user**
8. Try logging in to the app

### Option 2: Confirm Email on Existing User

If you want to keep the existing user account:

1. Go to https://app.supabase.com
2. Click: **Authentication** → **Users**
3. Find your user in the list
4. Click on them to open their details
5. Look for the **"Confirmed at"** field
6. If it says "Never", click the field to set a confirmation date
7. Or find the **"Email confirmed"** toggle and turn it ON
8. Save changes
9. Try logging in

## Test Your Credentials

Before trying to log in to the app, you can test if your credentials work:

### Method 1: Using the Test Script (Easiest)

```bash
cd /Users/markdias/project/FamCal
./TEST_LOGIN_CREDENTIALS.sh
```

Then enter:
- Email: `your-email@example.com`
- Password: `YourPassword123`

The script will tell you exactly why login is failing.

### Method 2: Using curl (Manual)

```bash
curl -X POST "https://tzkspidmzlipujsnxpzc.supabase.co/auth/v1/token?grant_type=password" \
  -H "Content-Type: application/json" \
  -H "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6a3NwaWRtemxpcHVqc254cHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM4OTI2MTYsImV4cCI6MjA3OTQ2ODYxNn0.QMKZYMrESCOCT0KCHAKhPU995_mIB1F3l4Y4uq8s1uM" \
  -d '{"email":"your-email@example.com","password":"YourPassword123"}'
```

If successful, you'll see:
```json
{
  "access_token": "eyJ...",
  "token_type": "bearer",
  "expires_in": 3600,
  "refresh_token": "...",
  "user": {
    "id": "...",
    "email": "your-email@example.com"
  }
}
```

If it fails, you'll see an error message like:
```json
{
  "error_code": "invalid_credentials",
  "msg": "Invalid login credentials"
}
```

## Common Errors and Solutions

### "Email not confirmed"

**Cause**: User was created without confirming their email

**Solutions**:
1. Go to Supabase dashboard → Users
2. Find your user
3. Toggle "Email confirmed" to ON
4. Or create a new user with "Confirm email" checkbox ON

### "Invalid login credentials"

**Cause**: Email or password is wrong

**Check**:
1. Is email exactly correct? (typos, extra spaces, wrong casing)
2. Is password exactly correct? (including caps, special chars)
3. Does the user exist in Supabase?

**Solutions**:
1. Double-check email and password
2. Delete and recreate the user with correct credentials
3. Use the test script to verify credentials work

### "User not found"

**Cause**: User doesn't exist in Supabase

**Solutions**:
1. Create a new user account
2. Make sure to toggle "Confirm email" ON
3. Use correct email/password combo

## How Password Works in Supabase

**Important**: Supabase stores passwords securely using bcrypt (industry standard). Here's what happens:

1. **User Creation**: You enter password in Supabase dashboard
   - Password is hashed with bcrypt (one-way encryption)
   - Original password is never stored
   - Only hash is saved in database

2. **User Login**: User enters email and password in app
   - App sends email + password to Supabase
   - Supabase compares hash of entered password with stored hash
   - If hashes match → Login succeeds
   - If hashes don't match → Login fails

3. **Password Reset**: User forgets password
   - User clicks "Forgot Password?"
   - Email is sent to user with reset link
   - User clicks link and sets new password
   - New password is hashed and stored

**You don't need to do anything special in the app** - the password handling is all done by Supabase automatically.

## Quick Checklist

- [ ] User was created in Supabase with correct email
- [ ] User was created with "Confirm email" toggled ON
- [ ] Email is exactly correct (no typos)
- [ ] Password is exactly correct
- [ ] Test script confirms credentials work (`access_token` in response)
- [ ] Try logging in to the app

## Still Stuck?

1. Run the test script: `./TEST_LOGIN_CREDENTIALS.sh`
2. Share the exact error message from the script
3. Check Supabase dashboard to confirm user exists and is confirmed
4. Try creating a brand new test user with a simple email like `test@example.com` and password like `Test123456`

The test script will give you the exact reason why login is failing. Use that to fix the issue!
