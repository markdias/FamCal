# Realtime Diagnostics Guide

## Overview

We've built a comprehensive diagnostic system to test Supabase Realtime connectivity without needing complex WebSocket management. This guide explains how to use it and what to do based on the results.

## How to Run Diagnostics

1. **Rebuild the app** (you just did this)
2. **Open Settings** in the app
3. **Scroll to "Test Only" section**
4. **Tap "Realtime Diagnostics"** button
5. **Watch the Console** (Xcode → View → Debug Area → Show Console)
6. **Check the diagnostic output** - it will tell you exactly what's happening

## What the Diagnostic Tests

The diagnostic runs 4 sequential tests:

### Test 1: URL Construction ✅
- **What it checks**: Can we build a valid WebSocket URL from your Supabase configuration?
- **Success**: Should show `Valid WebSocket URL created`
- **Failure**: Indicates invalid Supabase URL in SupabaseConfig.swift

### Test 2: WebSocket Connection ⚡
- **What it checks**: Can we establish a TLS WebSocket connection to Supabase?
- **Success**: "WebSocket connected and received initial message!"
- **Timeout**: "WebSocket connected but no data received within 5 seconds"
  - This suggests Realtime might not be enabled
- **Error**: Specific connection error (network issue, invalid credentials, etc.)

### Test 3: Connection State Detection 🔍
- **What it checks**: Is the socket responsive to receive requests?
- **Success**: "Socket received data immediately"
- **Timeout**: "Socket not responsive (timeout)"
- **This test**: Most diagnostic - if it times out, Realtime infrastructure is likely not enabled

### Test 4: Initial Message Reception 📨
- **What it checks**: Can we receive the Supabase Realtime handshake message?
- **Success**: "Received initial message (X chars)"
- **Timeout**: "Timeout - no initial handshake message"
  - This is the smoking gun for disabled Realtime

## Interpreting Results

### ✅ ALL TESTS PASSED
Your Realtime infrastructure is configured correctly!

**Next steps**:
1. Rebuild and run the app
2. Check console for "Realtime sync status: Connected"
3. Test by adding an activity from one user
4. Should receive notification on other user

### ⚠️ PARTIAL SUCCESS (2-3 tests passed)
Realtime is likely not enabled on the `family_activity_log` table.

**Quick fix**:
```bash
# Option A: Via CLI (recommended)
cd /Users/markdias/project/FamCal
supabase link --project-ref tzkspidmzlipujsnxpzc
supabase db push
```

**Option B: Manual SQL**
1. Go to Supabase Dashboard
2. SQL Editor
3. Run:
```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.family_activity_log;
```

Then:
1. Rebuild the app
2. Run diagnostics again (should pass all tests now)

### ❌ REALTIME NOT WORKING (0-1 tests passed)
Realtime is not enabled at the project level.

**Fix**:
1. **Open Supabase Dashboard** → https://app.supabase.com
2. **Go to: Settings → Extensions → Realtime** (look for this in your project)
   - OR: Check Infrastructure settings for Realtime toggle
3. **Enable Realtime** if toggle exists and is OFF
4. Then run the migration (see "Partial Success" section above)

## Detailed Test Output Example

### Successful Connection
```
============================================================
🔍 REALTIME DIAGNOSTIC TEST
============================================================

✅ Test 1: URL Construction
   Original: https://tzkspidmzlipujsnxpzc.supabase.co
   WebSocket: wss://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=***
   ✅ Valid URL created

✅ Test 2: WebSocket Connection
   ⏳ Attempting to establish WebSocket connection...
   ✅ WebSocket connected and received initial message!

✅ Test 3: Connection State Detection
   ⏳ Creating WebSocket and checking state...
   ✅ Socket received data immediately

✅ Test 4: Initial Message Reception
   ⏳ Waiting 2 seconds for TLS handshake...
   ⏳ Attempting to receive initial message...
   ✅ Received string message (150 chars)
   Content: {"type":"system","event":"init",...

============================================================
📋 DIAGNOSTIC SUMMARY
============================================================

✅ URL Construction
   Valid WebSocket URL

✅ WebSocket Connection
   Successfully connected and received data

✅ Connection State
   Socket responsive

✅ Message Reception
   Received initial message

============================================================
✅ ALL TESTS PASSED - Realtime should work!

Next steps:
1. Rebuild and run the app
2. Check console for 'Realtime sync status: Connected'
3. Test by adding an activity from one user
4. Should receive notification on other user
```

