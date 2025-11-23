# Quick Fix Guide - Login Error 400

## TL;DR - What to Do Right Now

### Step 1: Create Database Schema (5 minutes)
```
1. Go to: https://app.supabase.com
2. Open your project
3. Click: SQL Editor (left sidebar)
4. Open file: SUPABASE_SETUP_INSTRUCTIONS.md (in your project)
5. Copy ALL the SQL code
6. Paste into SQL Editor
7. Click: "Run" button
8. Wait for completion
```

### Step 2: Test Login (2 minutes)
```
1. In Xcode: Cmd+B (build)
2. In Xcode: Cmd+R (run)
3. Try any email and password
4. Check Xcode console output
5. Should see either:
   ✅ "User signed in successfully"  (SUCCESS!)
   ❌ "HTTP Status: 400" (still need help)
```

### Step 3: Report Results
Share the console output from your login attempt.

---

## Common Issues & Quick Fixes

### "HTTP 400" after running SQL
**Cause**: Database schema exists but something else is wrong
**Check**: Run this in SQL Editor:
```sql
SELECT COUNT(*) as profiles_count FROM public.profiles;
```
If it returns 0, that's fine. If it errors, re-run the setup SQL.

### "User doesn't exist" (invalid_grant)
**Create test user in Supabase**:
1. Auth → Users → Create user
2. Email: test@example.com
3. Password: test123456
4. Toggle: "Confirm email" ON
5. Click: Create user

### "Email not confirmed"
**Fix**: In Supabase Users list, click the user, toggle "Email Confirmed" switch.

### App builds but crashes on login
Check Xcode console for Swift errors, not HTTP errors.
This would be a code issue, not a server issue.

---

## The 400 Error Explained

```
HTTP 400 = Bad Request
= Server says "Your request makes no sense"

Common causes:
- Missing database tables
- User doesn't exist
- Password wrong
- Email not confirmed
```

**We added logging to show you EXACTLY what Supabase says is wrong.**

When you see: `❌ Parsed error message: invalid_grant`
= User doesn't exist or password is wrong

---

## File Locations
- Database setup: `SUPABASE_SETUP_INSTRUCTIONS.md`
- Detailed debugging: `LOGIN_DEBUG_GUIDE.md`
- Full status: `AUTHENTICATION_STATUS.md`
- Configuration: `FamCal/SupabaseConfig.swift`

---

## Success Looks Like This

```
ℹ️ Sign-in request: POST https://tzkspidmzlipujsnxpzc.supabase.co/auth/v1/token
ℹ️ Headers: Content-Type=application/json, apikey=eyJhbGc...
ℹ️ Body: email=test@example.com, grant_type=password
✅ User signed in successfully: test@example.com
```

Then the app loads the MainTabView! 🎉

---

## Need More Help?

1. Check `LOGIN_DEBUG_GUIDE.md` for detailed steps
2. Check `AUTHENTICATION_STATUS.md` for full status
3. Run the database schema SQL from `SUPABASE_SETUP_INSTRUCTIONS.md`
4. Try login again and share the console output
