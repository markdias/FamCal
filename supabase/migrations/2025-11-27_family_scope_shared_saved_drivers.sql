-- Backfill and enforce family scoping for shared data (calendars, saved places, drivers, Pro settings).
-- Safe to run multiple times; guards avoid duplicate constraints/policies.

-- Helper: ensure helper functions exist (use create or replace to avoid dropping dependencies)
create or replace function public.is_family_member(family uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1
    from public.families f
    left join public.family_members fm on fm.family_id = f.id
    where f.id = family
      and (f.owner_user_id = auth.uid() or fm.linked_user_id = auth.uid())
  );
$$;

create or replace function public.is_family_owner(family uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.families f where f.id = family and f.owner_user_id = auth.uid());
$$;

-- shared_calendars: add family_id and backfill from profiles.user_id
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'shared_calendars' and column_name = 'family_id'
  ) then
    alter table public.shared_calendars add column family_id uuid references public.families(id);
  end if;
end $$;
update public.shared_calendars sc
set family_id = p.family_id
from public.profiles p
where sc.family_id is null
  and sc.user_id = p.id;
-- RLS
drop policy if exists "family manages shared_calendars" on public.shared_calendars;
create policy "family manages shared_calendars"
  on public.shared_calendars
  for all using (is_family_member(shared_calendars.family_id))
  with check (is_family_member(shared_calendars.family_id));

-- saved_addresses: add family_id and backfill from profiles.user_id
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'saved_addresses' and column_name = 'family_id'
  ) then
    alter table public.saved_addresses add column family_id uuid references public.families(id);
  end if;
end $$;
update public.saved_addresses sa
set family_id = p.family_id
from public.profiles p
where sa.family_id is null
  and sa.user_id = p.id;
drop policy if exists "family manages saved_addresses" on public.saved_addresses;
create policy "family manages saved_addresses"
  on public.saved_addresses
  for all using (is_family_member(saved_addresses.family_id))
  with check (is_family_member(saved_addresses.family_id));

-- drivers: add family_id and backfill via family_members.family_id (if driver.family_member_id exists) or profiles
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'drivers' and column_name = 'family_id'
  ) then
    alter table public.drivers add column family_id uuid references public.families(id);
  end if;
end $$;
update public.drivers d
set family_id = fm.family_id
from public.family_members fm
where d.family_id is null
  and d.family_member_id = fm.id;
update public.drivers d
set family_id = p.family_id
from public.profiles p
where d.family_id is null
  and d.user_id = p.id;
drop policy if exists "family manages drivers" on public.drivers;
create policy "family manages drivers"
  on public.drivers
  for all using (is_family_member(drivers.family_id))
  with check (is_family_member(drivers.family_id));

-- app_settings (Pro flag): ensure family_id and one-per-family constraint
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'app_settings' and column_name = 'family_id'
  ) then
    alter table public.app_settings add column family_id uuid references public.families(id);
  end if;
end $$;
update public.app_settings s
set family_id = p.family_id
from public.profiles p
where s.family_id is null
  and s.user_id = p.id;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'unique_settings_per_family'
      and conrelid = 'public.app_settings'::regclass
  ) then
    alter table public.app_settings
      add constraint unique_settings_per_family unique (family_id);
  end if;
end $$;
drop policy if exists "family manages app_settings" on public.app_settings;
create policy "family manages app_settings"
  on public.app_settings
  for all using (is_family_member(app_settings.family_id))
  with check (is_family_member(app_settings.family_id));

-- Optional: enable RLS if not already
alter table public.shared_calendars enable row level security;
alter table public.saved_addresses enable row level security;
alter table public.drivers enable row level security;
alter table public.app_settings enable row level security;
