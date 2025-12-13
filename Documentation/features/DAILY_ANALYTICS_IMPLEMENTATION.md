# Daily Time Analytics Implementation Plan

## Overview
Add per-member daily time analytics to show free time remaining, busy time, and gap analysis for today and tomorrow. This will help parents answer "Do I have time for another event?" and "Am I over-scheduled?"

## Requirements Summary
- **Scope**: Per-member analytics for today and tomorrow
- **Time Boundaries**: Per-person wake/bed times (configurable in settings)
- **Free Time Calculation**: Exclude all-day events, count overlapping events as busy, include driver events as busy
- **Display**: Create 4 prototypes (SpotlightView tab, FamilyView cards, and 2 others) for user evaluation
- **Metrics**: Free time remaining, gap analysis, timeline visualization
- **Use Case**: Help parents manage schedules and decide if members have capacity

## Implementation Strategy

### Phase 1: Data Model (CoreData + Supabase)

#### Update FamilyMember Entity
**File**: `/Users/markdias/project/FamCal/FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel/contents`

Add to FamilyMember entity (lines 6-22):
```xml
<attribute name="wakeTimeHour" optional="YES" attributeType="Integer 16" defaultValueString="7" usesScalarValueType="YES"/>
<attribute name="wakeTimeMinute" optional="YES" attributeType="Integer 16" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="bedTimeHour" optional="YES" attributeType="Integer 16" defaultValueString="22" usesScalarValueType="YES"/>
<attribute name="bedTimeMinute" optional="YES" attributeType="Integer 16" defaultValueString="0" usesScalarValueType="YES"/>
<attribute name="useCustomSchedule" optional="YES" attributeType="Boolean" defaultValueString="NO" usesScalarValueType="YES"/>
```

Defaults: 7:00 AM wake, 10:00 PM bed (15 hours available)

#### Supabase Migration
**File**: `/Users/markdias/project/FamCal/supabase/migrations/YYYYMMDDHHMMSS_add_member_schedule.sql`

```sql
ALTER TABLE family_members
ADD COLUMN wake_time_hour INTEGER DEFAULT 7,
ADD COLUMN wake_time_minute INTEGER DEFAULT 0,
ADD COLUMN bed_time_hour INTEGER DEFAULT 22,
ADD COLUMN bed_time_minute INTEGER DEFAULT 0,
ADD COLUMN use_custom_schedule BOOLEAN DEFAULT FALSE;
```

#### Update SupabaseManager
**File**: `/Users/markdias/project/FamCal/FamCal/Managers/SupabaseManager.swift`

- Update FamilyMemberDTO to include schedule fields
- Modify `syncFamilyMember()` and `fetchFamilyMembers()` to handle new fields

---

### Phase 2: Analytics Calculation Engine

#### Create TimeAnalyticsCalculator
**New File**: `/Users/markdias/project/FamCal/FamCal/Utilities/TimeAnalyticsCalculator.swift`

Core data structures:
```swift
struct TimeAnalytics {
    let date: Date
    let memberID: UUID
    let totalAvailableMinutes: Int  // wake to bed
    let busyMinutes: Int            // non-overlapping event time
    let freeMinutes: Int            // available - busy
    let freePercentage: Int         // (free / available) * 100
    let gaps: [TimeGap]             // free blocks between events
    let busyBlocks: [BusyBlock]     // consolidated event times
}

struct TimeGap {
    let start: Date
    let end: Date
    let durationMinutes: Int
}

struct BusyBlock {
    let start: Date
    let end: Date
    let durationMinutes: Int
    let eventTitles: [String]
}
```

Algorithm:
1. **Filter events**: For specified date, exclude all-day events, filter by member
2. **Clamp to wake/bed**: Trim events outside wake-to-bed window
3. **Merge overlapping**: Sort by start time, merge into busy blocks
4. **Calculate gaps**: Identify free time between blocks (including before first/after last)
5. **Aggregate metrics**: Sum totals, calculate percentages

