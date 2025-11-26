# Family Invites, Linking, and Shared Data Access (Supabase)

Use this guide to add family invitations and shared data access to Supabase. It assumes one family per owner, members can view pending invites, and the app already uses the `famcal://` URL scheme.

## 1) Schema Changes (run in Supabase SQL editor)

```sql
-- Families anchor (one per owner)
create table if not exists public.families (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references auth.users(id) unique,
  created_at timestamptz default now()
);
alter table public.families enable row level security;

-- Profiles: add family_id
alter table public.profiles add column if not exists family_id uuid references public.families(id);
insert into public.families (owner_user_id)
select id from public.profiles p where p.family_id is null
on conflict do nothing;
update public.profiles p
  set family_id = f.id
  from public.families f
  where f.owner_user_id = p.id and p.family_id is null;

-- Family members: attach to family, link to auth user, add role
alter table public.family_members add column if not exists family_id uuid references public.families(id);
alter table public.family_members add column if not exists linked_user_id uuid references auth.users(id);
alter table public.family_members add column if not exists role text check (role in ('owner','member')) default 'member';
update public.family_members fm
  set family_id = p.family_id,
      role = case when fm.user_id = p.id then 'owner' else fm.role end
  from public.profiles p
  where fm.family_id is null and fm.user_id = p.id;
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'unique_family_member_per_family'
      and conrelid = 'public.family_members'::regclass
  ) then
    alter table public.family_members
      add constraint unique_family_member_per_family unique (family_id, name);
  end if;
end $$;

-- Calendars per member: add family_id for RLS joins
alter table public.family_member_calendars add column if not exists family_id uuid references public.families(id);
update public.family_member_calendars fmc
  set family_id = fm.family_id
  from public.family_members fm
  where fmc.family_id is null and fmc.family_member_id = fm.id;

-- Shared tables: add family_id and backfill from profiles
alter table public.shared_calendars add column if not exists family_id uuid references public.families(id);
update public.shared_calendars sc
  set family_id = p.family_id
  from public.profiles p
  where sc.family_id is null and sc.user_id = p.id;

alter table public.app_settings add column if not exists family_id uuid references public.families(id);
update public.app_settings s
  set family_id = p.family_id
  from public.profiles p
  where s.family_id is null and s.user_id = p.id;
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

alter table public.calendar_event_metadata add column if not exists family_id uuid references public.families(id);
update public.calendar_event_metadata cem
  set family_id = p.family_id
  from public.profiles p
  where cem.family_id is null and cem.user_id = p.id;

alter table public.saved_addresses add column if not exists family_id uuid references public.families(id);
update public.saved_addresses sa
  set family_id = p.family_id
  from public.profiles p
  where sa.family_id is null and sa.user_id = p.id;

-- Invitations table
create table if not exists public.invitations (
  id uuid primary key default gen_random_uuid(),
  family_id uuid not null references public.families(id) on delete cascade,
  family_member_id uuid references public.family_members(id) on delete set null,
  inviter_user_id uuid not null references auth.users(id),
  invitee_email text not null,
  token text not null unique,
  status text not null default 'pending' check (status in ('pending','accepted','expired','revoked')),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_user_id uuid references auth.users(id),
  accepted_at timestamptz,
  created_at timestamptz default now()
);
alter table public.invitations enable row level security;
```

## 2) RLS Policies (family-scoped access)

```sql
/* Helper functions to avoid recursive RLS lookups */
create or replace function public.is_family_owner(family uuid)
returns boolean language sql stable security definer set search_path=public as $$
  select exists(select 1 from public.families f where f.id = family and f.owner_user_id = auth.uid());
$$;

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

/* families */
drop policy if exists "family members can view their family" on public.families;
create policy "family members can view their family"
  on public.families for select using (
    is_family_member(families.id)
  );

/* profiles (self-read/update; family_id visible through joins) */
drop policy if exists "Users can read own profile" on public.profiles;
create policy "user reads own profile" on public.profiles
  for select using (auth.uid() = id);
drop policy if exists "Users can update own profile" on public.profiles;
create policy "user updates own profile" on public.profiles
  for update using (auth.uid() = id) with check (auth.uid() = id);

/* family_members */
drop policy if exists "Users can read own family members" on public.family_members;
drop policy if exists "family can read members" on public.family_members;
create policy "family can read members"
  on public.family_members for select using (
    is_family_member(family_members.family_id)
  );
create policy "owner manages members"
  on public.family_members for all using (
    is_family_owner(family_members.family_id)
  ) with check (
    is_family_owner(family_members.family_id)
  );

/* family_member_calendars */
drop policy if exists "family manages member calendars" on public.family_member_calendars;
create policy "family manages member calendars"
  on public.family_member_calendars for all using (
    is_family_member(family_member_calendars.family_id)
  ) with check (
    is_family_member(family_member_calendars.family_id)
  );

-- shared_calendars, app_settings, calendar_event_metadata, saved_addresses
do $$ declare t text; begin
  for t in select unnest(array['shared_calendars','app_settings','calendar_event_metadata','saved_addresses'])
  loop
    execute format('drop policy if exists "family manages %1$s" on public.%1$s;', t);
    execute format($fmt$
      create policy "family manages %1$s"
      on public.%1$s for all using (
        is_family_member(%1$s.family_id)
      ) with check (
        is_family_member(%1$s.family_id)
      );
    $fmt$, t);
  end loop;
end $$;

/* invitations (members can view, owner mutates) */
drop policy if exists "family reads invitations" on public.invitations;
create policy "family reads invitations"
  on public.invitations for select using (
    is_family_member(invitations.family_id)
  );
drop policy if exists "owner manages invitations" on public.invitations;
create policy "owner manages invitations"
  on public.invitations for all using (
    is_family_owner(invitations.family_id)
  ) with check (
    is_family_owner(invitations.family_id)
  );
```

