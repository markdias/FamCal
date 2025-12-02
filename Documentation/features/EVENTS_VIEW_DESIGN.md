# FamCal Events View Design

## Overview
The Events View displays upcoming calendar events for family members in two distinct sections:
1. **Next Events** - Quick glance view of each person's immediate next event
2. **Upcoming Events** - Detailed view with recurring event chip expansion

---

## Implementation Snapshot

### Swift Data Types
```swift
struct MemberEventGroup: Identifiable {
    let id: NSManagedObjectID
    let memberName: String
    let memberColor: Color
    let nextEvent: GroupedEvent?
    let upcomingEvents: [GroupedEvent]   // limited by eventsPerPerson
}

struct GroupedEvent: Identifiable {
    let id: String
    let title: String
    let timeRange: String?
    let location: String?
    let startDate: Date
    let endDate: Date
    var memberNames: [String]
    let memberColor: UIColor
    let calendarTitle: String
    let hasRecurrence: Bool
    let recurrenceRule: EKRecurrenceRule?
    var memberColors: [UIColor]
    var recurrenceChips: [RecurrenceChip]
}

struct RecurrenceChip: Identifiable {
    let id = UUID()
    let date: Date
    let label: String   // "Tue 19 Nov"
}
```

### View Hierarchy
- `FamilyView`
  - `Next Events` section → 2-column `LazyVGrid` where each `MemberEventGroup` renders a tile via `nextEventCard`
  - `Upcoming Events` section → stacked list of per-member headers with `eventCard` rows (chips included when `groupedEvent.recurrenceChips` is non-empty)

### Event Selection Pseudocode
```pseudocode
FUNCTION buildMemberEventGroup(member, calendarIDs, eventsPerPerson):
    rawEvents = fetchEvents(for: calendarIDs, limit: 100)
    eventItems = map rawEvents -> EventItem(timeRangeString, recurrenceRule, etc)
    groupedEvents = groupEventsByDetails(eventItems) // merges simultaneous shared events

    // Next Events requirement
    futureEvents = groupedEvents.filter(event.endDate >= now)

    // Upcoming Events requirement (chips)
    decoratedEvents = attachRecurringChips(
        groupedEvents: futureEvents,
        upcomingEvents: rawEvents,
        chipLimit: 5,
        boundary: nextDifferentEvent(from: rawEvents)
    )

    return MemberEventGroup(
        id: member.id,
        memberName: member.name,
        memberColor: member.color,
        nextEvent: decoratedEvents.first,
        upcomingEvents: decoratedEvents.prefix(eventsPerPerson)
    )
END FUNCTION
```

### Example Input / Output
```json
{
  "members": [
    { "id": "m1", "name": "Annabelle", "color": "#007AFF" },
    { "id": "m2", "name": "Mark", "color": "#FF9500" }
  ],
  "memberCalendars": {
    "m1": ["cal_school", "cal_shared"],
    "m2": ["cal_mark"]
  },
  "events": [
    {
      "id": "evt_school_mon",
      "title": "School",
      "calendarId": "cal_school",
      "startDate": "2025-11-17T08:45:00Z",
      "endDate": "2025-11-17T15:15:00Z",
      "location": "Ridgeway",
      "hasRecurrence": true,
      "recurrenceRule": "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR"
    },
    {
      "id": "evt_checkup",
      "title": "Knee Op",
      "calendarId": "cal_mark",
      "startDate": "2025-11-19T12:30:00Z",
      "endDate": "2025-11-19T17:30:00Z",
      "location": "City Hospital",
      "hasRecurrence": false
    }
  ],
  "eventsPerPerson": 3
}
```

```json
{
  "memberEventGroups": [
    {
      "memberName": "Annabelle",
      "nextEvent": {
        "title": "School",
        "startDate": "2025-11-17T08:45:00Z",
        "endDate": "2025-11-17T15:15:00Z",
        "timeRange": "08:45 – 15:15",
        "calendarTitle": "School",
        "hasRecurrence": true
      },
      "upcomingEvents": [
        {
          "title": "School",
          "startDate": "2025-11-17T08:45:00Z",
          "recurrenceChips": [
            { "date": "2025-11-18", "label": "Tue 18 Nov" },
            { "date": "2025-11-19", "label": "Wed 19 Nov" },
            { "date": "2025-11-20", "label": "Thu 20 Nov" }
          ]
        }
      ]
    },
    {
      "memberName": "Mark",
      "nextEvent": {
        "title": "Knee Op",
        "startDate": "2025-11-19T12:30:00Z",
        "endDate": "2025-11-19T17:30:00Z",
        "timeRange": "12:30 – 17:30",
        "hasRecurrence": false
      },
      "upcomingEvents": [
        {
          "title": "Knee Op",
          "startDate": "2025-11-19T12:30:00Z",
          "recurrenceChips": []
        }
      ]
    }
  ]
}
```

