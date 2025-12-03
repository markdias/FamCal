# WatchConnectivity Implementation Guide

## Overview

This document describes the simplified WatchConnectivity implementation for FamCal, which enables the watch app to fetch member names from the phone app.

## Architecture

### Watch Side (WatchAppExtension/NextEventsView.swift)

The watch app implements the following flow:

1. **Initialization**: Creates a WCSession on app startup
2. **Activation**: Calls `session.activate()` and sets the view model as delegate
3. **Waiting for Activation**: Does NOT immediately request data - waits for `activationDidCompleteWith` callback
4. **Request Data**: After activation completes, `requestEvents()` is called
5. **Send Message**: Calls `session.sendMessage(["action": "getMembers"], ...)`
6. **Wait for Reply**: Handles `replyHandler` callback with member names
7. **Parse Response**: Splits comma-separated member names
8. **Display**: Creates placeholder events for UI display

### Phone Side (FamCal/WatchSessionManager.swift)

The phone app handles requests as follows:

1. **Initialization**: Creates WCSession and sets itself as delegate
2. **Receives Message**: WCSessionDelegate's `didReceiveMessage` callback is invoked
3. **Validate Request**: Checks for `["action": "getMembers"]`
4. **Fetch Data**: Queries CoreData for FamilyMember objects
5. **Build Response**: Creates `["ok": "yes", "members": "name1,name2,name3"]`
6. **Send Reply**: Calls `replyHandler` with response
7. **Threading**: All work happens on background thread (no dispatch to main)

## Critical Implementation Details

### Threading

⚠️ **CRITICAL**: The `replyHandler` callback MUST be called from the background thread where the delegate method executes, NOT from the main thread.

**Correct**:
```swift
nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    handleMessage(message, replyHandler: replyHandler)
}

nonisolated private func handleMessage(_ message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
    persistenceController.container.performBackgroundTask { context in
        // Do work...
        replyHandler(response)  // ✅ Called on background thread
    }
}
```

**Incorrect** (will cause `WCErrorCodeGenericError`):
```swift
DispatchQueue.main.async {
    replyHandler(response)  // ❌ Wrong thread!
}
```

### Session Activation Order

⚠️ **CRITICAL**: The watch app must NOT call `requestEvents()` in `init()`. Instead:

**Correct**:
```swift
override init() {
    // ... setup ...
    session?.delegate = self
    session?.activate()
    // Don't call requestEvents() here!
}

func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if activationState == .activated {
        requestEvents()  // ✅ Call here
    }
}
```

### Data Serialization

WatchConnectivity has limitations on what can be serialized:

✅ **Supported**:
- String
- Number types (Int, Double)
- Bool
- Dictionary with string values
- Simple arrays of strings

❌ **Not Supported** (causes `WCErrorCodePayloadUnsupportedTypes`):
- Complex nested dictionaries
- Custom objects
- Codable types (must encode to JSON string first)
- Large nested arrays

**Solution**: Use simple types and encode complex data as JSON strings if needed.

## Message Protocol

### Request (Watch → Phone)

```swift
["action": "getMembers"]
```

### Response (Phone → Watch)

```swift
["ok": "yes", "members": "Alice,Bob,Charlie"]
```

Or on error:
```swift
["ok": "no", "error": "No members found"]
```

## Testing

### On Simulator

1. Boot both iPhone and Watch simulators:
   ```bash
   xcrun simctl boot 6E72EF6C-702E-4266-8941-7E534DF878E1  # iPhone
   xcrun simctl boot 9E4FD5CC-CD62-45F3-B61F-B87D1E8A870C  # Watch
   ```

2. Build both apps:
   ```bash
   # From Xcode, or:
   xcodebuild -workspace FamCal.xcworkspace -scheme FamCal -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1' build
   xcodebuild -workspace FamCal.xcworkspace -scheme "FamCal WatchKit App" -configuration Debug -destination 'generic/platform=watchOS' build
   ```

3. Launch from Xcode (easier than command line installation)

4. Watch console logs:
   - **Watch**: `⌚` prefix
   - **Phone**: `📱` prefix

### Expected Log Flow

```
⌚ WatchEventsViewModel initialized
⌚ WCSession state:
  - isSupported: true
  - activationState: 0
  - isReachable: false

📱 WCSession initialized:
  - isSupported: true
  - activationState: 2
  - isReachable: false

⌚ WCSession activation completed: 2
⌚ WCSession activated, requesting events
⌚ Session reachability changed: isReachable=true
⌚ Requesting events from iPhone via WatchConnectivity

📱 WatchSession activation callback received
📱 WatchSession activation state: 2
📱 Received message from watch: ["action": "getMembers"]
📱 Watch requested members
✅ Fetched 3 members
📤 Sending 3 member names
✔️ Response sent to watch

⌚ Received reply from iPhone: ["ok", "members"]
⌚ Processing reply: ["members", "ok"]
⌚ Successfully received 3 members: ["Alice", "Bob", "Charlie"]
```

### On Physical Devices

1. Ensure iPhone and Apple Watch are paired in real life
2. Install FamCal on both devices via Xcode
3. Keep iPhone app open in foreground
4. Launch watch app
5. Watch will communicate with phone

## Debugging

### Watch Doesn't See Phone (isReachable: false)

- ✅ Phone app must be running in foreground
- ✅ iPhone and Watch must be paired
- ✅ WatchConnectivity must be enabled
- ❌ Background execution doesn't trigger message delivery

### Message Doesn't Arrive at Phone

Phone console should show: `📱 Received message from watch: ...`

If not:
- Check phone app is actually running
- Check WCSession delegate is properly set
- Add logging to verify delegate methods are called

### Reply Not Received at Watch

Watch console should show: `⌚ Received reply from iPhone: ...`

If not:
- Check replyHandler is being called on correct thread
- Verify response dictionary is correct format
- Check for `WCErrorCodeGenericError` in error handler

### Timeout Error

If watch shows "Request timed out":
- Phone app may have crashed
- Phone app may be in background
- Network may be disconnected

## Next Steps

Once basic member name communication is confirmed working:

1. **Add member metadata**: Include IDs and colors in comma-separated format
2. **Add event data**: Include next event per member
3. **Optimize payload**: Use JSON encoding for complex structures if needed
4. **Add error handling**: Implement retry logic

## References

- [Apple WatchConnectivity Documentation](https://developer.apple.com/documentation/watchconnectivity)
- [WCSession sendMessage:replyHandler:errorHandler:](https://developer.apple.com/documentation/watchconnectivity/wcsession/1615687-sendmessage)
- [WCSessionDelegate](https://developer.apple.com/documentation/watchconnectivity/wcsessiondelegate)
