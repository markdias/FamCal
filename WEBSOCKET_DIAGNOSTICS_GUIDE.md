# WebSocket Diagnostics Guide

## Purpose

This guide explains the diagnostic enhancements added to help troubleshoot WebSocket connection failures with Supabase Realtime. These diagnostics follow Supabase's recommended troubleshooting approach.

## What Diagnostics Capture

The enhanced logging in [RealtimeFamilyActivitySubscription.swift](FamCal/RealtimeFamilyActivitySubscription.swift) now captures:

### 1. WebSocket Task Creation
```
🚀 WebSocket task created: ✅ Success
```
- Confirms `URLSessionWebSocketTask` instantiation worked
- If you see "❌ Failed", there's a problem with the task creation itself

### 2. TLS Handshake Progress
```
🚀 Calling webSocket.resume() to initiate TLS handshake...
⏳ WebSocket connection initiated (TLS handshake in progress)
⏳ Waiting for initial message from Supabase Realtime server...
```
- Shows when TLS handshake begins
- Clear indication of what to expect next

### 3. Request Details
```
🔗 Request URL: wss://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=[key]&access_token=[JWT]
🔗 Request headers: [Connection: websocket, Sec-WebSocket-Version: 13, ...]
```
- Shows exact URL being connected to (with tokens masked)
- Shows headers being sent with WebSocket handshake
- Helps identify if authentication is present in URL

### 4. Error Details
```
🔍 URLError code: 54
🔍 URLError code name: networkConnectionLost
🔍 URLError details: [comprehensive error info]
```
- Specific URLError codes help identify the problem:
  - Code 54: Network connection lost
  - Code -1001: Request timeout
  - Code -1003: No internet connection
  - Code -1002: Cannot find server
  - And many others

### 5. Immediate Connection Test
```
🧪 DIAGNOSTIC TEST: Attempting immediate receive to check WebSocket state...
```
- Tests if WebSocket can receive initial message from server
- Helps identify network/server issues
- Shows if Realtime is truly enabled

## Common Error Codes

| Code | Name | Meaning | Fix |
|------|------|---------|-----|
| -1 | Unknown | Generic URLError | Check logs for more details |
| -1000 | Cancelled | Request cancelled | Check if task was cancelled |
| -1001 | BadURL | Invalid URL format | Verify WebSocket URL construction |
| -1002 | TimedOut | Connection timed out | Check network, increase timeout |
| -1003 | UnsupportedURL | URL scheme not supported | Should be wss:// |
| -1004 | CannotFindHost | DNS resolution failed | Check domain name |
| -1006 | CannotConnectToHost | Connection refused | Server not responding |
| -1009 | NotConnectedToInternet | No network | Check WiFi/cellular |
| -1012 | UserCancelledAuthentication | Auth cancelled | Check auth flow |
| -1017 | RedirectToNonSecureURL | Redirect to HTTP | Keep as HTTPS |
| -1200 | SecureConnectionFailed | TLS handshake failed | Check certificates |

## Debugging Workflow

### Step 1: Check WebSocket Task Creation
```
Look for: 🚀 WebSocket task created
Expect: ✅ Success

If "❌ Failed":
  - URL might be malformed
  - Check the URL construction logic
  - Verify domain name spelling
```

### Step 2: Monitor TLS Handshake
```
Look for: ⏳ TLS handshake in progress
Then wait for: Either ✅ SUCCESS or ❌ ERROR

If timeout after 15 seconds:
  - Network issue (firewall, VPN, WiFi)
  - DNS resolution problem
  - Supabase service down
```

### Step 3: Check for Errors
```
If ❌ ERROR:
  1. Note the URLError code
  2. Reference the table above
  3. Take recommended action
```

### Step 4: Verify Authentication
```
Look for: 🔐 Using authenticated Realtime connection with JWT token in URL
Also look for: 🔐 JWT token: eyJhbGc... (XXX chars)

If missing:
  - User might not be logged in
  - Session might be expired
  - Check auth manager state
```

## Examples of Good Diagnostics Output

### Successful Connection
```
🔗 Request URL: wss://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=...&access_token=...
🔗 Request headers: [Connection: websocket, Sec-WebSocket-Version: 13]
🚀 WebSocket task created: ✅ Success
🚀 Calling webSocket.resume() to initiate TLS handshake...
⏳ WebSocket connection initiated (TLS handshake in progress)
⏳ Waiting for initial message from Supabase Realtime server...
✅ SUCCESS! Received message on first try!
📨 Message: {"type":"system","event":"init",...}
```

