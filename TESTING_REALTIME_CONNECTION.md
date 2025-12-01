# Realtime WebSocket Connection Testing Guide

## Latest Changes (Commit: 66a5fec)

### Problem Identified
The WebSocket connection was failing with "Socket is not connected" errors on initial attempts because:
1. Race condition between WebSocket handshake completion and receive loop attempts
2. Insufficient retry delay between connection attempts (was only 1 second)
3. No exponential backoff - aggressive retries could overwhelm the connection

### Solution Implemented
Enhanced the `receiveMessages()` method in `RealtimeFamilyActivitySubscription.swift` with:

1. **Exponential Backoff Retry Logic**
   - First retry: 2 seconds
   - Second retry: 4 seconds
   - Third retry: 6 seconds
   - Fourth retry: 8 seconds
   - Fifth+ retry: 10 seconds (capped)
   - Only applies to initial "Socket is not connected" errors during first connection

2. **Better State Tracking**
   - `isFirstConnection` flag distinguishes first attempt from reconnections
   - `consecutiveErrors` counter tracks retry attempts
   - Error count resets on successful message receipt

3. **Clearer Logging**
   - Shows attempt number: "attempt 1", "attempt 2", etc.
   - Shows retry delay: "Retrying in X seconds..."
   - Helps identify where connections are stabilizing

## Connection Timeline After Changes

```
1. subscribeToFamilyActivities() called with accessToken
   ↓
2. WebSocket URL created and webSocket.resume() called
   ↓
3. Task starts that waits 2 seconds
   ↓
4. receiveMessages() starts (receive loop begins)
   ↓
5. First receive() attempt fails with "Socket is not connected" (expected)
   ↓
6. Error caught - exponential backoff: wait 2 seconds then retry
   ↓
7. (Potentially more retries with 4, 6, 8, 10 second delays if still not connected)
   ↓
8. Eventually: Socket handshake completes, receive() succeeds!
   ↓
9. Task sleeps 1 more second before sending subscription
   ↓
10. subscribeToTable() sends subscription payload with JWT token
    ↓
11. Server responds with subscription confirmation
    ↓
12. startPingLoop() begins (keep-alive pings every 25 seconds)
    ↓
13. Connection stable - ready to receive activity broadcasts
```

## How to Test

### Setup
1. Have two users from the same family
2. Both users logged into the app (on different devices or simulators)
3. Open Xcode console to see the detailed logging

### Test Procedure

**User 1 (Add Location to Trigger Activity)**
1. Open app → navigate to Locations/Settings
2. Add a new location (or edit/delete existing one)
3. Watch User 2's console output

**User 2 (Should Receive Realtime Notification)**
1. Observe console logs - should see:
   ```
   📌 Waiting 2 seconds for WebSocket handshake...
   📌 Starting receiveMessages task after handshake delay...
   ✅ Starting message receive loop
   👂 Listening for WebSocket messages... (count: 0)
   (Potentially: ❌ WebSocket receive error ... "Socket is not connected")
   (Potentially: ⏳ Socket not yet connected (attempt 1, expected...))
   (Potentially: ⏳ Retrying in 2 seconds...)
   (Retry occurs...)
   📡 Sending Realtime subscription for family_activity_log...
   ✅ Successfully sent subscription to family_activity_log table
   💓 Starting keep-alive ping loop...
   ```

2. After subscription is sent, should eventually see:
   ```
   📨 [N] Received string message (X chars)
   ✅ Successfully decoded Realtime message with event: postgres_changes
   ℹ️ Realtime event: INSERT
   🔔 New family activity: [activity description]
   ```

3. **Most importantly**: Should receive a notification on the device!

### Expected vs Actual Behavior

**Before Fix:**
- "Socket is not connected" error immediately after receiveMessages starts
- Only 1 second retry - WebSocket not ready yet
- Tight retry loop hammering the connection
- User sees "Error: Connection lost: ..." status

**After Fix:**
- "Socket is not connected" expected on first attempt (logged with attempt number)
- Exponential delays (2, 4, 6, 8, 10 seconds) allow handshake to complete
- Clean state management - once connected, stays connected
- User sees status transition: "Syncing" → "Connected"
- Notifications arrive successfully

## Console Log Reference

### Green Indicators (Good Signs)
- ✅ Starting message receive loop
- ✅ Successfully sent subscription to family_activity_log table
- ✅ Successfully decoded Realtime message
- 📨 Received string/data message
- 💓 Sent keep-alive ping to Realtime server

### Yellow Indicators (Expected/Recoverable)
- ⏳ Socket not yet connected (attempt X, expected during initial connection)
- ⏳ Retrying in X seconds...
- 📌 Waiting X seconds for...

### Red Indicators (Problems)
- ❌ WebSocket receive error after 0 messages (if persists after retries)
- ❌ Failed to send subscription
- ❌ WebSocket not available
- 🔍 NSError details (check for permission/RLS issues)

## Debugging RLS Issues

If you see errors with accessing the table, check:

1. **Database Migration Applied**
   - Verify `family_activity_log` table exists
   - Check RLS is enabled: `ALTER TABLE public.family_activity_log ENABLE ROW LEVEL SECURITY;`
   - Check policies are in place (should select from families or family_members)

2. **User Authentication**
   - JWT token is being passed (check in FamCalApp.swift lines 318-321)
   - Token includes user ID: `auth.uid()`
   - User is actual member of family being subscribed to

3. **Family Relationship**
   - User is either family owner OR linked family member
   - Family ID matches the subscription filter

## Next Steps if Still Having Issues

1. **Check if first message ever arrives**
   - Look for "Received string message" in logs
   - This indicates socket is stable enough to receive

2. **Check subscription is being sent**
   - Look for "Sending Realtime subscription for family_activity_log"
   - Check it contains family_id filter

3. **Check server is sending messages**
   - Add activity from User 1
   - Does database trigger fire? (Check Supabase logs)
   - Does message get published to Realtime?
   - Does other client receive it?

4. **Network Issues**
   - Try on different network (WiFi vs cellular)
   - Check if firewall is blocking WebSocket connections
   - Verify `supabaseURL` in SupabaseConfig.swift is correct

5. **RLS Permission Issues**
   - Verify user has access to family_activity_log via policies
   - Check that the filter `family_id=eq.{familyId}` is correct
