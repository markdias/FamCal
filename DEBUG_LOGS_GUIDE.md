# In-App Debug Logs Guide

## 🎉 What's New

You no longer need Xcode console to see debug logs! All console output is captured in real-time and viewable directly in the FamCal app.

## 📱 How to Access Debug Logs

1. **Open FamCal app**
2. **Go to Settings** (gear icon)
3. **Scroll to "Test Only" section**
4. **Tap "Debug Logs"** (purple icon with magnifying glass)
5. **Watch logs appear in real-time** as the app runs

## 🎯 Key Features

### Real-Time Capture
- All `print()` statements are automatically captured
- Logs appear instantly in the viewer
- 500 most recent entries stored (rolling buffer)

### Filter & Search
- Type in the filter box to search logs by keyword
- Example: "Realtime", "WebSocket", "Error", etc.
- Case-insensitive search
- Shows matching count at top

### Auto-Scroll
- Tap "Auto" button to toggle automatic scrolling
- When enabled: automatically scrolls to newest logs
- When disabled: manually scroll through history
- Useful when you want to read a specific part

### Color Coding
- ✅ **Green**: Success messages (✅ prefix)
- ❌ **Red**: Error messages (❌ prefix)
- ⚠️ **Orange**: Warnings and waiting (⚠️, ⏳ prefix)
- 🔵 **Blue**: Realtime-specific messages (📡, 💓, 📊)
- ⚪ **White**: General info

### Copy & Clear
- **Copy button**: Copies all logs to clipboard (tap for confirmation)
- **Clear button**: Removes all logs from viewer
- Use Copy to paste logs into chat/email

### Timestamps
- Every log shows exact time captured
- Format: HH:MM:SS.mmm
- Helps identify timing issues

## 🔍 What to Look For

### Realtime Connection Logs
When connecting to Realtime, you should see:
```
ℹ️ Subscribing to family activities
🔗 Supabase URL: https://tzkspidmzlipujsnxpzc.supabase.co
📌 Starting receiveMessages task
✅ Starting message receive loop
📨 Received string message (150 chars)
✅ WebSocket is ready for subscription
📡 Sending Realtime subscription
✅ Successfully sent subscription
💓 Starting keep-alive ping loop
📊 Realtime sync status: Connected
```

### Activity Received
When an activity arrives:
```
📨 Received string message (450 chars)
✅ Successfully decoded Realtime message with event: postgres_changes
ℹ️ Realtime event: INSERT
🔔 New family activity: Address added to Saved Places
```

### Errors to Watch For
```
❌ WebSocket receive error: Socket is not connected
❌ Failed to send subscription: ...
❌ Connection lost: ...
```

## 📊 Using Filters to Debug

### Filter by Event Type
- Filter: `WebSocket` → See all connection events
- Filter: `Realtime` → See subscription events
- Filter: `activity` → See activity/notification events
- Filter: `error` → See only errors (shows ❌)

### Filter by Message Type
- Filter: `📨` → See all received messages
- Filter: `✅` → See all successful operations
- Filter: `🔔` → See all notifications sent

### Filter by Topic
- Filter: `📡` → Subscription messages
- Filter: `💓` → Keep-alive pings
- Filter: `timeout` → Connection timeouts

## 🧪 Testing Workflow

### Test Real-Time Notifications
1. **Open Debug Logs** (Settings → Test Only → Debug Logs)
2. **Enable Auto-Scroll** (tap "Auto" if not already on)
3. **Clear existing logs** (tap "Clear")
4. **Perform action** on another device (add location, create driver, etc.)
5. **Watch logs appear** in real-time
6. **Look for success message**: `🔔 New family activity: ...`
7. **Timing note**: Check timestamps to see how fast notification arrived

### Test Diagnostics & Logs Together
1. **Open Debug Logs** (auto-scroll on)
2. **Clear logs** (tap Clear)
3. **Go back to Settings**
4. **Run Realtime Diagnostics**
5. **Go back to Debug Logs** (already open)
6. **See full diagnostic output** with timestamps and details