### Failed Connection (Realtime Disabled)
```
✅ Test 1: URL Construction
   ✅ Valid URL created

✅ Test 2: WebSocket Connection
   ⏳ Attempting to establish WebSocket connection...
   ❌ WebSocket connected but no data received within 5 seconds

❌ Test 3: Connection State Detection
   ❌ Socket not responsive (timeout)

❌ Test 4: Initial Message Reception
   ❌ Timeout - no initial handshake message

============================================================
📋 DIAGNOSTIC SUMMARY
============================================================

✅ URL Construction
   Valid WebSocket URL

❌ WebSocket Connection
   No data received (Realtime may not be enabled)

❌ Connection State
   Socket not responding within 3 seconds

❌ Message Reception
   Timeout - no initial handshake message

============================================================
❌ REALTIME NOT WORKING (0/4 tests passed)

Likely issues:
1. Realtime not enabled at project level (Settings → Extensions → Realtime)
2. Network connectivity issue
3. Invalid Supabase URL or API key

Quick check:
- Verify Supabase URL: https://tzkspidmzlipujsnxpzc.supabase.co
- Check network connectivity
- Enable Realtime in Supabase dashboard if not enabled
```

## Code Architecture

### RealtimeDiagnostic.swift
New file that runs independent diagnostic tests without interfering with the main Realtime subscription.

**Key methods**:
- `runDiagnostics()` - Runs all 4 tests and prints summary
- `testURLConstruction()` - Validates URL format
- `testWebSocketConnection()` - Attempts connection with message reception
- `testConnectionState()` - Checks socket responsiveness
- `testInitialMessageReception()` - Verifies handshake
- `withTimeout()` - Helper for timeout management

### SettingsView.swift
Added "Realtime Diagnostics" button in "Test Only" section.

**New state variables**:
- `isRunningDiagnostics` - Tracks if test is running
- `diagnosticsLog` - Stores diagnostic output

**New UI**:
- Button with stethoscope icon (orange when idle, blue with spinner when running)
- Shows "Test Realtime WebSocket connection" description
- Disabled while diagnostics are running

## Next Steps After Diagnostics

### If All Tests Pass
1. Realtime is ready to use
2. The RealtimeFamilyActivitySubscription will connect automatically when you add activities
3. Other logged-in users should receive notifications within 2 seconds

### If Some Tests Fail
1. **Enable Realtime** (if project-level toggle is OFF)
2. **Apply migration** (via `supabase db push` or manual SQL)
3. **Run diagnostics again** to confirm fix
4. **Rebuild the app**

### If Tests Still Fail After Fixes
1. **Check network connectivity**
   - Can you access https://tzkspidmzlipujsnxpzc.supabase.co from device?
   - Is device behind a firewall that blocks WebSocket?
   - Try different WiFi network

2. **Check Supabase status**
   - Go to https://status.supabase.com
   - Check if Realtime service is up

3. **Verify Supabase credentials**
   - SupabaseConfig.swift has correct URL
   - API key is valid and not expired

## Testing After Successful Diagnostics

Once diagnostics pass and you rebuild:

1. **Open the app** on Device/Simulator A (logged in as User 1)
2. **Add a location, driver, or make any change** that logs an activity
3. **Watch the console** for "Realtime sync status: Connected" message
4. **Open the app** on Device/Simulator B (logged in as User 2 from same family)
5. **Should see notification** appear within 2 seconds
6. **Check console logs** for "🔔 New family activity: ..."

## Troubleshooting

### "All Tests Passed but Still No Notifications"
- Check if both users are in the **same family**
- Check console logs for "Realtime sync status: Connected"
- If status shows "Syncing" or "Disconnected", something else is wrong
- Run diagnostics again - might be intermittent network issue

### "Diagnostic Shows Realtime NOT WORKING on Device but PASSES on Simulator"
- Device might be on different network with WebSocket restrictions
- Try: Different WiFi, disable VPN, cellular data instead of WiFi
- Check if device firewall blocks port 443

### "Diagnostics Timeout But Network Seems Fine"
- Supabase might be experiencing issues
- Check https://status.supabase.com
- Try running diagnostics multiple times
- If consistently timeouts, Realtime infrastructure might need restart

## Files Modified

- ✅ **RealtimeDiagnostic.swift** - NEW diagnostic utility
- ✅ **SettingsView.swift** - Added diagnostic button and UI
- ✅ **RealtimeFamilyActivitySubscription.swift** - Unchanged (still has comprehensive logging)

## How It Works (Technical)

The diagnostic uses URLSessionWebSocketTask to:
1. Create WSS connection to Supabase Realtime endpoint
2. Resume the connection (initiates TLS handshake)
3. Attempt to receive messages with timeout
4. Track each stage to identify exactly where failure occurs

Each test is independent - failures in earlier tests don't prevent running later tests, so you get a complete picture of what's working and what's not.

---

**Need help?** Check the console output from diagnostics - it will tell you exactly what's happening at each stage.
