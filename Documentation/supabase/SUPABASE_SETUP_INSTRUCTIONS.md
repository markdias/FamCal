# Supabase Setup Instructions

Follow these steps to set up your Supabase database for FamCal:

## 1. Create Tables

Go to your Supabase dashboard and open the SQL Editor. Run the following SQL to create the necessary tables:

```sql
-- Create profiles table (extends auth.users)
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) PRIMARY KEY,
  email TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now()
);

-- Create family_members table
CREATE TABLE public.family_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color_hex TEXT NOT NULL DEFAULT '#007AFF',
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  CONSTRAINT unique_family_member_per_user UNIQUE(user_id, name)
);

-- Create family_member_calendars table
CREATE TABLE public.family_member_calendars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_member_id UUID NOT NULL REFERENCES public.family_members(id) ON DELETE CASCADE,
  calendar_id TEXT NOT NULL,
  calendar_name TEXT NOT NULL,
  calendar_color_hex TEXT NOT NULL,
  is_auto_linked BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP DEFAULT now(),
  CONSTRAINT unique_calendar_per_member UNIQUE(family_member_id, calendar_id)
);

-- Create shared_calendars table
CREATE TABLE public.shared_calendars (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  calendar_id TEXT NOT NULL,
  calendar_name TEXT NOT NULL,
  calendar_color_hex TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT now(),
  CONSTRAINT unique_shared_calendar_per_user UNIQUE(user_id, calendar_id)
);

-- Create calendar_event_metadata table (stores app-only fields that should NOT sync to iOS)
CREATE TABLE public.calendar_event_metadata (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  calendar_id TEXT NOT NULL,
  event_identifier TEXT NOT NULL, -- iOS calendar item identifier
  driver_family_member_id UUID REFERENCES public.family_members(id) ON DELETE SET NULL,
  notes TEXT,
  extra JSONB NOT NULL DEFAULT '{}'::jsonb, -- flexible bucket for future app-only fields
  created_at TIMESTAMP DEFAULT now(),
  updated_at TIMESTAMP DEFAULT now(),
  CONSTRAINT unique_metadata_per_user_event UNIQUE(user_id, calendar_id, event_identifier)
);

-- Create indexes for better query performance
CREATE INDEX idx_family_members_user_id ON public.family_members(user_id);
CREATE INDEX idx_family_member_calendars_family_member_id ON public.family_member_calendars(family_member_id);
CREATE INDEX idx_shared_calendars_user_id ON public.shared_calendars(user_id);
CREATE INDEX idx_calendar_event_metadata_user_event ON public.calendar_event_metadata(user_id, calendar_id, event_identifier);
```

## 1.5 Add Daily Schedule Columns (Analytics Feature)

**Note**: If you're setting up a fresh database, the schedule columns below are already included in the `family_members` table definition above. Only run these ALTER TABLE statements if you're upgrading an existing database.

```sql
-- Add schedule columns to family_members table for daily time analytics
ALTER TABLE public.family_members
ADD COLUMN IF NOT EXISTS wake_time_hour INTEGER DEFAULT 7,
ADD COLUMN IF NOT EXISTS wake_time_minute INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS bed_time_hour INTEGER DEFAULT 22,
ADD COLUMN IF NOT EXISTS bed_time_minute INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS use_custom_schedule BOOLEAN DEFAULT FALSE;

-- Add comments for documentation
COMMENT ON COLUMN public.family_members.wake_time_hour IS 'Hour member wakes up (0-23), default 7am';
COMMENT ON COLUMN public.family_members.wake_time_minute IS 'Minute of wake time (0-59)';
COMMENT ON COLUMN public.family_members.bed_time_hour IS 'Hour member goes to bed (0-23), default 10pm';
COMMENT ON COLUMN public.family_members.bed_time_minute IS 'Minute of bed time (0-59)';
COMMENT ON COLUMN public.family_members.use_custom_schedule IS 'Flag to enable custom schedule times, defaults to false';
```

These columns enable the daily time analytics feature that calculates free vs busy time for family members based on their wake/bed times and calendar events.