Key methods:
- `calculate(for:date:wakeTime:bedTime:events:) -> TimeAnalytics`
- `filterEvents(_:for:) -> [UpcomingCalendarEvent]`
- `consolidateBusyBlocks(_:wakeTime:bedTime:) -> [BusyBlock]`
- `calculateGaps(busyBlocks:wakeTime:bedTime:) -> [TimeGap]`

---

### Phase 3: Visualization Components

#### TimelineVisualizationView
**New File**: `/Users/markdias/project/FamCal/FamCal/Views/Analytics/TimelineVisualizationView.swift`

Horizontal timeline bar showing busy vs free blocks:
- Use GeometryReader for proportional sizing
- Busy blocks: Member's color
- Free blocks: Light gray/transparent
- Current time indicator: Red line (if today)
- Tap blocks to show time labels

#### AnalyticsMetricsView
**New File**: `/Users/markdias/project/FamCal/FamCal/Views/Analytics/AnalyticsMetricsView.swift`

Cards displaying:
- Free time remaining (hours/minutes, percentage)
- Busy time (hours/minutes, percentage)
- Largest gap (duration, time range)
- Number of free gaps

---

### Phase 4: Prototype Implementations

#### Prototype A: SpotlightView Analytics Tab
**File**: `/Users/markdias/project/FamCal/FamCal/Views/Shared/SpotlightView.swift`

Changes:
1. Update `SpotlightTab` enum (line 105-108):
```swift
private enum SpotlightTab: Hashable {
    case all
    case member
    case analytics  // NEW
}
```

2. Add tab button in `ribbonTabs` (line 435-449)

3. Add analytics content in `tabContent` switch (line 319-433):
```swift
case .analytics:
    VStack {
        // Day selector (Today/Tomorrow)
        dayPickerSegmented

        // Timeline visualization
        TimelineVisualizationView(analytics: analytics)

        // Metrics cards
        AnalyticsMetricsView(analytics: analytics)

        // Event list for context
        compactEventsList
    }
```

4. Add state for selected date and analytics calculation

**Pros**: Natural fit in existing member-focused view, minimal navigation changes
**Cons**: Adds third tab to already dual-tab interface

#### Prototype B: FamilyView Compact Cards
**New File**: `/Users/markdias/project/FamCal/FamCal/Views/prototypes/FamilyAnalyticsPrototype.swift`

Add to FamilyView after Upcoming Events section:
- Horizontal scroll of compact analytics cards
- Each card shows: member name, mini timeline, free time %
- Tap card navigates to SpotlightView analytics tab

**Pros**: At-a-glance overview of all members, quick comparison
**Cons**: Adds to already dense FamilyView

#### Prototype C: Standalone Analytics View
**New File**: `/Users/markdias/project/FamCal/FamCal/Views/Analytics/AnalyticsView.swift`

Full-featured analytics dashboard:
- Member picker
- Date picker (Today/Tomorrow/Custom)
- Full timeline
- Detailed metrics
- Insights section (future: "Best time to add event" suggestions)

**Pros**: Maximum flexibility, room for advanced features
**Cons**: Requires new navigation entry point

#### Prototype D: Modal/Sheet Analytics
**New File**: `/Users/markdias/project/FamCal/FamCal/Views/Analytics/AnalyticsModalView.swift`

Accessible via long-press on member in FamilyView:
- Sheet presentation with analytics
- Quick view without navigation

**Pros**: Contextual access, doesn't change existing navigation
**Cons**: Limited space, modal context switch

---

### Phase 5: Settings UI

#### Member Schedule Settings
**New File**: `/Users/markdias/project/FamCal/FamCal/Views/Settings/MemberScheduleSettingsView.swift`

Form with:
- Toggle: "Use Custom Schedule"
- Time pickers: Wake time, Bed time (only shown if custom enabled)
- Preview card showing available hours
- Save triggers CoreData + Supabase sync

