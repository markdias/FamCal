# Testing Realtime with Debug Logs Guide

## Overview

This guide combines the **optimized WebSocket implementation** with the **in-app Debug Logs viewer** to systematically test and troubleshoot Realtime notifications.

## Prerequisites

- Two iOS devices/simulators with FamCal installed
- Both logged in as members of the same family
- Both have notification permissions granted
- Build 1: Latest with WebSocket timeout optimizations (15s initial, 60s normal)
- Build 2: Include DebugLogViewer component in Settings

## Step 1: Access Debug Logs

### In-App Debug Logs

1. **Open Settings** → Scroll to "Test Only" section
2. **Tap "Debug Logs"** (purple icon with doc.text.magnifyingglass)
3. **Clear existing logs** (tap "Clear" button)
4. Watch the log stream in real-time as events happen

### Colored Log Indicators

- **✅ Green** - Success messages (token present, connection established, message received)
- **❌ Red** - Errors (connection failed, auth denied, socket errors)
- **⚠️ Orange** - Warnings (no token, connection closing)
- **🔵 Blue** - Realtime-specific messages (📨 messages, 💓 pings, 📡 subscriptions)

## Step 2: Test WebSocket Connection

### Part A: Check Authentication Token

**In Debug Logs, look for these messages:**

```
🔐 Access token present (XXX chars): eyJhbGciOi...
```

**If you see this:**
- ✅ Auth token is available
- Proceed to Part B

**If you DON'T see this:**
- ❌ No auth token found
- **Fix**: Ensure user is logged in
  - Go to FamilyView
  - Verify you see family members
  - If not logged in, log out and log back in
  - Rebuild and try again

### Part B: Check Initial Connection

**In Debug Logs, look for these messages:**

```
🚀 Creating WebSocket task...
🚀 Calling webSocket.resume()...
⏳ WebSocket connection initiated (resuming)
```

Then immediately after:

```
✅ SUCCESS! Received message on first try!
```

OR

```
❌ TIMEOUT: WebSocket did not send any message within 5 seconds
```

**If you see SUCCESS:**
- ✅ WebSocket is connecting
- Proceed to Part C

**If you see TIMEOUT:**
- ❌ WebSocket isn't getting initial message
- **Diagnosis**: Check if this is a network issue or configuration issue
- See **Troubleshooting: Network Issues** below

### Part C: Check Subscription

**In Debug Logs, look for these messages:**

```
📡 Sending Realtime subscription for family_activity_log...
```

Then:

```
✅ Successfully sent subscription to family_activity_log table
📊 Subscription confirmed, monitoring for changes
```

OR

```
❌ Failed to send subscription: auth error
```

OR

```
❌ Failed to send subscription: policy denies access
```

**If you see "Successfully sent":**
- ✅ Subscription is active
- Proceed to Step 3 (Test Activity Notifications)

**If you see auth/policy errors:**
- ❌ RLS policy or auth token issue
- See **Troubleshooting: Auth/RLS Issues** below

## Step 3: Test Activity Notifications

### Device A (Sender)

1. **Clear Debug Logs**
2. **Add a Location**:
   - Tap the navigation/map icon
   - Type an address (e.g., "1600 Pennsylvania Ave, Washington DC")
   - Tap "Save to Saved Addresses"
3. **In Debug Logs, look for**:
   ```
   📝 Creating activity for location_added event
   📊 [Activity API] POST request to family_activity_log
   ✅ Successfully created activity record
   ```

### Device B (Receiver)

1. **Debug Logs should show**:
   ```
   📨 [1] Received string message (450 chars)
   ```

   Then:
   ```
   ✅ Successfully decoded Realtime message with event: postgres_changes
   ℹ️ Realtime event: INSERT
   ```

   Then:
   ```
   🔔 New family activity: Address added to Saved Places
   ```

2. **On screen**: You should see a notification appear with the activity details

## Troubleshooting: Authentication Token Issues

**Symptom**: No `🔐 Access token present` message in logs

