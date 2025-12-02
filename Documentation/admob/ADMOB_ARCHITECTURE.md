# AdMob Integration Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────┐
│                    FamCalApp.swift                      │
│  • Initializes GoogleMobileAds SDK on app launch       │
│  • GADMobileAds.sharedInstance().start()               │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────┐
        │   Google Mobile Ads SDK    │
        │  (CocoaPods dependency)    │
        │                            │
        │  • Handles ad requests     │
        │  • Manages ad lifecycle    │
        │  • Tracks impressions      │
        └────────────────────────────┘
                     │
         ┌───────────┼───────────┐
         │           │           │
         ▼           ▼           ▼
    ┌──────────┐ ┌──────────┐ ┌──────────────┐
    │FamilyView│ │CalendarView│ │Future Views │
    └──────────┘ └──────────┘ └──────────────┘
         │           │              │
         │           │              │
         ▼           ▼              ▼
    ┌────────────────────────────────────────┐
    │      AdBannerContainer (SwiftUI)       │
    │  • Checks appSettingsManager.isProUser │
    │  • Conditionally renders ad or empty   │
    │  • Applies theme styling               │
    └────────────┬───────────────────────────┘
                 │
                 ▼
    ┌────────────────────────────────────┐
    │  GoogleMobileAdsView              │
    │  (UIViewRepresentable)            │
    │                                   │
    │  • Wraps GADBannerView (UIKit)    │
    │  • Manages ad lifecycle           │
    │  • Handles delegate callbacks     │
    │  • Logs events                    │
    └────────────┬──────────────────────┘
                 │
                 ▼
         ┌──────────────────┐
         │  GADBannerView   │
         │  (UIKit native)  │
         │                  │
         │  Size: 320x50    │
         │  Ad Unit ID:     │
         │  ca-app-pub-.../ │
         │  5907724370      │
         └──────────────────┘
```

---

## Data Flow

### Ad Display Flow (Free User)

```
1. User Launches App
   │
   ├─→ FamCalApp.init()
   │   └─→ GADMobileAds.sharedInstance().start()
   │
2. User Navigates to FamilyView
   │
   ├─→ FamilyView.body
   │   │
   │   └─→ Check: appSettingsManager.isProUser?
   │       │
   │       ├─→ TRUE (Pro user)
   │       │   └─→ Skip ad rendering (return nil)
   │       │
   │       └─→ FALSE (Free user)
   │           │
   │           └─→ Render AdBannerContainer
   │               │
   │               └─→ GoogleMobileAdsView
   │                   │
   │                   └─→ Create GADBannerView
   │                       │
   │                       └─→ Load ad via GADRequest
   │                           │
   │                           ├─→ Success: Show banner
   │                           │   └─→ Log: "✅ Banner ad received"
   │                           │
   │                           └─→ Error: Graceful hide
   │                               └─→ Log: "❌ Banner ad failed"
```

### Pro User Path

```
User is Pro (appSettingsManager.isProUser == true)
   │
   ├─→ FamilyView
   │   └─→ if !isProUser → SKIP ad rendering
   │       └─→ NO AD SHOWN ✓
   │
   └─→ CalendarView
       └─→ if !isProUser → SKIP ad rendering
           └─→ NO AD SHOWN ✓
```

---

## Component Hierarchy

```
FamCalApp
├── EnvironmentObject: AppSettingsManager
│   └── isProUser (Boolean flag)
│
├── FamilyView
│   ├── mainScrollView
│   │   └── ScrollView
│   │       └── VStack
│   │           ├── contentView (calendar/events)
│   │           │
│   │           └── Conditional: if !isProUser
│   │               └── AdBannerContainer
│   │                   ├── adUnitID: String
│   │                   ├── isProUser: Bool
│   │                   └── theme: AppTheme
│   │                       │
│   │                       └── GoogleMobileAdsView
│   │                           └── makeUIView()
│   │                               └── GADBannerView
│   │
│   └── floatingControls
│       └── Settings, Search, Calendar buttons
│
└── CalendarView
    ├── content (month/day view)
    │   ├── monthView
    │   │   └── LazyVGrid (calendar days)
    │   │
    │   └── Conditional: if .month && !isProUser
    │       └── AdBannerContainer
    │           └── GoogleMobileAdsView
    │               └── GADBannerView
    │
    └── dayView
        └── (No ad in day view - better UX)