## 2. Enable Row Level Security (RLS)

Add RLS policies so users can only access their own data:

```sql
-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_member_calendars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shared_calendars ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.calendar_event_metadata ENABLE ROW LEVEL SECURITY;

-- Profiles: Users can only read their own profile
CREATE POLICY "Users can read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can create family members" ON public.family_members
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own family members" ON public.family_members
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own family members" ON public.family_members
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own family members" ON public.family_members
  FOR DELETE USING (auth.uid() = user_id);

-- Family Member Calendars: users can only access calendars tied to their family_members; admins bypass via JWT claim `is_admin = true`
CREATE POLICY "Users can insert family member calendars" ON public.family_member_calendars
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.family_members
      WHERE family_members.id = family_member_calendars.family_member_id
      AND family_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update own family member calendars" ON public.family_member_calendars
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.family_members
      WHERE family_members.id = family_member_calendars.family_member_id
      AND family_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Users/admins can read family member calendars" ON public.family_member_calendars
  FOR SELECT USING (
    COALESCE((auth.jwt() ->> 'is_admin')::boolean, false)
    OR EXISTS (
      SELECT 1 FROM public.family_members
      WHERE family_members.id = family_member_calendars.family_member_id
      AND family_members.user_id = auth.uid()
    )
  );

CREATE POLICY "Users/admins can delete family member calendars" ON public.family_member_calendars
  FOR DELETE USING (
    COALESCE((auth.jwt() ->> 'is_admin')::boolean, false)
    OR EXISTS (
      SELECT 1 FROM public.family_members
      WHERE family_members.id = family_member_calendars.family_member_id
      AND family_members.user_id = auth.uid()
    )
  );

-- Shared Calendars: Users can only access their own
CREATE POLICY "Users can create shared calendars" ON public.shared_calendars
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can read own shared calendars" ON public.shared_calendars
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own shared calendars" ON public.shared_calendars
  FOR DELETE USING (auth.uid() = user_id);

-- Calendar Event Metadata: app-only fields keyed by iOS event id; allow owner or admin (JWT is_admin=true)
CREATE POLICY "Users can create event metadata" ON public.calendar_event_metadata
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users/admins can read event metadata" ON public.calendar_event_metadata
  FOR SELECT USING (
    COALESCE((auth.jwt() ->> 'is_admin')::boolean, false)
    OR auth.uid() = user_id
  );

CREATE POLICY "Users can update own event metadata" ON public.calendar_event_metadata
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own event metadata" ON public.calendar_event_metadata
  FOR DELETE USING (auth.uid() = user_id);
```

## 3. Set Up Auth Trigger (Create Profile on Sign Up)

This automatically creates a profile entry when a user signs up:

```sql
-- Create a trigger function to create a profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email)
  VALUES (NEW.id, NEW.email);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

## 4. Verify Setup

After running all the SQL above, verify that:

1. All tables exist under "Tables" in Supabase Dashboard
2. RLS is enabled on each table
3. You can see the policies listed under each table's RLS settings

## 5. Apply Migrations

The project includes migration files in the `supabase/migrations/` directory. These are automatically applied when deploying with the Supabase CLI.

### Using Supabase CLI (Recommended)

If you're using the Supabase CLI:

```bash
# Navigate to project directory
cd /path/to/FamCal

# Push migrations to your Supabase project
supabase db push

# Or, reset the database and reapply all migrations
supabase db reset
```

### Manual Migration Application

If you prefer to apply migrations manually via the Supabase dashboard:

1. Go to your Supabase Dashboard
2. Open the **SQL Editor**
3. For each migration file in `supabase/migrations/` (in chronological order by filename):
   - Open the migration file from the repository
   - Copy all SQL content
   - Paste into the SQL Editor in Supabase
   - Click **Run** to execute

**Important**: Always apply migrations in chronological order (by timestamp in filename).

**Current Migrations**:
- `20251213220000_add_member_schedule.sql` - Adds wake/bed time columns for daily analytics feature

## 6. Update the App

The app is now ready to use the Supabase database for family data. Family members and shared calendars will be stored per user, ensuring data isolation.
