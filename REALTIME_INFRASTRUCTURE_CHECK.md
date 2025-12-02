# Supabase Realtime Infrastructure Status Check

**Date**: December 2, 2025
**Purpose**: Verify Realtime service is enabled and properly configured
**Status**: Investigating HTTP 500 errors on WebSocket upgrade

---

## Current Findings

### ✅ What We Know Works
- REST API to Supabase domain works fine (curl to `/rest/v1/` succeeds)
- App code is correct (JWT token properly included in WebSocket URL)
- Database table `family_activity_log` IS in `supabase_realtime` publication
- Network connectivity is fine (domain is reachable)
- iOS app code properly implements authenticated WebSocket connection

### ❌ What's Failing
- WebSocket upgrade request to `wss://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1` returns HTTP/2 500 error
- This happens from Mac (curl/websocat) AND iOS app
- REST API works, but Realtime doesn't
- **Conclusion**: The problem is NOT network or app code—it's Realtime service-level

---

## Step 1: Check Realtime Toggle in Dashboard

The HTTP 500 error suggests Realtime service may not be enabled. Here's how to check:

### Go to Supabase Dashboard

1. **Login**: https://app.supabase.com
2. **Select Project**: Choose your FamCal project (tzkspidmzlipujsnxpzc)
3. **Navigate to Settings**:
   - Click ⚙️ Settings (bottom left sidebar)
   - Look for **Infrastructure** section
   - Or search for "Realtime" in settings

### Look for Realtime Toggle

You should see something like:
```
🚀 Realtime
  Enabled  [Toggle: ON/OFF]

  Status: Active
  Version: v1
```

### If Realtime is OFF
```
⚠️ Realtime is currently DISABLED
   Click toggle to enable →  [Turn ON]
```

### If Realtime is ON
```
✅ Realtime is ACTIVE
   Status: Running
   Health: OK
```

---

## Step 2: Understanding the HTTP 500

If Realtime is **enabled** but returning HTTP 500, it could be:

### Possible Causes

| Cause | Evidence | Fix |
|-------|----------|-----|
| Realtime service disabled | Toggle is OFF in Settings | Turn ON the toggle |
| Realtime service down | Status shows "Unhealthy" or "Maintenance" | Wait for service to recover or contact Supabase |
| Misconfigured publication | Table not in publication | (Already verified - table IS there) |
| JWT verification issue | 500 + auth token present | Check token expiration |
| Memory/resource issue | Intermittent 500 errors | Contact Supabase support |

---

## Step 3: Verify Publication Configuration

We already confirmed via SQL query that the table IS in the publication, but let's verify the publication itself exists:

### Check from Supabase Dashboard SQL Editor

Run this query to see all publications:

```sql
SELECT * FROM pg_publication;
```

You should see `supabase_realtime` in the list.

### Check Publication Contents

```sql
SELECT pubname, tablename FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
```

You should see `family_activity_log` in the results.

---

## Step 4: Check Project Health

### In Dashboard - Project Overview

Look for:
- **Database Status**: Should be "Healthy" ✅
- **API Status**: Should be "Running" ✅
- **Realtime Status**: Should be "Running" ✅
- **Auth Status**: Should be "Running" ✅

If any show ⚠️ or ❌, there may be a project-level issue.

---

## Step 5: Verify Authentication

The HTTP 500 could theoretically be caused by auth token issues. Let's verify:

### Test Authenticated vs Anonymous Connection

Run these from your Mac terminal:

**Test 1: Anonymous connection (should fail with 101 Switching Protocols or 500)**
```bash
curl -v -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  "https://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=YOUR_ANON_KEY"
```

**Test 2: With JWT token (if you have one from login)**
```bash
# Replace YOUR_JWT with actual token from supabase.auth.session()
curl -v -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  "https://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=YOUR_ANON_KEY&access_token=YOUR_JWT"
```

Both should either:
- Return `HTTP/1.1 101 Switching Protocols` ✅ (success)
- Return `HTTP/2 500` ❌ (current error)
- Return `HTTP/2 401` (auth error)

---

## Step 6: Potential Fixes

### If Realtime Toggle is OFF
```
1. Go to Supabase Dashboard
2. Settings → Infrastructure
3. Find "Realtime" section
4. Toggle it ON
5. Wait 30-60 seconds for service to start
6. Test with websocat again
```

### If Realtime Toggle is ON but Still 500
```
1. Check "Realtime Status" in Dashboard
2. If status is "Unhealthy":
   - Try toggling OFF then ON
   - Wait 1-2 minutes
   - Test again
3. If status is "Running" but still 500:
   - Screenshot the error response
   - Contact Supabase support at support@supabase.com
   - Include: Project ID (tzkspidmzlipujsnxpzc), error code, curl output
```

### If You Need to Contact Supabase

Provide this information:
```
Project ID: tzkspidmzlipujsnxpzc
Issue: WebSocket upgrade returns HTTP 500
Evidence:
- REST API works: curl https://tzkspidmzlipujsnxpzc.supabase.co/rest/v1/ → 200 OK
- WebSocket fails: curl wss://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1 → 500
- Table in publication: SELECT confirms family_activity_log in supabase_realtime
- Realtime toggle: [ON/OFF - specify]
- Error: [paste curl/websocat output]
```

---

## Checklist: Before Contacting Support

- [ ] Confirmed Realtime toggle status in Dashboard (ON or OFF)
- [ ] Checked project health (all services "Healthy" or "Running")
- [ ] Verified table is in publication (SQL query run)
- [ ] Tested WebSocket from Mac with curl/websocat
- [ ] Noted exact HTTP status code and response
- [ ] Tried toggling Realtime OFF then ON if it's currently ON
- [ ] Waited 2 minutes after enabling/toggling before retesting

---

## What Happens After Fix

Once Realtime infrastructure is verified/fixed:

### Test from Mac First
```bash
websocat wss://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=[key]&access_token=[jwt]
```

Should see:
```json
{"type":"system","event":"init","data":{"server_version":"X.X.X","...":"..."}}
```

### Then Test from iOS App
1. Build and run app on physical device
2. Go to Settings → Test Only → Debug Logs
3. Clear logs
4. Perform action that triggers Realtime
5. Watch logs for:
   - ✅ WebSocket task created: ✅ Success
   - ✅ Using authenticated Realtime connection with JWT token
   - ✅ Received message from server (within 3 seconds)

---

## Summary

The HTTP 500 error on WebSocket upgrade is a **service-level problem**, not a code or network issue:

1. **First**: Check if Realtime toggle is ON in Dashboard
2. **Second**: If it is ON, try toggling OFF then ON again
3. **Third**: If still 500, contact Supabase with the diagnostic info above

Once Realtime responds with `101 Switching Protocols` instead of `500`, everything else (app code, JWT handling, publication configuration) is ready to work.

---

**Next Action**: Check Supabase Dashboard Settings → Infrastructure and let me know what the Realtime status shows.