---

## Section 1: Next Events

### Purpose
Provides a quick, at-a-glance view of what's coming up for each family member.

### Layout
- **Grid**: 2 columns (responsive 2x2, 2x3, etc. based on family members)
- **Tile Size**: 140×200pt per card
- **Spacing**: 12pt between tiles
- **Overflow**: Scrollable if more than 4 people

### Component Structure

```swift
struct NextEventCard {
    let memberName: String
    let memberInitials: String
    let memberColor: Color
    let eventTitle: String
    let eventTime: String? // "HH:mm – HH:mm" or "All Day"
    let timeUntil: String  // "Tomorrow", "In 3 days", "In 2 hrs"
}
```

### Data Shape (Swift)

```swift
private struct NextEventData {
    let memberId: NSManagedObjectID
    let memberName: String
    let memberColor: Color
    let nextEvent: EventOccurrence?  // Next upcoming occurrence only
}

private struct EventOccurrence {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let timeRange: String?
    let location: String?
    let hasRecurrence: Bool
}
```

### Selection Logic (Pseudocode)

```pseudocode
FUNCTION getNextEventPerPerson(memberCalendars: [String], allEvents: [CalendarEvent]) -> [NextEventData]
    FOR EACH member IN familyMembers DO
        calendarIds = getMemberCalendarIds(member)
        memberEvents = filterEventsByCalendars(allEvents, calendarIds)

        // Only future events
        futureEvents = memberEvents.filter(event.startDate > now)

        IF futureEvents.isEmpty THEN
            nextEventData.nextEvent = nil
        ELSE
            // For recurring events, get FIRST occurrence only
            firstEvent = futureEvents[0]
            nextEventData.nextEvent = {
                id: firstEvent.id,
                title: firstEvent.title,
                startDate: firstEvent.startDate,
                endDate: firstEvent.endDate,
                hasRecurrence: firstEvent.hasRecurrence
            }
        END IF

        nextEventData.memberName = member.name
        nextEventData.memberColor = member.color

        APPEND nextEventData
    END FOR

    RETURN nextEventData sorted by event.startDate
END FUNCTION
```

### JSON Example Input

```json
{
  "members": [
    { "id": "m1", "name": "Alice", "color": "#FF6B6B" },
    { "id": "m2", "name": "Bob", "color": "#4ECDC4" }
  ],
  "memberCalendars": {
    "m1": ["cal_alice@icloud.com", "cal_shared_family@google.com"],
    "m2": ["cal_bob@icloud.com"]
  },
  "events": [
    {
      "id": "evt_1",
      "title": "School",
      "startDate": "2025-11-18T09:00:00Z",
      "endDate": "2025-11-18T15:00:00Z",
      "calendarId": "cal_alice@icloud.com",
      "hasRecurrence": true,
      "recurrenceRule": "FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR",
      "location": "Lincoln High"
    },
    {
      "id": "evt_2",
      "title": "Soccer",
      "startDate": "2025-11-19T16:00:00Z",
      "endDate": "2025-11-19T17:30:00Z",
      "calendarId": "cal_bob@icloud.com",
      "hasRecurrence": false,
      "location": "Central Park"
    }
  ]
}
```

### JSON Example Output

```json
{
  "nextEvents": [
    {
      "memberId": "m1",
      "memberName": "Alice",
      "memberColor": "#FF6B6B",
      "nextEvent": {
        "id": "evt_1",
        "title": "School",
        "startDate": "2025-11-18T09:00:00Z",
        "endDate": "2025-11-18T15:00:00Z",
        "timeRange": "09:00 – 15:00",
        "location": "Lincoln High",
        "hasRecurrence": true
      }
    },
    {
      "memberId": "m2",
      "memberName": "Bob",
      "memberColor": "#4ECDC4",
      "nextEvent": {
        "id": "evt_2",
        "title": "Soccer",
        "startDate": "2025-11-19T16:00:00Z",
        "endDate": "2025-11-19T17:30:00Z",
        "timeRange": "16:00 – 17:30",
        "location": "Central Park",
        "hasRecurrence": false
      }
    }
  ]
}
```

---

## Section 2: Upcoming Events

### Purpose
Detailed view of upcoming events per person, with recurring event occurrences shown as expandable chips.

