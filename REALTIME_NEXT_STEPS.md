# Realtime Feature - Current Status & Next Steps

## 🔴 Current Issue

WebSocket connections are failing with persistent "Socket is not connected" errors. Even with exponential backoff (2, 4, 6, 8 second delays), the socket never becomes ready to receive messages.

**Console Pattern Observed:**
```
❌ WebSocket receive error after 0 messages: Socket is not connected
⏳ Socket not yet connected (attempt 1/10, expected during initial connection)
⏳ Retrying in 2 seconds...
(repeats with increasing delays: 4, 6, 8, 10 seconds...)
```

## 🎯 Root Cause Analysis

### Most Likely: Realtime Not Enabled on `family_activity_log` Table

When Supabase Realtime isn't enabled for a table:
- TLS WebSocket handshake succeeds (so no cert errors)
- Supabase closes the connection immediately
- Client gets "Socket is not connected" when trying to receive
- This happens repeatedly because the connection never actually opens

**Why this happens:**
- Supabase uses PostgreSQL **Publications** to define which tables support Realtime
- The migration `20251202120000_enable_realtime_family_activity_log.sql` must be deployed
- If migration wasn't run in production, Realtime won't work

## 🔧 Action Steps - DO THIS NOW

### Step 1: Verify Supabase Setup (5 minutes)

Open your Supabase dashboard and run these SQL queries to check if Realtime is actually enabled:

**Query 1 - Check if supabase_realtime publication exists:**
```sql
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime';
```
- Expected: One row
- If no results: Realtime isn't enabled on project (rare, but possible)

**Query 2 - Check if family_activity_log is in the publication:**
```sql
SELECT
    p.pubname,
    c.relname as table_name
FROM pg_publication p
JOIN pg_publication_rel pr ON p.oid = pr.prpubid
JOIN pg_class c ON pr.prrelid = c.oid
WHERE p.pubname = 'supabase_realtime'
AND c.relname = 'family_activity_log';
```
- Expected: One row with `table_name = family_activity_log`
- If no results: **The migration wasn't applied** - LIKELY CULPRIT

### Step 2: Apply Missing Migration (if needed)

If Query 2 returned no results, the migration needs to be applied:

**Option A: Via Supabase CLI (Recommended)**

```bash
cd /Users/markdias/project/FamCal

# Link your project (if not already linked)
supabase link --project-ref tzkspidmzlipujsnxpzc

# Push all pending migrations to production
supabase db push
```

**Option B: Manual SQL Execution**

If CLI doesn't work, manually execute in Supabase SQL Editor:

```sql
-- Enable Realtime for family_activity_log table
ALTER PUBLICATION supabase_realtime ADD TABLE public.family_activity_log;
```

### Step 3: Verify RLS Setup

Also check that RLS policies are correct:

```sql
SELECT
    policyname,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'family_activity_log'
ORDER BY policyname;
```

Should see policies for:
- SELECT (users can view activities from their families)
- INSERT (system can insert via triggers)

### Step 4: Test Again

After applying the migration:

1. Rebuild and run the app
2. Check console logs - should now see:
   ```
   📨 [1] Received string message (X chars)
   ✅ Successfully decoded Realtime message with event: system
   📡 Sending Realtime subscription for family_activity_log...
   ✅ Successfully sent subscription to family_activity_log table
   💓 Starting keep-alive ping loop...
   📊 Realtime sync status: Connected
   ```

3. Add an activity from Account A
4. Should receive notification on Account B within 2 seconds

## 📋 Complete Checklist

- [ ] **Query 1 passed**: `supabase_realtime` publication exists
- [ ] **Query 2 passed**: `family_activity_log` is in publication
  - If not: [ ] Applied migration via `supabase db push` OR manual SQL
- [ ] **Query 3 passed**: RLS policies exist on `family_activity_log`
- [ ] **Rebuilt app** after any migrations
- [ ] **Console shows**: "Realtime sync status: Connected" (not "Syncing" or error)
- [ ] **Added test activity** from one account
- [ ] **Received notification** on other account
- [ ] **Checked notification** contains correct activity details

