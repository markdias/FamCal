-- Add RLS policy for families table to allow owners to create and manage families
-- Safe to run multiple times; guards avoid duplicate constraints/policies.

-- Helper function to check if user is a linked member of a family (with security definer to avoid RLS recursion)
create or replace function public.is_linked_family_member(family_id uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(
    select 1
    from public.family_members fm
    where fm.family_id = family_id
      and fm.linked_user_id = auth.uid()
  );
$$;

-- Enable RLS on families table if not already enabled
alter table public.families enable row level security;

-- Policy 1: Owners can view and manage their own families
drop policy if exists "Users can view families they own" on public.families;
create policy "Users can view families they own"
  on public.families
  for select using (owner_user_id = auth.uid());

-- Policy 2: Family members can view families they're part of
drop policy if exists "Family members can view their families" on public.families;
create policy "Family members can view their families"
  on public.families
  for select using (is_linked_family_member(public.families.id));

-- Policy 3: Users can create families (insert with owner_user_id = auth.uid())
drop policy if exists "Users can create families" on public.families;
create policy "Users can create families"
  on public.families
  for insert with check (owner_user_id = auth.uid());

-- Policy 4: Owners can update their own families
drop policy if exists "Owners can update families" on public.families;
create policy "Owners can update families"
  on public.families
  for update using (owner_user_id = auth.uid())
  with check (owner_user_id = auth.uid());

-- Policy 5: Owners can delete their own families (optional - add if needed)
drop policy if exists "Owners can delete families" on public.families;
create policy "Owners can delete families"
  on public.families
  for delete using (owner_user_id = auth.uid());