## 3) RPCs (server-side)

```sql
-- Create invitation and token (owner only)
create or replace function public.create_family_invitation(
  family_member uuid,
  invitee_email text
) returns public.invitations language plpgsql security definer as $$
declare v_family uuid; v_token text;
declare inv public.invitations;
begin
  select fm.family_id into v_family
    from public.family_members fm
    where fm.id = family_member;
  if not exists (select 1 from public.families f where f.id = v_family and f.owner_user_id = auth.uid()) then
    raise exception 'not allowed';
  end if;
  v_token := encode(gen_random_bytes(24), 'hex');
  insert into public.invitations (family_id, family_member_id, inviter_user_id, invitee_email, token)
  values (v_family, family_member, auth.uid(), invitee_email, v_token)
  returning * into inv;
  return inv;
end; $$;

-- Accept invitation (called after deep link auth)
create or replace function public.accept_family_invitation(invite_token text)
returns public.invitations language plpgsql security definer as $$
declare inv public.invitations;
begin
  select * into inv from public.invitations
    where token = invite_token and status = 'pending' and expires_at > now();
  if not found then raise exception 'invalid or expired'; end if;

  update public.profiles set family_id = inv.family_id where id = auth.uid();
  update public.family_members set linked_user_id = auth.uid()
    where id = inv.family_member_id;

  update public.invitations set status = 'accepted', accepted_user_id = auth.uid(), accepted_at = now()
    where id = inv.id
    returning * into inv;
  return inv;
end; $$;
```

## 4) Email + Deep Link

- **Configure Supabase Auth redirect**  
  - In Supabase Dashboard → Authentication → URL Configuration, add `famcal://invite` as an allowed redirect.  
  - In your email template, include a CTA link to `{{ .RedirectTo }}?token={{ .Token }}` (Supabase will replace `RedirectTo` with what you pass in the API call).

- **Edge Function to send invite email (service role)**  
  - CLI scaffold: `supabase functions new invite-email` (creates `supabase/functions/invite-email/index.ts`).  
  - Environment: set secrets (service role key, Supabase URL) with `supabase secrets set SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=...`.  
  - Logic (TypeScript example):
    ```ts
    import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

    const url = Deno.env.get("SUPABASE_URL")!;
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(url, serviceKey);

    Deno.serve(async (req) => {
      try {
        const { family_member_id, invitee_email } = await req.json();
        if (!family_member_id || !invitee_email) {
          return new Response(JSON.stringify({ error: "missing params" }), { status: 400 });
        }

        // 1) Create invitation/token via RPC
        const { data: inv, error: invErr } = await supabase.rpc("create_family_invitation", {
          family_member: family_member_id,
          invitee_email,
        });
        if (invErr) throw invErr;

        // 2) Send Supabase invite email (built-in template)
        const { error: emailErr } = await supabase.auth.admin.inviteUserByEmail(invitee_email, {
          redirectTo: "famcal://invite",
        });
        if (emailErr) throw emailErr;

        return new Response(JSON.stringify({ invitation_id: inv.id, status: "sent" }), { status: 200 });
      } catch (e) {
        console.error("invite-email error", e);
        return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
      }
    });
    ```
  - Local test: `supabase functions serve invite-email --no-verify-jwt` then `curl -X POST -H "Content-Type: application/json" -d '{"family_member_id":"<uuid>","invitee_email":"test@example.com"}' http://localhost:54321/functions/v1/invite-email`.  
  - Deploy: `supabase functions deploy invite-email --no-verify-jwt` (or enforce JWT and check a secret header).  
  - Security: Prefer checking a secret header or requiring a JWT with a specific role claim so only your app/backend can call it.

- **App-side deep link handling**  
  - You already have `famcal://` configured. Ensure the handler recognizes the `invite` host and `token` param. Example addition:
    ```swift
    if components.scheme == "famcal", components.host == "invite",
       let token = components.queryItems?.first(where: { $0.name == "token" })?.value {
        Task { @MainActor in
            do {
                try await SupabaseManager.shared.acceptInvitation(token: token)
                await SupabaseDataManager.shared.fetchUserData()
            } catch {
                print("❌ Invitation accept failed: \(error)")
            }
        }
    }
    ```
  - `acceptInvitation` should call the `accept_family_invitation` RPC; require an authenticated session first (the Supabase invite email flow will create/confirm the user and return a session via the email link).

- **Redirect flow checklist**  
  1. Owner taps “Invite” → app calls Edge Function → function creates `invitations` row + sends Supabase Auth invite with `redirectTo: famcal://invite`.  
  2. Invitee opens email and taps link → Supabase GoTrue handles signup/confirmation and opens `famcal://invite?token=...` in the app.  
  3. App receives the deep link, ensures user is logged in (GoTrue attaches session to the link), then calls `accept_family_invitation(token)` to link the account to the family and set `linked_user_id`.  
  4. App refreshes data (families, members, calendars, settings, addresses) filtered by `family_id`.

## 5) Rollout Checklist

- [ ] Run the schema SQL above (tables + columns + backfills).  
- [ ] Apply RLS policies.  
- [ ] Deploy RPCs.  
- [ ] Update Supabase Auth email template redirect to `famcal://invite`.  
- [ ] Add Edge Function (service role) to create invite + send email.  
- [ ] Update app: settings UI for invites, SupabaseManager calls for create/accept, deep-link handler for `famcal://invite`.  
- [ ] Test: owner sends invite → email → app opens via deep link → accept → shared data visible to both.
