# Supabase Support Message (5000 char limit)

---

**Subject**: WebSocket Upgrade Returns HTTP/2 500 - Realtime Service Error

**Project ID**: `tzkspidmzlipujsnxpzc`

---

## Problem

Our iOS app cannot connect to Supabase Realtime. WebSocket upgrade requests to `wss://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1` return HTTP/2 500 error instead of 101 Switching Protocols.

## What Works ✅
- REST API: `https://tzkspidmzlipujsnxpzc.supabase.co/rest/v1/` → HTTP 200
- Network: Domain reachable, connectivity confirmed
- Database: `family_activity_log` table IS in `supabase_realtime` publication (verified via SQL)
- App Code: WebSocket implementation correct (JWT in URL, proper headers)
- iOS: Both simulator and physical device fail with same error

## What's Failing ❌
- WebSocket: Both anonymous and authenticated connections return HTTP/2 500
- Terminal Test: `curl` and `websocat` from Mac also get HTTP/2 500
- Consistent: Every attempt gets Internal Server Error

## Test Results

**REST API Test (Works)**:
```
curl https://tzkspidmzlipujsnxpzc.supabase.co/rest/v1/
→ HTTP/2 200 ✅
```

**WebSocket Test (Fails)**:
```
curl -H "Connection: Upgrade" -H "Upgrade: websocket" -H "Sec-WebSocket-Key: ..." \
  "https://tzkspidmzlipujsnxpzc.supabase.co/realtime/v1?apikey=..."
→ HTTP/2 500 ❌
```

**Database Verification (Works)**:
```sql
SELECT pubname, tablename FROM pg_publication_tables
WHERE tablename = 'family_activity_log';
→ supabase_realtime | family_activity_log ✅
```

## App Implementation

**Platform**: iOS Swift, URLSessionWebSocketTask
**Supabase SDK**: v2.37.0

**Code**:
```swift
let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)&access_token=\(token)"
let request = URLRequest(url: URL(string: realtimeURL)!)
let webSocket = URLSession.shared.webSocketTask(with: request)
webSocket.resume()
```

All JWT tokens are valid (140+ characters, proper format).

## Questions

1. Why does WebSocket upgrade return HTTP 500?
2. Is Realtime service enabled and healthy for this project?
3. Are there undocumented configuration requirements?
4. Any recent changes to Realtime infrastructure?

## Impact

This blocks real-time family calendar notifications—a core feature. Users cannot see instant updates when family members add events.

## What We've Verified

✅ JWT token in WebSocket URL
✅ Proper WebSocket headers
✅ Table in Realtime publication
✅ RLS policies configured
✅ Network connectivity confirmed
✅ REST API fully functional

**The HTTP 500 is a service-level issue we cannot fix on our side.**

---

**Ready to provide**: Additional logs, debug output, or any diagnostic info needed.

