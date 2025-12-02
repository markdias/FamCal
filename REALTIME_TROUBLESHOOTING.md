# Realtime WebSocket Troubleshooting Guide

Based on standard Supabase Realtime issues, here's how to diagnose and fix problems.

## 🎯 Quick Diagnosis

Use the **Debug Logs** to identify your issue:

1. Open Settings → Test Only → Debug Logs
2. Clear logs (tap Clear)
3. Perform test action (add location, etc.)
4. Watch for specific messages below

---

## Issue 1: Auth/Session Problems

### Symptoms
- Connection opens then immediately closes
- Unauthorized errors
- Subscription rejected silently

### What to Look For in Logs
```
🔐 Access token present (XXX chars): eyJhbGciOi...
✅ Including access token in subscription
```

OR

```
⚠️ WARNING: No access token provided
⚠️ Ensure authManager.accessToken is not nil
```

### How to Fix

**If no token:**
1. Ensure user is logged in
2. Check `authManager.accessToken` is not nil
3. Verify session hasn't expired
4. Try logging out and back in

**If token present but subscription fails:**
1. Token might be expired - try logging out/in again
2. Check Supabase user exists in `auth.users` table
3. Verify user has correct permissions

**Code to check:**
```swift
// In FamCalApp.swift, near subscribeToFamilyActivities call
print("Debug: authManager.accessToken = \(authManager.accessToken ?? "NIL")")
```

---

## Issue 2: RLS Policy Denials

### Symptoms
- Subscription fails silently (no events received)
- No error messages in logs
- Works with anonymous key but not with JWT

### What to Look For in Logs
```
📨 Received string message (subscription confirmation)
✅ Successfully sent subscription to family_activity_log table
(then... crickets, no events)
```

### Root Cause: `auth.uid()` Returns NULL

Your RLS policy checks `auth.uid()`, but:
- Missing JWT token → `auth.uid()` = NULL → policy denies
- Expired token → `auth.uid()` = NULL → policy denies
- Invalid token → `auth.uid()` = NULL → policy denies

### How to Fix

1. **Verify token is present:**
   - Look for: `✅ Including access token in subscription`
   - If missing, see **Issue 1** above

2. **Check RLS policy:**
   - Go to Supabase Dashboard
   - SQL Editor → Run:
   ```sql
   SELECT * FROM pg_policies
   WHERE tablename = 'family_activity_log';
   ```
   - Look for SELECT policy that uses `auth.uid()`

3. **Test with correct JWT:**
   - Log in as a user
   - Their JWT should allow access to their family's activities
   - Ensure user is actually part of the family (in family_members table)

4. **Temporary debug fix:**
   ```sql
   -- ONLY FOR DEBUGGING - DELETE AFTER!
   CREATE POLICY "debug_all_access" ON family_activity_log
     FOR SELECT USING (true);
   ```
   - If this makes it work, your RLS policy is the issue
   - Fix the policy, then delete this debug policy

---

## Issue 3: Network/WebSocket Errors

### Symptoms
- "Socket is not connected" errors
- WebSocket handshake fails
- Connection timeouts
- Error codes: 400, 403, 502

### What to Look For in Logs
```
❌ WebSocket receive error: Socket is not connected
❌ CRITICAL: WebSocket failed to connect after 10 attempts
nw_write_request_report [C2] Send failed with error "Socket is not connected"
```

### Root Causes

**Firewall/VPN blocking WebSocket:**
- Some networks block WebSocket ports
- VPN might block wss:// connections
- Proxy might not support WebSocket upgrade

**Network connectivity:**
- No internet connection
- Unstable connection
- DNS resolution failing

**Supabase service issue:**
- Service temporarily down
- Regional outage

### How to Fix

**Step 1: Check connectivity**
```bash
# Can you reach Supabase?
ping tzkspidmzlipujsnxpzc.supabase.co

# Can you use HTTPS?
curl https://tzkspidmzlipujsnxpzc.supabase.co/rest/v1/
```

**Step 2: Try different network**
- Switch WiFi to cellular (or vice versa)
- Try different WiFi network
- Disable VPN if using one
- Test from different location

**Step 3: Check Supabase status**
- Go to https://status.supabase.com
- Check if Realtime is up

**Step 4: Verify Supabase URL**
- Check SupabaseConfig.swift
- Should be: `https://tzkspidmzlipujsnxpzc.supabase.co`
- NOT localhost or test URL

**Step 5: Check logs for specific error**
```
⚠️ This could mean:
   1. Firewall or VPN blocking WebSocket connections
   2. Network connectivity issue (try different WiFi)
   3. DNS resolution problem
   4. Supabase service temporarily down
   5. Invalid Supabase URL or API key
```

---

## Issue 4: Channel Config Mismatch

### Symptoms
- Subscription rejected
- Policy denies access
- Works for some users but not others

### What to Look For
```
📡 Sending Realtime subscription for family_activity_log...
❌ Failed to send subscription: policy denies access
```

