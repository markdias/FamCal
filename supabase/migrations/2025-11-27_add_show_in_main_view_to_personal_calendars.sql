-- Add per-surface visibility flags for personal_calendars.
-- Defaults: month/day ON, next/spotlight/upcoming OFF.

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'personal_calendars' and column_name = 'show_in_next'
  ) then
    alter table public.personal_calendars add column show_in_next boolean not null default false;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'personal_calendars' and column_name = 'show_in_spotlight'
  ) then
    alter table public.personal_calendars add column show_in_spotlight boolean not null default false;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'personal_calendars' and column_name = 'show_in_upcoming'
  ) then
    alter table public.personal_calendars add column show_in_upcoming boolean not null default false;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'personal_calendars' and column_name = 'show_in_month'
  ) then
    alter table public.personal_calendars add column show_in_month boolean not null default true;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'personal_calendars' and column_name = 'show_in_day'
  ) then
    alter table public.personal_calendars add column show_in_day boolean not null default true;
  end if;
end $$;

-- Backfill existing rows to defaults (idempotent).
update public.personal_calendars
set
  show_in_next = coalesce(show_in_next, false),
  show_in_spotlight = coalesce(show_in_spotlight, false),
  show_in_upcoming = coalesce(show_in_upcoming, false),
  show_in_month = coalesce(show_in_month, true),
  show_in_day = coalesce(show_in_day, true);