Integration: Add to member settings or FamilyView member context menu

---

## Critical Files

### To Modify
1. `/Users/markdias/project/FamCal/FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel/contents` - Add wake/bed attributes
2. `/Users/markdias/project/FamCal/FamCal/Views/Shared/SpotlightView.swift` - Add analytics tab
3. `/Users/markdias/project/FamCal/FamCal/Managers/SupabaseManager.swift` - Sync schedule data

### To Create
1. `/Users/markdias/project/FamCal/FamCal/Utilities/TimeAnalyticsCalculator.swift` - Core analytics engine
2. `/Users/markdias/project/FamCal/FamCal/Views/Analytics/TimelineVisualizationView.swift` - Timeline component
3. `/Users/markdias/project/FamCal/FamCal/Views/Analytics/AnalyticsMetricsView.swift` - Metrics cards
4. `/Users/markdias/project/FamCal/FamCal/Views/Settings/MemberScheduleSettingsView.swift` - Settings UI
5. `/Users/markdias/project/FamCal/FamCal/Views/prototypes/FamilyAnalyticsPrototype.swift` - FamilyView cards
6. `/Users/markdias/project/FamCal/FamCal/Views/Analytics/AnalyticsView.swift` - Standalone view
7. `/Users/markdias/project/FamCal/FamCal/Views/Analytics/AnalyticsModalView.swift` - Modal view
8. `/Users/markdias/project/FamCal/supabase/migrations/YYYYMMDDHHMMSS_add_member_schedule.sql` - DB migration

---

## Implementation Sequence

### Step 1: Data Foundation (CoreData Model Update)

**CRITICAL**: This step modifies the CoreData model. Follow these sub-steps carefully to avoid data loss.

#### 1.1 Open CoreData Model
- File: `/Users/markdias/project/FamCal/FamCal/FamCal.xcdatamodeld/FamCal.xcdatamodel/contents`
- Open in Xcode's Data Model editor (not text editor)

#### 1.2 Add Attributes to FamilyMember Entity
Select FamilyMember entity, add these attributes in the Attributes inspector:

| Attribute Name | Type | Optional | Default | Scalar |
|----------------|------|----------|---------|--------|
| wakeTimeHour | Integer 16 | Yes | 7 | Yes |
| wakeTimeMinute | Integer 16 | Yes | 0 | Yes |
| bedTimeHour | Integer 16 | Yes | 22 | Yes |
| bedTimeMinute | Integer 16 | Yes | 0 | Yes |
| useCustomSchedule | Boolean | Yes | NO | Yes |

#### 1.3 Generate NSManagedObject Subclass (if needed)
- Editor → Create NSManagedObject Subclass
- Select FamilyMember entity
- Replace existing FamilyMember+CoreDataProperties.swift if prompted

#### 1.4 Verify Model Version
- Xcode should NOT prompt for model migration since attributes are optional with defaults
- If prompted: Create new model version, don't modify existing

#### 1.5 Test Data Persistence
```swift
// Test code to verify attributes persist
let member = FamilyMember(context: viewContext)
member.wakeTimeHour = 8
member.bedTimeHour = 23
try? viewContext.save()

// Verify fetch
let fetch = FamilyMember.fetchRequest()
let results = try? viewContext.fetch(fetch)
print(results?.first?.wakeTimeHour) // Should print 8
```

**Safety Check**: Existing FamilyMember records should retain all existing data with new fields defaulting to nil (optional) or default values.

---

### Step 2: Supabase Migration (Database Schema Update)

**CRITICAL**: This step modifies the Supabase schema. Existing sync logic must not break.

#### 2.1 Create Migration File
- File: `/Users/markdias/project/FamCal/supabase/migrations/20251213220000_add_member_schedule.sql`
- Use timestamp format: YYYYMMDDHHMMSS

