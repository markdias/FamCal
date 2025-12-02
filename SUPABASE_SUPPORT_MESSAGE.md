# Supabase Support Message - Realtime WebSocket HTTP 500 Error

---

## Subject: WebSocket Upgrade Returns HTTP/2 500 - Realtime Service Issue

**Project ID**: `tzkspidmzlipujsnxpzc`
**Date**: December 2, 2025
**Severity**: Blocking (Realtime notifications not functional)

---

## Problem Summary

Our iOS app cannot connect to Supabase Realtime. When attempting to establish a WebSocket connection, the Realtime endpoint returns **HTTP/2 500 error** instead of the expected HTTP 101 Switching Protocols upgrade response.

**Affected Component**: Supabase Realtime WebSocket service
**Impact**: All real-time notifications and event streaming are non-functional

---

## Diagnostic Findings

### ✅ What Works
- **REST API**: Successfully connects to `https://tzkspidmzlipujsnxpzc.supabase.co/rest/v1/`
- **Database Connectivity**: All REST endpoints functional
- **Network**: Domain is reachable and responsive
- **Authentication**: JWT tokens are valid and properly formatted
- **Database Configuration**: `family_activity_log` table IS present in `supabase_realtime` publication (verified via SQL query)
- **App Code**: WebSocket implementation follows Supabase best practices (JWT in URL, proper headers)

### ❌ What's Failing
- **WebSocket Upgrade**: `wss://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1` returns HTTP/2 500
- **Both Protocols Tested**: Anonymous and authenticated connections both return 500
- **Consistent Across Devices**: iOS simulator and physical device both fail with same error
- **Consistent From Terminal**: Mac terminal (curl/websocat) also receives HTTP/2 500

---

## Test Evidence

### Test 1: REST API (Working ✅)
```bash
curl -v https://tzkspidmzlipujsnxpzc.supabase.co/rest/v1/
```

**Result**:
```
HTTP/2 200
content-type: application/json
{...successful response...}
```

### Test 2: WebSocket with Anonymous Key (Failing ❌)
```bash
curl -v -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  "https://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6a3NwaWRtemxpcHVqc254cHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4OTI2MTYsImV4cCI6MjA3OTQ2ODYxNn0.QMKZYMrESCOCT0KCHAKhPU995_mIB1F3l4Y4uq8s1uM"
```

**Result**:
```
HTTP/2 500
content-type: text/plain
Internal Server Error
```

### Test 3: WebSocket with JWT Token (Failing ❌)
```bash
curl -v -i -N \
  -H "Connection: Upgrade" \
  -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
  -H "Sec-WebSocket-Version: 13" \
  "https://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR6a3NwaWRtemxpcHVqc254cHpjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI4OTI2MTYsImV4cCI6MjA3OTQ2ODYxNn0.QMKZYMrESCOCT0KCHAKhPU995_mIB1F3l4Y4uq8s1uM&access_token=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
```

**Result**:
```
HTTP/2 500
content-type: text/plain
Internal Server Error
```

### Test 4: Database Publication Configuration (Verified ✅)

**SQL Query**:
```sql
SELECT pubname, schemaname, tablename FROM pg_publication_tables
WHERE tablename = 'family_activity_log';
```

**Result**:
```json
{
  "pubname": "supabase_realtime",
  "schemaname": "public",
  "tablename": "family_activity_log",
  "attnames": "{id,family_id,action_by_user_id,action_by_member_id,action_type,action_subject_id,action_subject_type,subject_name,action_details,created_at,updated_at}",
  "rowfilter": null
}
```

---

## App Implementation Details

### Platform & Environment
- **Framework**: iOS (Swift 5+, iOS 14+)
- **WebSocket Implementation**: URLSessionWebSocketTask (Foundation framework)
- **Supabase Swift SDK**: v2.37.0
- **App**: FamCal (Family Calendar)

### WebSocket Connection Code
```swift
var realtimeURL: String
if let token = accessToken, !token.isEmpty {
    realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)&access_token=\(token)"
} else {
    realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"
}

let url = URL(string: realtimeURL)!
let request = URLRequest(url: url)
let webSocket = URLSession.shared.webSocketTask(with: request)
webSocket.resume()
```

### Authentication Flow
1. User signs in via Supabase Auth
2. JWT token obtained from `supabase.auth.getSession()`
3. Token (140+ characters, valid JWT format) included in WebSocket URL
4. Connection attempt made with authenticated context

---

## Questions for Supabase

1. **HTTP 500 Cause**: What is causing the HTTP/2 500 error on WebSocket upgrade requests to the Realtime endpoint?

2. **Realtime Status**: Is the Realtime service currently operational and healthy for this project?

3. **Configuration**: Are there any specific configuration requirements for Realtime that may not be documented?

4. **Recent Changes**: Have there been any recent changes or maintenance on the Realtime service that might affect our project?

5. **Debugging**: What additional diagnostic information would help you investigate this issue?

---

## Timeline

- **November 2025**: Initial Realtime implementation in iOS app
- **December 1, 2025**: Discovered WebSocket connection failures
- **December 2, 2025**: Diagnosed as HTTP 500 on WebSocket upgrade
- **December 2, 2025**: Verified database configuration and app code are correct
- **December 2, 2025**: Opening support ticket after confirming issue is service-level

---

## Attempted Workarounds

We've already implemented all recommended best practices:
- ✅ JWT token included in WebSocket URL (not just anonymous key)
- ✅ Proper WebSocket headers and upgrade request format
- ✅ Error logging and diagnostics for debugging
- ✅ Table correctly added to Supabase Realtime publication
- ✅ RLS policies configured with `auth.uid()` checks
- ✅ Network connectivity confirmed (REST API works, domain reachable)

**What We Cannot Fix**: The HTTP 500 error returned by the Realtime service itself

---

## Required Next Steps

To resolve this issue, we need:

1. **Acknowledgment** of the WebSocket HTTP 500 error
2. **Root Cause Analysis** from Supabase engineering on why the endpoint is returning 500
3. **Timeline** for resolution or workaround
4. **Verification** that Realtime service is enabled and healthy for this project

---

## Project Impact

This blocks our ability to deliver real-time family calendar notifications, which is a core feature of FamCal. Without Realtime functionality:
- Users cannot see instant updates when family members add events
- Morning briefing notifications are delayed
- Location sharing updates are not real-time
- Overall user experience is significantly degraded

---

## Contact Information

- **Project**: FamCal (iOS Calendar App)
- **Project ID**: `tzkspidmzlipujsnxpzc`
- **Issue Type**: Realtime WebSocket Service Error
- **Urgency**: High (Blocking feature)

---

**Ready to provide any additional logs, error outputs, or diagnostic information.**

