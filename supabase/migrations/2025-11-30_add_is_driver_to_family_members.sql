-- Add is_driver column to family_members table
-- Safe to run multiple times; checks if column exists before adding

do $$
begin
  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'family_members' and column_name = 'is_driver'
  ) then
    alter table public.family_members add column is_driver boolean default false;
  end if;
end $$;
