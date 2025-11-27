import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Supabase CLI disallows secrets prefixed with SUPABASE_. Support alternative names.
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

// Admin client for invite emails
const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

// Simple secret header guard to avoid public abuse when deployed with --no-verify-jwt
const INVITE_FUNCTION_KEY = Deno.env.get("INVITE_FUNCTION_KEY");

type InviteRequest = {
  family_member_id: string;
  invitee_email: string;
};

Deno.serve(async (req) => {
  try {
    if (INVITE_FUNCTION_KEY) {
      const headerKey = req.headers.get("x-invite-fn-key");
      if (headerKey !== INVITE_FUNCTION_KEY) {
        return json({ error: "unauthorized" }, 401);
      }
    }

    if (req.method !== "POST") {
      return json({ error: "method not allowed" }, 405);
    }

    const authHeader = req.headers.get("authorization") ?? req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "missing auth" }, 401);
    }

    // User-scoped client so RPC auth.uid() is the caller
    const supabaseUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { family_member_id, invitee_email } = (await req.json()) as Partial<InviteRequest>;
    if (!family_member_id || !invitee_email) {
      return json({ error: "family_member_id and invitee_email are required" }, 400);
    }

    // 1) Create invitation and token via RPC (uses service role)
    const { data: inv, error: invErr } = await supabaseUser.rpc("create_family_invitation", {
      family_member: family_member_id,
      invitee_email,
    });
    if (invErr) {
      console.error("create_family_invitation error", invErr);
      return json({ error: invErr.message }, 400);
    }

    if (!inv?.token) {
      console.error("create_family_invitation returned no token", inv);
      return json({ error: "missing invite token" }, 500);
    }

    // 2) Send Supabase invite email with built-in template
    //    Use a distinct query param name to avoid collisions with Supabase's own `token` param
    const redirect = `famcal://invite?invite_token=${inv.token}`;

    const { error: emailErr } = await supabaseAdmin.auth.admin.inviteUserByEmail(invitee_email, {
      // Include the invite token so the app can accept the invitation after auth
      redirectTo: redirect,
    });
    if (emailErr) {
      console.error("inviteUserByEmail error", emailErr);
      return json({ error: emailErr.message }, 400);
    }

    return json({ invitation_id: inv?.id, status: "sent" });
  } catch (error) {
    console.error("invite-email unexpected error", error);
    return json({ error: "internal error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