```

---

## Class Hierarchy

### GoogleMobileAdsView

```
GoogleMobileAdsView (UIViewRepresentable)
│
├── Properties:
│   ├── adUnitID: String
│   └── isProUser: Bool
│
├── Coordinator (GADBannerViewDelegate)
│   ├── parent: GoogleMobileAdsView
│   │
│   └── Delegate Methods:
│       ├── bannerViewDidReceiveAd(_:)
│       ├── bannerView(_:didFailToReceiveAdWithError:)
│       ├── bannerViewDidRecordImpression(_:)
│       ├── bannerViewWillPresentScreen(_:)
│       ├── bannerViewWillDismissScreen(_:)
│       └── bannerViewDidDismissScreen(_:)
│
├── Methods:
│   ├── makeCoordinator() → Coordinator
│   ├── makeUIView(context:) → UIView
│   │   ├── if isProUser → return empty view (no ads)
│   │   └── else → create GADBannerView
│   │       ├── Set adUnitID
│   │       ├── Set rootViewController
│   │       ├── Set delegate
│   │       └── Load with GADRequest()
│   │
│   └── updateUIView(_:context:)
│       └── Update delegate reference
│
└── Static Property:
    └── defaultHeight: CGFloat = 50
```

### AdBannerContainer

```
AdBannerContainer (View)
│
├── Properties:
│   ├── adUnitID: String
│   ├── isProUser: Bool
│   └── theme: AppTheme?
│
└── body: some View
    └── Conditional: if !isProUser
        └── GoogleMobileAdsView
            ├── .frame(height: 50)
            ├── .background(theme.cardBackground)
            ├── .clipShape(RoundedRectangle)
            ├── .padding(.horizontal, 16)
            └── .padding(.vertical, 8)
```

---

## State Management Flow

```
AppSettingsManager (EnvironmentObject)
    │
    ├── isProUser: Bool
    │   ├── Default: false (free tier)
    │   ├── Set to true when: user purchases/test Pro mode
    │   └── Published: @Published property (observable)
    │
    ├── Observers:
    │   ├── FamilyView watches isProUser
    │   │   └── Triggers re-render of ad container
    │   │
    │   └── CalendarView watches isProUser
    │       └── Triggers re-render of ad container
    │
    └── When isProUser changes:
        └── Conditional view automatically hides/shows ads
            ├── FamilyView ads appear/disappear
            └── CalendarView ads appear/disappear
```

---

## Ad Loading Lifecycle

```
┌─────────────────────────────────────────────────┐
│            googleMobileAdsView Created           │
└────────────────┬────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────┐
│     makeUIView() called (UIViewRepresentable)    │
└────────────────┬────────────────────────────────┘
                 │
         ┌───────┴───────┐
         │               │
         ▼               ▼
    [Pro User]      [Free User]
    │              │
    ├─→ Return      ├─→ Create GADBannerView
        empty view  │   ├─→ Set adUnitID
                    │   ├─→ Set rootViewController
                    │   └─→ Set delegate
                    │
                    └─→ Load Ad
                        │
                        └─→ GADRequest()
                            │
                            ├─→ Network call to Google
                            │
                            └─→ Response
                                │
                        ┌───────┴───────┐
                        │               │
                        ▼               ▼
                    [Success]      [Error]
                    │              │
                    ├─→ Show ad     ├─→ Log error
                    ├─→ Log: "✅"   ├─→ Hide gracefully
                    ├─→ Record      └─→ No crash
                    │   impression
                    └─→ Ready for
                        clicks
```

---

## Theme Integration

```
ThemeManager (EnvironmentObject)
    │
    └── selectedTheme: AppTheme
        │
        ├── cardBackground: Color
        │   └── Used by AdBannerContainer.background()
        │
        ├── mutedTagColor: Color
        │   └── Future use for ad styling
        │
        └── prefersDarkInterface: Bool
            └── Light/dark mode automatically
                applied to banner view
