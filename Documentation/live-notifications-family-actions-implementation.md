# Live Notifications for Family Actions - Implementation Plan

## Overview
Enable family members to receive push/local notifications when important family actions occur. These notifications inform users about significant changes without requiring them to open the app—adding transparency and improving family coordination.

**Problem Solved:** Family members currently have no visibility into what others are doing in the app (except by checking the app directly).

**End Result:** Family feels more connected with real-time awareness of important shared activities.

---

## Phase 1: Architecture Overview

### Notification Types

1. **Family Member Added/Edited**
   - Trigger: New member added or existing member updated
   - Recipient: All family members except the updater
   - Content: "Sarah added John to Family" or "Sarah updated John's info"

2. **Shared Calendar Added**
   - Trigger: Shared calendar added to family
   - Recipient: All family members
   - Content: "Sarah added Work Calendar to shared calendars"

3. **Driver Information Updated**
   - Trigger: Driver created/updated with new phone, email, notes
   - Recipient: All family members (maybe configurable)
   - Content: "Mom updated Coach's phone number" or "New driver: Coach"

4. **Saved Address Added**
   - Trigger: Important location saved (e.g., "Soccer Field", "Grandma's House")
   - Recipient: All family members
   - Content: "Dad saved new location: Soccer Field (123 Main St)"

5. **Family Member Linked Account**
   - Trigger: Family member links their account (e.g., John connects to his Apple account)
   - Recipient: Family owner + linked member
   - Content: "John linked their account to this family"

6. **Family Member Went Online (optional)**
   - Trigger: Family member presence changes to online
   - Recipient: All family members
   - Content: "Sarah just came online" (can be frequent, optional)

### Action Categories:
```
Family Roster Changes:
├─ Member Added → "Sarah added John to Family"
├─ Member Edited → "Mom updated John's nickname"
├─ Member Linked → "John just linked their account"
└─ Member Deleted → "Sarah removed John from Family"

Calendar Changes:
├─ Shared Calendar Added → "Dad shared Work Calendar"
├─ Shared Calendar Removed → "Mom unshared Work Calendar"
└─ Member Calendars Updated → "John added 3 more calendars"

Driver Information:
├─ Driver Created → "New driver: Coach (555-1234)"
├─ Driver Updated → "Mom updated Coach's phone"
└─ Travel Time Updated → "Coach's estimated travel time: 25 min"

Locations:
├─ Address Added → "Dad saved: Soccer Field (456 Park Ave)"
└─ Address Updated → "Sarah updated Grandma's address"

Presence (optional):
└─ Member Online → "Sarah just came online"
```

---

## Phase 2: Database Design

### Create `family_activity_log` table (NEW)
**File:** `supabase/migrations/2025-12-01_create_family_activity_log.sql`

Stores audit trail of family actions for notification purposes:

