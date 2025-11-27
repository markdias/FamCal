import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Support alternative env prefixes
const supabaseUrl =
  Deno.env.get("SUPABASE_URL") ??
  Deno.env.get("SB_URL") ??
  Deno.env.get("PROJECT_URL");
const serviceRoleKey =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ??
  Deno.env.get("SB_SERVICE_ROLE_KEY") ??
  Deno.env.get("SERVICE_ROLE_KEY");
const anonKey =
  Deno.env.get("SUPABASE_ANON_KEY") ??
  Deno.env.get("SB_ANON_KEY") ??
  Deno.env.get("ANON_KEY");

if (!supabaseUrl || !serviceRoleKey || !anonKey) {
  throw new Error("Missing Supabase URL, service role key, or anon key in env");
}

const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
const INVITE_FUNCTION_KEY = Deno.env.get("INVITE_FUNCTION_KEY");

type EmailRow = {
  family_member_id: string;
  email: string | null;
};

Deno.serve(async (req) => {
  try {
    // If a function key is set, prefer to check it, but don't block when JWT is valid.
    if (INVITE_FUNCTION_KEY) {
      const headerKey = req.headers.get("x-invite-fn-key");
      if (headerKey !== INVITE_FUNCTION_KEY) {
        console.warn("member-emails: missing/invalid x-invite-fn-key, proceeding with JWT only");
      }
    }

    if (req.method !== "GET") {
      return json({ error: "method not allowed" }, 405);
    }

    const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "missing auth" }, 401);
    }

    // User-scoped client to discover family_id; queries are RLS-safe here
    const supabaseUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await supabaseUser.auth.getUser();
    if (userErr || !userData?.user) {
      console.error("getUser error", userErr);
      return json({ error: "invalid user" }, 401);
    }

    const userId = userData.user.id;

    // Resolve family_id: try profile → linked family_members → owned family
    let familyId: string | null = null;

    const { data: profile, error: profileErr } = await supabaseUser
      .from("profiles")
      .select("family_id")
      .eq("id", userId)
      .single();
    if (!profileErr && profile?.family_id) {
      familyId = profile.family_id as string;
    }

    if (!familyId) {
      const { data: fm, error: fmErr } = await supabaseUser
        .from("family_members")
        .select("family_id")
        .eq("linked_user_id", userId)
        .maybeSingle();
      if (!fmErr && fm?.family_id) {
        familyId = fm.family_id as string;
      }
    }

    if (!familyId) {
      const { data: fam, error: famErr } = await supabaseUser
        .from("families")
        .select("id")
        .eq("owner_user_id", userId)
        .maybeSingle();
      if (!famErr && fam?.id) {
        familyId = fam.id as string;
      }
    }

    if (!familyId) {
      console.error("family_id resolution failed", { profileErr, profile, userId });
      return json({ emails: [] });
    }

    // Fetch linked members in the family
    const { data: members, error: memberErr } = await supabaseAdmin
      .from("family_members")
      .select("id, linked_user_id")
      .eq("family_id", familyId)
      .not("linked_user_id", "is", null);

    if (memberErr) {
      console.error("member fetch error", memberErr);
      return json({ error: memberErr.message }, 400);
    }

    const linkedIds = (members ?? []).map((m: any) => m.linked_user_id).filter(Boolean);
    const result: EmailRow[] = [];

    // Fetch emails from auth.users via admin API (service role)
    for (const m of members ?? []) {
      const linkedId = m.linked_user_id as string | undefined;
      if (!linkedId) continue;
      const { data: user, error: userErr } = await supabaseAdmin.auth.admin.getUserById(linkedId);
      if (userErr) {
        console.error("auth user fetch error", userErr);
        result.push({ family_member_id: m.id as string, email: null });
        continue;
      }
      result.push({ family_member_id: m.id as string, email: user?.user?.email ?? null });
    }

    return json({ emails: result });
  } catch (error) {
    console.error("member-emails unexpected error", error);
    return json({ error: "internal error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
