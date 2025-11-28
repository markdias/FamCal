-- Create personal_calendars table
create table public.personal_calendars (
  id uuid default gen_random_uuid() primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  family_id uuid not null references public.families(id) on delete cascade,
  calendar_id text not null,
  calendar_name text not null,
  calendar_color_hex text not null default '#007AFF',
  show_in_next boolean not null default false,
  show_in_spotlight boolean not null default false,
  show_in_upcoming boolean not null default false,
  show_in_month boolean not null default true,
  show_in_day boolean not null default true,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null,
  updated_at timestamp with time zone default timezone('utc'::text, now()) not null,

  -- Ensure unique calendar per user (can't add same calendar twice)
  unique(user_id, calendar_id)
);

-- Enable RLS
alter table public.personal_calendars enable row level security;

-- RLS Policy: Users can only see their own personal calendars
create policy "Users can view their own personal calendars"
  on public.personal_calendars for select
  using (auth.uid() = user_id);

-- RLS Policy: Users can only insert their own personal calendars
create policy "Users can insert their own personal calendars"
  on public.personal_calendars for insert
  with check (auth.uid() = user_id);

-- RLS Policy: Users can only update their own personal calendars
create policy "Users can update their own personal calendars"
  on public.personal_calendars for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- RLS Policy: Users can only delete their own personal calendars
create policy "Users can delete their own personal calendars"
  on public.personal_calendars for delete
  using (auth.uid() = user_id);

-- Create index for faster queries by user_id
create index personal_calendars_user_id_idx on public.personal_calendars(user_id);

-- Create index for faster queries by family_id
create index personal_calendars_family_id_idx on public.personal_calendars(family_id);
