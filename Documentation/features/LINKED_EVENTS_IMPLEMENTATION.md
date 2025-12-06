# Linked Events & Soft Delete Implementation Guide

## Overview
This document describes the comprehensive system for handling linked recurring event deletions, soft deletes (mark not attending), and attendee management with scope options in FamCal.

## New Features

### 1. Linked Event Deletion (5 Scenarios)

#### Scenario 1: Delete Single Occurrence for All People
- **When:** You want to remove a specific day's event for everyone
- **Flow:** Delete → All Linked → Hard Delete → This Event Only
- **Result:** Event removed for all linked calendars, rest of series continues
- **Example:** "Team Meeting Jan 15" deleted for everyone, but Jan 22, 29 remain

#### Scenario 2: Delete Single Occurrence for One Person
- **When:** One person can't attend one occurrence but others still can
- **Options:** Soft Delete (default) or Hard Delete
- **Soft Delete:** Event remains in calendar but marked "Not Attending" (grayed out)
- **Hard Delete:** Event completely removed from that person's calendar
- **Flow:** Delete → This Calendar → Soft/Hard Delete → This Event Only

#### Scenario 3: Delete Entire Recurrence for All People
- **When:** Cancel a recurring meeting completely for everyone
- **Flow:** Delete → All Linked → Hard Delete → All Events in Series
- **Result:** Entire recurring series removed for all people
- **Warning:** "This cannot be undone"

#### Scenario 4: Delete Entire Recurrence for One Person
- **When:** Person stops attending entire recurring series
- **Options:** Soft Delete (keep history) or Hard Delete (complete removal)
- **Soft Delete:** Event visible but marked "Not Attending"
- **Hard Delete:** Completely removed
- **Flow:** Delete → This Calendar → Soft/Hard Delete → All Events in Series

#### Scenario 5 (Bonus): Delete "This & Future" for One Person
- **When:** Person can only attend up to a certain date
- **Flow:** Delete → This Calendar → Soft/Hard Delete → This and Future Events
- **Result:** Person removed from this occurrence and all future ones

### 2. Soft Delete (Mark Not Attending)
- **Purpose:** Track that someone is not attending without deleting event history
- **Features:**
  - Optional deletion reason (stored in CoreData & Supabase)
  - Event remains visible but grayed out in calendar
  - Automatically hidden from event lists/views
  - Can be restored later if needed
  - Syncs across all devices via Supabase

### 3. Attendee Editing with Scope
- **When editing attendees on a linked event:**
  1. Change attendee list
  2. Tap Save
  3. Dialog appears: "Update for this event only" or "Update for all linked events"
  4. Changes applied based on selection
- **Automatic Detection:** Tracks original attendees and only shows dialog if changed

## Data Model Changes

### FamilyEvent Entity - New Fields
```swift
isAttending: Bool         // Default: true, false = not attending (soft deleted)
deletionType: String?     // "hard" or "soft"
deletedAt: Date?          // Timestamp when soft deleted
deletionReason: String?   // Optional reason for deletion
```

## Technical Implementation

### Files Created
1. **EventDeletionEnums.swift** - All enums, types, and DeletionContext
2. **LinkedEventDeletionHandler.swift** - Core deletion orchestration logic

### Files Modified
1. **EditEventView.swift** - 4-step deletion dialog flow + attendee editing
2. **EventDetailView.swift** - Same deletion flow as EditEventView
3. **SupabaseManager.swift** - Soft delete sync methods
4. **CalendarManager.swift** - Soft delete filtering for event displays
5. **FamCal.xcdatamodel** - Added 4 fields to FamilyEvent

## Dialog Flow

### Deletion Process (4 Steps)
```
1. Click Delete
   ↓
2. [IF linked events exist] Scope Dialog: "Single Calendar" or "All Linked"
   ↓
3. Deletion Type Dialog: "Mark as Not Attending" or "Delete Permanently"
   ↓
4. [IF recurring + hard delete] Target Dialog: "This Event", "This & Future", or "All in Series"
   ↓
5. Confirmation Dialog: Smart message showing exactly what will happen
   ↓
6. [IF soft delete] Optional: Reason Sheet - "Why are you removing this?"
   ↓
7. Execute Deletion → Success feedback → Auto-dismiss
```

### Attendee Editing (2 Steps)
```
1. Edit attendees and tap Save
   ↓
2. [IF attendees changed AND linked events exist]
   Scope Dialog: "Update for this event only" or "Update for all linked events"
   ↓
3. Save with selected scope
```

## Filtering & Display

### Soft-Deleted Events
- **Calendar Views:** Automatically hidden from all calendar displays
- **Event Lists:** Filtered out by CalendarManager.fetchNextEvents()
- **Widgets:** Soft-deleted events not shown in widgets
- **Appearance:** If visible (admin mode), would appear grayed out

### Filtering Logic
- CalendarManager checks CoreData for `eventIdentifier` where `isAttending == false`
- Soft-deleted events skipped during event fetching
- Applied consistently across all calendar views

## Supabase Sync

### Methods Added
- **`syncSoftDeletedEvent()`** - Sync soft delete state to Supabase
- **`restoreSoftDeletedEvent()`** - Restore soft deleted event

### Sync Behavior
1. When soft delete happens → syncs to Supabase in background
2. Deletion metadata stored: `is_attending`, `deletion_type`, `deleted_at`, `deletion_reason`
3. Cross-device sync: Other devices pull metadata and update local state
4. Graceful degradation: If sync fails, deletion still works locally

