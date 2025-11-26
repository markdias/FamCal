# AdMob Integration Setup Guide

## Overview
This guide walks you through integrating Google Mobile Ads SDK into FamCal for displaying banner ads to free-tier users.

### Your AdMob Credentials
- **App ID**: `ca-app-pub-6842193682076971~7907201759`
- **Banner Ad Unit ID**: `ca-app-pub-6842193682076971/5907724370`
- **Ad Size**: Standard banner (320x50)

---

## Step 1: Install Google Mobile Ads SDK via CocoaPods

### Option A: Create a Podfile (Recommended for Easy Management)

1. **Navigate to your project directory**:
   ```bash
   cd /Users/markdias/project/FamCal
   ```

2. **Initialize CocoaPods** (if not already initialized):
   ```bash
   pod repo update
   ```

3. **Create a Podfile**:
   ```bash
   pod init
   ```

4. **Edit the Podfile**:
   Open `Podfile` in your preferred editor and add:
   ```ruby
   target 'FamCal' do
     pod 'Google-Mobile-Ads-SDK'
   end
   ```

5. **Install dependencies**:
   ```bash
   pod install
   ```

6. **Close your current Xcode project** and **open the generated `.xcworkspace` file**:
   ```bash
   open FamCal.xcworkspace
   ```

### Option B: Add via SPM (Swift Package Manager)
If you prefer to avoid CocoaPods, you can try the unofficial Swift Package:
- Add `https://github.com/google/google-mobile-ads-swift.git` via Xcode's package manager
- However, the official CocoaPods version is more stable and recommended

---

## Step 2: Configure Info.plist

Add your Google AdMob App ID to `Info.plist`:

1. Open `FamCal/Info.plist` (or `Info.plist` in your project)
2. Add the following key-value pair:
   ```xml
   <key>GADApplicationIdentifier</key>
   <string>ca-app-pub-6842193682076971~7907201759</string>
   ```

---

## Step 3: Build & Test

### Build the Project
```bash
xcodebuild build -workspace FamCal.xcworkspace -scheme FamCal
```

### Running on Simulator
- The app will attempt to load ads
- On simulator, Google Mobile Ads SDK will show test ads by default (safe for development)

### Running on Device
- Ads will display normally on real devices
- Free users will see ads at the bottom of:
  - **FamilyView** (main dashboard)
  - **CalendarView** (monthly view only)
- Pro users will see NO ads (hidden by `appSettingsManager.isProUser` check)

---

## AdMob Placement Details

### Banner Locations
1. **FamilyView** (`FamilyView.swift:202-208`)
   - Located at the bottom of the scroll view
   - Hidden above floating controls
   - Only visible to free users

2. **CalendarView** (`CalendarView.swift:262-270`)
   - Located below the calendar grid
   - Only shown in month view (not in day view)
   - Only visible to free users

### Ad Unit Configuration
- **Size**: Standard Banner (320x50)
- **Ad Unit ID**: `ca-app-pub-6842193682076971/5907724370`
- **Theme Integration**: Adapts to app's current theme
- **Safe Area**: Respects safe areas and notches

---

## Implementation Components

### 1. GoogleMobileAdsView.swift
- **UIViewRepresentable** wrapper that bridges UIKit GADBannerView to SwiftUI
- Handles:
  - Ad loading and error handling
  - GADBannerViewDelegate callbacks (impressions, clicks)
  - Pro user exemption (returns empty view if `isProUser == true`)
  - Lifecycle management

**Key Methods**:
- `makeUIView()` - Creates and configures GADBannerView
- `updateUIView()` - Updates delegate references
- Delegate methods for logging ad events

### 2. AdBannerContainer
- **SwiftUI View** that wraps GoogleMobileAdsView
- Provides proper sizing, theming, and padding
- Conditionally renders based on `isProUser`

### 3. FamCalApp.swift Integration
- Initializes Google Mobile Ads SDK on app launch: `GADMobileAds.sharedInstance().start()`
- Ensures SDK is ready before ads are requested

### 4. View Integrations
- **FamilyView**: Adds AdBannerContainer to main scroll view
- **CalendarView**: Adds AdBannerContainer to content view (month mode only)

---

## AdMob Policy Compliance

### What We're Doing Right ✅
- **Proper Spacing**: 16px horizontal padding, proper vertical spacing
- **Clear Ad Labels**: AdMob banners are labeled as ads (built-in)
- **Non-Intrusive**: Placed at bottom of content, doesn't interfere with primary actions
- **Safe Area**: Respects safe areas and device notches
- **Pro Exemption**: Pro users see zero ads
- **Error Handling**: Graceful degradation if ads fail to load
- **No Forced Clicks**: Users can easily dismiss or scroll past ads
- **Proper SDK Usage**: Using official Google Mobile Ads SDK

### What You Must Do ⚠️
1. **Keep Privacy Policy Updated**
   - Update your app's privacy policy to disclose ad serving
   - Mention "Google Mobile Ads" and "personalized ads"

2. **Comply with Google Play Policies**
   - Ads must not be the primary focus of the app
   - Users should be able to use the app's core features without viewing ads
   - ✅ FamCal complies: calendar and family management work ad-free

