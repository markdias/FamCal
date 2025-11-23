# FamCal Development Notes

## Overview
FamCal is an iOS calendar application built with SwiftUI and CoreData. It uses a multi-screen onboarding flow to introduce users to the app and request necessary permissions.

## Instructions 
Ask Questions if unsure. 
Using Settings Layout.png as a design guide for settings

## Completed Tasks (Nov 17, 2025)

### Initial Launch Screens
- **IntroScreen.swift**: First launch screen with app intro, calendar icon, and "Get Started" button
- **PermissionScreen.swift**: Calendar permission request screen with EventKit integration
  - Displays current permission status with green checkmark when granted
  - Triggers iOS system permission dialog on tap
  - "Next" button only appears after permission is granted
- **ReadyScreen.swift**: Final launch screen with success message and "Start Using FamCal" button
- **OnboardingView.swift**: Manages navigation between the three onboarding screens
  - Uses enum-based state (`OnboardingStep`) for clean state management
  - Tracks completion in UserDefaults with key "hasCompletedOnboarding"
  - Shows FamilyView via fullScreenCover upon completion

### Support Changes
- **FamCalApp.swift**: Updated to check onboarding completion and route to appropriate view
- **Info.plist**: Added NSCalendarsUsageDescription for iOS calendar access
- **FamilyView.swift**: Created as main home screen (currently shows "Family" title, ready for content expansion)

## Design Decisions
1. **Navigation**: Used enum-based state management (`OnboardingStep`) - simplest and cleanest approach
2. **State Persistence**: UserDefaults for tracking onboarding completion across app launches
3. **Permission Handling**: EventKit's `requestFullAccessToEvents` for iOS 17+ compatibility
4. **UI/UX**:
   - Consistent spacing (16px padding, 12px gaps)
   - Blue primary actions with 56px button height
   - Green checkmark for granted permissions (visually obvious)
   - System background color for clean appearance
   - 12px corner radius for modern look

## Architecture Notes
- Framework: SwiftUI
- Data: CoreData with PersistenceController
- Entitlements: Minimal (removed Push Notifications and iCloud for personal development team compatibility)
- Permissions: Calendar access via EventKit