### Compare Multiple Test Runs
1. **Clear logs** before each test
2. **Copy logs** after test (Copy button)
3. **Paste in Notes app** or text editor
4. **Compare across multiple runs** to find patterns

## 💡 Tips & Tricks

### Reduce Noise
If logs are too chatty:
- Filter by specific keyword: "Realtime", "connection", "error"
- Clear logs frequently between tests
- Disable auto-scroll to pause viewing

### Find Timing Issues
- Look at timestamps between related logs
- Example: Time between "Sending subscription" and "Successfully sent"
- Can identify slow operations or hanging awaits

### Capture Full Session
1. Clear logs
2. Perform entire test flow
3. Copy logs
4. Paste into file for analysis
5. Look for pattern of events

### Export for Analysis
1. Tap "Copy" when you see an issue
2. Paste into Notes app or text editor
3. Save with date/time in filename
4. Share with developers for analysis

## 🔧 What Gets Captured

**Captured** (shows up in logs):
- ✅ All `print()` statements from code
- ✅ All debug logs from iOS
- ✅ Timestamps for every log entry
- ✅ System messages

**Not Captured**:
- ❌ System alerts or popups
- ❌ Network traffic details (only console output)
- ❌ Variable values (must be printed explicitly)
- ❌ Stack traces (unless printed)

## 📋 Filter Examples

| Filter | Shows |
|--------|-------|
| `WebSocket` | All WebSocket connection messages |
| `📡` | All subscription messages |
| `❌` | All errors and failures |
| `timeout` | Connection timeouts |
| `subscri` | Subscription-related logs |
| `family_activity` | Realtime channel messages |
| `notification` | Notification scheduling |
| `JWT` | Authentication-related logs |
| `receive` | Message reception logs |

## 🎓 Understanding Common Patterns

### Successful Connection Pattern
```
ℹ️ Subscribing to family activities
📌 Starting receiveMessages task
✅ Starting message receive loop
📨 Received string message (initial handshake)
✅ WebSocket is ready for subscription
📡 Sending Realtime subscription
✅ Successfully sent subscription
💓 Starting keep-alive ping loop
📊 Realtime sync status: Connected
```

### Connection Timeout Pattern
```
✅ Starting message receive loop
⏳ Listening for WebSocket messages
⏳ Socket not yet connected (attempt 1/10)
⏳ Retrying in 2 seconds...
(repeats with increasing delays)
❌ WebSocket failed to connect after 10 attempts
```

### Activity Received Pattern
```
👂 Listening for WebSocket messages
📨 Received string message (450 chars)
✅ Successfully decoded Realtime message
ℹ️ Realtime event: INSERT
🔔 New family activity: [Activity details]
```

## ⚙️ Technical Details

### How It Works
- Redirects stdout and stderr to a custom pipe
- Continuously reads from pipe in background thread
- Stores logs with timestamps in memory
- Updates UI in real-time on main thread
- Maintains rolling buffer of 500 entries

### Performance
- Minimal overhead (background thread)
- Doesn't slow down app
- Efficient memory management (rolling buffer)
- Safe thread handling (GCD queues)

### Limitations
- Only 500 most recent entries stored
- Logs cleared when app is force-closed
- Copy button copies to device clipboard only
- Not persisted to disk

## 🐛 Debugging Tips

### "Logs not appearing"
- Ensure app is printing (should see logs from startup)
- Check filter isn't too restrictive
- Toggle auto-scroll to refresh view
- Return to Settings and re-open Debug Logs

### "Too many logs"
- Use filter to reduce to specific event
- Clear logs between tests
- Disable auto-scroll and scroll manually
- Focus on one feature at a time

### "Logging too much code"
- Filter out noisy parts (like keep-alive pings)
- Example: Avoid filtering by "ping" to see ALL other messages
- Focus on specific keywords related to your test

---

## Quick Start

1. **Rebuild app**: `Cmd + R`
2. **Open Settings** (gear icon)
3. **Test Only → Debug Logs**
4. **Watch logs in real-time** as you test features
5. **No more Xcode console dependency!**

---

**Last Updated**: December 2, 2025
**Feature**: In-app debug log viewer
**Status**: Ready to use