## Key Classes & Enums

### DeletionScope
```swift
case singleCalendar    // Only this person's calendar
case allLinked         // All linked calendars
```

### DeletionTarget
```swift
case singleOccurrence   // Just this day's event
case thisAndFuture      // This and all future occurrences
case allInSeries        // Entire recurring series
```

### DeleteActionType
```swift
case hardDelete    // Permanent deletion from EventKit & CoreData
case softDelete    // Mark isAttending=false (not attending)
```

### DeletionContext
Contains all deletion metadata and generates contextual confirmation messages:
- `displayMessage` - Smart message for confirmation dialog
- `actionButtonTitle` - "Delete" or "Mark as Not Attending"

## Error Handling

### Graceful Degradation
- If Supabase sync fails, deletion still succeeds locally
- Sync retries on next network sync cycle
- Failed syncs logged for debugging

### Validation
- Checks calendar ID exists before deletion
- Validates event exists in EventKit before attempting delete
- Handles missing FamilyEvent records gracefully

## Testing Checklist

### Deletion Scenarios
- [ ] Scenario 1: Delete single occurrence for all people
- [ ] Scenario 2: Soft delete single occurrence for 1 person
- [ ] Scenario 2b: Hard delete single occurrence for 1 person
- [ ] Scenario 3: Delete entire series for all people
- [ ] Scenario 4: Soft delete entire series for 1 person
- [ ] Scenario 4b: Hard delete entire series for 1 person
- [ ] Scenario 5: Soft delete "this & future" for 1 person

### Soft Delete Features
- [ ] Event marked as not attending appears grayed (if visible)
- [ ] Soft-deleted events filtered from calendar views
- [ ] Deletion reason saved and displayed
- [ ] Soft delete syncs to Supabase
- [ ] Cross-device soft delete sync works

### Attendee Editing
- [ ] Changing attendees shows scope dialog
- [ ] "Update this event only" works correctly
- [ ] "Update all linked events" propagates to all copies
- [ ] Attendee changes sync to Supabase

### Recurrence Handling
- [ ] Single occurrence deletion works
- [ ] "This & future" works for recurring events
- [ ] "All in series" works for recurring events
- [ ] Non-recurring events don't show recurrence options

### Edge Cases
- [ ] Deleting non-existent event fails gracefully
- [ ] Soft delete with no reason works (optional)
- [ ] Restoration of soft-deleted events works
- [ ] Multiple linked calendars handled correctly

## Future Enhancements

1. **Visual Indicators** - Gray out soft-deleted events in calendar UI
2. **Undo Toast** - "Event removed - Undo?" notification
3. **Restore Menu** - Long-press to restore soft-deleted events
4. **Deletion History** - View list of deleted events
5. **Batch Operations** - Delete multiple occurrences at once
6. **Conflict Resolution** - Handle simultaneous edits/deletes

## Debugging

### Logging
All deletions and syncs logged with emojis:
- 🗑️ Deletion started
- ✅ Deletion succeeded
- ❌ Deletion failed
- 🔄 Sync in progress
- ⊘ Soft-deleted event filtered

### Common Issues

**Problem:** "Missing package product" warnings
- **Solution:** Run `pod install` and `swift package resolve`

**Problem:** Soft-deleted events still showing
- **Check:** Verify `isAttending` field in FamilyEvent CoreData
- **Check:** Confirm CalendarManager.isSoftDeletedEvent() is being called

**Problem:** Supabase sync not working
- **Check:** Network connectivity
- **Check:** Authentication token valid
- **Check:** Family_events table has new columns (is_attending, deletion_type, etc.)

## API Reference

### LinkedEventDeletionHandler

```swift
// Main deletion execution
static func executeLinkedEventDeletion(
    scope: DeleteScope,
    target: DeletionTarget,
    actionType: DeleteActionType,
    primaryEvent: UpcomingCalendarEvent,
    linkedFamilyEvents: [FamilyEvent],
    affectedMember: FamilyMember?,
    deletionReason: String?,
    viewContext: NSManagedObjectContext
) async -> Bool

// Soft delete recovery
func canRestoreEvent(_ event: FamilyEvent) -> Bool
func restoreEvent(_ event: FamilyEvent, viewContext: NSManagedObjectContext)

// Get affected people for messaging
func getAffectedPeopleNames(
    scope: DeleteScope,
    linkedFamilyEvents: [FamilyEvent],
    currentMemberName: String?
) -> [String]
```

### CalendarManager

```swift
// Filter out soft-deleted events automatically
private static func isSoftDeletedEvent(eventIdentifier: String) -> Bool
```

### SupabaseManager

```swift
func syncSoftDeletedEvent(
    userId: String,
    eventIdentifier: String,
    isAttending: Bool,
    deletionType: String?,
    deletionReason: String?
) async throws

func restoreSoftDeletedEvent(
    userId: String,
    eventIdentifier: String
) async throws
```

## Support

For issues or questions about the linked events implementation, refer to:
- `EventDeletionEnums.swift` - Type definitions and messaging logic
- `LinkedEventDeletionHandler.swift` - Core deletion logic
- `EditEventView.swift` - UI/UX for deletion flow
- `CalendarManager.swift` - Filtering logic