### How to Fix

Our implementation uses:
```swift
"configs": [
    "scope": "postgres_changes",
    "filter": "family_id=eq.\(familyId)"
]
```

This is correct for:
- ✅ INSERT/UPDATE/DELETE events on family_activity_log
- ✅ Filtered by family_id matching current user's family

If you see rejection:
1. Check user is in family (query `family_members` table)
2. Verify filter is correct: `family_id=eq.<actual-family-id>`
3. Check RLS policy allows SELECT on family_activity_log

---

## Issue 5: Timing Issues

### Symptoms
- Connection works but events arrive late
- Notifications delayed by seconds
- "Keep-alive ping" shows but no data events

### What to Look For
```
💓 Sent keep-alive ping to Realtime server (every 25 seconds)
(long silence...)
📨 Received activity event
```

### Root Cause
- Network latency
- Server processing delay
- Activity trigger not firing

### How to Fix

**Check trigger is firing:**
- Add activity from one user
- Check database directly:
```sql
SELECT * FROM family_activity_log
ORDER BY created_at DESC LIMIT 5;
```
- Should see new record within 1-2 seconds

**If trigger works, check subscription:**
- Look for `📨 Received string message` with event data
- If not receiving: go back to Issue 2 (RLS denials)
- If receiving but late: network latency (normal, expected)

---

## Issue 6: Silent Failures

### Symptoms
- Connection shows as "Connected"
- No events received
- No error messages
- Debug logs look normal

### Root Cause
Usually **Issue 2** (RLS policy denies) in disguise

### How to Fix

1. **Check logs for silent rejection:**
   - Look for: subscription confirmed but no events
   - Compare activity added time with event received time
   - If no event in logs, policy is denying

2. **Add auth debugging:**
   - Go to Debug Logs
   - Look for: `✅ Including access token in subscription`
   - If not there → Issue 1
   - If there → Issue 2 (RLS policy)

3. **Check RLS policy directly:**
```sql
-- Check if user can SELECT from family_activity_log
SELECT * FROM family_activity_log
WHERE family_id = 'your-family-id' LIMIT 1;
```
- If "permission denied" → RLS policy issue
- If returns rows → policy is working

---

## Testing Checklist

Use this to isolate which issue you have:

- [ ] **Auth token present?** (look for 🔐)
  - No → Issue 1
  - Yes → Continue

- [ ] **Token included in subscription?** (look for ✅)
  - No → Issue 1 (token is nil when sending)
  - Yes → Continue

- [ ] **WebSocket connects?** (look for 📨 initial message)
  - No → Issue 3 (network)
  - Yes → Continue

- [ ] **Subscription confirmed?** (look for ✅ Successfully sent)
  - No → Issue 4 (config) or Issue 2 (RLS)
  - Yes → Continue

- [ ] **Activity events received?** (look for 📨 with data)
  - No → Issue 2 (RLS denying silently)
  - Yes → Realtime is working! 🎉

---

## Common Fixes Quick Reference

| Symptom | Fix |
|---------|-----|
| No token in logs | Log out and back in |
| Token invalid | Logout/login to refresh token |
| RLS policy denies | Check user in family_members, verify filter |
| Network error | Try different WiFi/cellular |
| Connection closes immediately | Check auth token (Issue 1) |
| No events but subscribed | Check RLS policy (Issue 2) |
| Silent failure | Add debugging, check logs carefully |
| Delayed events | Check network latency, check trigger |

---

## Emergency Debug Mode

If nothing else works, add this temporary debug logging:

**In RealtimeFamilyActivitySubscription.swift:**
```swift
// Add in receiveMessages() after handleMessage call
print("🔍 DEBUG: Full message: \(message)")
print("🔍 DEBUG: Message length: \(message.count)")
```

**In FamCalApp.swift:**
```swift
// Before subscribing
print("🔍 DEBUG: familyId = \(appSettingsManager.familyId ?? "NIL")")
print("🔍 DEBUG: userId = \(userId)")
print("🔍 DEBUG: token = \(authManager.accessToken?.prefix(50) ?? "NIL")...")
```

Then check Debug Logs for all 🔍 messages.

---

## When to Ask for Help

If you've checked all these and still stuck, gather:

1. **Debug Logs output** (Settings → Debug Logs → Copy)
2. **Realtime Diagnostic results** (Settings → Realtime Diagnostics)
3. **Which issue number** you think it is (1-6 above)
4. **What action triggers** the problem
5. **Any custom RLS policies** you added

---

## Supabase Documentation References

- [Realtime Troubleshooting](https://supabase.com/docs/guides/realtime#troubleshooting)
- [RLS Policies Guide](https://supabase.com/docs/guides/auth/row-level-security)
- [WebSocket Debugging](https://supabase.com/docs/guides/realtime/debugging)

---

**Last Updated**: December 2, 2025
**Status**: Ready to troubleshoot
