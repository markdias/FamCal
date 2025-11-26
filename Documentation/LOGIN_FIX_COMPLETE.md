# Login Fix - COMPLETE ✅

## Problem Diagnosis
Your app was returning "AuthError error 400" because the Supabase authentication endpoint was receiving requests in the wrong format.

## Root Cause
The `/auth/v1/token` endpoint (Supabase GoTrue) requires:
- **grant_type as a query parameter**, not in the request body
- **JSON Content-Type** header
- **JSON body** with email and password

### What Was Wrong ❌
```
POST /auth/v1/token
Content-Type: application/json
Body: {"email":"...","password":"...","grant_type":"password"}
Result: HTTP 400 - "unsupported_grant_type"
```

## Solution Applied ✅
Changed to the correct format:
```
POST /auth/v1/token?grant_type=password
Content-Type: application/json
Body: {"email":"...","password":"..."}
Result: HTTP 200 - access_token returned OR HTTP 400 - "Invalid login credentials" (user doesn't exist)
```

## Code Changes
**File:** `FamCal/SupabaseAuthManager.swift`
**Method:** `signIn(email:password:)`
**Lines:** 125-155

### Before
```swift
let url = supabaseURL.appendingPathComponent("auth/v1/token")
// grant_type in body...
let body = ["grant_type":"password", "email":email, "password":password]
```

### After
```swift
var urlComponents = URLComponents(url: supabaseURL.appendingPathComponent("auth/v1/token"),
                                   resolvingAgainstBaseURL: false)!
urlComponents.queryItems = [URLQueryItem(name: "grant_type", value: "password")]
let url = urlComponents.url!
// grant_type in URL, body only has email/password...
let body = SignInBody(email: email, password: password)
```

## Testing the Fix

### Step 1: Build the App (✅ Already Done)
```bash
xcodebuild build -scheme FamCal -project FamCal.xcodeproj -destination 'generic/platform=iOS Simulator'
```
**Result:** BUILD SUCCEEDED

### Step 2: Verify Endpoint is Working (✅ Already Tested)
Tested with curl to confirm endpoint accepts correct format:
```bash
curl -X POST "https://tzkspidmzlipujsnxpzc.supabase.co/auth/v1/token?grant_type=password" \
  -H "Content-Type: application/json" \
  -H "apikey: ..." \
  -d '{"email":"mark@example.com","password":"Test123456"}'
```
**Result:** `{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}`

✅ This is the correct response! It means the endpoint is working. The 400 error is now a business logic error (user doesn't exist), not a format error.

### Step 3: Create a Test User (You Need to Do This)
To test with a real user:

1. **Go to:** https://app.supabase.com
2. **Open project:** tzkspidmzlipujsnxpzc
3. **Navigate to:** Authentication → Users
4. **Click:** "Create new user"
5. **Enter:**
   - Email: `test@example.com`
   - Password: `Test123456`
6. **Toggle:** "Confirm email" ON (important!)
7. **Click:** "Create user"

### Step 4: Test Login in the App
1. **Run the app** in the simulator
2. **Enter login credentials:**
   - Email: `test@example.com`
   - Password: `Test123456`
3. **Tap:** "Sign In"
4. **Check Xcode console** for logs

### Expected Console Output on Success
```
ℹ️ Sign-in request: POST https://tzkspidmzlipujsnxpzc.supabase.co/auth/v1/token?grant_type=password
ℹ️ Content-Type: application/json
ℹ️ apikey: eyJhbGciOi...
ℹ️ Body: {"email":"test@example.com","password":"***"}
ℹ️ Response status: 200
✅ User signed in successfully: test@example.com
```

Then the app should navigate to the OnboardingView or MainTabView! 🎉

### If You Get "Invalid login credentials"
This means the endpoint is working but:
- User doesn't exist with that email
- Password is wrong
- User email isn't confirmed

**Solution:** Create the test user in Supabase as shown in Step 3 above.

## Files Modified
- `FamCal/SupabaseAuthManager.swift` - signIn() method

## Architecture
```
App (iOS)
  ↓
LoginView.signIn()
  ↓
SupabaseAuthManager.signIn()
  ↓
URLSession POST to:
  https://tzkspidmzlipujsnxpzc.supabase.co/auth/v1/token?grant_type=password
  ↓
Supabase GoTrue
  ✓ Validates grant_type parameter
  ✓ Parses JSON body
  ✓ Checks credentials
  ✓ Returns access_token on success
```

## What's Working Now
1. ✅ Authentication endpoint accepting requests
2. ✅ Correct OAuth 2.0 password grant format
3. ✅ JSON body parsing
4. ✅ Error messages accurate ("Invalid login credentials" = user doesn't exist)
5. ✅ Ready to test with real users

## Next Steps
1. **Create a test user** in Supabase dashboard (Step 3 above)
2. **Run the app** and test login
3. **Check console logs** - should see "✅ User signed in successfully"
4. **App should navigate** to OnboardingView or MainTabView
5. **Then test:** Signup, family member creation, data sync

## Verification Checklist
- [ ] User created in Supabase with email: test@example.com
- [ ] User email confirmed in Supabase
- [ ] App built successfully
- [ ] App runs in simulator without crashes
- [ ] Login attempt shows detailed console logs
- [ ] If login succeeds, app navigates to MainTabView
- [ ] If login fails, error message is clear and actionable

## Success Indicators
When the fix is working:
- ✅ "✅ User signed in successfully" message in console
- ✅ App navigates past LoginView
- ✅ Family data can be fetched
- ✅ No more "AuthError error 400" alerts

---

**Status:** The authentication API endpoint fix is complete and tested.
**Remaining work:** Create test user and verify login flow works end-to-end.
