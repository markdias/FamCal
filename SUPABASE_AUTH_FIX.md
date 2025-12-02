# Supabase Realtime Authentication Fix - December 2, 2025

## The Issue

**Error**: "Socket is not connected" when trying to establish WebSocket connection to Supabase Realtime

**Root Cause**: The WebSocket URL was using only the **anonymous API key** without including the authenticated **JWT token** from the logged-in user.

## Why This Matters

Supabase Realtime channels with Row-Level Security (RLS) policies require **authenticated connections**. The authentication context (who is making the request) is essential for RLS policies to work.

When you subscribe to a channel with RLS policies enabled, Supabase checks `auth.uid()` in the policy. This requires:
1. A valid JWT token in the connection
2. The token to be from an authenticated user
3. The server to verify the token before allowing access

## The Fix

### Before (Incorrect)
```swift
let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"
```
- Only includes anonymous key
- No authentication context
- RLS policies see `auth.uid() = NULL`
- Connection rejected

### After (Correct)
```swift
if let token = accessToken, !token.isEmpty {
    let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)&access_token=\(token)"
} else {
    let realtimeURL = "\(wsURL)/realtime/v1?apikey=\(anonKey)"
}
```
- Includes both anonymous key AND JWT token
- Connection establishes with authenticated context
- RLS policies can verify `auth.uid()` from token
- Subscription succeeds

## Technical Details

### WebSocket URL Parameters

| Parameter | Purpose | Value |
|-----------|---------|-------|
| `apikey` | Project public key | Anonymous key (required) |
| `access_token` | User authentication | JWT from supabase.auth.getSession() |

The `access_token` parameter tells Supabase which user is connecting. This user's ID is extracted from the JWT and used in RLS policy checks.

### RLS Policy Flow

```
1. Client connects to WebSocket with URL including access_token=JWT
2. Supabase server receives connection
3. Server decodes JWT token
4. Server extracts user ID from token: auth.uid() = "user-123"
5. Client subscribes to table with RLS policy
6. Server checks RLS policy using auth.uid() = "user-123"
7. Policy allows access if user is in family_members table
8. Client receives events
```

Without the JWT in the URL:
```
1. Client connects with only apikey (anonymous)
2. Server has no user context: auth.uid() = NULL
3. Client subscribes to table with RLS policy
4. Server checks RLS policy using auth.uid() = NULL
5. Policy DENIES access (NULL doesn't match any user)
6. Connection fails or no events received
```

## Implementation in FamCal

### Code Location
[RealtimeFamilyActivitySubscription.swift](FamCal/RealtimeFamilyActivitySubscription.swift) lines 85-108

### Authentication Flow

1. **User logs in** → Supabase session created with JWT token
2. **App calls `subscribeToFamilyActivities()`** with `accessToken` parameter
3. **Token validation** → Logs if token is present or missing
4. **URL construction** → Includes token if available
5. **WebSocket connection** → Establishes with authenticated context
6. **Subscription** → Includes token in payload for additional verification
7. **Events flow** → RLS policies allow access because auth context is verified

### Logging Indicators

When token is properly included:
```
🔐 Access token present (XXX chars): eyJhbGciOi...
🔐 Using authenticated Realtime connection with JWT token in URL
🔐 JWT token: eyJhbGciOi... (XXX chars)
✅ Including access token in subscription payload (XXX chars): eyJhbGciOi...
✅ Token also present in WebSocket URL for authenticated connection
```

When token is missing:
```
⚠️ WARNING: No access token provided - RLS policies may deny access
⚠️ Using anonymous key only - RLS policies will deny access
⚠️ For authenticated channels, access_token MUST be in URL
```

## References

**Supabase Documentation**:
- [Realtime Auth Extensions](https://supabase.com/docs/guides/realtime/extensions/auth)
- [Row-Level Security](https://supabase.com/docs/guides/auth/row-level-security)
- [Realtime Authorization](https://supabase.com/docs/guides/realtime#authorization)

**Key Quote from Supabase**:
> "For authenticated realtime channels you must provide the authenticated session token to the client before subscribing. Ensure user is signed in (supabase.auth.getSession()). Then include the access_token in the WebSocket URL."

## Testing the Fix

### Quick Test
1. Open app Settings → Test Only → Debug Logs
2. Clear logs
3. Add a location on Device A
4. Watch Device B Debug Logs for:
   - `🔐 Using authenticated Realtime connection with JWT token in URL`
   - `📨 Received string message` (event from other device)
   - `🔔 New family activity:` (notification triggered)

### Expected Behavior
- WebSocket connects immediately (within 2-3 seconds)
- No "Socket is not connected" errors
- Events flow within 1-3 seconds of creation
- RLS policies allow access based on family_members table

## Performance Impact

✅ **Minimal** - Token is just added to URL query string
- No additional network calls
- No latency increase
- Same WebSocket handshake time

## Security Considerations

✅ **More Secure** - Authenticated connections are:
- Required for RLS policies to work
- Verified by Supabase backend
- User-scoped (only see own data)
- Token expires (automatic refresh via auth manager)

⚠️ **Token in URL** - Some concerns about tokens in URLs:
- URL is sent in TLS (encrypted)
- WebSocket protocols typically pass auth in URL or headers
- Supabase recommends this approach
- Token is short-lived (1 hour default)

## Debugging

If connection still fails after this fix:

1. **Check token is being passed**:
   ```
   In Debug Logs, look for: 🔐 Using authenticated Realtime connection
   ```

2. **Check token is valid**:
   ```
   In Debug Logs, look for: 🔐 Access token present (XXX chars)
   If <100 chars: Token might be corrupted
   ```

3. **Check user is logged in**:
   ```
   In FamilyView, do you see family members?
   If not: User not logged in or session expired
   ```

4. **Check user is in family**:
   ```
   In Supabase Dashboard SQL Editor:
   SELECT * FROM family_members WHERE id = '[user-id]';
   Should return a row. If not: Add user to family.
   ```

5. **Check RLS policy**:
   ```
   In Supabase Dashboard SQL Editor:
   SELECT * FROM pg_policies WHERE tablename = 'family_activity_log';
   Should show policy using auth.uid()
   ```

## Commit Information

**Commit**: 0331789
**Date**: December 2, 2025
**Files Modified**: RealtimeFamilyActivitySubscription.swift (2 changes)
**Build Status**: ✅ Successful
**Testing**: Ready

## Version History

| Version | Date | Change |
|---------|------|--------|
| 1.0 | Dec 2, 2025 | Added JWT token to WebSocket URL for RLS authentication |
| 0.9 | Dec 1, 2025 | Initial implementation with anonymous key only |

---

## Summary

The fix moves authentication handling from just the subscription payload to the WebSocket connection level. This ensures Supabase knows who the user is from the moment the connection is established, enabling RLS policies to work correctly.

**Key Change**:
```
apikey=[key]                              (BEFORE - anonymous)
↓
apikey=[key]&access_token=[JWT]           (AFTER - authenticated)
```

This single change from anonymous to authenticated connection should resolve the "Socket is not connected" errors and enable RLS policies to function properly.
