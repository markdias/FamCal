# AdMob Integration - Deployment Checklist

Use this checklist to track your progress through setup, testing, and deployment.

---

## Phase 1: Local Setup (5 minutes)

### Installation & Configuration
- [ ] Read ADMOB_QUICK_START.md for overview
- [ ] Navigate to project: `cd /Users/markdias/project/FamCal`
- [ ] Run CocoaPods: `pod install`
- [ ] Verify Pods/ folder created and Podfile.lock generated
- [ ] Close current Xcode project window
- [ ] Open `.xcworkspace` file (not `.xcodeproj`)
  ```bash
  open FamCal.xcworkspace
  ```

### Info.plist Configuration
- [ ] Open `FamCal/Info.plist` in Xcode
- [ ] Add new key-value pair:
  - **Key**: `GADApplicationIdentifier`
  - **Value**: `ca-app-pub-6842193682076971~7907201759`
- [ ] Save file (Xcode auto-saves)
- [ ] Verify change was saved

### Code Verification
- [ ] Verify GoogleMobileAdsView.swift exists at `FamCal/GoogleMobileAdsView.swift`
- [ ] Verify FamCalApp.swift includes:
  - [ ] `import GoogleMobileAds`
  - [ ] `GADMobileAds.sharedInstance().start()` in init()
- [ ] Verify FamilyView.swift includes AdBannerContainer
- [ ] Verify CalendarView.swift includes AdBannerContainer

---

## Phase 2: Build & Compile (5 minutes)

### Initial Build
- [ ] Clean build folder: ⌘⇧K
- [ ] Build project: ⌘B
- [ ] Verify build succeeds without errors
- [ ] Check for warnings (optional, but recommended)
- [ ] Verify no linking errors related to GoogleMobileAds

### Build Artifacts
- [ ] Verify `Pods/` folder has Google-Mobile-Ads-SDK
- [ ] Verify `Pods/Pods.xcodeproj` exists
- [ ] Verify `Podfile.lock` exists

---

## Phase 3: Simulator Testing (10 minutes)

### Simulator Preparation
- [ ] Select simulator target: iPhone 15 (or any iOS 14+)
- [ ] Build for simulator: ⌘B
- [ ] Launch simulator: ⌘R
- [ ] Wait for app to fully load

### Functionality Testing - Free User

#### FamilyView (Dashboard)
- [ ] App launches without crashes
- [ ] FamilyView displays normally
- [ ] Scroll to bottom of event list
- [ ] **Verify ad banner appears** ✓
- [ ] Ad banner is 320x50 pixels
- [ ] Ad banner has rounded corners
- [ ] Ad has proper spacing from edges
- [ ] Check Xcode console for:
  - [ ] `📱 Google Mobile Ads SDK initialized`
  - [ ] `✅ Banner ad received successfully` or `❌ Banner ad failed to load`

#### CalendarView (Monthly View)
- [ ] Navigate to Calendar tab
- [ ] Verify month view is displayed
- [ ] Scroll to bottom
- [ ] **Verify ad banner appears below calendar** ✓
- [ ] Switch to day view
- [ ] **Verify ad banner disappears in day view** ✓
- [ ] Switch back to month view
- [ ] **Verify ad banner reappears** ✓

### Functionality Testing - Pro User

#### Enable Pro Mode for Testing
- [ ] Navigate to Settings
- [ ] Find "Testing" section (or equivalent)
- [ ] Enable "Pro enabled via Settings > Test Only"
- [ ] Go back to FamilyView

#### Verify No Ads for Pro Users
- [ ] Navigate to FamilyView
- [ ] Scroll to bottom
- [ ] **Verify NO ad banner appears** ✓
- [ ] Navigate to CalendarView (month view)
- [ ] Scroll to bottom
- [ ] **Verify NO ad banner appears** ✓
- [ ] Force quit app: Swipe up from bottom
- [ ] Relaunch app
- [ ] Verify Pro setting persisted
- [ ] **Verify NO ads** ✓

#### Disable Pro Mode
- [ ] Go back to Settings
- [ ] Disable Pro mode
- [ ] Force quit and relaunch
- [ ] **Verify ads reappear** ✓

### Console Monitoring
- [ ] Open Xcode console (⌘⇧C)
- [ ] Filter for "Ad" or "GAD" messages
- [ ] Expected logs:
  - [ ] `📱 Google Mobile Ads SDK initialized`
  - [ ] `✅ Banner ad received successfully` (successful ad load)
  - [ ] `👀 Banner ad impression recorded` (user viewed ad)
- [ ] No crashes in console
- [ ] No unrecognized selector errors
- [ ] No memory warnings

---

## Phase 4: Device Testing (15 minutes)

### Device Preparation
- [ ] Connect physical iPhone/iPad (iOS 14+)
- [ ] Trust device in Xcode
- [ ] Select device as build target
- [ ] Build for device: ⌘B

### Device Build
- [ ] Build succeeds on device
- [ ] App installs without errors
- [ ] App launches successfully
- [ ] No provisioning profile errors