```

---

## Error Handling Paths

```
GADBannerView.load(GADRequest)
    │
    ├─→ Success Path
    │   └─→ bannerViewDidReceiveAd(_:)
    │       └─→ Log: "✅ Banner ad received successfully"
    │           └─→ Ad displays normally
    │
    └─→ Error Path
        └─→ bannerView(_:didFailToReceiveAdWithError:)
            ├─→ Log: "❌ Banner ad failed to load: {error}"
            │
            └─→ Graceful degradation
                ├─→ View doesn't crash
                ├─→ App continues normally
                └─→ No ad shown (user doesn't notice)
```

---

## File Dependencies

```
GoogleMobileAdsView.swift
├── Imports:
│   ├── SwiftUI
│   └── GoogleMobileAds (from CocoaPods)
│
└── Used by:
    └── AdBannerContainer

AdBannerContainer
├── Imports: SwiftUI, AppTheme
│
└── Used by:
    ├── FamilyView (bottom of scroll)
    └── CalendarView (below calendar grid)

FamCalApp.swift
├── Imports: GoogleMobileAds
│
└── Initialization:
    └── GADMobileAds.sharedInstance().start()

FamilyView.swift
├── Imports: [unchanged]
│
└── Uses:
    ├── AdBannerContainer
    └── appSettingsManager.isProUser

CalendarView.swift
├── Imports: [unchanged]
│
└── Uses:
    ├── AdBannerContainer
    └── appSettingsManager.isProUser
```

---

## Deployment Chain

```
1. Development
   └─→ CocoaPods: pod install
   └─→ Xcode: Build with .xcworkspace
   └─→ Simulator: Test with sandbox ads

2. Testing
   └─→ Device: Real ad loading
   └─→ Logs: Monitor console output
   └─→ AdMob: Check test device in console

3. Production
   └─→ Privacy Policy: Updated
   └─→ AdMob: App approved
   └─→ App Store: Submit with ad implementation
   └─→ Live: Real users see ads

4. Monitoring
   └─→ AdMob Console: Track impressions/clicks
   └─→ App Logs: Monitor errors
   └─→ Crashes: Watch for ad-related issues
```

---

## Performance Metrics

```
Load Time Impact:
├─→ Ad View Creation: ~50ms
├─→ Ad Network Request: ~1-3s (parallel to UI)
├─→ Ad Display: Immediate (once loaded)
└─→ Total Impact: Negligible (async loading)

Memory Impact:
├─→ GoogleMobileAdsView: ~2-5MB
├─→ GADBannerView: ~1-2MB
└─→ Total: ~3-7MB (acceptable for modern devices)

Network Impact:
├─→ Ad Requests: 1 per view load
├─→ Size: ~10-50KB per ad
└─→ Cached: Yes (ads cached by Google)
```

---

## Security & Privacy

```
Data Sent to Google:
├── Device ID (anonymized)
├── App ID
├── Ad Unit ID
├── Device type/model
├── Location (if permitted)
└── User interest data

Your App:
├── NO personal user data sent
├── NO sensitive information sent
├── GDPR compliant (respects user consent)
└── Privacy policy updated

User Control:
├── Opt-out: Available in device settings
├── Personalization: Respects device settings
└── Non-personalized: Ads if user opts out
```

---

## Scaling Considerations

```
If You Add More Ads:

1. Multiple Banners
   └─→ Can have multiple AdBannerContainers
   └─→ Each needs unique internal logic
   └─→ Consider rate limiting

2. Interstitial Ads
   └─→ Create GADInterstitialAd component
   └─→ Show on specific actions
   └─→ Time delays between ads

3. Rewarded Ads
   └─→ Create GADRewardedAd component
   └─→ Offer premium features for watching
   └─→ Track reward redemption

4. Native Ads
   └─→ Create custom native ad view
   └─→ Matches app design exactly
   └─→ More flexible positioning
```

---

## Checklist for Code Review

- ✅ GoogleMobileAdsView properly implements UIViewRepresentable
- ✅ Coordinator pattern used correctly for delegate callbacks
- ✅ Ad loading happens asynchronously (no UI blocking)
- ✅ Error handling prevents crashes
- ✅ Pro user exemption properly checked
- ✅ Theme integration applied
- ✅ Safe area compliance
- ✅ Memory management (no strong reference cycles)
- ✅ Consistent ad unit ID across app
- ✅ No hardcoded test ad IDs in production
- ✅ Proper logging for debugging
- ✅ Comments explain key logic

---

**Last Updated**: November 24, 2025