## Build Issues Fixed (Nov 17, 2025)
- Removed Push Notifications and iCloud capabilities from entitlements (personal dev teams don't support these)
- Removed unused `eventStore` variable in `checkCalendarPermission()` method
- Project now builds without provisioning profile errors

## Key Files
### Onboarding
- `FamCalApp.swift` - App entry point with onboarding routing logic
- `OnboardingView.swift` - Onboarding orchestrator and state management
- `IntroScreen.swift` - Initial welcome screen
- `PermissionScreen.swift` - Calendar permission request with EventKit
- `ReadyScreen.swift` - Completion screen

### Core App
- `FamilyView.swift` - Main home screen with settings button
- `Persistence.swift` - CoreData setup

### Family Management
- `FamilySettingsView.swift` - Family members screen (add, edit, delete)
- `AddFamilyMemberView.swift` - Create new family member
- `EditFamilyMemberView.swift` - Edit existing family member
- `VisibleCalendarsView.swift` - Shows all visible calendars (members + shared)
- `AddSharedCalendarView.swift` - Select and add shared calendars (grouped by account)
- `CalendarManager.swift` - iOS calendar fetching and matching with account info
- `ColorExtensions.swift` - Color utilities for hex/Color conversion and UIColor.hex()

### Configuration
- `Info.plist` - Contains NSCalendarsUsageDescription
- `FamCal.xcdatamodeld` - CoreData model with FamilyMember and SharedCalendar entities

### Family Settings Implementation (Nov 17, 2025)
- **FamilyMember** CoreData entity with properties:
  - `id` (UUID) - unique identifier
  - `name` (String) - family member's name
  - `linkedCalendarID` (String, optional) - matched iOS calendar identifier
  - `colorHex` (String) - hex color code for avatar (default: #007AFF)
  - `avatarInitials` (String) - generated initials from name

- **CalendarManager.swift**: Handles iOS calendar operations
  - `fetchAvailableCalendars()` - retrieves all user's iOS calendars (on-demand)
  - `findMatchingCalendar()` - case-insensitive exact name matching
  - Returns `AvailableCalendar` struct with id, title, and UIColor

- **FamilySettingsView.swift**: Main settings screen
  - Shows list of all family members sorted by name
  - Displays calendar link status (green check or orange warning)
  - Add button for new members
  - Edit/delete functionality with swipe support
  - Empty state when no members exist

- **AddFamilyMemberView.swift**: Create new family member
  - Text input for name
  - Color picker with 9 preset colors
  - Real-time calendar matching (triggers on name change)
  - Shows matched calendar with visual preview
  - Auto-generates initials for avatar
  - Disables save button if name is empty

- **EditFamilyMemberView.swift**: Edit existing family member
  - Same UI as AddFamilyMemberView for consistency
  - Pre-populates with current member data
  - Re-matches calendar when name changes
  - Removes calendar link if no match found

- **ColorExtensions.swift**: Color utilities
  - `familyColors` - array of 9 preset colors
  - `toHex()` - converts Color to hex string
  - `fromHex()` - creates Color from hex string

- **FamilyView.swift**: Updated with settings access
  - Gear icon button in bottom-left corner
  - Button styled with blue color on gray background
  - Opens FamilySettingsView in sheet

### Shared Calendar Implementation (Nov 17, 2025)
- **SharedCalendar** CoreData entity with properties:
  - `id` (UUID) - unique identifier
  - `calendarID` (String) - iOS calendar identifier
  - `calendarName` (String) - calendar display name
  - `calendarColorHex` (String) - hex color code for display

- **AddSharedCalendarView.swift**: Select and add shared calendars
  - Shows all available calendars on the device
  - Displays calendar name and color
  - Prevents duplicate calendar additions
  - Green checkmark for already-added calendars
  - Loading state while fetching calendars

- **FamilySettingsView.swift**: Refactored with two sections
  - **Visible Calendars** section (top):
    - Shows linked family member calendars
    - Shows shared family calendars
    - X button to remove shared calendars
    - "Add Shared Calendar" button for new calendars
  - **Family Members** section (below):
    - Shows all family members
    - Option to add and edit members

- **ColorExtensions.swift**: Added UIColor.hex() method
  - Converts UIColor to hex string
  - Used for storing calendar colors in CoreData

### Multiple Calendars per Family Member Implementation (Nov 17, 2025)
- **FamilyMemberCalendar** CoreData entity (NEW) with properties:
  - `id` (UUID, optional) - unique identifier
  - `calendarID` (String, optional) - iOS calendar identifier
  - `calendarName` (String, optional) - calendar display name
  - `calendarColorHex` (String, optional) - hex color code for display
  - `isAutoLinked` (Bool, optional, default: NO) - indicates if calendar was auto-matched or manually added
  - Relationship to FamilyMember (many-to-one, inverse relationship)

- **FamilyMember** CoreData entity (UPDATED):
  - Now has one-to-many relationship `memberCalendars` to FamilyMemberCalendar entities
  - `linkedCalendarID` remains for backward compatibility but now also populated via relationship

- **SelectMemberCalendarsView.swift** (NEW):
  - Modal view for selecting multiple calendars for a family member
  - Shows member header with avatar and count badge
  - Two sections: "Linked Calendars" and "Add More Calendars"
  - Auto-linked calendar is greyed out (opacity: 0.6) with lock icon, not removable
  - Manual calendars have X button for removal
  - Available calendars grouped by source account (iCloud, Gmail, Exchange, etc.)
  - Click plus icon to add more calendars
  - Done button to close

- **VisibleCalendarsView.swift** (UPDATED):
  - Family member names now clickable/tappable (not just read-only rows)
  - Shows count badge: "John (3)" where 3 is number of linked calendars
  - Expandable/collapsible sections for each family member
  - Expanded content shows all linked calendars (auto and manual)
  - Auto-linked calendars show lock icon and are slightly greyed out
  - "Select Calendars" button in expanded section opens SelectMemberCalendarsView sheet
  - Chevron icon indicates expand/collapse state (up/down)

- **AddFamilyMemberView.swift** (UPDATED):
  - Now creates FamilyMemberCalendar entry for auto-matched calendar
  - Sets `isAutoLinked = true` for the matched calendar
  - Establishes relationship between FamilyMember and FamilyMemberCalendar

- **EditFamilyMemberView.swift** (UPDATED):
  - Handles calendar relationship updates when name changes
  - If new name matches a different calendar, updates the auto-linked entry
  - If new name matches no calendar, removes the auto-linked entry
  - Preserves all manually-added calendars when updating

- **FamilySettingsView.swift** (UPDATED):
  - Now filters members using `memberCalendars` relationship instead of `linkedCalendarID`
  - Displays count of linked calendars in member rows
  - Shows "X calendars linked" (instead of single "Calendar linked")
  - Uses `memberCalendars` to check if member has any calendars

### Shared Calendar Enhancement - Many-to-Many Relationship (Nov 17, 2025)
- **CoreData Model Changes**:
  - SharedCalendar now has `members` relationship (one-to-many to FamilyMember)
  - FamilyMember now has `sharedCalendars` relationship (many-to-many with SharedCalendar)
  - Enables automatic linking of shared calendars to all family members

- **AddSharedCalendarView.swift** (UPDATED):
  - Fetches all FamilyMember entities
  - When a shared calendar is added, links it to all existing members via `addToMembers()`
  - Ensures shared calendars are accessible to everyone

- **FamilyView.swift** (SIMPLIFIED):
  - Removed separate `sharedCalendarSelections` FetchRequest
  - Removed union logic that manually combined shared calendars with member calendars
  - Now only iterates through familyMembers and their memberCalendarLinks
  - Retrieves shared calendars through the relationship: `member.sharedCalendars`
  - Fetches ONE next event per person across all their calendars (personal + shared)

- **SelectMemberCalendarsView.swift** (UPDATED):
  - Added `sharedCalendars` FetchRequest to display all shared calendars
  - New "Shared Calendars" section shows calendars shared with all members
  - Shared calendars greyed out and marked with "Shared with all" label
  - User can view but not remove shared calendars (they're linked to everyone)
  - Personal calendar selection unchanged (can add/remove individual selections)

### Visible Calendars Implementation (Nov 17, 2025)
- **VisibleCalendarsView.swift**: Dedicated screen for viewing all visible calendars
  - Shows linked family member calendars
  - Shows shared family calendars
  - X button to remove shared calendars
  - "Add Shared Calendar" button
  - Empty state when no calendars visible

- **AddSharedCalendarView.swift**: Updated with account grouping
  - Calendars grouped by source (iCloud, Gmail, Exchange, etc.)
  - Section headers show account names
  - Calendars sorted alphabetically within each account
  - Duplicate prevention (green checkmark)
  - Clean visual separation between account groups

- **CalendarManager.swift**: Enhanced calendar fetching
  - Now includes sourceTitle (account name) and sourceType (EKSourceType)
  - Used for grouping calendars by account in AddSharedCalendarView

- **SettingsView.swift**: Reorganized menu structure
  - "Visible Calendars" menu item opens VisibleCalendarsView
  - "Family Members" menu item opens FamilySettingsView
  - Cleaner separation of concerns

- **FamilySettingsView.swift**: Simplified to Family Members only
  - Removed Visible Calendars section
  - Focuses solely on managing family members
  - Cleaner, more focused UI

## Design Decisions (Family Settings)
1. **Data Storage**: CoreData for persistent storage of family members and shared calendars
2. **Calendar Matching**: Case-insensitive exact name matching only (no partial/fuzzy matching)
3. **Color Scheme**: 9 preset colors for family member avatars, iOS calendar colors for shared calendars
4. **Avatar**: Generated from first letters of name (e.g., "John Doe" = "JD")
5. **Calendar Linking**: Automatic on-demand for family members, manual selection for shared calendars
6. **Deleted Calendars**: Links removed silently if calendar no longer exists on device
7. **Performance**: Calendar fetching runs on background thread to prevent UI blocking
8. **Matching Logic**: Triggered on name input change with real-time feedback
9. **Shared Calendars**: Multiple calendars can be added, duplicate prevention in UI, X button to remove
10. **Settings Layout**: VisibleCalendarsView accessed from main Settings menu, FamilySettingsView for member management
11. **Calendar Grouping**: Calendars grouped by account/source for clarity and organization

## Design Decisions (Multiple Calendars per Member)
1. **Relationship Model**:
   - One-to-many FamilyMember → FamilyMemberCalendar for personal/selected calendars
   - Many-to-many SharedCalendar ↔ FamilyMember for shared calendars
2. **Auto-linked Calendar**: Marked with `isAutoLinked = true`, greyed out, not removable, shown with lock icon
3. **Shared Calendars**: Linked to ALL family members automatically when added
   - When a shared calendar is added, it's linked to all existing members
   - When a new member is created, they automatically get all shared calendars
   - Shown in SelectMemberCalendarsView as "Shared with all" (read-only, greyed out)
4. **Manual Selection**: Users can add additional personal calendars via SelectMemberCalendarsView modal
5. **Event Aggregation**: FamilyView fetches ONE next event per person combining:
   - Personal/auto-linked calendars (FamilyMemberCalendar)
   - Shared calendars (through SharedCalendar.members relationship)
6. **Duplicate Prevention**: Same personal calendar can be assigned to multiple family members
7. **Backward Compatibility**: `linkedCalendarID` field remains in FamilyMember for fallback compatibility
8. **Expandable UI**: Family members in VisibleCalendarsView are clickable and expandable
9. **Count Badge**: Shows calendar count next to member name (includes personal + shared)
10. **Calendar Sorting**: Auto-linked calendar listed first, then manual selections, then shared calendars (all greyed)
11. **Modal Selection**: SelectMemberCalendarsView shows personal, shared, and available calendars
12. **Edit Updates**: EditFamilyMemberView handles auto-linked calendar updates when name changes

### Context Menu Implementation (Nov 20, 2025)
- **Context Menu Feature**: Long-press actions on events across all screens
  - Available on CalendarView, FamilyView, and EventDetailView
  - Three main actions: Duplicate, Move to Calendar, Delete
  - **Duplicate**: Creates copy of event 1 hour after original
  - **Move to Calendar**: Submenu showing all available calendars with checkmark on current
  - **Delete**: Smart options based on event recurrence
    - For recurring events: Submenu with "Delete This Event" and "Delete This & Future Events"
    - For single events: Simple delete button
  - Both EventKit and CoreData are updated when events are moved
  - Available calendars loaded on view appearance and refreshed via EKEventStoreChanged notifications

- **Implementation Details**:
  - Added to CalendarView.swift, FamilyView.swift, and EventDetailView.swift
  - State variables: `availableCalendars`, `showingCalendarPicker`, `contextMenuEvent`
  - Helper functions in each view:
    - `loadAvailableCalendars()`: Synchronous fetch of EKEventStore calendars (simple 2-line function)
    - `moveEventToCalendar()`: Updates EventKit event and CoreData FamilyEvent
    - `deleteEvent()`: Handles EKSpan.thisEvent or .futureEvents deletion
    - `duplicateEvent()`: Creates new event with same details, 1 hour later
  - **Fixed async/await warnings** (Nov 20): Removed unnecessary Task wrapper and await keyword from loadAvailableCalendars() since eventStore.calendars(for:) is synchronous

### Consolidated Event Notifications with Map Preview (Nov 21, 2025)
- **NotificationManager.swift**: Enhanced notification scheduling
  - Added `location` parameter to `scheduleEventNotification()`
  - Consolidated notifications: ONE notification for all members instead of separate notifications per member
  - Fixed notification identifier to use event's unique ID (was generating duplicate with UUID suffix)
  - Added `categoryIdentifier = "EVENT_NOTIFICATION"` for custom notification handling
  - Set `interruptionLevel = .timeSensitive` for important events
  - Stores all event metadata in `userInfo`: location, family members, drivers
  - Improved logging with confirmation messages

- **AddEventView.swift**: Modified event creation flow
  - Collects all attendees before creating events (lines 431-441)
  - Creates events in all target calendars (lines 443-543)
  - Sends ONE consolidated notification with all member names (lines 545-552)
  - Updated `scheduleNotificationForCreatedEvent()` signature:
    - Removed `calendarId` parameter (derives from first member's calendar)
    - Accepts array of attending members
    - Accepts location parameter
  - Passes location address to notification system

- **EventNotificationView.swift** (NEW): Custom notification UI (iOS 16.2+)
  - SwiftUI view for rich notification presentation
  - Displays:
    - Event title + all member names in single notification
    - Time with clock icon
    - All members (driver, attendees) with icons
    - Location with real-time geocoding
    - Interactive map preview showing event location
    - "Get Directions" button for route planning in Apple Maps
  - Features:
    - Automatic address geocoding to coordinates
    - Map preview with pin showing exact location
    - One-tap route planning with driving/walking options
    - Responsive layout with proper text truncation
    - Clean, modern UI with color-coded icons

## Design Decisions (Consolidated Notifications)
1. **One Notification Per Event**: Regardless of how many members are assigned, sends single notification with all names concatenated
2. **Location Geocoding**: Uses CLGeocoder to convert address to coordinates for map display
3. **Map Preview**: Shows interactive map with pin at exact event location
4. **Route Planning**: Opens Apple Maps with route options (driving/walking)
5. **Member Listing**: Fits all names on notification; truncates with text limit if needed
6. **Notification ID**: Uses event's unique identifier to prevent duplicates
7. **Time Sensitive**: Marked as `.timeSensitive` interrupt level for visibility
8. **Custom Category**: Uses "EVENT_NOTIFICATION" for future custom actions
9. **Backward Compatibility**: Location parameter is optional, won't break existing code

## To Do for Future Development
- [ ] Add custom notification actions (e.g., "Join Event", "Decline")
- [ ] Add calendar event display to FamilyView
- [ ] Set up CloudKit sync for family sharing
- [ ] Add custom avatar/photo support
- [ ] Add family group/organization features
- [ ] Implement notification sounds for different event types
- [ ] Add notification history/logs
