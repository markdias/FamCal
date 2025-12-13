# Analytics Calendar Integration Update

**Date**: December 13, 2025
**Status**: ✅ Complete - Build verified successfully

## Summary

The Daily Time Analytics feature has been enhanced to properly fetch and include events from all calendar sources:

- ✅ Shared calendars (family calendars shared with each member)
- ✅ Personal calendars (linked to each member's family member record)
- ✅ User's own personal calendars (if logged-in user, toggled for family view)

All three analytics views (Prototypes A, C, D) and the family cards prototype (B) now fetch real calendar events instead of using empty arrays.

---

## What Changed

### 1. SpotlightView.swift - Analytics Tab (Prototype A)

**Addition**: New helper function `fetchAllEventsForAnalytics()`

- Fetches all events from shared calendars linked to the member
- Fetches all personal calendars linked to the member
- If member is logged-in user: includes their personal calendars (toggled for spotlight)
- Resolves calendar ID mismatches by name fallback
- Returns full list of `UpcomingCalendarEvent` for calendar calculations

**Modified**: `calculateAnalytics()` function
- Now calls `fetchAllEventsForAnalytics()` instead of using limited spotlight events
- Ensures all relevant events are included in analytics calculation
- Maintains same calculation interface

**Key Implementation Details**:
```swift
// Fetch ALL events for analytics (not limited by spotlightEventsPerPerson)
let analyticsEvents = fetchAllEventsForAnalytics()

analytics = calculator.calculate(
    for: member.id ?? UUID(),
    date: selectedAnalyticsDate,
    wakeTime: (hour: wakeHour, minute: wakeMinute),
    bedTime: (hour: bedHour, minute: bedMinute),
    events: analyticsEvents  // All events, not limited
)
```

### 2. AnalyticsView.swift - Full Dashboard (Prototype C)

**Additions**:
- Import `EventKit`
- `@EnvironmentObject` for `AppSettingsManager`
- `@FetchRequest` for `PersonalCalendar` data
- `@State` for `EKEventStore`

**New Helper Function**: `fetchAllEventsForMember(_ member: FamilyMember)`
- Identical logic to SpotlightView's version
- Includes shared calendars for the member
- Includes personal calendars for the member
- Filters personal calendars by `showInSpotlight` toggle
- Resolves calendar IDs with name fallback

**Modified**: `calculateAnalytics()` function
- Replaced empty array with call to `fetchAllEventsForMember(member)`
- Now properly calculates analytics with real event data

### 3. AnalyticsModalView.swift - Quick Modal (Prototype D)

**Additions**:
- Import `EventKit`
- `@EnvironmentObject` for `AppSettingsManager`
- `@FetchRequest` for `PersonalCalendar` data
- `@State` for `EKEventStore`

**New Helper Function**: `fetchAllEventsForMember(_ member: FamilyMember)`
- Same implementation as other views
- Consistent behavior across all prototypes

**Modified**: `calculateAnalytics()` function
- Fetches real events from shared and personal calendars

### 4. FamilyAnalyticsPrototype.swift - Family Overview Cards (Prototype B)

**Additions**:
- Import `EventKit`
- `@Environment` for managed object context
- `@EnvironmentObject` for `AppSettingsManager`
- `@FetchRequest` for `PersonalCalendar` data
- `@State` for `EKEventStore`

**New Helper Function**: `fetchAllEventsForMember(_ member: FamilyMember)`
- Same implementation as other views

**Modified**: `calculateAnalytics(for:)` function
- Now calls `fetchAllEventsForMember(member)` to get all events
- Provides accurate free time percentages for family overview cards

---

## Event Fetching Logic (Shared Implementation)

All four views use the same event fetching pattern:

### 1. Resolve Calendar IDs
```swift
let localCalendars = eventStore.calendars(for: .event)
let calendarById = Dictionary(uniqueKeysWithValues: localCalendars.map { ($0.calendarIdentifier, $0) })
let calendarByTitle = Dictionary(grouping: localCalendars, by: { $0.title }).mapValues { $0.first! }
```

### 2. Collect Calendar IDs from Three Sources

**Personal Calendars (Member-linked)**:
- From `member.memberCalendars` (FamilyMemberCalendar relationships)
- These are calendars explicitly linked to this family member

**Shared Calendars**:
- From `member.sharedCalendars` (SharedCalendar relationships)
- These are family calendars shared with this member

**User's Personal Calendars**:
- From `personalCalendars` FetchRequest (PersonalCalendar entities)
- Only included if member is the logged-in user
- Filtered by `showInSpotlight` toggle (synced to family view)

### 3. Resolve Calendar ID Mismatches
```swift
var resolvedID = storedID
if calendarById[storedID] == nil, let name = cal.calendarName, let localCal = calendarByTitle[name] {
    resolvedID = localCal.calendarIdentifier
}
```
Handles cases where calendar IDs change or become stale.

### 4. Fetch All Events
```swift
let upcomingEvents = CalendarManager.shared.fetchNextEvents(
    for: Array(calendarIDs),
    limit: 0,  // No limit - fetch all events
    pastDays: appSettingsManager.eventsPastDays,
    futureDays: appSettingsManager.eventsFutureDays
)
```

Key difference from SpotlightView: `limit: 0` means ALL events, not just top N.

---

## How Analytics Include All Events

### Before
- Analytics used only the spotlight-limited events
- If spotlightEventsPerPerson = 5, analytics would only see top 5 events
- Resulting free time calculations were incomplete

### After
- Analytics fetch ALL events from all relevant calendars
- Complete and accurate free time calculations
- Independent from spotlight view's event limiting
- Includes shared family events even if not shown in spotlight

### Example Scenario

Member John has:
- 3 personal events
- 7 family shared events
- spotlightEventsPerPerson = 5

**Before**: Analytics would see only 5 total events (mixed personal/shared)
**After**: Analytics sees all 10 events, accurate free time calculation

---

## Dependencies Added

### Imports
- `EventKit` - For calendar access
- Already existed in SpotlightView, added to other views

### Environment Objects
- `AppSettingsManager` - For event past/future days settings
- Already available via environment

### Fetch Requests
- `PersonalCalendar` - For logged-in user's personal calendars
- Used only when member matches logged-in user

### State Variables
- `EKEventStore` - For accessing device calendars
- Standard iOS calendar framework

---

## Calendar Coverage Matrix

| Calendar Type | Who Gets It | When | How |
|---|---|---|---|
| Member personal (linked) | All members | Always | `member.memberCalendars` |
| Shared family calendars | Member + others | If member is in sharedCalendars | `member.sharedCalendars` |
| User's personal calendars | Logged-in user only | If `showInSpotlight` = true | `personalCalendars` FetchRequest |

---

## Implementation Quality

✅ **Type Safety**: Proper `UpcomingCalendarEvent` construction
✅ **Error Handling**: ID resolution with fallback to name
✅ **Performance**: Efficient dictionary lookups for ID resolution
✅ **Consistency**: Same logic across all 4 analytics views
✅ **Maintainability**: Extracted to separate helper functions
✅ **Documentation**: Clear comments explaining calendar sources

---

## Testing Considerations

### Unit Testing
- Calendar ID resolution (normal case + fallback case)
- Empty calendar list handling
- Event filtering by date range

### Integration Testing
- Shared calendar events appear in analytics
- Personal calendar events appear in analytics
- Personal calendars toggle (`showInSpotlight`) affects results
- Free time calculations are accurate with full event set

### Edge Cases
- Member with no calendars → empty event array
- Calendar ID mismatch → resolved by name
- Invalid calendar names → skipped safely
- Logged-in user viewing another member → no personal calendars included

---

## Build Status

```
BUILD SUCCEEDED
Errors: 0
Warnings: 0
```

All modifications compile cleanly with no errors or warnings.

---

## Files Modified

1. `FamCal/Views/Shared/SpotlightView.swift`
   - Added `fetchAllEventsForAnalytics()` helper (~100 lines)
   - Updated `calculateAnalytics()` to use new helper

2. `FamCal/Views/Analytics/AnalyticsView.swift`
   - Added imports and dependencies
   - Added `fetchAllEventsForMember()` helper (~110 lines)
   - Updated `calculateAnalytics()` to use new helper

3. `FamCal/Views/Analytics/AnalyticsModalView.swift`
   - Added imports and dependencies
   - Added `fetchAllEventsForMember()` helper (~110 lines)
   - Updated `calculateAnalytics()` to use new helper

4. `FamCal/Views/prototypes/FamilyAnalyticsPrototype.swift`
   - Added imports and dependencies
   - Added `fetchAllEventsForMember()` helper (~110 lines)
   - Updated `calculateAnalytics()` to use new helper

**Total Lines Added**: ~430 lines of event fetching and calendar integration code

---

## Next Steps

### Immediate Testing
1. ✅ Verify build succeeds (DONE)
2. [ ] Test with sample calendar data
3. [ ] Verify shared calendar events appear in analytics
4. [ ] Verify personal calendar events appear
5. [ ] Confirm free time percentages are accurate

### Future Enhancements
1. Cache event fetching results to avoid repeated queries
2. Add filtering for event types (all-day, busy, tentative)
3. Support timezone handling
4. Add event prioritization logic
5. Performance optimization for large event sets

---

## Summary

The Daily Time Analytics feature now properly includes all relevant calendar events from:
- ✅ Shared family calendars
- ✅ Member-linked personal calendars
- ✅ Logged-in user's personal calendars (when toggled)

All four analytics prototypes (SpotlightView tab, Full Dashboard, Quick Modal, Family Cards) have been updated with consistent event fetching logic. The implementation is clean, maintainable, and ready for integration testing with real calendar data.

**Status: Ready for Testing**
