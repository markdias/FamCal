# Realtime Channel Subscription - How It Works

## Overview

After the WebSocket connection is established and the initial handshake is received, the app automatically "joins" (subscribes to) the `family_activity_log` table to listen for changes. This is already implemented and happens automatically.

## The Subscription Flow

```
1. WebSocket connects to Supabase Realtime endpoint
   ↓
2. Receive initial "system" message from Supabase (handshake)
   ↓
3. Send subscription message to join the family_activity_log channel
   ↓
4. Receive subscription confirmation from Supabase
   ↓
5. Start receiving activity change events (INSERT/UPDATE/DELETE)
   ↓
6. Send keep-alive pings every 25 seconds to maintain connection
```

## The Subscription Message (Already Implemented)

In [RealtimeFamilyActivitySubscription.swift:210-214](FamCal/RealtimeFamilyActivitySubscription.swift#L210-L214), the app sends:

```json
{
  "type": "subscribe",
  "id": "1",
  "payload": {
    "schema": "public",
    "table": "family_activity_log",
    "configs": {
      "scope": "postgres_changes",
      "filter": "family_id=eq.ABC123"
    },
    "access_token": "[JWT_TOKEN]"
  }
}
```

**What each field does**:
- `"type": "subscribe"` - Tells Supabase we're subscribing to changes
- `"id": "1"` - Channel identifier (can be any unique string)
- `"schema": "public"` - Database schema (where table lives)
- `"table": "family_activity_log"` - Which table to listen to
- `"scope": "postgres_changes"` - Listen to INSERT/UPDATE/DELETE operations
- `"filter": "family_id=eq.ABC123"` - Only changes where family_id matches the current family
- `"access_token"` - JWT token for Row-Level Security authorization

## What Happens After Subscription

Once the subscription is sent and confirmed, the WebSocket will receive messages whenever:

1. **Someone adds a location** → INSERT into family_activity_log
2. **Someone edits a member** → INSERT into family_activity_log (via trigger)
3. **Someone deletes a driver** → INSERT into family_activity_log (via trigger)
4. **Someone adds a calendar** → INSERT into family_activity_log (via trigger)

The message will look like:

```json
{
  "type": "postgres_changes",
  "event": "INSERT",
  "schema": "public",
  "table": "family_activity_log",
  "commit_timestamp": "2025-12-01T23:45:30.123Z",
  "data": {
    "id": "activity-uuid",
    "family_id": "family-uuid",
    "action_type": "location_added",
    "subject_type": "saved_address",
    "subject_id": "address-uuid",
    "subject_details": "{...location data...}",
    "created_at": "2025-12-01T23:45:30.123Z"
  },
  "changes": [
    { "id": "activity-uuid", "family_id": "family-uuid", ... }
  ]
}
```

## How the App Responds

When this message is received in [RealtimeFamilyActivitySubscription.swift:430-485](FamCal/RealtimeFamilyActivitySubscription.swift#L430-L485):

1. **Decode the message** - Parse JSON
2. **Extract activity data** - Get the new activity record
3. **Create FamilyActivityDTO** - Convert to app model
4. **Trigger callback** - Call `onActivityCreated` handler
5. **Send notification** - NotificationManager schedules notification to user
6. **Update UI** - Activity appears in any views listening for updates

## Status During Subscription

The app tracks subscription status with these values:

- `🔄 .syncing` - Connected to WebSocket, waiting for subscription confirmation
- `✅ .connected` - Subscribed and listening for changes
- `📊 .disconnected` - Not connected
- `❌ .error(String)` - Connection failed with error message

You can see this in the console as: `📊 Realtime sync status: Connected`

## Automatic Keep-Alive

After subscription succeeds, the app sends a keep-alive ping every 25 seconds to prevent the server from closing the idle connection:

```swift
{
  "type": "ping"
}
```

The server responds with a `pong` message. This keeps the connection alive indefinitely.

## What Happens If Subscription Fails

If the subscription message fails to send:
- Status changes to `.error("Subscription failed: ...")`
- Console shows `❌ Failed to send subscription: ...`
- No activities will be received
- App will not show notifications for family activities

**Common reasons**:
1. WebSocket connection was already closed
2. Invalid JWT token (RLS authorization failure)
3. Network error during send

## In Code

The entire subscription flow is handled in:

**File**: [RealtimeFamilyActivitySubscription.swift](FamCal/RealtimeFamilyActivitySubscription.swift)

**Key methods**:
- `subscribeToFamilyActivities()` [Line 57] - Entry point, creates WebSocket
- `receiveMessages()` [Line 318] - Receives all messages, calls subscribeToTable on first message
- `subscribeToTable()` [Line 170] - Sends the subscription message
- `handleMessage()` [Line 430] - Processes incoming messages
- `processRealtimeMessage()` [Line 455] - Handles activity change events
- `startPingLoop()` [Line 267] - Sends keep-alive pings

## Testing the Subscription

To verify subscription is working:

1. **Run diagnostics** → Settings → Test Only → Realtime Diagnostics
2. **Watch for**: `📊 Realtime sync status: Connected` in console
3. **Add an activity** from one user (location, driver, etc.)
4. **Watch other user's console** for: `🔔 New family activity: ...`
5. **Check for notification** on the device

If subscription isn't working but diagnostics passed:
- Check `subscribeToTable()` logs in console
- Verify JWT token is being sent: `🔐 Using JWT token for RLS authorization`
- Check that subscription message is being sent: `📡 Sending Realtime subscription...`
- Look for any "Failed to send subscription" errors

## Summary

**Channel subscription is already fully implemented.** The app automatically:
1. ✅ Connects to Supabase Realtime WebSocket
2. ✅ Receives initial handshake
3. ✅ Sends subscription to family_activity_log table
4. ✅ Filters for current family only
5. ✅ Receives activity change events
6. ✅ Sends notifications to user
7. ✅ Maintains connection with keep-alive pings

No additional code is needed - it's all automatic once the WebSocket connection succeeds. The diagnostic helps verify each stage is working.
