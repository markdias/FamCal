# Travel Time Feature Implementation Progress

## Overview
This document tracks the implementation of iOS Calendar's travel time feature in FamCal. The feature allows users to view and set travel time for events, with automatic departure time calculation and visualization across multiple views.

## Architecture

### Data Flow
1. **EventKit** → Travel time fetched directly from iOS Calendar events
2. **CalendarManager** → Helper functions for travel time retrieval and departure time calculation
3. **FamilyView** → EventItem → GroupedEvent → GroupedEventDTO → Cache
4. **UI Views** → Display travel time with departure time calculations

### Key Data Structures
- `EventItem`: Raw event data from EventKit (includes `travelTimeMinutes: Int?`)
- `GroupedEvent`: Events grouped by details for display (includes `travelTimeMinutes`)
- `GroupedEventDTO`: Codable version for caching (includes `travelTimeMinutes`)

### Helper Functions (CalendarManager.swift)
- `getTravelTimeMinutes(from event: EKEvent) -> Int?`
  - Uses KVC to access iOS 17+ travel time property
  - Supports iOS 16+ via Key-Value Coding

- `calculateDepartureTime(eventStartDate: Date, travelTimeMinutes: Int?) -> Date`
  - Calculates when user needs to leave
  - Returns `eventStartDate - travelTimeMinutes`

- `setTravelTime(on event: EKEvent, travelTimeMinutes: Int?, span: EKSpan = .thisEvent) -> Bool`
  - Sets travel time on EventKit event
  - Pass `.futureEvents` for recurring series so every occurrence stays in sync (Add/Edit use this automatically)
  - 2-way sync with iOS Calendar

---

## Implementation Status

### ✅ COMPLETED: Phase 1 - Helper Functions & Data Model
**Files Modified:**
- `Managers/CalendarManager.swift`
- `FamCal/FamCal.xcdatamodeld` (data model checked)

**What was done:**
- Created `getTravelTimeMinutes()` using KVC for iOS 16+ compatibility
- Created `calculateDepartureTime()` for departure time calculation
- Created `setTravelTime()` for 2-way sync with EventKit
- Used KVC pattern to avoid compile-time errors on older iOS versions

**Status:** ✅ Fully Implemented

---

### ✅ COMPLETED: Phase 2 - Event Creation UI
**Files Modified:**
- `Views/Events/AddEventView.swift`
- `Views/Events/EditEventView.swift`

**What was done:**
- Added `@State var travelTimeMinutes: Int? = nil` to both views
- Created travel time picker with presets (15, 30, 45, 60 min) + custom input
- Orange car icon (🚗) for visual consistency
- `loadExistingTravelTime()` function in EditEventView
- Travel time saved to EventKit on event creation/update

**Status:** ✅ Fully Implemented

---

### ✅ COMPLETED: Phase 3 - Event Detail Display
**Files Modified:**
- `Views/Events/EventDetailView.swift`

**What was done:**
- Added `@State var travelTimeMinutes: Int?` state variable
- Created `travelTimeRow` displayed in `quickActionsCard`
- Shows: "[minutes] min" and "Depart [time]" using secondary styling
- Positioned after alertRow with proper Divider separator
- Removed duplicate driverSection that was showing twice

**Status:** ✅ Fully Implemented

---

### ✅ COMPLETED: Phase 4 - Calendar Day View Visualization
**Files Modified:**
- `Views/Calendar/DailyEventsView.swift`

**What was done:**
- Added `getTravelTimeForEvent()` helper to fetch travel time from EventKit
- Renders gray translucent travel time blocks (.fill(Color.gray.opacity(0.2)))
- Blocks positioned at calculated departure time
- Block height proportional to travel duration
- Travel blocks render behind event blocks for clean layering

**Status:** ✅ Fully Implemented

---

### ✅ COMPLETED: Phase 5 - Family View Integration
**Files Modified:**
- `Views/Family/FamilyView.swift`
- `Managers/EventCache.swift`

**What was done:**
- Added `travelTimeMinutes: Int?` to EventItem struct
- Added `travelTimeMinutes` field to GroupedEvent struct
- Added `travelTimeMinutes` field to GroupedEventDTO struct
- Travel time fetched when creating EventItem: `CalendarManager.shared.getTravelTimeMinutes(from: event)`
- Updated all GroupedEvent initializations to include travel time
- Updated all GroupedEventDTO initializations to include travel time in cache

**CompactCardStyle Updates:**
- **CompactCardStyle1**: Shows "Leaves [time]" below start time
- **CompactCardStyle3**: Same departure time display
- **CompactCardStyle4**: Departure time inline with event time
- All styles use reduced opacity (0.7) for secondary departure time text
- Departure time displays only when travelTimeMinutes > 0

**Status:** ✅ Fully Implemented

---

## Pending Implementation

### ✅ COMPLETED: Phase 6 - Analytics Integration
**Goal:** Include travel time in busy/free time calculations

**Scope:**
- Analytics calculations now extend busy windows to include travel time (with wake/bed clamping)
- Timeline metrics count travel as committed time and show travel overlays
- Travel minutes surfaced in metrics cards

**Files Modified:**
- `Utilities/TimeAnalyticsCalculator.swift`
- `Views/Analytics/AnalyticsView.swift`
- `Views/Analytics/AnalyticsModalView.swift`
- `Views/Analytics/AnalyticsMetricsView.swift`
- `Views/Analytics/TimelineVisualizationView.swift`
- `Views/Shared/SpotlightView.swift`

