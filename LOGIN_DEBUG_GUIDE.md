# Login Error 400 - Debugging Guide

## Issue
When attempting to log in with email and password, the app returns:
```
Login Error
the operation could not be completed
AuthError error 400
```

## Root Cause Analysis
HTTP 400 (Bad Request) means the Supabase API rejected the request. Likely causes:
1. **Database schema not created** - The most likely cause. SQL schema from `SUPABASE_SETUP_INSTRUCTIONS.md` hasn't been executed in Supabase
2. **Email/password auth not enabled** in Supabase project settings
3. **Invalid Supabase credentials** in SupabaseConfig.swift
4. **CORS issues** (unlikely since signup worked with 201 response)

## What Was Just Changed
Improved error logging in SupabaseAuthManager.swift to help diagnose the issue:

### Added Logging (lines 139-141)
```swift
print("ℹ️ Sign-in request: POST \(url.absoluteString)")
print("ℹ️ Headers: Content-Type=application/json, apikey=\(anonKey.prefix(20))...")
print("ℹ️ Body: email=\(email), grant_type=password")
```

### Improved Error Response Parsing (lines 154-162)
- Prints HTTP status code
- Prints full error response body
- Attempts to parse and display specific error message
- Falls back through multiple error message fields

## How to Debug

### Step 1: Build and Run the App
```bash
# Build for iOS Simulator
xcodebuild build -scheme FamCal -project /Users/markdias/project/FamCal/FamCal.xcodeproj -destination 'generic/platform=iOS Simulator'

# Or use Xcode directly:
# 1. Open FamCal.xcodeproj
# 2. Select FamCal scheme
# 3. Select an iOS Simulator destination
# 4. Press Cmd+B to build, then Cmd+R to run
```

### Step 2: Try Logging In and Check Console
1. App starts → go to Login screen
2. Enter test email and password (any values)
3. Tap "Sign In"
4. Look at Xcode console for detailed logs

You should see something like:
```
ℹ️ Sign-in request: POST https://tzkspidmzlipujsnxpzc.supabase.co/auth/v1/token
ℹ️ Headers: Content-Type=application/json, apikey=eyJhbGciOiJI...
ℹ️ Body: email=test@example.com, grant_type=password
❌ HTTP Status: 400
❌ Error response body: {"error":"invalid_grant","error_description":"..."}
❌ Parsed error message: invalid_grant: ...
```

**The key information is in the "Parsed error message" line** - this tells us exactly why Supabase rejected the request.

### Step 3: Check Supabase Configuration
Verify your Supabase project is properly configured:

1. **Access your Supabase dashboard:**
   - Go to https://app.supabase.com
   - Find project: `tzkspidmzlipujsnxpzc`

2. **Verify email/password auth is enabled:**
   - Go to Settings → Authentication
   - Check "Email" provider is enabled
   - Look for any configuration issues

3. **Verify database schema exists:**
   - Go to SQL Editor
   - Run: `SELECT * FROM profiles LIMIT 1;`
   - If table doesn't exist, run ALL SQL from SUPABASE_SETUP_INSTRUCTIONS.md

### Step 4: Verify Database Schema Was Created
The most likely cause of a 400 error is that the database schema hasn't been created yet. To check:

1. Go to https://app.supabase.com and open your project
2. Go to "SQL Editor"
3. Run this query:
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' ORDER BY table_name;
```

**Expected result:** You should see these tables:
- family_member_calendars
- family_members
- profiles
- shared_calendars

**If you don't see these tables:**
- The schema hasn't been created yet
- Go to SQL Editor and run ALL the SQL from SUPABASE_SETUP_INSTRUCTIONS.md in order
- This includes: tables, RLS policies, and auth trigger

### Step 5: Create Test User in Supabase Dashboard
If the schema exists, test authentication directly:

1. Go to Authentication → Users
2. Click "Create new user"
3. Enter test email: `test@example.com`
4. Enter password: `test123456`
5. Confirm the email (toggle the email verified switch)
6. Try logging in from the app with these credentials

### Step 6: Check Supabase Logs
For more details on why the request failed:

1. Go to Supabase dashboard
2. Look for "Logs" or "Analytics" section
3. Check authentication logs for the failed login attempt
4. This will show the exact error reason

## Expected Success
When login works, you should see:
```
ℹ️ Sign-in request: POST ...
✅ User signed in successfully: test@example.com
```

And the app should navigate to the MainTabView.

## Common Error Messages and Solutions

### "Invalid grant type"
- **Cause**: Request body has wrong format
- **Fix**: Verify the `grant_type` field is exactly `"password"`

### "Missing email parameter"
- **Cause**: Email field is empty or null
- **Fix**: Verify email validation in LoginView

### "Invalid email or password"
- **Cause**: User doesn't exist or password is wrong
- **Fix**: Create test user in Supabase dashboard or use signup

### "Email not confirmed"
- **Cause**: User exists but email verification required
- **Fix**: Check Supabase auth settings - may need to disable email verification for testing

### "Database connection error"
- **Cause**: Supabase database schema not created
- **Fix**: Run SQL schema from SUPABASE_SETUP_INSTRUCTIONS.md

## SQL Schema Status
To verify the database is set up:

```sql
-- Run this in Supabase SQL Editor
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public';
```

You should see:
- `profiles`
- `family_members`
- `family_member_calendars`
- `shared_calendars`

If any are missing, run the full setup from SUPABASE_SETUP_INSTRUCTIONS.md.

## Next Steps

1. **Try login with improved error logging** and check the console output
2. **Review the actual error message** from Supabase
3. **Verify database schema** is created in Supabase
4. **Report the exact error message** you see in Xcode console
5. Once login works, test with multiple users to verify data isolation

## Files Modified
- `SupabaseAuthManager.swift` - Enhanced error logging in signIn and signUp methods

## Key Configuration
- Supabase URL: `https://tzkspidmzlipujsnxpzc.supabase.co`
- Auth Endpoint: `{url}/auth/v1/token`
- Your anon key is configured in SupabaseConfig.swift
