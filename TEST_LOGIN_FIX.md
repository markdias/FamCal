# Login Fix - Form-Encoded Body

## Problem Found
The Supabase password grant endpoint (`/auth/v1/token`) follows OAuth 2.0 standard which requires:
- `Content-Type: application/x-www-form-urlencoded`
- Form-encoded body: `grant_type=password&email=user@example.com&password=pass123`

We were sending:
- `Content-Type: application/json`
- JSON body: `{"email":"user@example.com","password":"pass123","grant_type":"password"}`

**That's why the server returned HTTP 400 (Bad Request)!**

## Solution Applied
Updated `signIn()` method in `SupabaseAuthManager.swift` to:
1. Set Content-Type to `application/x-www-form-urlencoded`
2. Encode request body as form parameters
3. Properly percent-encode email and password values

## Testing the Fix

### Step 1: Build the App
```bash
xcodebuild build -scheme FamCal -project FamCal.xcodeproj -destination 'generic/platform=iOS Simulator'
```
**Status: ✅ BUILD SUCCEEDED**

### Step 2: Run the App and Test Login
1. Open the app in the iOS Simulator
2. Try logging in with any email and password
3. Check Xcode console output

### Expected Result
If a user exists in Supabase (or after you create one), you should see:
```
ℹ️ Sign-in request: POST https://tzkspidmzlipujsnxpzc.supabase.co/auth/v1/token
ℹ️ Content-Type: application/x-www-form-urlencoded
ℹ️ apikey: eyJhbGciOiJIUzI1Ni...
ℹ️ Body: grant_type=password&email=test@example.com&password=***
ℹ️ Response status: 200
✅ User signed in successfully: test@example.com
```

If the user doesn't exist yet, you'll see the actual error from Supabase:
```
❌ HTTP Status: 400
❌ Full error response: {"error":"invalid_grant","error_description":"Invalid login credentials"}
❌ Parsed error: error: invalid_grant | description: Invalid login credentials
```

### Step 3: If Login Still Fails
The error message will now tell you exactly what's wrong:
- **"invalid_grant"** = User doesn't exist or password is wrong
- **"Email not confirmed"** = User exists but needs email verification
- **"...invalid_bearer_token"** = Authentication system issue

## How to Create a Test User

If you don't have any users yet:

1. Go to https://app.supabase.com
2. Open your project (tzkspidmzlipujsnxpzc)
3. Go to Authentication → Users
4. Click "Create new user"
5. Enter:
   - Email: `test@example.com`
   - Password: `test123456`
   - Toggle "Confirm email" ON
6. Click "Create user"
7. Now try logging in from the app

## Files Modified
- `SupabaseAuthManager.swift` - Line 118-147: Changed signIn to use form-encoded body

## Technical Details
OAuth 2.0 Resource Owner Password Credentials Grant requires:
- Endpoint: POST `/auth/v1/token`
- Content-Type: `application/x-www-form-urlencoded`
- Body parameters: `grant_type`, `email`, `password`
- Response: JSON with `access_token`, `refresh_token`, `user`

This is the standard OAuth 2.0 password grant flow that Supabase GoTrue implements.

## Next Steps
1. ✅ Build app (done)
2. Run app and test login
3. If login works: Test signup and family member creation
4. If login fails: Check the Supabase error message and create test user if needed
