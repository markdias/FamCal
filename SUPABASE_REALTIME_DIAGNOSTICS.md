# Supabase Realtime Setup Diagnostics

## Current Issue

The WebSocket connection is failing with "Socket is not connected" errors repeatedly, even with exponential backoff. The socket never becomes ready to receive messages.

## Root Cause Hypothesis

**Realtime is not enabled on the `family_activity_log` table in your Supabase project.**

When Realtime isn't enabled on a table:
- TLS WebSocket connection succeeds (so you don't get cert errors)
- But the subscription fails silently
- Or the connection closes immediately after handshake
- You get "Socket is not connected" when trying to receive

## Verification Steps

### Step 1: Check if Realtime Publication Exists

1. Open your Supabase dashboard
2. Go to **SQL Editor**
3. Run this query:

```sql
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime';
```

**Expected Result**: One row with `pubname = 'supabase_realtime'`

**If No Results**: Realtime isn't enabled on the project at all

---

### Step 2: Check if family_activity_log is in the Publication

```sql
SELECT
    p.pubname,
    r.relname as table_name
FROM pg_publication p
JOIN pg_publication_rel pr ON p.oid = pr.prpubid
JOIN pg_class r ON pr.prrelid = r.oid
WHERE p.pubname = 'supabase_realtime';
```

**Expected Result**: Rows including `family_activity_log`

**If family_activity_log is Missing**: The migration wasn't applied

---

### Step 3: Check Migration Status

In Supabase dashboard:

1. Go to **Settings** → **Migrations**
2. Look for migration: `20251202120000_enable_realtime_family_activity_log`

**If Missing from List**: Migration wasn't pushed to production

---

### Step 4: Verify Table Exists and Has Data

```sql
SELECT COUNT(*) FROM family_activity_log;
```

**Expected Result**: Should have some rows (from previous activities)

**If Error**: Table doesn't exist or user doesn't have access

---

## How to Fix

### Option A: Apply Migration via Supabase CLI

1. **Install Supabase CLI** (if not already done):
```bash
brew install supabase/tap/supabase
```

2. **Link your project**:
```bash
cd /Users/markdias/project/FamCal
supabase link --project-ref tzkspidmzlipujsnxpzc
```

3. **Push migrations**:
```bash
supabase db push
```

This will apply any pending migrations (including the Realtime enable migration).

### Option B: Manual SQL Execution

If CLI approach doesn't work, manually run in Supabase SQL Editor:

```sql
-- Add family_activity_log to Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE public.family_activity_log;
```

---

## Expected Result After Fix

After Realtime is enabled, you should see in console logs:

```
👂 Listening for WebSocket messages... (count: 0)
(Wait a moment...)
📨 [1] Received string message (X chars)
✅ Successfully decoded Realtime message with event: system
(Potentially more system messages)
📡 Sending Realtime subscription for family_activity_log...
✅ Successfully sent subscription to family_activity_log table
💓 Starting keep-alive ping loop...
📊 Realtime sync status: Connected
```

The key difference: you'll actually **receive** messages instead of continuously getting "Socket is not connected" errors.

---

## Why This Happens

### Database Publication System

PostgreSQL uses **Publications** to determine which tables should be replicated. Supabase created a `supabase_realtime` publication for Realtime subscriptions.

When you want a table to support Realtime:
1. Must be in the `supabase_realtime` publication
2. Must have `REPLICA IDENTITY FULL` set
3. RLS policies must allow SELECT access

### The Realtime v1 Protocol Flow

```
Client → WebSocket upgrade request
         ↓ (TLS handshake)
Server → 101 Switching Protocols

Client → Subscribe message:
         {
           "type": "subscribe",
           "payload": {
             "schema": "public",
             "table": "family_activity_log",
             "configs": { "scope": "postgres_changes" }
           }
         }

Server → Subscription response:
         - If table not in publication: Error or silent close
         - If table in publication: Confirmation

Client ← Receives events on INSERT/UPDATE/DELETE
```

If the table isn't in the publication, the server either:
- Returns a subscription error (which we'd see)
- Silently closes the connection (which we're seeing)

---

## Testing After Fix

Once Realtime is enabled:

1. **Keep app running** with console visible
2. **Add a location** from Account A
3. **Watch console on Account B**
4. **Should see**: Realtime message received with activity details
5. **Should get**: Notification on Account B

---

## Verification Queries

Run these in Supabase SQL Editor to verify everything is set up correctly:

### All tables in Realtime publication:
```sql
SELECT
    p.pubname,
    n.nspname as schema_name,
    c.relname as table_name,
    c.relreplident as replica_identity
FROM pg_publication p
JOIN pg_publication_rel pr ON p.oid = pr.prpubid
JOIN pg_class c ON pr.prrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE p.pubname = 'supabase_realtime'
ORDER BY n.nspname, c.relname;
```

### Check if family_activity_log has correct REPLICA IDENTITY:
```sql
SELECT
    tablename,
    CASE relreplident
        WHEN 'f' THEN 'FULL'
        WHEN 'i' THEN 'USING INDEX'
        WHEN 'n' THEN 'NOTHING'
        WHEN 'd' THEN 'DEFAULT'
    END as replica_identity
FROM pg_tables t
JOIN pg_class c ON c.relname = t.tablename
WHERE tablename = 'family_activity_log'
AND schemaname = 'public';
```

### Check RLS policies on family_activity_log:
```sql
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    cmd,
    qual
FROM pg_policies
WHERE schemaname = 'public'
AND tablename = 'family_activity_log'
ORDER BY policyname;
```

---

## If Verification Queries Fail

### Problem: "family_activity_log" does not exist
- **Cause**: Main activity log table migration wasn't applied
- **Fix**: Apply `20251201000000_create_family_activity_log.sql` migration

### Problem: No rows returned for Realtime publication
- **Cause**: Realtime isn't enabled on the Supabase project
- **Fix**: This is a project-level setting in Supabase dashboard
  - Go to **Settings** → **Infrastructure**
  - Check if "Realtime" is enabled

### Problem: REPLICA IDENTITY is not FULL
- **Cause**: Table doesn't have correct replica identity for Realtime
- **Fix**: Run migration or manual SQL to fix
  ```sql
  ALTER TABLE public.family_activity_log REPLICA IDENTITY FULL;
  ```

### Problem: RLS policies are missing
- **Cause**: Migrations that create policies weren't applied
- **Fix**: Apply all activity log trigger migrations

---

## Summary Checklist

- [ ] Supabase Realtime is enabled on project
- [ ] `family_activity_log` table exists
- [ ] `supabase_realtime` publication exists
- [ ] `family_activity_log` is in `supabase_realtime` publication
- [ ] `family_activity_log` has REPLICA IDENTITY FULL
- [ ] RLS policies exist on `family_activity_log`
- [ ] User has SELECT access via RLS (is family member)
- [ ] `20251202120000_enable_realtime_family_activity_log.sql` migration was applied

If all checks pass but Realtime still doesn't work, the issue is likely:
- Network blocking WebSocket connections
- Firewall blocking port 443 for WSS connections
- DNS resolution issues to Supabase servers