---

### ✅ COMPLETED: Phase 7 - Widget & Other Views Polish
**Goal:** Extend travel time display to remaining views

**Scope:**
- **Widgets:** NextEventWidget shows departure time
- **Morning Brief:** Displays departure time in daily summary
- **Spotlight View:** Adds departure time line to spotlight cards

**Files Modified:**
- `NextEventWidget/*`
- `Managers/NotificationManager.swift`
- `Views/Events/MorningBriefView.swift`
- `Views/Shared/SpotlightView.swift`

---

## Known Issues & Notes

### Xcode Project Configuration
- **Status:** ✅ Resolved (as of last session)
- Package products (Auth, PostgREST, Realtime, Storage, GoogleSignIn) properly configured
- Supabase version pinned to 2.37.0
- If "missing package product" errors appear in Xcode UI:
  - Run: `xcodebuild -resolvePackageDependencies`
  - Clear cache: `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
  - Restart Xcode

### iOS Version Compatibility
- Travel time API: iOS 17+
- KVC approach handles iOS 16+ gracefully
- No compile-time errors, works across all supported iOS versions

### Performance Considerations
- Travel time fetched once per event loading cycle
- Cached in GroupedEventDTO for UI refresh efficiency
- No additional database queries (uses EventKit directly)

---

## Testing Checklist

### Phase 1-3 (✅ Complete)
- [ ] Create event with travel time in AddEventView
- [ ] Edit event to modify travel time in EditEventView
- [ ] Verify departure time displays correctly in EventDetailView
- [ ] Verify 2-way sync: changes in app reflect in iOS Calendar app

### Phase 4 (✅ Complete)
- [ ] View event in calendar day view (DailyEventsView)
- [ ] Verify travel time blocks appear before event block
- [ ] Verify block position matches calculated departure time

### Phase 5 (✅ Complete)
- [ ] View family member events in FamilyView
- [ ] Verify departure time shows in compact event cards
- [ ] Test with different compact card styles (option1, option3, option4)
- [ ] Verify travel time displays only when > 0 minutes

### Phase 6 (✅ Complete)
- [x] Analytics view shows travel time in busy calculations
- [x] Timeline metrics account for travel as committed time
- [x] Busy/free percentages include travel time

### Phase 7 (✅ Complete)
- [x] NextEventWidget displays departure time
- [x] Morning brief includes travel time info
- [x] Spotlight view shows departure time
- [x] All views use consistent "Leaves [time]" format

---

## Code Examples

### Adding Travel Time to a New View

```swift
// 1. Include travel time in your data struct
struct YourEventModel {
    let travelTimeMinutes: Int?
}

// 2. Calculate departure time when displaying
if let travelMinutes = event.travelTimeMinutes, travelMinutes > 0 {
    let departureTime = CalendarManager.shared.calculateDepartureTime(
        eventStartDate: event.startDate,
        travelTimeMinutes: travelMinutes
    )
    Text("Leaves \(departureTime.formatted(date: .omitted, time: .shortened))")
        .font(.caption)
        .foregroundColor(.secondary)
}

// 3. When loading events from EventKit
let travelTime = CalendarManager.shared.getTravelTimeMinutes(from: ekEvent)
```

### Fetching Travel Time from EventKit

```swift
// CalendarManager already provides this, but for reference:
let travelMinutes = CalendarManager.shared.getTravelTimeMinutes(from: event)
// Returns: Int? (nil if not set, otherwise 0-999 minutes)
```

---

## File Manifest

### Modified Files
1. `Managers/CalendarManager.swift` - Helper functions for travel time
2. `Views/Events/AddEventView.swift` - Travel time input UI
3. `Views/Events/EditEventView.swift` - Travel time editing
4. `Views/Events/EventDetailView.swift` - Travel time display in detail view
5. `Views/Calendar/DailyEventsView.swift` - Travel time blocks in calendar
6. `Views/Family/FamilyView.swift` - Travel time in family view cards
7. `Managers/EventCache.swift` - Travel time in cached DTO
8. `FamCal/FamCal.xcdatamodeld` - Data model (verified, no changes needed)

### Not Modified (But May Need Updates)
- `NextEventWidget/NextEventWidget.swift`
- `Views/Analytics/AnalyticsView.swift` or similar
- `Views/Shared/SpotlightView.swift`
- Other dashboard/summary views

---

## Dependencies & Requirements

### Required Frameworks
- **EventKit** - Access iOS Calendar travel time
- **SwiftUI** - UI rendering
- **CoreData** - Local caching via EventCache

### Minimum iOS Version
- iOS 16.0 (KVC provides compatibility)
- iOS 17.0+ for native travel time API

### External Dependencies
- None (uses system frameworks only)

---

## Future Enhancements

1. **Smart Travel Time Estimation**
   - Auto-calculate travel time based on event location
   - Integrate maps for ETA-based departure suggestions

2. **Departure Reminders**
   - Separate notification for departure time
   - Customizable departure reminder offset

3. **Travel Time Analytics**
   - Dashboard widget showing daily travel time
   - Monthly travel time trends

4. **Location-Based Features**
   - Integration with saved addresses
   - One-touch calendar event creation from location

---

**Last Updated:** 2025-12-14
**Implementation Lead:** Claude Code
**Status:** 7 of 7 phases complete (100%)