### Step 1: Verify User is Logged In

```
In FamilyView:
- Do you see family members listed?
- Do you see "Family Members" in Settings?
```

**If no family members**:
1. Log out (Settings → Log Out)
2. Log back in
3. Create a new family or join existing family
4. Clear Debug Logs and try WebSocket connection again

### Step 2: Check Session Expiration

Auth tokens expire. If everything was working but stopped:

```
1. Go to Settings → Log Out
2. Wait 5 seconds
3. Log back in
4. Go to FamilyView
5. Clear Debug Logs
6. Try WebSocket connection test again
```

### Step 3: Verify Token is Passed to Realtime

**In Debug Logs, look for**:
```
✅ Including access token in subscription (XXX chars): eyJhbGciOi...
```

If present: ✅ Token is being passed correctly

If missing: ❌ Token lost between subscription start and subscription message
- This suggests a timing issue
- App might be calling disconnect before token is passed
- Rebuild and test again

## Troubleshooting: Network Issues

**Symptom**: "❌ TIMEOUT: WebSocket did not send any message within 5 seconds"

### Check Network Connectivity

```bash
# From your Mac, test basic connectivity
ping tzkspidmzlipujsnxpzc.supabase.co

# Test HTTPS connectivity
curl -v https://tzkspidmzlipujsnxpzc.supabase.co/rest/v1/
```

### Try Different Network

1. **If on WiFi**: Switch to cellular
2. **If on cellular**: Switch to WiFi
3. **Try different WiFi network** if available

### Check VPN

If using VPN:
1. **Disable VPN** completely
2. Clear Debug Logs
3. Try WebSocket connection test again

### Check Supabase Status

Go to https://status.supabase.com

Look for:
- ✅ All systems operational
- ❌ Realtime service degraded (if so, wait and retry)

### Improved Timeout Diagnostics

The optimized WebSocket has longer timeouts:
- **Initial connection**: 15 seconds (up from 10)
- **Normal operation**: 60 seconds (up from 10)

**What this means**:
- If it times out after 15s on initial: Network is very slow or blocked
- If it connects but then times out after 60s: Connection established but no data coming through

**If still timing out after 15s**:
1. Check if firewall blocking WebSocket (port 443 is used)
2. Check if VPN is blocking wss:// connections
3. Try from completely different network (coffeeshop WiFi, different cellular provider)

## Troubleshooting: RLS Policy Issues

**Symptom**: WebSocket connects, subscription sent, but NO activity events received

**In Debug Logs, you should see**:
```
✅ Successfully sent subscription to family_activity_log table
📊 Subscription confirmed, monitoring for changes
```

But then when Device A creates activity:
- NO `📨 Received string message` on Device B
- NO `🔔 New family activity:` notification

### Cause

RLS (Row-Level Security) policy is denying access. The policy checks `auth.uid()` which requires:
1. Valid JWT token
2. User exists in Supabase `auth.users` table
3. User is in `family_members` table for that family

### Debug Steps

**Step 1: Verify User is in Family**

```
In FamilyView:
- Do you see Device B's user listed as family member?
- If Device B's account isn't in the family, add them
```

**Step 2: Verify Token is Valid**

```
In Debug Logs:
- Look for: ✅ Including access token in subscription
- If present and XXX chars > 100, token looks valid
- If not present, see Authentication Token Issues above
```

**Step 3: Manual Database Check** (Supabase Dashboard)

1. Open Supabase Dashboard
2. Go to SQL Editor
3. Run this query:
   ```sql
   SELECT * FROM family_members
   WHERE id = '<user-id-of-device-b>';
   ```
   - If returns a row: User is in family ✅
   - If returns nothing: User not in family ❌
     - Go to FamilyView
     - Add the user as family member
     - Try notification test again

4. Check RLS policy:
   ```sql
   SELECT * FROM pg_policies
   WHERE tablename = 'family_activity_log';
   ```
   - Should show a policy that uses `auth.uid()`
   - If no policy, RLS might not be enabled correctly

