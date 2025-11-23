# Adding Supabase SDK to FamCal

## Step 1: Add Swift Package Dependency

1. Open `FamCal.xcodeproj` in Xcode
2. Select the **FamCal** project in the navigator
3. Select the **FamCal** target
4. Go to the **Package Dependencies** tab
5. Click the **+** button
6. Enter this URL: `https://github.com/supabase/supabase-swift`
7. Click **Add Package**
8. Select the following products to add:
   - ✅ **Supabase** (main library)
   - ✅ **Auth** (authentication)
   - ✅ **PostgREST** (database operations)
   - ✅ **Realtime** (real-time subscriptions)
9. Click **Add Package**

## Step 2: Enter Your Supabase API Key

1. Open `FamCal/SupabaseConfig.swift` in Xcode
2. Find the line: `static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY_HERE"`
3. Replace `YOUR_SUPABASE_ANON_KEY_HERE` with your actual Supabase anon key
4. Your anon key can be found in:
   - Supabase Dashboard → Project Settings → API → anon/public key

The URL is already set to: `https://tzkspidmzlipujsnxpzc.supabase.co`

## Step 3: Verify Configuration

After adding your API key, the app will validate the configuration on startup. If there are any issues, you'll see a helpful error message.

## Important Notes

- ⚠️ **DO NOT** commit `SupabaseConfig.swift` to git (it's already in `.gitignore`)
- The anon key is safe to use in client apps (it's public)
- Row Level Security (RLS) in Supabase protects your data
- Keep your service role key secret (never use it in the app)

## Next Steps

Once you've added the package and API key, I'll continue with:
1. Creating the authentication manager
2. Building login/signup screens
3. Setting up database operations
4. Implementing data sync
