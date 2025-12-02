# AdMob Integration - Visual Guide

## Ad Placement in FamilyView

```
┌─────────────────────────────────────────┐
│    FamilyView (Dashboard)               │
├─────────────────────────────────────────┤
│                                         │
│     📅 Upcoming Events (Scrollable)     │
│     ┌───────────────────────────────┐   │
│     │ John                          │   │
│     │ Soccer Practice               │   │
│     │ Tomorrow, 4:00 PM             │   │
│     └───────────────────────────────┘   │
│                                         │
│     ┌───────────────────────────────┐   │
│     │ Sarah                         │   │
│     │ Doctor Appointment            │   │
│     │ Friday, 2:30 PM               │   │
│     └───────────────────────────────┘   │
│                                         │
│     [More events...]                    │
│                                         │
│  ╔═════════════════════════════════╗   │
│  ║      GOOGLE MOBILE ADS          ║   │
│  ║    [Ad Banner 320x50]           ║   │
│  ║  "Shop Now" / "Learn More"      ║   │
│  ╚═════════════════════════════════╝   │
│                                         │
├─────────────────────────────────────────┤
│  [⚙️ Settings] [🔍 Search] [📅 Calendar]│
└─────────────────────────────────────────┘

FREE USER: Ad visible at bottom ✓
PRO USER:  Ad hidden ✓
```

---

## Ad Placement in CalendarView

```
┌─────────────────────────────────────────┐
│    CalendarView (Monthly)               │
├─────────────────────────────────────────┤
│                                         │
│           NOVEMBER 2025                 │
│                                         │
│  Mon Tue Wed Thu Fri Sat Sun             │
│   28  29  30  31   1   2   3             │
│    4   5   6   7   8   9  10             │
│   11  12 [13] 14  15  16  17             │
│   18  19  20  21  22  23  24             │
│   25  26  27  28  29  30   1             │
│                                         │
│  Selected day 13th: 2 events            │
│  ┌─────────────────────────────────┐   │
│  │ Soccer Practice - 4:00 PM       │   │
│  │ Doctor Appointment - 2:30 PM    │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ╔═════════════════════════════════╗   │
│  ║      GOOGLE MOBILE ADS          ║   │
│  ║    [Ad Banner 320x50]           ║   │
│  ║  "Shop Now" / "Learn More"      ║   │
│  ╚═════════════════════════════════╝   │
│                                         │
└─────────────────────────────────────────┘

IN MONTH VIEW: Ad visible ✓
IN DAY VIEW:   Ad hidden (better UX) ✓
FREE USER:     Ad visible ✓
PRO USER:      Ad hidden ✓
```

---

## Theme Integration

### Light Mode
```
┌─────────────────────────────────────┐
│ FamCal Dashboard                    │
├─────────────────────────────────────┤
│ 📅 Upcoming Events                  │
│ ┌─────────────────────────────────┐ │
│ │ John - Soccer - Tomorrow 4PM   │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Sarah - Doctor - Friday 2:30PM │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │ ← Ad adapts to light background
│ │        AD BANNER (Light BG)     │ │
│ │  "Check out our new app"        │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

### Dark Mode
```
┌─────────────────────────────────────┐
│ FamCal Dashboard                    │ (dark)
├─────────────────────────────────────┤
│ 📅 Upcoming Events                  │
│ ┌─────────────────────────────────┐ │
│ │ John - Soccer - Tomorrow 4PM   │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ Sarah - Doctor - Friday 2:30PM │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌─────────────────────────────────┐ │ ← Ad adapts to dark background
│ │        AD BANNER (Dark BG)      │ │
│ │  "Check out our new app"        │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

## User Experience Flow

### Free User Journey
```
🚀 App Launches
    │
    ▼
📊 Check: isProUser?
    │
    ├─→ NO (Free User)
    │   │
    │   ▼
    │ Initialize Ads
    │   │
    │   ▼
    │ User opens FamilyView
    │   │
    │   ▼
    │ ╔════════════════╗
    │ ║ [Ad Banner] ✓  ║ ← Free user sees ad
    │ ╚════════════════╝
    │   │
    │   ▼
    │ User scrolls past ad (or clicks)
    │ App continues normally
    │
    └─→ YES (Pro User)
        │
        ▼
    User opens FamilyView
        │
        ▼
    ╔════════════════╗
    ║ [No Ad] ✓      ║ ← Pro user sees NO ad
    ╚════════════════╝
        │
        ▼
    User gets full ad-free experience
```

---

## Size and Spacing

### Banner Dimensions
```
┌────────────────────────────────────┐
│ FamilyView Container               │
├────────────────────────────────────┤
│ Padding: 16px horizontal           │
│                                    │
│ ┌──────────────────────────────┐   │
│ │  ╔══════════════════════╗    │   │
│ │  ║  GOOGLE MOBILE ADS  ║    │   │
│ │  ║   Width: 320px      ║    │   │
│ │  ║   Height: 50px      ║    │   │
│ │  ║  Corner Radius: 8px ║    │   │
│ │  ╚══════════════════════╝    │   │
│ │                              │   │
│ │  Padding: 8px v, 16px h      │   │
│ └──────────────────────────────┘   │
│                                    │
│ Padding: 16px horizontal           │
└────────────────────────────────────┘
```

---

## Ad Display States

### Loading State
```
┌─────────────────────────┐
│   [Ad Loading...]       │
│   ⏳ Fetching from      │
│      Google AdMob       │
└─────────────────────────┘
```