### Device Testing - Free User

#### Basic Functionality
- [ ] App opens without crashes
- [ ] FamilyView loads family events
- [ ] CalendarView displays calendar

#### Ad Display on Device
- [ ] Navigate to FamilyView
- [ ] Scroll to bottom
- [ ] **Real ads appear** (not test ads) ✓
  - (Or test placeholder if app not approved yet)
- [ ] Ad banner size looks correct
- [ ] Ad text is readable
- [ ] Ad is clickable (optional to test)

#### Calendar View Ad
- [ ] Navigate to Calendar
- [ ] Ensure month view selected
- [ ] Scroll to bottom
- [ ] **Ads appear in month view** ✓
- [ ] Switch to day view
- [ ] **Ads disappear in day view** ✓

### Device Testing - Pro User
- [ ] Enable Pro mode in Settings
- [ ] Force quit app
- [ ] Relaunch app
- [ ] Navigate to FamilyView
- [ ] **Verify NO ads** ✓
- [ ] Navigate to CalendarView
- [ ] **Verify NO ads** ✓
- [ ] Disable Pro mode
- [ ] Force quit
- [ ] Relaunch
- [ ] **Verify ads reappear** ✓

### Console Output (Device)
- [ ] Connect device
- [ ] Open Window > Devices and Simulators
- [ ] View device console
- [ ] Expected logs same as simulator:
  - [ ] `📱 Google Mobile Ads SDK initialized`
  - [ ] `✅ Banner ad received successfully`

---

## Phase 5: Compliance & Documentation (20 minutes)

### Privacy Policy
- [ ] Review app's existing privacy policy
- [ ] Add section about ad serving:
  - [ ] Mention Google Mobile Ads
  - [ ] Explain data sharing with Google
  - [ ] Explain personalization/opt-out
  - [ ] GDPR compliance statement (if EU target)
- [ ] Update version date
- [ ] Test link to updated policy (if hosted online)

### Google AdMob Account
- [ ] Log in to AdMob console: https://admob.google.com
- [ ] Verify app listed
- [ ] Check app approval status:
  - [ ] If not approved, request review
  - [ ] Upload privacy policy URL if requested
- [ ] Create test device ID (if needed):
  - [ ] Get device ID from Xcode or console
  - [ ] Add to test devices in AdMob
- [ ] Verify ad unit ID matches:
  - [ ] `ca-app-pub-6842193682076971/5907724370`

### Google Play/App Store
- [ ] Prepare app store listing
- [ ] Add to description: "Contains ads"
- [ ] Set appropriate content rating
- [ ] Upload new build with ad implementation

### Documentation Review
- [ ] Have ADMOB_README.md available
- [ ] Have ADMOB_QUICK_START.md available
- [ ] Have ADMOB_SETUP_GUIDE.md available
- [ ] Keep in project for future reference

---

## Phase 6: Performance & Monitoring (Ongoing)

### Pre-Launch Performance
- [ ] App launch time: < 5 seconds
- [ ] Memory usage: < 200 MB
- [ ] CPU usage: Normal (not spiking)
- [ ] Battery usage: Minimal impact
- [ ] Network: No unexpected extra requests
- [ ] Crashes: Zero crashes on test devices

### Post-Launch Monitoring

#### First Week
- [ ] Monitor AdMob console daily
- [ ] Check impressions count
- [ ] Check click-through rate (CTR)
- [ ] Monitor app crashes
- [ ] Check user reviews for ad complaints
- [ ] Monitor memory/battery impact reports

#### Ongoing
- [ ] Weekly: Check AdMob dashboard
- [ ] Weekly: Review crash reports
- [ ] Monthly: Analyze revenue
- [ ] Monthly: Check performance metrics
- [ ] Quarterly: Review user feedback

### AdMob Console Metrics
- [ ] Impressions: Expected for traffic volume
- [ ] CTR: Typical 0.5-2% (varies by niche)
- [ ] eCPM: Monitor for reasonable rates
- [ ] Revenue: Accumulating as expected
- [ ] No suspicious activity

---

## Phase 7: Troubleshooting (As Needed)

### Build Issues

**Issue: "Module 'GoogleMobileAds' not found"**
- [ ] Run `pod install` again
- [ ] Delete `Pods/` and `Podfile.lock`
- [ ] Run `pod install` fresh
- [ ] Clean build folder: ⌘⇧K
- [ ] Rebuild: ⌘B

**Issue: Build hangs on linking**
- [ ] Close Xcode
- [ ] Delete `DerivedData`: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
- [ ] Delete `Pods/` folder
- [ ] Run `pod install`
- [ ] Open `.xcworkspace`
- [ ] Rebuild

**Issue: Provisioning profile error**
- [ ] Select correct team in build settings
- [ ] Verify signing certificate
- [ ] Regenerate provisioning profile if needed

### Runtime Issues