3. **Avoid**
   - ❌ Misleading ad placement (we don't do this)
   - ❌ Clicking ads programmatically (we don't do this)
   - ❌ Ads covering critical UI (we don't do this)
   - ❌ Forcing users to view ads (we don't do this)

---

## Testing the Integration

### On Simulator
```swift
// Ads will show test placeholder (safe)
// Check Xcode console for: "✅ Banner ad received successfully"
```

### On Device
```swift
// Ads will load real ads
// Monitor console for:
// - "✅ Banner ad received successfully" (success)
// - "❌ Banner ad failed to load: ..." (error)
// - "👀 Banner ad impression recorded" (user view)
```

### Test Scenarios

#### Scenario 1: Free User (Normal)
1. Ensure `AppSettingsManager.isProUser == false`
2. Navigate to FamilyView
3. Scroll to bottom → **Ad banner appears**
4. Navigate to CalendarView → Month mode → **Ad banner appears below calendar**
5. Switch to Day mode → **Ad banner disappears** (by design)

#### Scenario 2: Pro User
1. Set `AppSettingsManager.isProUser == true` (via Settings > Test Only > Pro enabled)
2. Navigate to FamilyView → **No ad banner**
3. Navigate to CalendarView → **No ad banner**
4. This is correct behavior (Pro users get ad-free experience)

#### Scenario 3: Ad Loading Failure
1. Disconnect internet temporarily
2. Watch console for error message
3. Ad section gracefully hides (no UI crash)
4. Reconnect internet → Ad reloads

---

## Troubleshooting

### Issue: "Module 'GoogleMobileAds' not found"
**Solution**:
1. Ensure you ran `pod install`
2. Close Xcode completely
3. Delete `Pods/` folder and `Podfile.lock`
4. Run `pod install` again
5. Open `.xcworkspace` file (not `.xcodeproj`)

### Issue: Ads not loading on device
**Solution**:
1. Check Info.plist has `GADApplicationIdentifier` key
2. Verify Ad Unit ID is correct in code
3. Ensure device has internet connection
4. Check Google AdMob console for approval status
5. Test with test device ID (generate in AdMob console)

### Issue: Ads not showing for free users
**Solution**:
1. Verify `appSettingsManager.isProUser == false`
2. Check that ad unit ID is correctly passed to AdBannerContainer
3. Review console logs for load failures
4. Ensure user is not in Pro testing mode

### Issue: Pro users still see ads
**Solution**:
1. Check if `isProUser` is being set correctly
2. Force app refresh (swipe up in iOS switcher, relaunch)
3. Check UserDefaults for Pro status: `AppSettingsManager.shared.isProUser`

---

## Next Steps

### Optional Enhancements
1. **Interstitial Ads**: Add full-screen ads on specific actions
2. **Rewarded Ads**: Offer users premium features for watching ads
3. **Native Ads**: Custom-designed ads that match your UI
4. **Custom Event Tracking**: Log when users click ads for analytics

### Monitoring
1. **AdMob Console**: https://admob.google.com
   - Monitor impressions and clicks
   - Check revenue reports
   - View performance metrics
   - Test ad behavior with test device IDs

2. **Xcode Console**:
   - Watch for ad load success/failure logs
   - Monitor for any SDK warnings

---

## Important Notes

### Privacy & GDPR
- Google Mobile Ads SDK respects GDPR settings
- Users in EU may see non-personalized ads
- Your privacy policy must disclose ad serving

### Code Changes Made

1. **GoogleMobileAdsView.swift** (NEW)
   - UIViewRepresentable wrapper for GADBannerView
   - Handles SDK delegate callbacks

2. **AdBannerContainer** (NEW)
   - SwiftUI container for GoogleMobileAdsView
   - Conditional rendering based on Pro status

3. **FamCalApp.swift** (MODIFIED)
   - Added `import GoogleMobileAds`
   - Added SDK initialization: `GADMobileAds.sharedInstance().start()`

4. **FamilyView.swift** (MODIFIED)
   - Added AdBannerContainer to main scroll view (lines 202-208)

5. **CalendarView.swift** (MODIFIED)
   - Added AdBannerContainer to content view (lines 262-270)
   - Only shows in month mode for better UX

---

## Support

For issues with Google Mobile Ads SDK:
- **Official Docs**: https://developers.google.com/admob/ios/quick-start
- **Google AdMob Support**: https://support.google.com/admob
- **Community**: Stack Overflow tag: `google-mobile-ads-sdk`

---

## Checklist Before Launch

- [ ] CocoaPods installed and dependencies updated
- [ ] Info.plist configured with AdMob App ID
- [ ] GoogleMobileAdsView.swift created
- [ ] AdBannerContainer created
- [ ] FamCalApp.swift updated with SDK initialization
- [ ] FamilyView updated with ad banner
- [ ] CalendarView updated with ad banner
- [ ] Tested on simulator (test ads should appear)
- [ ] Tested on device (real ads should appear for eligible devices)
- [ ] Pro user testing (verified ads hidden for Pro users)
- [ ] AdMob account verified (app and ad units approved)
- [ ] Privacy policy updated to mention ads
- [ ] Google Play Console app listing updated

---

**Last Updated**: November 24, 2025
**iOS Minimum Version**: iOS 14+
**Google Mobile Ads SDK**: Latest version (installed via CocoaPods)
