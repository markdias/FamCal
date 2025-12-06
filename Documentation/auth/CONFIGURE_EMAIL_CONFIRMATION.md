# Configure Email Confirmation Redirect URLs

## The Problem

When users click the email confirmation link in Supabase, it redirects to `localhost:3000` instead of your iOS app.

This happens because Supabase has a default redirect URL configured. We need to change it to use an iOS app scheme instead.

## Solution

### Step 1: Set Up App-Specific Redirect URL

We'll use a custom app scheme `famcal://` to handle email confirmation links in your iOS app.

#### Update Info.plist

Add a URL scheme to your app's Info.plist:

1. Open `FamCal/Info.plist` in Xcode (or use Property List editor)
2. Add this key:

**Key**: `URL types`
**Value**: Array with one item:
  - **Item 0**: Dictionary
    - **URL identifier**: `mdias.famcal`
    - **URL Schemes**: Array with one item:
      - **Item 0**: `famcal`

Or add this XML directly to Info.plist:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>mdias.famcal</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>famcal</string>
        </array>
    </dict>
</array>
```

This allows your app to handle links like: `famcal://auth/confirm?token=...`

### Step 2: Configure Supabase Redirect URLs

1. Go to https://app.supabase.com
2. Open your project (tzkspidmzlipujsnxpzc)
3. Click: **Settings** (left sidebar at bottom)
4. Click: **Auth** (under Settings)
5. Scroll down to: **Redirect URLs**
6. Clear the existing URLs
7. Add these redirect URLs:
   ```
   famcal://auth/confirm
   famcal://auth/callback
   ```
   (One per line)
8. Click: **Save**

The settings should look like:

```
Redirect URLs
famcal://auth/confirm
famcal://auth/callback
```

### Step 3: Handle Email Confirmation Link in App

Now when users click the email confirmation link, iOS will open your app with the token. We need to handle this.

Update `FamCalApp.swift` to handle the deep link:

The app already has a `handleDeepLink` method. We just need to make sure it handles email confirmation tokens.

#### Already Implemented

Looking at FamCalApp.swift, you already have:

```swift
.onOpenURL(perform: handleDeepLink(_:))
```

This means the app will receive deep links. We just need to make sure email confirmation is handled.

### Step 4: What Happens Now

1. User receives email confirmation link from Supabase
2. Link looks like: `famcal://auth/confirm?access_token=eyJ...&type=signup`
3. User clicks link
4. iOS opens your app with the token
5. App receives the deep link and processes the token
6. User is automatically logged in with the confirmed email

### Important Notes

**About localhost:3000**:
- That's a default redirect URL Supabase creates
- It's for web apps, not iOS apps
- We're replacing it with `famcal://` scheme
- This won't affect your iOS app - it will use the custom scheme instead

**URL Scheme Format**:
- `famcal://` is the custom scheme
- `auth/confirm` is the path
- Supabase will append parameters like `?access_token=...`
- Your app receives the full URL

**Multiple Redirect URLs**:
- We add both `famcal://auth/confirm` and `famcal://auth/callback`
- Covers different types of authentication flows
- Supabase might use either one depending on the operation

## Testing Email Confirmation

Once configured:

1. Create a new user in Supabase WITHOUT toggling "Confirm email"
   - This time, Supabase will send a confirmation email
2. Check your email inbox (or spam folder)
3. Click the confirmation link
4. iOS should open your FamCal app
5. App should automatically log in the user
6. User appears in MainTabView

## Troubleshooting

### Links still go to localhost:3000

**Solution**:
1. Double-check you saved the changes in Supabase
2. Make sure you added the URL types to Info.plist
3. Rebuild the app (Cmd+B)
4. Try the email link again

### App doesn't open when clicking link

**Solution**:
1. Check that URL scheme is in Info.plist as `famcal`
2. Make sure bundle identifier matches: `mdias.FamCal`
3. Try copying the link and pasting it in Safari: `famcal://auth/confirm`
4. If Safari can't open it, something is wrong with Info.plist setup

### App opens but doesn't log in

**Solution**:
1. Check FamCalApp.swift `handleDeepLink` method
2. Make sure it's handling the auth parameters
3. Add logging to see what parameters are received

## Alternative: Email Confirmation OFF (For Now)

If you want to skip email confirmation for testing, you can:

1. Go to https://app.supabase.com
2. Click: **Settings** → **Auth**
3. Find: **Disable Confirm Email** or similar toggle
4. Turn it ON (if available)

This makes new users automatically confirmed without needing to click a link.

**Trade-off**:
- Easier for testing (no email clicking)
- Less secure for production
- Good for development, bad for real users

## Summary

To fix the localhost:3000 redirect:

1. ✅ Add `famcal://` URL scheme to Info.plist
2. ✅ Configure Supabase Redirect URLs to use `famcal://auth/confirm` and `famcal://auth/callback`
3. ✅ App already handles deep links via `handleDeepLink`
4. ✅ Email confirmation now works with your iOS app

Once these steps are done, email confirmation links will open your app instead of going to localhost! 🎉