## 📊 What to Expect After Fix

### Successful Connection
```
📌 Waiting 2 seconds for WebSocket handshake before starting receive...
📌 Starting receiveMessages task after handshake delay...
✅ Starting message receive loop
👂 Listening for WebSocket messages... (count: 0)
📨 [1] Received string message (150 chars)
Content: {"type":"system","event":"init","data":{"server_version":"1.0"...
✅ Successfully decoded Realtime message with event: system
ℹ️ Ignoring non-postgres event: system
👂 Listening for WebSocket messages... (count: 1)
📡 Sending Realtime subscription for family_activity_log...
✅ Successfully sent subscription to family_activity_log table
💓 Starting keep-alive ping loop...
📊 Realtime sync status: Connected
👂 Listening for WebSocket messages... (count: 2)
📨 [2] Received string message (200 chars)
Content: {"type":"system","event":"subscribed"...
ℹ️ Ignoring non-postgres event: subscribed
👂 Listening for WebSocket messages... (count: 3)
```

### Activity Reception
```
📨 [4] Received string message (450 chars)
Content: {"type":"postgres_changes","data":{...,"data":{"id":"xxx","action_type":"address_added"...
✅ Successfully decoded Realtime message with event: postgres_changes
ℹ️ Realtime event: INSERT
🔔 New family activity: [Activity Details]
```

### Problem: Still Getting "Socket is not connected" After 10 Retries

If the app shows:
```
❌ ⚠️ CRITICAL: WebSocket failed to connect after 10 attempts
⚠️ This usually means:
   1. Realtime is not enabled on the family_activity_log table in Supabase
   2. Check: Settings → Database → Publications → supabase_realtime
   ...
```

Then the migration definitely wasn't applied. Go back to Step 2 and apply it.

## 🔍 If Diagnostics Still Don't Work

### Check Database Migrations in Supabase

1. Open Supabase Dashboard
2. Go to **Settings** → **Migrations** (or **Database** → **Migrations**)
3. Look for:
   - `20251201000000_create_family_activity_log` (should be ✅ Applied)
   - `20251202000000_create_activity_log_triggers` (should be ✅ Applied)
   - `20251202120000_enable_realtime_family_activity_log` (should be ✅ Applied)

If any show "Pending" or are missing:
- These migrations need to be deployed
- Use `supabase db push` to deploy them

### Network/Firewall Issues

If migrations are applied but Realtime still doesn't work:

1. **Network connectivity** - is the device on a network that allows WebSocket?
   - Try on different WiFi/network
   - Check if firewall blocks port 443 (HTTPS/WSS)

2. **DNS resolution** - can the device reach Supabase?
   - Try pinging `tzkspidmzlipujsnxpzc.supabase.co` from device

3. **VPN** - some VPNs block WebSocket upgrades
   - Try disabling VPN if using one

## 📞 Support Resources

1. **SUPABASE_REALTIME_DIAGNOSTICS.md** - Detailed troubleshooting guide
2. **REALTIME_CONNECTION_ANALYSIS.md** - Technical deep dive
3. **TESTING_REALTIME_CONNECTION.md** - Testing procedures

All files are in the project root directory.

## 🚀 Expected Timeline

- **Step 1 (Verification)**: 5 minutes
- **Step 2 (Migration)**: 2 minutes (if needed)
- **Step 3 (Rebuild)**: 2 minutes
- **Step 4 (Testing)**: 5 minutes
- **Total**: ~15 minutes

## Next Update

After you verify/apply the migrations, run the app again and share the console output. The logs will show either:

1. ✅ **Success** - "Realtime sync status: Connected"
2. ❌ **Still failing** - We'll know something else is wrong and can investigate further

---

**Latest Code Change**: Commit `504e964`
- Added max retry limit (10 attempts) with diagnostic message
- Helps identify Realtime configuration issues
- Guides user to SUPABASE_REALTIME_DIAGNOSTICS.md
