# Supabase Integration - Next Steps

## ✅ What's Been Completed

I've set up the foundation for Supabase integration with authentication:

### 1. Configuration Files
- ✅ `SupabaseConfig.swift` - Configuration file with your URL pre-filled
- ✅ `.env.example` - Example environment file
- ✅ Updated `.gitignore` to protect credentials

### 2. Authentication System
- ✅ `SupabaseAuthManager.swift` - Complete authentication manager
- ✅ `LoginView.swift` - Beautiful login screen
- ✅ `SignupView.swift` - User registration screen  
- ✅ `ForgotPasswordView.swift` - Password reset functionality

### 3. App Integration
- ✅ Updated `FamCalApp.swift` - Authentication flow integrated
- ✅ Updated `SettingsView.swift` - Added account section with logout

---

## 🔧 What You Need to Do

### Step 1: Add Supabase SDK Package

1. Open `FamCal.xcodeproj` in Xcode
2. Select the **FamCal** project in the navigator
3. Select the **FamCal** target
4. Go to the **Package Dependencies** tab
5. Click the **+** button
6. Enter: `https://github.com/supabase/supabase-swift`
7. Click **Add Package**
8. Select these products:
   - ✅ Supabase
   - ✅ Auth
   - ✅ PostgREST
   - ✅ Realtime
9. Click **Add Package**

### Step 2: Add Your Supabase API Key

1. Open `FamCal/SupabaseConfig.swift` in Xcode
2. Find line 24: `static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY_HERE"`
3. Replace with your actual anon key from Supabase Dashboard
4. Save the file

**Where to find your anon key:**
- Go to your Supabase project dashboard
- Click **Project Settings** (gear icon)
- Click **API** in the sidebar
- Copy the **anon/public** key

### Step 3: Update Your Supabase Database

Run this SQL in your Supabase SQL Editor to add user association:

```sql
-- Add user_id column to family_members table
ALTER TABLE family_members ADD COLUMN user_id UUID REFERENCES auth.users(id);
CREATE INDEX idx_family_members_user_id ON family_members(user_id);

-- Update RLS policies to filter by user_id
DROP POLICY IF EXISTS "Users can view their own family members" ON family_members;
DROP POLICY IF EXISTS "Users can insert their own family members" ON family_members;
DROP POLICY IF EXISTS "Users can update their own family members" ON family_members;
DROP POLICY IF EXISTS "Users can delete their own family members" ON family_members;

CREATE POLICY "Users can view their own family members"
    ON family_members FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own family members"
    ON family_members FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own family members"
    ON family_members FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own family members"
    ON family_members FOR DELETE
    USING (auth.uid() = user_id);
```

### Step 4: Build and Test

1. Build the project in Xcode (⌘B)
2. Fix any compilation errors (should be minimal)
3. Run the app
4. You should see the login screen!

---

## 🎯 What's Next

After you complete the steps above, I'll continue with:

1. **Database Layer** - Create `SupabaseManager` for CRUD operations
2. **Data Models** - Swift structs matching your Supabase schema
3. **Data Sync** - Sync between CoreData and Supabase
4. **Testing** - Verify everything works end-to-end

---

## 📝 Testing the Authentication

Once you've added the SDK and API key:

1. **Sign Up**: Create a new account
2. **Sign In**: Login with your credentials
3. **Onboarding**: Complete the onboarding flow
4. **Settings**: Check the account section shows your email
5. **Sign Out**: Test logout functionality

---

## ⚠️ Important Notes

- The app will show a login screen on first launch
- Existing local data won't be lost - we'll sync it after login
- The anon key is safe to use in the app (it's public)
- Row Level Security (RLS) protects your data in Supabase

---

## 🆘 Need Help?

If you encounter any issues:
1. Check the Xcode console for error messages
2. Verify your Supabase URL and anon key are correct
3. Make sure you ran the SQL migration scripts
4. Let me know what error you're seeing!