### Connection Timeout
```
🚀 WebSocket task created: ✅ Success
🚀 Calling webSocket.resume() to initiate TLS handshake...
⏳ WebSocket connection initiated (TLS handshake in progress)
⏳ Waiting for initial message from Supabase Realtime server...
❌ TIMEOUT: WebSocket did not send any message within 5 seconds
⚠️ This could mean:
   - Firewall or VPN blocking WebSocket connections
   - Network connectivity issue (try different WiFi)
   - DNS resolution problem
```

### Authentication Error
```
🔐 Using authenticated Realtime connection with JWT token in URL
🔐 JWT token: eyJhbGciOi... (145 chars)
❌ ERROR during initial receive: The operation couldn't be completed...
🔍 URLError code: 1200
🔍 URLError code name: secureConnectionFailed
```

## Using Debug Logs

### Access Debug Logs
1. Open Settings → Test Only → Debug Logs
2. Clear logs (tap "Clear" button)
3. Try connecting
4. Watch for diagnostic messages

### Filter for Diagnostics
- Filter by `🚀` to see connection steps
- Filter by `❌` to see only errors
- Filter by `🔐` to see auth-related messages
- Filter by `⏳` to see progress messages

## Network Testing (from Terminal)

### Test if Domain is Reachable
```bash
ping tzkspidmzlipujsnxpzc.supabase.co
```

### Test HTTPS Connectivity
```bash
curl -v https://tzkspidmzlipujsnxpzc.supabase.co/rest/v1/
```

### Test WebSocket (if websocat installed)
```bash
websocat "wss://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=YOUR_ANON_KEY"
```

If WebSocket works from terminal but not from app:
- Might be VPN/proxy issue specific to app network stack
- Check App Transport Security settings
- Verify app has network permissions

## Supabase's Diagnostic Recommendations

Based on official Supabase troubleshooting guidance:

1. **Test connectivity first**
   - Use curl/ping to verify domain is reachable
   - Use websocat to test raw WebSocket handshake
   - Works outside app? → Issue specific to iOS app

2. **Capture error codes**
   - Our diagnostics now log URLError codes
   - Specific codes point to specific problems
   - Reference URLError documentation

3. **Verify authentication**
   - Ensure JWT token is present in URL
   - Token must not be expired
   - User must be authenticated in app

4. **Check network environment**
   - Try different network (WiFi vs cellular)
   - Disable VPN/proxy
   - Check for firewall rules

5. **Inspect request/response**
   - We log URL and headers being sent
   - Helps verify WebSocket upgrade headers
   - Can use Charles/mitmproxy to capture full TLS handshake

## When to Escalate to Supabase

Gather this information before contacting Supabase support:

1. **Full diagnostic output** (from Debug Logs)
   - Copy entire output from Settings → Debug Logs
   - Include both error messages and successful messages

2. **URLError codes** (if any)
   - Exact code number (e.g., -1200)
   - Code name (e.g., secureConnectionFailed)

3. **Network environment**
   - Type of network (WiFi/cellular/VPN)
   - Geographic location
   - ISP information if known

4. **App information**
   - iOS version (visible in app logs)
   - Supabase Swift SDK version (2.37.0)
   - When did it last work (if applicable)

5. **Reproduction steps**
   - Exact steps to reproduce the issue
   - Consistent or intermittent
   - Only on certain networks

## Code Changes

### File: RealtimeFamilyActivitySubscription.swift

**Added Logging**:
- WebSocket task creation success/failure
- Full request URL (with tokens masked)
- Request headers
- URLError code and detailed information
- NSError domain/code/userInfo

**Improved Messages**:
- Clearer indication of TLS handshake progress
- Better distinction between different failure types
- More actionable error messages

**No Breaking Changes**:
- All diagnostics are logging only
- No behavior changes
- No timeout changes
- Fully backward compatible

## Related Documentation

- [SUPABASE_AUTH_FIX.md](SUPABASE_AUTH_FIX.md) - JWT token in WebSocket URL
- [TESTING_WITH_DEBUG_LOGS.md](TESTING_WITH_DEBUG_LOGS.md) - End-to-end testing
- [REALTIME_TROUBLESHOOTING.md](REALTIME_TROUBLESHOOTING.md) - 6-issue troubleshooting
- [QUICK_DEBUG_REFERENCE.md](QUICK_DEBUG_REFERENCE.md) - Quick reference card

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 2, 2025 | Enhanced WebSocket error logging and diagnostics |
| 0.9 | Dec 1, 2025 | Initial WebSocket implementation |

---

**Last Updated**: December 2, 2025
**Status**: Enhanced diagnostics ready for testing
**Next**: Test with Debug Logs and review diagnostic output