### Temporary Debug Fix

**ONLY FOR DEBUGGING - DELETE AFTER TESTING**

```sql
-- In Supabase Dashboard SQL Editor
CREATE POLICY "debug_all_access" ON family_activity_log
  FOR SELECT USING (true);
```

This policy allows ALL access (no security checks). If notifications now work:
- ✅ RLS policy was the issue
- Delete this debug policy
- Fix the real policy to allow your users

If notifications STILL don't work:
- ❌ Problem is not RLS
- Delete debug policy
- Check auth token issues instead

## Troubleshooting: Silent Failures

**Symptom**: Everything looks connected, but no notifications appear

**Debug Process**:

1. **On Device A**: Add an activity
   - Check Debug Logs for `✅ Successfully created activity record`

2. **On Device B**: Wait 3 seconds, then check logs
   - Look for `📨 [N] Received string message`
   - If you see it: Data is coming through
   - If you don't see it: See RLS Policy Issues above

3. **If data is coming through**:
   - Look for `🔔 New family activity:` message
   - If missing: NotificationManager issue
   - Try restarting app on Device B
   - Check notification settings on Device B
   - Tap Settings → Notifications → FamCal
   - Ensure "Allow Notifications" is toggled ON

## End-to-End Test Checklist

- [ ] **Auth**: See `🔐 Access token present` in logs
- [ ] **Connection**: See `✅ SUCCESS! Received message` on initial connection
- [ ] **Subscription**: See `✅ Successfully sent subscription` with token included
- [ ] **Activity Creation**: See `✅ Successfully created activity record` on Device A
- [ ] **Event Reception**: See `📨 Received string message` on Device B within 3 seconds
- [ ] **Decoding**: See `✅ Successfully decoded Realtime message` on Device B
- [ ] **Notification**: See `🔔 New family activity:` on Device B
- [ ] **Visual Notification**: See notification appear on Device B screen

**If all 8 items checked**: ✅ Realtime is working perfectly!

**If any item missing**: Use troubleshooting section for that step

## Quick Reference: Common Log Patterns

| What You See | What It Means | Next Step |
|--------------|----------------|-----------|
| No `🔐` messages | No auth token | Log out/in again |
| `🔐` but no `✅ Including` | Token lost before subscription | App might be disconnecting too fast |
| TIMEOUT after 15s | Network issue | Try different WiFi/cellular |
| `✅ Successfully sent subscription` but no `📨` on other device | RLS policy denying | Check user is in family_members table |
| `📨 Received string message` but no `🔔 New family activity` | Notification system issue | Restart app, check notification permissions |
| Keeps showing `⚠️ Socket is not connected` | Network connectivity problem | Check WiFi/VPN, try cellular |

## Advanced: Using Filter in Debug Logs

**Filter by keyword** to reduce noise:

- Filter by `🔐` to see all auth messages
- Filter by `✅` to see all successes
- Filter by `❌` to see all errors
- Filter by `📨` to see all received messages
- Filter by `🔔` to see all notifications
- Filter by `⚠️` to see all warnings

**Example workflow**:
1. Clear logs
2. Add activity on Device A
3. Switch to Device B
4. Filter by `🔔` to see if notification message appeared
5. If not, filter by `❌` to see what error occurred

## When Everything Works

You'll see this pattern:

**Device A** (creating activity):
```
📝 Creating activity for location_added event
📊 [Activity API] POST request to family_activity_log
✅ Successfully created activity record
```

**Device B** (receiving activity):
```
📨 [5] Received string message (450 chars)
✅ Successfully decoded Realtime message with event: postgres_changes
ℹ️ Realtime event: INSERT
🔔 New family activity: Address added to Saved Places

[Notification appears on screen]
```

**Time between Activity and Notification**: 1-3 seconds (normal)

---

**Last Updated**: December 2, 2025
**Build Status**: ✅ Builds successfully
**Testing Status**: Ready for end-to-end testing
**Next Step**: Run through end-to-end test checklist above