### Layout
- **Structure**: Per-person grouping
- **Card Size**: Variable height (90pt minimum)
- **Recurring Chips**: Inline with event card (tag-style badges)
- **Limit**: Respects `eventsPerPerson` setting (default: 3)
- **Date Box**: 70×90pt colored box on left with date/weekday
- **Content Area**: Right panel with title, members, time, location

### Component Structure

```swift
struct UpcomingEventCard {
    let eventId: String
    let title: String
    let memberNames: [String]
    let memberColors: [UIColor]  // For gradient
    let startDate: Date
    let endDate: Date
    let timeRange: String?
    let location: String?
    let hasRecurrence: Bool
    let recurringOccurrences: [Date]?  // Next occurrence dates as chips
}

struct MemberUpcomingEventsSection {
    let memberName: String
    let memberColor: Color
    let events: [UpcomingEventCard]  // Limited by eventsPerPerson
}
```

### Data Shape (Swift)

```swift
private struct RecurringEventExpansion {
    let baseEvent: EventOccurrence
    let nextOccurrences: [Date]  // Dates only, not full events
    let truncatedAt: TruncationReason?  // why we stopped expanding
}

enum TruncationReason {
    case differentEventFound(eventTitle: String, date: Date)
    case limitReached(limit: Int)
    case endDateReached(date: Date)
}
```

### Selection & Expansion Logic (Pseudocode)

```pseudocode
FUNCTION expandRecurringEventsWithChips(
    memberEvents: [CalendarEvent],
    upcomingEvents: [CalendarEvent],
    eventsPerPerson: Int
) -> [UpcomingEventCard]

    result: [UpcomingEventCard] = []
    eventCount = 0

    FOR EACH event IN memberEvents (sorted by startDate) DO
        IF event.startDate <= now THEN
            CONTINUE  // Skip past events
        END IF

        IF eventCount >= eventsPerPerson THEN
            BREAK  // Reached limit
        END IF

        eventCard = createEventCard(event)

        // Handle recurring events
        IF event.hasRecurrence THEN
            occurrences = calculateRecurringOccurrences(
                baseDate: event.startDate,
                rule: event.recurrenceRule,
                futureEvents: upcomingEvents,
                currentEventTitle: event.title
            )

            eventCard.recurringOccurrences = occurrences
            eventCard.recurringChips = convertToChips(occurrences)
        END IF

        APPEND eventCard TO result
        INCREMENT eventCount
    END FOR

    RETURN result
END FUNCTION

FUNCTION calculateRecurringOccurrences(
    baseDate: Date,
    rule: RecurrenceRule,
    futureEvents: [CalendarEvent],
    currentEventTitle: String
) -> [Date]

    occurrences: [Date] = []
    currentDate = baseDate
    chipLimit = 5  // Max chips to show

    // Find when this recurring event should stop (next different event)
    differentEvents = futureEvents.filter(
        startDate > baseDate AND title != currentEventTitle
    )
    stopDate = differentEvents[0]?.startDate ??
               (baseDate + 365 days)

    WHILE occurrences.count < chipLimit DO
        // Calculate next occurrence
        nextDate = getNextOccurrenceDate(currentDate, rule)

        // Check boundaries
        IF nextDate >= stopDate THEN
            BREAK  // Stop before different event
        END IF

        // Skip the first occurrence (already shown as main card)
        IF nextDate > baseDate THEN
            APPEND nextDate TO occurrences
        END IF

        currentDate = nextDate
    END WHILE

    RETURN occurrences
END FUNCTION

FUNCTION getNextOccurrenceDate(currentDate: Date, rule: RecurrenceRule) -> Date
    SWITCH rule.frequency:
        CASE DAILY:
            RETURN currentDate + (rule.interval days)
        CASE WEEKLY:
            RETURN currentDate + (rule.interval weeks)
        CASE MONTHLY:
            RETURN currentDate + (rule.interval months)
        CASE YEARLY:
            RETURN currentDate + (rule.interval years)
    END SWITCH
END FUNCTION
```

### JSON Example Input

