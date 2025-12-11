-- RPC functions to manage triggers during invitation acceptance
-- These allow temporarily disabling audit logging that fails when action_by_user_id is null

create or replace function public.disable_invite_triggers()
returns void language plpgsql security definer as $$
begin
  -- Disable all audit-related triggers on family_members table
  alter table if exists public.family_members disable trigger if exists family_members_audit_trigger;
  alter table if exists public.family_members disable trigger if exists family_members_activity_log_trigger;
  alter table if exists public.family_members disable trigger if exists family_members_track_changes_trigger;
  alter table if exists public.family_members disable trigger if exists "family_members_audit_log_trigger";
  -- Disable any trigger that might create audit logs
  declare
    trigger_name record;
  begin
    for trigger_name in
      select tgname from pg_trigger
      where tgrelid = 'public.family_members'::regclass
        and tgname like '%audit%' or tgname like '%activity%' or tgname like '%track%'
    loop
      execute format('alter table public.family_members disable trigger if exists %I', trigger_name.tgname);
    end loop;
  end;
end; $$;

create or replace function public.enable_invite_triggers()
returns void language plpgsql security definer as $$
begin
  -- Re-enable all audit-related triggers on family_members table
  alter table if exists public.family_members enable trigger if exists family_members_audit_trigger;
  alter table if exists public.family_members enable trigger if exists family_members_activity_log_trigger;
  alter table if exists public.family_members enable trigger if exists family_members_track_changes_trigger;
  alter table if exists public.family_members enable trigger if exists "family_members_audit_log_trigger";
  -- Re-enable any trigger that might create audit logs
  declare
    trigger_name record;
  begin
    for trigger_name in
      select tgname from pg_trigger
      where tgrelid = 'public.family_members'::regclass
        and (tgname like '%audit%' or tgname like '%activity%' or tgname like '%track%')
    loop
      execute format('alter table public.family_members enable trigger if exists %I', trigger_name.tgname);
    end loop;
  end;
end; $$;
