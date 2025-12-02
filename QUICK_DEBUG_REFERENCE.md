# Quick Debug Reference Card

## 30-Second Diagnostics

**When something doesn't work:**

1. Open Settings → Test Only → Debug Logs
2. Clear logs
3. Perform the failing action
4. Wait 3 seconds
5. Check which icon appears:

| Icon | Message | Problem | Fix |
|------|---------|---------|-----|
| 🔐 | Access token present | ✅ Good - continue | N/A |
| ⚠️ | No access token | ❌ Not logged in | Log out & back in |
| ✅ | Including access token | ✅ Good - token sent | N/A |
| ❌ | No token in subscription | ❌ Token timing issue | Rebuild & retry |
| ✅ | Successfully sent subscription | ✅ Good - connected | N/A |
| ❌ | Failed to send subscription | ❌ Auth denied | Check user in family |
| 📨 | Received string message | ✅ Good - data coming | N/A |
| ❌ | Socket is not connected | ❌ Network issue | Try different WiFi |
| ❌ | Timed out after 15s | ❌ Very slow network | Disable VPN, try cellular |
| 🔔 | New family activity | ✅ Success - notification triggered | N/A |

## The 4-Step Flow

When Device A creates an activity, you should see:

### Device A (1-2 seconds total)
```
1. 📝 Creating activity
2. ✅ Successfully created activity record
```

### Device B (within 3 seconds after A)
```
3. 📨 [N] Received string message
4. ✅ Successfully decoded Realtime message
5. 🔔 New family activity: [details]
[Notification appears on screen]
```

**If step 1-2 missing**: Activity creation failed (unrelated to Realtime)
**If step 3-4 missing**: Realtime subscription not working

## Most Common Issues & Quick Fixes

### Issue 1: No Blue Realtime Messages (📨 🔔)

**Symptoms**:
- See `✅ Successfully sent subscription`
- But NO `📨 Received string message` when other device creates activity

**Quick Fix**:
```
Step 1: Verify user is in family
  → Go to FamilyView
  → Look for the other user as family member
  → If not there: Add them
  → Try again

Step 2: Try logging out/in
  → Settings → Log Out
  → Wait 5 seconds
  → Log back in
  → Clear Debug Logs
  → Try activity test again

Step 3: Check RLS policy (advanced)
  → Supabase Dashboard → SQL Editor
  → SELECT * FROM family_members WHERE id = '[your-user-id]';
  → Should return a row
  → If not: Add user to family
```

### Issue 2: Timeout After 15 Seconds

**Symptoms**:
- See `⏳ WebSocket connection initiated`
- Then `❌ TIMEOUT: WebSocket did not send any message within 5 seconds`
- After retries, see `❌ CRITICAL: WebSocket failed to connect`

**Quick Fix**:
```
Step 1: Try different network
  → If on WiFi → Switch to cellular
  → If on cellular → Switch to WiFi
  → Clear Debug Logs
  → Try again

Step 2: Disable VPN
  → Some VPNs block WebSocket connections
  → Disable VPN completely
  → Try again

Step 3: Check network status
  → Go to https://status.supabase.com
  → Look for Realtime service status
  → If degraded: Wait and retry
```

### Issue 3: Notification Doesn't Appear on Screen

**Symptoms**:
- See `🔔 New family activity:` in logs
- But notification doesn't appear on screen

**Quick Fix**:
```
Step 1: Check notification permissions
  → Go to device Settings → Notifications → FamCal
  → Toggle "Allow Notifications" OFF then ON
  → Rebuild app

Step 2: Restart app
  → Force close FamCal
  → Wait 5 seconds
  → Reopen app
  → Try activity test again

Step 3: Check Do Not Disturb
  → Device might be in Do Not Disturb mode
  → Swipe from top right
  → Turn off Focus mode if active
```

### Issue 4: See No Auth Token (⚠️)

**Symptoms**:
- See `⚠️ WARNING: No access token provided`
- OR no `🔐 Access token present` message

**Quick Fix**:
```
Step 1: Verify logged in
  → Go to FamilyView
  → Do you see family members?
  → If not: Log out and back in

Step 2: Log out/in cycle
  → Settings → Log Out (or swipe to delete account)
  → Wait 5 seconds for full logout
  → Log back in
  → Verify you see family members
  → Rebuild app
  → Try again

Step 3: Check auth manager state
  → FamilyView: Does account name appear in top-right?
  → If not: Try log out/in again
```

## The Greenlight Checklist

When testing, you want to see this exact sequence:

```
On Device A (Sender):
  ✅ Successfully created activity record

On Device B (Receiver):
  📨 Received string message (within 3 seconds of A)
  ✅ Successfully decoded Realtime message
  🔔 New family activity: [details]
  [Notification appears on screen within 1 second]
```

If you see this: **Realtime is working perfectly! ✅**

## Debug Log Color Guide

When viewing Debug Logs in app:

- **🟢 Green text** = `✅` Success - continue monitoring
- **🔴 Red text** = `❌` Error - needs action
- **🟠 Orange text** = `⚠️` Warning - might be OK but check
- **🔵 Blue text** = `📨 📡 💓 🔔 📝` Realtime-specific info - for monitoring
- **⚪ Gray text** = `ℹ️` Informational - context/details

## Copy Logs for Help

If you get stuck:

1. **In Debug Logs** → Tap "Copy" button
2. **Paste in message** to share with support
3. **Include**:
   - Which device (A or B)
   - What action was performed
   - Which step in the 4-step flow fails
   - Any error messages in red

## Pro Tips

**Tip 1**: Clear logs frequently
- Each test, clear logs first
- Makes it easier to spot issues

**Tip 2**: Use filter to focus
- Filter by `🔐` to see auth flow
- Filter by `❌` to see only errors
- Filter by `🔔` to see if notification triggered

**Tip 3**: Check timestamps
- Each log entry has time
- If 5 seconds between Device A activity and Device B notification: Normal
- If 20+ seconds: Network latency or processing delay

**Tip 4**: Watch for repeating patterns
- If see same error every 5 seconds: Retry loop
- If see pattern change after action: Timing-dependent issue
- If error persists: Configuration issue

## When to Check Supabase Dashboard

**Check migrations applied**:
```sql
-- Supabase Dashboard → SQL Editor
SELECT * FROM pg_tables
WHERE schemaname = 'public'
AND tablename = 'family_activity_log';
```
Should return one row. If not: Migrations didn't run.

**Check RLS enabled**:
```sql
SELECT * FROM pg_policies
WHERE tablename = 'family_activity_log';
```
Should return at least one policy. If not: RLS needs setup.

**Check Realtime enabled**:
```sql
SELECT * FROM pg_publication
WHERE pubname = 'supabase_realtime';
```
Should exist. Then check:
```sql
SELECT * FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
AND tablename = 'family_activity_log';
```
Should return one row. If not: Run migration.

## Minimum Viable Test

If you have 5 minutes:

```
1. Device A: Open Settings → Debug Logs → Clear
2. Device A: Add a location
3. Device B: Open Settings → Debug Logs
4. Device B: Look for 🔔 New family activity message
5. Result:
   - See 🔔? → ✅ Working
   - Don't see 🔔? → ❌ Check RLS policy or auth token
```

---

**Last Updated**: December 2, 2025
**Print this**: Great reference to keep while testing
**More details**: See TESTING_WITH_DEBUG_LOGS.md for comprehensive guide