```json
{
  "memberEvents": [
    {
      "id": "evt_school_001",
      "title": "School",
      "startDate": "2025-11-18T09:00:00Z",
      "endDate": "2025-11-18T15:00:00Z",
      "location": "Lincoln High",
      "hasRecurrence": true,
      "recurrenceRule": {
        "frequency": "DAILY",
        "interval": 1,
        "byDay": ["MO", "TU", "WE", "TH", "FR"]
      },
      "memberNames": ["Alice"],
      "calendarId": "cal_alice@icloud.com"
    },
    {
      "id": "evt_dance_001",
      "title": "Dance",
      "startDate": "2025-11-22T16:00:00Z",
      "endDate": "2025-11-22T17:00:00Z",
      "location": "Dance Studio",
      "hasRecurrence": false,
      "memberNames": ["Alice"],
      "calendarId": "cal_alice@icloud.com"
    },
    {
      "id": "evt_soccer_001",
      "title": "Soccer",
      "startDate": "2025-11-25T17:00:00Z",
      "endDate": "2025-11-25T18:30:00Z",
      "location": "Central Park",
      "hasRecurrence": true,
      "recurrenceRule": {
        "frequency": "WEEKLY",
        "interval": 1,
        "byDay": ["MO"]
      },
      "memberNames": ["Bob"],
      "calendarId": "cal_bob@icloud.com"
    }
  ],
  "upcomingEvents": [
    // All events across all calendars for boundary detection
  ],
  "eventsPerPerson": 3
}
```

### JSON Example Output

```json
{
  "upcomingEventsSections": [
    {
      "memberName": "Alice",
      "memberColor": "#FF6B6B",
      "events": [
        {
          "eventId": "evt_school_001",
          "title": "School",
          "memberNames": ["Alice"],
          "memberColors": ["#FF6B6B"],
          "startDate": "2025-11-18T09:00:00Z",
          "endDate": "2025-11-18T15:00:00Z",
          "timeRange": "09:00 – 15:00",
          "location": "Lincoln High",
          "hasRecurrence": true,
          "recurringChips": [
            { "date": "2025-11-19", "label": "Tue 19" },
            { "date": "2025-11-20", "label": "Wed 20" },
            { "date": "2025-11-21", "label": "Thu 21" }
          ],
          "chipTruncationReason": "differentEventFound",
          "nextDifferentEvent": {
            "title": "Dance",
            "date": "2025-11-22"
          }
        },
        {
          "eventId": "evt_dance_001",
          "title": "Dance",
          "memberNames": ["Alice"],
          "memberColors": ["#FF6B6B"],
          "startDate": "2025-11-22T16:00:00Z",
          "endDate": "2025-11-22T17:00:00Z",
          "timeRange": "16:00 – 17:00",
          "location": "Dance Studio",
          "hasRecurrence": false,
          "recurringChips": null
        }
      ]
    },
    {
      "memberName": "Bob",
      "memberColor": "#4ECDC4",
      "events": [
        {
          "eventId": "evt_soccer_001",
          "title": "Soccer",
          "memberNames": ["Bob"],
          "memberColors": ["#4ECDC4"],
          "startDate": "2025-11-25T17:00:00Z",
          "endDate": "2025-11-25T18:30:00Z",
          "timeRange": "17:00 – 18:30",
          "location": "Central Park",
          "hasRecurrence": true,
          "recurringChips": [
            { "date": "2025-12-02", "label": "Tue 2" },
            { "date": "2025-12-09", "label": "Tue 9" },
            { "date": "2025-12-16", "label": "Tue 16" }
          ],
          "chipTruncationReason": "limitReached",
          "chipLimit": 5
        }
      ]
    }
  ]
}
```

---

## Edge Cases & Handling

### 1. **Overlapping Events**
**Scenario**: Two events at the same time for the same person
```
School: Mon 9am-3pm (recurring daily)
Doctor: Mon 10am-11am
```
**Handling**:
- Show both events as separate cards in Upcoming Events
- Each gets its own card with full details
- Doctor event stops expansion of School recurring chips

### 2. **Shared Calendars / Multiple Attendees**
**Scenario**: Event with multiple family members
```
Family Dinner: Alice + Bob + Charlie
```
**Handling**:
- Show in each person's Upcoming Events section separately
- Combine member names on single card if same event/time
- Use gradient colors if multiple members on shared event
- For Next Events, Alice sees it as next event, Bob sees it, Charlie sees it

### 3. **All-Day Events**
**Scenario**: Birthday, Vacation day
```
Alice's Birthday: All Day
```
**Handling**:
- `timeRange` = null/undefined
- Display "All Day" instead of time range
- Still shows date box with same styling

### 4. **Recurring Event at Boundary**
**Scenario**: School repeats daily, stops on Nov 21; Dance is Nov 22
```
School: Mon-Fri 9am (Daily)
Dance: Nov 22 4pm
```
**Handling**:
- Show: School (base) → [Tue 19, Wed 20, Thu 21]
- STOP: Don't include Nov 22+ occurrences (Dance is different event)
- Chip shows: "Next: Dance" or "Cut off by Dance event"

