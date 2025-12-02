# How to Add Supabase Swift Package in Xcode

## Step-by-Step Instructions with Screenshots

### Step 1: Open Your Project
1. Open `FamCal.xcodeproj` in Xcode
2. Make sure you're viewing the project navigator (⌘1)

### Step 2: Access Package Dependencies
1. Click on the **FamCal** project (blue icon at the top of the navigator)
2. In the main editor area, you'll see project settings
3. Select the **FamCal** target (under TARGETS, not PROJECTS)
4. Click on the **Package Dependencies** tab at the top

### Step 3: Add Package
1. Click the **+** button at the bottom of the package list
2. A sheet will appear titled "Add Package Dependency"

### Step 4: Enter Package URL
1. In the search field at the top right, paste this URL:
   ```
   https://github.com/supabase/supabase-swift
   ```
2. Press Enter or click the search button

### Step 5: Configure Package
1. Xcode will fetch the package (this may take a moment)
2. You'll see package information appear
3. For "Dependency Rule", keep the default (usually "Up to Next Major Version")
4. Click **Add Package**

### Step 6: Select Products
1. A new sheet appears asking which products to add
2. Make sure these are **checked**:
   - ✅ **Supabase**
   - ✅ **Auth**
   - ✅ **PostgREST**
   - ✅ **Realtime**
3. The target should be **FamCal**
4. Click **Add Package**

### Step 7: Verify Installation
1. Wait for Xcode to download and integrate the package
2. You should see "supabase-swift" appear in the Package Dependencies list
3. Try building the project (⌘B)

---

## Alternative: Add via File Menu

If the above doesn't work, try this:

1. Go to **File** → **Add Package Dependencies...**
2. Follow steps 4-7 above

---

## Troubleshooting

### "Unable to find module dependency: 'Supabase'"
- This means the package hasn't been added yet
- Follow the steps above to add it

### "Failed to resolve package"
- Check your internet connection
- Make sure the URL is exactly: `https://github.com/supabase/supabase-swift`
- Try again in a few moments

### Package appears but still getting errors
- Clean build folder: **Product** → **Clean Build Folder** (⌘⇧K)
- Restart Xcode
- Try building again

---

## After Adding the Package

Once the package is successfully added:
1. Build the project (⌘B)
2. The "Unable to find module dependency" error should disappear
3. Let me know if you see any other errors!

---

## Quick Reference

**Package URL:** `https://github.com/supabase/supabase-swift`

**Products to add:**
- Supabase
- Auth
- PostgREST
- Realtime

**Target:** FamCal