#### 2.2 Migration SQL
```sql
-- Add schedule columns to family_members table
ALTER TABLE family_members
ADD COLUMN IF NOT EXISTS wake_time_hour INTEGER DEFAULT 7,
ADD COLUMN IF NOT EXISTS wake_time_minute INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS bed_time_hour INTEGER DEFAULT 22,
ADD COLUMN IF NOT EXISTS bed_time_minute INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS use_custom_schedule BOOLEAN DEFAULT FALSE;

-- Add comment for documentation
COMMENT ON COLUMN family_members.wake_time_hour IS 'Hour member wakes up (0-23), default 7am';
COMMENT ON COLUMN family_members.bed_time_hour IS 'Hour member goes to bed (0-23), default 10pm';
```

#### 2.3 Apply Migration
```bash
cd supabase
supabase db reset  # If testing locally
# OR
supabase db push   # For production
```

#### 2.4 Verify Schema
```sql
-- Run in Supabase SQL editor
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'family_members'
AND column_name LIKE '%time%';
```

**Safety Check**: Use `IF NOT EXISTS` to make migration idempotent. Existing rows will have default values.

---

### Step 3: Supabase Sync Logic (CRITICAL - Avoid Breaking Existing Sync)

**File**: `/Users/markdias/project/FamCal/FamCal/Managers/SupabaseManager.swift`

#### 3.1 Update FamilyMemberDTO
Locate the FamilyMemberDTO struct (should be near top of file), add new fields:

```swift
struct FamilyMemberDTO: Codable {
    // ... existing fields ...
    let wake_time_hour: Int?      // NEW - must be optional for backward compatibility
    let wake_time_minute: Int?    // NEW
    let bed_time_hour: Int?       // NEW
    let bed_time_minute: Int?     // NEW
    let use_custom_schedule: Bool? // NEW
}
```

**CRITICAL**: Make fields optional (`?`) to maintain backward compatibility with existing data.

#### 3.2 Update syncFamilyMember() - UPLOAD to Supabase
Locate `syncFamilyMember()` method, modify the DTO creation to include new fields:

```swift
func syncFamilyMember(_ member: FamilyMember) async throws {
    let dto = FamilyMemberDTO(
        // ... existing fields ...
        wake_time_hour: Int(member.wakeTimeHour),           // NEW
        wake_time_minute: Int(member.wakeTimeMinute),       // NEW
        bed_time_hour: Int(member.bedTimeHour),             // NEW
        bed_time_minute: Int(member.bedTimeMinute),         // NEW
        use_custom_schedule: member.useCustomSchedule       // NEW
    )

    // ... rest of existing sync logic (DO NOT MODIFY) ...
}
```

**Safety**: Only ADD fields to DTO, don't remove or rename existing fields.

#### 3.3 Update fetchFamilyMembers() - DOWNLOAD from Supabase
Locate `fetchFamilyMembers()` method, modify the CoreData mapping to include new fields:

```swift
func fetchFamilyMembers() async throws -> [FamilyMemberDTO] {
    // ... existing fetch logic ...

    // When mapping DTO to CoreData, add:
    member.wakeTimeHour = Int16(dto.wake_time_hour ?? 7)        // NEW - default to 7 if nil
    member.wakeTimeMinute = Int16(dto.wake_time_minute ?? 0)    // NEW
    member.bedTimeHour = Int16(dto.bed_time_hour ?? 22)         // NEW - default to 10pm
    member.bedTimeMinute = Int16(dto.bed_time_minute ?? 0)      // NEW
    member.useCustomSchedule = dto.use_custom_schedule ?? false // NEW

    // ... rest of existing mapping (DO NOT MODIFY) ...
}
```

**Safety**: Use nil coalescing (`??`) to provide defaults for existing records that don't have these fields yet.

#### 3.4 Test Sync (DO NOT SKIP)
```swift
// Test upload
let member = fetchedMember
member.wakeTimeHour = 8
try await SupabaseManager.shared.syncFamilyMember(member)

// Verify in Supabase dashboard that wake_time_hour = 8

// Test download
let members = try await SupabaseManager.shared.fetchFamilyMembers()
print(members.first?.wake_time_hour) // Should print 8
```

