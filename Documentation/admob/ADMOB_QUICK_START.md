# AdMob Integration - Quick Start

## 🚀 TL;DR - Get Running in 5 Minutes

### Your AdMob Credentials
```
App ID:     ca-app-pub-6842193682076971~7907201759
Ad Unit ID: ca-app-pub-6842193682076971/5907724370
```

### Step 1: Install Dependencies (2 minutes)
```bash
cd /Users/markdias/project/FamCal
pod install
```

### Step 2: Configure Info.plist (1 minute)
Open `FamCal/Info.plist` and add:
```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-6842193682076971~7907201759</string>
```

### Step 3: Use the Workspace (1 minute)
Close `FamCal.xcodeproj` and open `FamCal.xcworkspace` instead:
```bash
open FamCal.xcworkspace
```

### Step 4: Build & Test (1 minute)
```bash
⌘B to build
⌘R to run on simulator/device
```

✅ **Done!** Ads will now display for free users.

---

## What Was Done

### Files Created (1 new file)
- **GoogleMobileAdsView.swift** - SwiftUI wrapper for Google Mobile Ads

### Files Modified (3 files)
- **FamCalApp.swift** - Initialize SDK
- **FamilyView.swift** - Add banner to dashboard
- **CalendarView.swift** - Add banner to monthly calendar

### Where Ads Appear
1. **FamilyView** (Dashboard) - Bottom of scroll view
2. **CalendarView** (Calendar) - Below calendar grid in month view

### Who Sees Ads
- ✅ Free users → See ads
- ❌ Pro users → No ads (hidden automatically)

---

## Expected Behavior

### On Simulator
- Test ads appear (Google's placeholder ads)
- Console shows: `✅ Banner ad received successfully`

### On Device
- Real ads appear (if app approved in AdMob)
- Banner 320x50 pixels, theme-integrated

### Console Output
```
📱 Google Mobile Ads SDK initialized
✅ Banner ad received successfully
👀 Banner ad impression recorded  (when user views ad)
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Module not found" | Run `pod install`, open `.xcworkspace` |
| App crashes | Check Info.plist has AdMob App ID |
| No ads showing | Check free user status (`isProUser`) |
| Ads not loading | Check internet, verify Ad Unit ID |
| Pro user sees ads | Force quit app and relaunch |

---

## Complete Documentation

For detailed setup, configuration, and advanced options:
- 📖 **ADMOB_SETUP_GUIDE.md** - Full setup instructions
- 📋 **ADMOB_IMPLEMENTATION_SUMMARY.md** - What was implemented

---

## Next Actions

1. ✅ Run `pod install`
2. ✅ Update Info.plist with App ID
3. ✅ Open .xcworkspace file
4. ✅ Build and test
5. ✅ Update privacy policy
6. ✅ Submit for AdMob approval (if needed)

---

## Key Points

- **Non-Intrusive**: Ads at bottom, don't block content
- **Themeable**: Ads adapt to light/dark mode
- **Pro-Friendly**: Pro users get zero ads
- **Safe**: Error handling for load failures
- **Fast**: Minimal performance impact

---

**Questions?** See the full ADMOB_SETUP_GUIDE.md for troubleshooting and details.
