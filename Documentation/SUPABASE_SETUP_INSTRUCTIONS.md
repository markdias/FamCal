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

## 5. Update the App

The app is now ready to use the Supabase database for family data. Family members and shared calendars will be stored per user, ensuring data isolation.