**Safety Checklist**:
- [ ] Existing member data still syncs correctly
- [ ] New fields sync both directions (up and down)
- [ ] Nil values don't crash the app
- [ ] Default values applied correctly for existing members

---

### Step 4: Analytics Calculation Engine

**New File**: `/Users/markdias/project/FamCal/FamCal/Utilities/TimeAnalyticsCalculator.swift`

See full implementation in code sections below.

---

### Step 5: Timeline Visualization Component

**New File**: `/Users/markdias/project/FamCal/FamCal/Views/Analytics/TimelineVisualizationView.swift`

Horizontal timeline bar showing busy vs free blocks with current time indicator.

---

### Step 6: Metrics Display Component

**New File**: `/Users/markdias/project/FamCal/FamCal/Views/Analytics/AnalyticsMetricsView.swift`

Metrics cards showing free time, busy time, longest gap, and free block count.

---

### Step 7: Settings UI for Wake/Bed Times

**New File**: `/Users/markdias/project/FamCal/FamCal/Views/Settings/MemberScheduleSettingsView.swift`

Form with custom schedule configuration and preview.

---

### Step 8: Prototype A - SpotlightView Analytics Tab

**File**: `/Users/markdias/project/FamCal/FamCal/Views/Shared/SpotlightView.swift`

Add `.analytics` case to SpotlightTab enum and implement analytics content.

---

### Step 9: Remaining Prototypes (B, C, D)

These follow similar patterns but with different integration points:

**Prototype B (FamilyView Cards)**: Add horizontal scroll section to FamilyView
**Prototype C (Standalone View)**: New top-level navigation destination
**Prototype D (Modal)**: Sheet presentation from long-press gesture

Each prototype uses the same core components (TimeAnalyticsCalculator, TimelineVisualizationView, AnalyticsMetricsView) but with different layouts and navigation patterns.

---

## Testing Checklist

Before marking any step complete:

- [ ] Step 1: CoreData model updated, no migration issues, existing data intact
- [ ] Step 2: Supabase migration applied, schema verified
- [ ] Step 3: Sync works both directions, nil values handled, existing members unaffected
- [ ] Step 4: Calculator produces correct results for edge cases
- [ ] Step 5: Timeline displays correctly at different screen sizes
- [ ] Step 6: Metrics format correctly (hours/minutes display)
- [ ] Step 7: Settings save and sync properly
- [ ] Step 8: Analytics tab loads without crashing
- [ ] Step 9: All prototypes functional

---

## Key Design Decisions

**Wake/Bed Times**: Stored per-member with defaults (7am-10pm), configurable via toggle in settings

**Event Filtering**:
- Exclude all-day events from busy time
- Include events where member has driver assignment
- Merge overlapping events to avoid double-counting

**Timeline Visualization**: Horizontal bar with proportional blocks, inspired by DailyEventsView's timeline approach

**Prototype Strategy**: Build 4 options for user evaluation, then refine chosen approach rather than guessing best fit upfront

**Future Consideration**: Travel time prediction noted but deferred (requires location APIs, real-time tracking complexity)

---

## Edge Cases Handled

- Member with no events → 100% free time
- Events spanning midnight → Split by day boundary
- Wake time after bed time → Validation error in settings
- All-day schedule (24 hours) → Support 0:00-23:59 range
- Events outside wake/bed window → Clamp or exclude
- Multiple overlapping events → Merge into single busy block
- Driver events → Count as busy time for driver member

---

## Success Criteria

- [x] Per-member wake/bed times configurable and synced
- [x] Analytics accurately calculate free vs busy time
- [x] Timeline visualization clearly shows daily breakdown
- [x] User can view analytics for today and tomorrow
- [x] All 4 prototypes functional for user testing
- [x] No performance degradation on event list loading
- [x] Analytics update in real-time as events change