### 5. **Recurring Event with No Boundary**
**Scenario**: Weekly Soccer, no conflicting events for 3 months
```
Soccer: Every Monday 5pm
```
**Handling**:
- Show: Soccer (base) → [Next Mon, +2 Weeks, +3 Weeks, +4 Weeks, +5 Weeks]
- Stop at 5 chips (configurable limit)
- Indicator: "5 more occurrences" or "+" badge

### 6. **Past Events Filtering**
**Scenario**: User views events, event just started
```
Event: Today 2pm-3pm, it's currently 2:15pm
```
**Handling**:
- Include in Upcoming if startDate > now (strict)
- Once endDate < now, completely remove from view
- Next refresh loads new events

### 7. **No Events for Member**
**Scenario**: Member has no calendars linked or no upcoming events
```
Charlie has no calendars linked
```
**Handling**:
- Charlie appears in Next Events grid with "No upcoming events"
- Charlie doesn't appear in Upcoming Events section at all
- Settings show "Link calendars" link

### 8. **Event Across Multiple Calendars**
**Scenario**: Alice linked to 2 calendars, event exists in both
```
Alice's Calendars: [personal, work]
Meeting: Exists in both
```
**Handling**:
- Fetch only returns one instance (EventKit deduplicates)
- Safe with EventKit API behavior
- Show once with merged color/info

### 9. **Spanning Events (Multi-day)**
**Scenario**: Vacation spanning 3 days
```
Vacation: Nov 20-22 (3 days)
```
**Handling**:
- Show on first occurrence date (Nov 20)
- Time range: "All Day" (multi-day events are all-day)
- Don't repeat in daily view
- Recurring logic: Treat as single event

### 10. **Settings Change During View**
**Scenario**: User increases eventsPerPerson from 3 to 5
```
Before: Shows 3 events per person
After: Should show 5 events per person
```
**Handling**:
- Observe @AppStorage changes
- Trigger reload: `onChange(of: eventsPerPerson)`
- Animate transition or just update view

---

## Performance Considerations

### Data Loading Strategy
1. **Initial Load**: Fetch 100 events per member (configurable limit)
2. **Filtering**: Filter in memory, not API (faster on device)
3. **Sorting**: Sort by startDate once after fetch
4. **Caching**: Store in @State, refresh on interval (auto-refresh timer)

### Recurring Event Calculation
- Limit chip generation to 5 occurrences max (configurable)
- Calculate on-demand, not pre-calculated
- Cache results for same event until next refresh
- Stop early on boundary detection (optimization)

### Memory Optimization
- Don't store expanded occurrences permanently
- Generate chips from rule + calculation
- Release old events after refresh
- Limit view hierarchy depth (avoid deep nesting)

---

## Implementation Checklist

### Next Events Section
- [ ] Fetch next event per person (future only)
- [ ] Handle recurring: show first occurrence only
- [ ] 2-column grid layout
- [ ] Member avatar + initials circle
- [ ] Time until badge ("Tomorrow", "In 3 days")
- [ ] Card styling with shadow/corner radius
- [ ] Click to open event detail

### Upcoming Events Section
- [ ] Group by member name
- [ ] Limit events by eventsPerPerson setting
- [ ] Filter future events (startDate > now)
- [ ] Full event card: colored date box + details
- [ ] For recurring events: generate chip dates
- [ ] Stop chips at next different event
- [ ] Display chips inline or as tags
- [ ] Handle empty states per member

### Data Management
- [ ] Preserve recurrence rule from EventKit
- [ ] Calculate occurrence dates on demand
- [ ] Detect boundary conditions (next different event)
- [ ] Sort chronologically
- [ ] Refresh on timer interval
- [ ] Observe settings changes

### Testing Edge Cases
- [ ] Member with no calendars
- [ ] Member with no upcoming events
- [ ] Recurring event with boundary
- [ ] Overlapping recurring events
- [ ] Shared calendar event
- [ ] All-day event
- [ ] Multi-day event
- [ ] Past event filtering

---

## Current Implementation Notes

The app currently implements:
✅ Next Events section with 2x2 grid
✅ Per-person event grouping
✅ Future event filtering
✅ Recurring event detection
✅ Event card styling (colored date box + details)
✅ Auto-refresh timer
✅ Settings integration (eventsPerPerson)

**Pending Refinement**:
🔄 Recurring event chip display (currently shows as separate cards)
🔄 Boundary detection optimization
🔄 Chip UI styling and layout
