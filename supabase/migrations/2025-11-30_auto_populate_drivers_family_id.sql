-- Auto-populate family_id for new drivers
-- This ensures drivers always have a family_id set, either from:
-- 1. The linked family member (if family_member_id is provided), or
-- 2. The user's profile (from profiles.family_id)

-- Create or replace the function that populates family_id on insert
create or replace function public.set_driver_family_id()
returns trigger as $$
begin
  -- If family_member_id is provided, get family_id from that family member
  if new.family_member_id is not null then
    select fm.family_id into new.family_id
    from public.family_members fm
    where fm.id = new.family_member_id;
  -- Otherwise, get family_id from the user's profile
  else
    select p.family_id into new.family_id
    from public.profiles p
    where p.id = new.user_id;
  end if;

  return new;
end;
$$ language plpgsql security definer set search_path = public;

-- Drop existing trigger if it exists
drop trigger if exists set_driver_family_id_trigger on public.drivers;

-- Create trigger to run before insert
create trigger set_driver_family_id_trigger
before insert on public.drivers
for each row
execute function public.set_driver_family_id();