**Issue: App crashes on launch**
- [ ] Check Info.plist has AdMob App ID
- [ ] Verify app ID syntax: `ca-app-pub-...~...`
- [ ] Check console for specific error
- [ ] Ensure GoogleMobileAds imported in FamCalApp

**Issue: Ads don't appear**
- [ ] Verify user is not Pro (`isProUser == false`)
- [ ] Check internet connection
- [ ] Verify Ad Unit ID in code
- [ ] Check AdMob console for app approval
- [ ] Check test device settings

**Issue: Pro user still sees ads**
- [ ] Force quit app (swipe up)
- [ ] Relaunch
- [ ] Check Pro mode setting in Settings
- [ ] Verify AppSettingsManager persisting state

**Issue: Banner size wrong**
- [ ] Verify size is `kGADAdSizeBanner` (320x50)
- [ ] Check padding constraints
- [ ] Verify frame height is 50

### Performance Issues

**Issue: App slower after ad implementation**
- [ ] Check ad loading isn't on main thread
- [ ] Verify async/await used correctly
- [ ] Monitor memory growth over time
- [ ] Check for memory leaks with Instruments

**Issue: High memory usage**
- [ ] Normal: 3-7 MB for ads
- [ ] If higher, check for memory leaks
- [ ] Use Xcode Memory profiler
- [ ] Check for retained references

**Issue: Battery drain**
- [ ] Ad SDK network calls are minimal
- [ ] Should have negligible impact
- [ ] If issues, check for excessive refreshes
- [ ] Monitor in Settings > Battery

---

## Phase 8: Launch Readiness

### Final Checks Before Launch
- [ ] ✅ All tests passed
- [ ] ✅ No crashes
- [ ] ✅ Ads display correctly
- [ ] ✅ Pro users exempt
- [ ] ✅ Privacy policy updated
- [ ] ✅ AdMob app approved
- [ ] ✅ App Store/Play Store listing updated
- [ ] ✅ Code committed to git
- [ ] ✅ Version bumped
- [ ] ✅ Release notes prepared

### Pre-Release
- [ ] Final code review
- [ ] Run all tests one more time
- [ ] Archive app for distribution
- [ ] Submit to App Store/Play Store
- [ ] Document AdMob setup in team wiki/docs

### Post-Release
- [ ] Monitor first 24 hours closely
- [ ] Check for new crash reports
- [ ] Monitor AdMob impressions
- [ ] Review user feedback
- [ ] Be ready to push hotfix if needed

---

## Quick Reference

### Critical Commands
```bash
# Install dependencies
pod install

# Clean build
⌘⇧K

# Build
⌘B

# Run on simulator
⌘R

# Stop running app
⌘.

# View console
⌘⇧C
```

### File Locations
```
GoogleMobileAdsView.swift
  └─ /FamCal/FamCal/GoogleMobileAdsView.swift

Info.plist (add App ID here)
  └─ /FamCal/FamCal/Info.plist

FamCalApp.swift (SDK initialization)
  └─ /FamCal/FamCal/FamCalApp.swift

FamilyView.swift (ad banner 1)
  └─ /FamCal/FamCal/FamilyView.swift

CalendarView.swift (ad banner 2)
  └─ /FamCal/FamCal/CalendarView.swift
```

### Key Values
```
App ID:      ca-app-pub-6842193682076971~7907201759
Ad Unit ID:  ca-app-pub-6842193682076971/5907724370
Banner Size: 320x50 (kGADAdSizeBanner)
```

---

## Support Contacts

**Google AdMob Support**: https://support.google.com/admob

**Xcode Help**:
- Product > Scheme > Edit Scheme
- Run > Info > Arguments Passed On Launch

**Swift Documentation**: https://swift.org

---

## Sign-Off

- [ ] All checklist items completed
- [ ] Ready for launch
- [ ] Team notified
- [ ] Backup plan prepared

**Date Completed**: _______________

**Completed By**: _______________

**Notes**:
```
_________________________________________________________________

_________________________________________________________________

_________________________________________________________________
```

---

**Last Updated**: November 24, 2025

---

## Appendix: Common Warnings & Fixes

### Warning: "Unused variable" in GoogleMobileAdsView
**Fix**: Verify all Coordinator methods are called by delegate

### Warning: "Memory leak" in profiler
**Fix**: Ensure bannerView delegate is nil in deinit

### Warning: "Thread performance issue"
**Fix**: Verify ad loading happens asynchronously

### Info: Ad impressions low
**Note**: Normal for first days; ramp up over time

### Info: CTR lower than expected
**Note**: Normal range 0.5-2%; can vary by audience

---

## Additional Resources

- ADMOB_README.md - Start here
- ADMOB_QUICK_START.md - 5-minute setup
- ADMOB_SETUP_GUIDE.md - Complete instructions
- ADMOB_IMPLEMENTATION_SUMMARY.md - What's implemented
- ADMOB_ARCHITECTURE.md - Technical details
- ADMOB_VISUAL_GUIDE.md - UI/UX diagrams

---

**Checklist Version**: 1.0
**Last Updated**: November 24, 2025