Structure:
- `id` (UUID, PRIMARY KEY)
- `family_id` (UUID, FK to families) - for RLS scoping
- `action_by_user_id` (UUID, FK to auth.users) - who performed action
- `action_by_member_id` (UUID, FK to family_members, nullable) - which member was acting
- `action_type` (VARCHAR enum: "member_added", "member_edited", "driver_created", "address_added", etc.)
- `action_subject_id` (VARCHAR) - ID of entity affected (member_id, driver_id, address_id, etc.)
- `action_subject_type` (VARCHAR enum: "family_member", "driver", "address", "shared_calendar")
- `subject_name` (VARCHAR) - human-readable name (John's name, address name, etc.)
- `action_details` (JSONB) - additional context
  ```json
  {
    "oldValue": "Coach",
    "newValue": "Coach - Soccer",
    "changedFields": ["name"]
  }
  ```
- `created_at` (TIMESTAMP WITH TIME ZONE, auto-set)
- `updated_at` (TIMESTAMP WITH TIME ZONE)

Indices:
- `(family_id, created_at DESC)` - fetch recent activities
- `(action_by_user_id, created_at)` - per-user activity
- `(action_type)` - filter by activity type

RLS Policies:
- Users can view activity logs for families they're part of
- Automatic insert on family member/driver/address changes (via triggers)

---

## Phase 3: Trigger-Based Activity Logging

### Database Triggers (NEW)

Create triggers to automatically log activities:

```sql
-- Trigger on family_members INSERT/UPDATE/DELETE
CREATE OR REPLACE FUNCTION log_family_member_activity()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO family_activity_log (
      family_id, action_by_user_id, action_by_member_id,
      action_type, action_subject_id, action_subject_type,
      subject_name, action_details
    ) VALUES (
      NEW.family_id, auth.uid(), NEW.id,
      'member_added', NEW.id::text, 'family_member',
      NEW.name, jsonb_build_object('colorHex', NEW.color_hex)
    );
  ELSIF TG_OP = 'UPDATE' THEN
    INSERT INTO family_activity_log (...) VALUES (
      NEW.family_id, auth.uid(), NEW.id,
      'member_edited', NEW.id::text, 'family_member',
      NEW.name, jsonb_build_object(
        'oldName', OLD.name,
        'newName', NEW.name,
        'changedFields', ARRAY['name']
      )
    );
  ELSIF TG_OP = 'DELETE' THEN
    INSERT INTO family_activity_log (...) VALUES (...);
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

Similar triggers for:
- drivers table
- saved_addresses table
- shared_calendars table
- user_presence table (for online notifications)

---

## Phase 4: Notification Manager Enhancement

### Update NotificationManager.swift

Add new notification scheduling method:

```swift
// Schedule family activity notification
func scheduleFamilyActionNotification(
    familyActivity: FamilyActivityDTO,
    recipients: [String] // user IDs to notify
) async throws

// New notification category
let FAMILY_ACTION_NOTIFICATION = "FAMILY_ACTION_NOTIFICATION"

// Notification types
enum FamilyActionType: String {
    case memberAdded = "family.member.added"
    case memberEdited = "family.member.edited"
    case driverCreated = "family.driver.created"
    case addressAdded = "family.address.added"
    case calendarShared = "family.calendar.shared"
    case memberOnline = "family.member.online"
}
```

**Notification Content:**
```swift
// Example: "Sarah added John to Family"
// - Title: "[Family Name] Family"
// - Body: "Sarah added John"
// - Category: FAMILY_ACTION_NOTIFICATION
// - userInfo: action details for deep linking

let content = UNMutableNotificationContent()
content.title = "Family Update"
content.body = familyActivity.actionSummary // "Sarah added John"
content.categoryIdentifier = "FAMILY_ACTION_NOTIFICATION"
content.sound = .default
content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
content.userInfo = [
    "actionType": familyActivity.actionType.rawValue,
    "familyId": familyActivity.familyId,
    "actionSubjectId": familyActivity.actionSubjectId,
    "deepLink": "fam-cal://family/activity/\(familyActivity.id)"
]
```

---

## Phase 5: Activity Log Fetching

### Create FamilyActivityManager.swift (NEW)
**Location:** `FamCal/FamCal/FamilyActivityManager.swift`

Fetch and manage family activity log:

```swift
class FamilyActivityManager: ObservableObject {
    @Published var recentActivities: [FamilyActivityDTO] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Fetch recent activities
    func fetchRecentActivities(
        familyId: String,
        limit: Int = 20
    ) async throws -> [FamilyActivityDTO]

    // Subscribe to new activities via Realtime
    func subscribeToNewActivities(
        familyId: String
    ) async throws

    // Handle new activity (from Realtime)
    func handleNewActivity(_ activity: FamilyActivityDTO) async
}
```

### Update SupabaseManager.swift

Add activity log methods:

```swift
// Fetch family activity log
func getFamilyActivityLog(
    familyId: String,
    limit: Int = 20,
    token: String?
) async throws -> [FamilyActivityDTO]

// Define DTO
struct FamilyActivityDTO: Codable, Identifiable {
    let id: String
    let family_id: String
    let action_by_user_id: String
    let action_by_member_id: String?
    let action_type: String
    let action_subject_id: String
    let action_subject_type: String
    let subject_name: String
    let action_details: [String: AnyCodable]
    let created_at: String // ISO8601

    var actionSummary: String {
        // Generate human-readable summary
        // E.g., "Sarah added John to Family"
    }
}
```

---

## Phase 6: Realtime Activity Subscriptions

### Update RealtimeFamilyDataSubscription.swift
Add activity log subscription:

```swift
func subscribeToFamilyActivities(
    familyId: String
) async throws

// Callback for new activities
var onFamilyActivityCreated: ((FamilyActivityDTO) -> Void)?
```

**Activity Event Handler:**
```swift
// When new activity received:
// 1. Parse activity details
// 2. Determine which users to notify (usually all except actor)
// 3. Schedule notification
// 4. Update activity feed UI
// 5. Show toast if app in foreground
```

---

## Phase 7: User Preferences for Notifications

### Extend AppSettingsManager.swift

Add activity notification preferences:

```swift
@Published var familyActivityNotificationsEnabled: Bool = true
@Published var notifyOnMemberChanges: Bool = true
@Published var notifyOnDriverChanges: Bool = true
@Published var notifyOnLocationChanges: Bool = true
@Published var notifyOnCalendarChanges: Bool = true
@Published var notifyOnPresenceChanges: Bool = false // opt-in, can be frequent

// Notification sounds
@Published var familyActivityNotificationSound: String = "default"
```

### Update NotificationSettingsView.swift

Add family activity notification section:

```swift
Section("Family Activity Notifications") {
    Toggle("Family Updates", isOn: $appSettings.familyActivityNotificationsEnabled)

    if appSettings.familyActivityNotificationsEnabled {
        Toggle("Member Changes", isOn: $appSettings.notifyOnMemberChanges)
        Toggle("Driver Updates", isOn: $appSettings.notifyOnDriverChanges)
        Toggle("Location Changes", isOn: $appSettings.notifyOnLocationChanges)
        Toggle("Calendar Changes", isOn: $appSettings.notifyOnCalendarChanges)
        Toggle("Online Status", isOn: $appSettings.notifyOnPresenceChanges)

        Picker("Sound", selection: $appSettings.familyActivityNotificationSound) {
            Text("Default").tag("default")
            Text("None").tag("none")
            // Custom sounds if available
        }
    }
}
```

---

## Phase 8: Activity Feed UI

### Create FamilyActivityFeedView.swift (NEW)
**Location:** `FamCal/FamCal/FamilyActivityFeedView.swift`

Display recent family activities:

```swift
struct FamilyActivityFeedView: View {
    @StateObject private var activityManager = FamilyActivityManager()
    @EnvironmentObject private var dataManager: SupabaseDataManager

    var body: some View {
        NavigationStack {
            List {
                Section("Recent Activity") {
                    if activityManager.recentActivities.isEmpty {
                        Text("No recent family activity")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(activityManager.recentActivities) { activity in
                            FamilyActivityRow(activity: activity)
                        }
                    }
                }
            }
            .navigationTitle("Family Activity")
            .onAppear {
                Task {
                    await activityManager.fetchRecentActivities(
                        familyId: dataManager.familyId ?? ""
                    )
                    try? await activityManager.subscribeToNewActivities(
                        familyId: dataManager.familyId ?? ""
                    )
                }
            }
        }
    }
}

struct FamilyActivityRow: View {
    let activity: FamilyActivityDTO

    var body: some View {
        HStack(spacing: 12) {
            // Activity icon based on type
            Image(systemName: activityIcon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.actionSummary)
                    .font(.body)

                HStack(spacing: 8) {
                    Text(activity.created_at.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.gray)

                    if let details = activity.action_details["changedFields"] as? [String] {
                        Text("•")
                            .foregroundColor(.gray)
                        Text("Changed: \(details.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var activityIcon: String {
        switch activity.action_type {
        case "member_added": return "person.badge.plus"
        case "member_edited": return "pencil.circle"
        case "driver_created": return "car.fill"
        case "address_added": return "location.fill"
        case "calendar_shared": return "calendar"
        case "member_online": return "circle.fill"
        default: return "info.circle"
        }
    }
}
```

### Add Activity Tab to FamilyView (optional)
Or accessible from settings menu.

---

## Phase 9: Deep Linking

### Handle Family Activity Notifications
When user taps notification, deep link to relevant screen:

```swift
// In FamCalApp or deeplink handler
func handleActivityNotification(userInfo: [AnyHashable: Any]) {
    guard let actionType = userInfo["actionType"] as? String else { return }
    guard let subjectId = userInfo["actionSubjectId"] as? String else { return }

    switch actionType {
    case "member_added", "member_edited":
        // Navigate to FamilySettingsView and highlight member
        navigationPath.append(NavigationDestination.familyMember(subjectId))

    case "driver_created", "driver_updated":
        // Navigate to drivers list
        navigationPath.append(NavigationDestination.drivers)

    case "address_added":
        // Navigate to saved addresses
        navigationPath.append(NavigationDestination.savedAddresses)

    case "calendar_shared":
        // Navigate to visible calendars
        navigationPath.append(NavigationDestination.visibleCalendars)

    case "member_online":
        // Just show family view (presence dot)
        navigationPath.append(NavigationDestination.family)

    default:
        break
    }
}
```

---

## Phase 10: Privacy & Opt-Out

### User Control
```swift
// Users can disable per activity type:
// - Turn off "Member Changes" → no notifications when members added/edited
// - Turn off "Driver Updates" → no driver notifications
// - Turn off "Location Changes" → no address notifications
// - Turn off "Online Status" → no presence notifications
// - Turn off all → toggle "Family Activity Notifications"
```

### Filter Sent Notifications
Before sending notification, check recipient's settings:

```swift
// When activity occurs:
// 1. Get all family members
// 2. For each member, check their notification preferences
// 3. Only send if enabled in their settings
// 4. Respect their sound preference

func shouldNotifyUser(
    userId: String,
    activityType: String
) async -> Bool {
    let settings = try? await appSettingsManager.getSettingsForUser(userId)
    guard let settings else { return false }

    guard settings.familyActivityNotificationsEnabled else { return false }

    switch activityType {
    case "member_added", "member_edited":
        return settings.notifyOnMemberChanges
    case "driver_created", "driver_updated":
        return settings.notifyOnDriverChanges
    // ... etc
    }
}
```

---

## Phase 11: Notification Rate Limiting

### Prevent Notification Spam
```swift
// Rate limiting rules:
// - Max 1 notification per user per family per 10 seconds
// - Batch rapid-fire activities (e.g., member creates 3 addresses in 5s → 1 notification)
// - Skip notifications for minor changes (e.g., only changed one letter in name)

class FamilyActivityNotificationThrottler {
    private var lastNotificationTime: [String: Date] = [:]
    private let minInterval: TimeInterval = 10

    func shouldNotify(userId: String) -> Bool {
        if let lastTime = lastNotificationTime[userId],
           Date().timeIntervalSince(lastTime) < minInterval {
            return false
        }
        lastNotificationTime[userId] = Date()
        return true
    }
}
```

---

## Implementation Order

1. ✅ Create `family_activity_log` table
2. ✅ Create database triggers for auto-logging
3. ✅ Create FamilyActivityManager.swift
4. ✅ Update SupabaseManager with activity fetch methods
5. ✅ Update RealtimeFamilyDataSubscription for activities
6. ✅ Update NotificationManager to schedule activity notifications
7. ✅ Update AppSettingsManager with activity notification preferences
8. ✅ Update NotificationSettingsView UI
9. ✅ Create FamilyActivityFeedView (optional)
10. ✅ Implement deep linking for notifications
11. ✅ Test notification delivery and preferences

---

## Non-Breaking Changes

- ✅ New table only (`family_activity_log`)
- ✅ New database triggers (don't affect existing operations)
- ✅ Optional feature (can be disabled in settings)
- ✅ No CoreData model changes
- ✅ No existing table schema changes
- ✅ Backward compatible (notifications gracefully fail if feature unavailable)

---

## Testing Checklist

- [ ] Add family member on Device A → Device B receives notification
- [ ] Edit member details on Device A → Device B receives notification
- [ ] Add shared calendar on Device A → all family members notified
- [ ] Add saved address on Device A → all family members notified
- [ ] Create driver on Device A → all family members notified
- [ ] User disables "Member Changes" → no notifications for member edits
- [ ] User disables all → no family activity notifications
- [ ] Tap notification → deep links to correct screen
- [ ] Activity feed shows recent activities
- [ ] Rate limiting prevents spam (rapid actions → single notification)
- [ ] Offline user → catches up on activities when reconnects

---

## Real-World Scenarios

### Scenario 1: Family Planning Event
```
Mom (Device A): Adds "Coach - Soccer" to family members
Mom (Device A): Sets Coach's phone to 555-1234
Dad (Device B): Receives "Sarah added Coach to Family"
Dad (Device B): Receives "Sarah updated Coach's contact info"
Dad (Device B): Opens app, sees Coach already in list, taps notification to open Coach's details
```

### Scenario 2: New Location Saved
```
John (Device A): Adds "Soccer Field" at 456 Park Ave
Sarah (Device B): Receives notification "John saved Soccer Field"
Sarah (Device B): Notification appears in lock screen
Sarah (Device B): Taps notification, deep links to Saved Addresses view
Sarah (Device B): Sees "Soccer Field" address and can use it for navigation
```

### Scenario 3: Family Member Goes Online
```
Mom (Device A): Opens app (goes online)
Dad (Device B): Receives optional notification "Mom just came online"
Dad (Device B): Can see green dot next to Mom's name in FamilyView
```

---

## Performance Metrics

- **Notification Latency:** <2 seconds from action to notification arrival
- **Database Trigger:** <10ms per activity log insert
- **Activity Feed Load:** <500ms for 20 most recent activities
- **Realtime Subscription:** ~50KB memory per family
- **Rate Limiting:** Prevents >1 notification per 10 seconds per user