### Loaded State
```
┌─────────────────────────┐
│  Special Offer!         │
│  Get 50% off today      │
│  [Learn More →]         │ ← Clickable
└─────────────────────────┘
```

### Error State (Graceful Hide)
```
[No ad shown - space collapses]
→ User doesn't notice issue
→ App continues normally
→ Try again on next refresh
```

---

## Code Implementation Map

### File Structure
```
FamCal/
├── FamCal/
│   ├── GoogleMobileAdsView.swift ← NEW: Ad wrapper
│   ├── FamCalApp.swift          ← MODIFIED: Init SDK
│   ├── FamilyView.swift         ← MODIFIED: Add banner
│   ├── CalendarView.swift       ← MODIFIED: Add banner
│   ├── AppSettingsManager.swift (isProUser flag)
│   ├── AppTheme.swift           (theme colors)
│   └── ...other files
│
├── ADMOB_QUICK_START.md         ← Start here!
├── ADMOB_SETUP_GUIDE.md         ← Detailed setup
├── ADMOB_IMPLEMENTATION_SUMMARY.md
├── ADMOB_ARCHITECTURE.md
└── ADMOB_VISUAL_GUIDE.md        ← You are here
```

---

## Decision Tree

```
                        Start App
                            │
                            ▼
                 Has CocoaPods been run?
                       ╱         ╲
                    NO/            \YES
                    /               ╲
                    ▼                ▼
              ❌ Won't build    ✅ Continue
                   │                │
                   ▼                ▼
         Run: pod install    Info.plist updated?
              │                  ╱     ╲
              └─→ Ready       NO/       \YES
                                ▼       ▼
                           ❌ Crash  ✅ App runs
                           (in       │
                            init)    ▼
                                  isProUser?
                                  ╱       ╲
                               NO/         \YES
                               /           ╲
                               ▼            ▼
                            ✅ Ads      ✅ No ads
                           visible      (as designed)
```

---

## Interaction Flow

### User Clicks Ad
```
┌──────────────────────────────┐
│ User sees ad banner          │
├──────────────────────────────┤
│  "Limited Time Offer!"       │
│  ╔══════════════════════╗    │
│  ║   [CLICK AREA]   ◄───────→ User taps here
│  ║  Save 30% today!      ║    │
│  ╚══════════════════════╝    │
└──────────────────────────────┘
         │
         ▼ (User taps)
    ╔════════════════════╗
    ║ Log impression      ║
    ║ Open ad URL         ║
    ║ Safari launches     ║
    ║ (or in-app browser) ║
    ╚════════════════════╝
         │
         ▼
    User can:
    ├─→ Complete action (purchase, signup)
    ├─→ Browse advertiser's site
    ├─→ Go back to FamCal
    └─→ Continue using app
```

### User Scrolls Past Ad
```
┌──────────────────────────────┐
│ User scrolls                 │
├──────────────────────────────┤
│  Previous content            │
│                              │
│  ╔══════════════════════╗    │
│  ║   AD BANNER          ║    │
│  ║  (User scrolls past)  ║    │
│  ╚══════════════════════╝    │
│                              │
│  Next content                │
│                              │
└──────────────────────────────┘
         │
         ▼
    Ad is logged as:
    ├─→ "Impression" (viewed)
    ├─→ No click
    └─→ FamCal continues normally
```

---

## Network Activity

### When App Launches
```
┌─────────────────────────────────────┐
│ App Launch                          │
│                                     │
│ FamCalApp.init()                    │
│   └─→ GADMobileAds.start()          │
│       └─→ Network call              │
│           └─→ Initialize SDK        │
│               └─→ Ready to show ads │
└─────────────────────────────────────┘
     (takes ~100-200ms, non-blocking)
```

### When Ad View Appears
```
┌─────────────────────────────────────┐
│ User navigates to FamilyView        │
│                                     │
│ GoogleMobileAdsView.makeUIView()    │
│   └─→ GADBannerView.load()          │
│       └─→ Network call              │
│           └─→ Fetch ad from Google  │
│               └─→ Ad displays       │
│                   (takes 1-3 seconds)
└─────────────────────────────────────┘
     (happens in background, no lag)
```

---

## Debugging Indicators

### Console Logs You'll See

**✅ Success**
```
📱 Google Mobile Ads SDK initialized
✅ Banner ad received successfully
👀 Banner ad impression recorded
```

**⚠️ Potential Issues**
```
❌ Banner ad failed to load: Network error
  → Check internet connection
  → Verify ad unit ID

❌ Banner ad failed to load: Invalid ad unit
  → Check Info.plist
  → Verify app ID
```

**ℹ️ Lifecycle Events**
```
📱 Banner ad will present screen
  → User is about to click ad

📱 Banner ad did dismiss screen
  → User returned from ad
```

---

## Performance Indicators

### Acceptable Performance
```
Ad Loading: 1-3 seconds ✓
Memory Usage: 3-7 MB ✓
Network Usage: 10-50 KB ✓
Frame Rate Impact: <1% ✓
```

### Performance Metrics to Monitor
```
First Paint:     ✓ Unaffected (ads load asynchronously)
Scroll FPS:      ✓ Smooth (ad is static view)
Memory Growth:   ✓ Stable (no memory leaks)
CPU Usage:       ✓ Normal (Google SDK optimized)
Battery Impact:  ✓ Minimal (short network calls)
```

---

**Last Updated**: November 24, 2025
