# Test the Login Fix Right Now 🚀

## 3 Simple Steps

### Step 1: Create a Test User in Supabase (3 min)
1. Open https://app.supabase.com in your browser
2. Open your project (tzkspidmzlipujsnxpzc)
3. Click: **Authentication** (left sidebar)
4. Click: **Users**
5. Click: **Create new user** (top right button)
6. Fill in the form:
   - Email: `test@example.com`
   - Password: `Test123456`
   - ✅ Toggle: "Confirm email" (turn it ON)
7. Click: **Create user**

That's it! The user is created.

### Step 2: Build & Run the App (2 min)
```bash
# In your terminal at the FamCal directory:
xcodebuild build -scheme FamCal -project FamCal.xcodeproj -destination 'generic/platform=iOS Simulator'
```

Or in Xcode:
1. Click the play button (run)
2. Select an iPhone simulator
3. Wait for the app to launch

### Step 3: Test Login (1 min)
1. The app should show the LoginView
2. Enter email: `test@example.com`
3. Enter password: `Test123456`
4. Tap: **Sign In**

## What You Should See

### In the App
✅ Loading spinner appears briefly
✅ No error alert
✅ App navigates away from LoginView
✅ App shows MainTabView or OnboardingView

### In Xcode Console
Look for these messages (Xcode menu: View → Debug Area → Show Debug Area):
```
ℹ️ Sign-in request: POST https://tzkspidmzlipujsnxpzc.supabase.co/auth/v1/token?grant_type=password
ℹ️ Content-Type: application/json
ℹ️ apikey: eyJhbGciOi...
ℹ️ Body: {"email":"test@example.com","password":"***"}
ℹ️ Response status: 200
✅ User signed in successfully: test@example.com
```

## What This Means

| Result | Status |
|--------|--------|
| ✅ Successfully logged in + navigated away | **FIX WORKS!** |
| ❌ Error alert with "Invalid login credentials" | User wasn't created properly, try Step 1 again |
| ❌ Error alert with "AuthError 400" | Something else is wrong, check console logs |
| ❌ App crashes | Code issue, check console for Swift error |

## If Login Fails

### "Invalid login credentials" Error
- The endpoint format is working (good news!)
- But the user doesn't exist
- **Solution:** Go back to Step 1 and verify:
  - Email is exactly: `test@example.com`
  - Password is exactly: `Test123456`
  - "Confirm email" toggle is ON
  - You clicked "Create user" successfully

### Still Getting "AuthError 400"
- **Check:** Did you run the new code? (Step 2 - rebuild)
- **Check:** Look at Xcode console for the exact error message
- **Report:** Share the console error message

### App Crashes
- **Check:** Xcode console for Swift error details
- **This is separate** from the login endpoint fix

## Troubleshooting

### Can't find Xcode Console
```
Xcode → View → Debug Area → Show Debug Area
(or: Cmd+Shift+Y)
```

### Need to rebuild
```bash
xcodebuild clean -scheme FamCal -project FamCal.xcodeproj
xcodebuild build -scheme FamCal -project FamCal.xcodeproj -destination 'generic/platform=iOS Simulator'
```

### Wrong project/scheme
Make sure you're using:
- Project: `FamCal.xcodeproj`
- Scheme: `FamCal`
- Destination: `iOS Simulator`

## Success Criteria

✅ You see "✅ User signed in successfully" in console
✅ App shows MainTabView or OnboardingView
✅ No error alerts
✅ No app crashes

**If all above ✅ then the fix is working!**

---

That's it! The fix is complete. Just follow these 3 steps to verify it works.
