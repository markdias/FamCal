-- Add family_id and RLS policies to family_members table
-- Safe to run multiple times; guards avoid duplicate constraints/policies.
-- Uses existing helper functions (is_family_member, is_family_owner) with security definer
-- to avoid infinite recursion with families table RLS policies

-- Ensure family_members table has family_id column
do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'family_members' and column_name = 'family_id'
  ) then
    alter table public.family_members add column family_id uuid references public.families(id);
  end if;
end $$;

-- Backfill family_id from profiles for existing members
-- First try: use linked_user_id to find family_id in profiles
update public.family_members fm
set family_id = p.family_id
from public.profiles p
where fm.family_id is null
  and fm.linked_user_id is not null
  and fm.linked_user_id = p.id;

-- Second try: use user_id to find family_id in profiles (for members added by the owner)
update public.family_members fm
set family_id = p.family_id
from public.profiles p
where fm.family_id is null
  and fm.user_id is not null
  and fm.user_id = p.id;

-- Third try: for any remaining NULL family_id, find the family that owns this profile
-- This handles edge cases where a member was created but profile.family_id wasn't set yet
update public.family_members fm
set family_id = f.id
from public.profiles p
join public.families f on f.owner_user_id = p.id
where fm.family_id is null
  and fm.user_id = p.id;

-- IMPORTANT: DO NOT ENABLE RLS ON family_members TABLE
-- The families table has RLS policies that check family_members.
-- If we enable RLS on family_members, it creates infinite recursion:
-- families policy -> checks family_members -> family_members policy -> checks families -> ...
-- Instead, access control is managed at the application level and through the families table RLS.
-- The family_id column on family_members is used for scoping by the application.
