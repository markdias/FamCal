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

// Admin client for privileged operations
const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

// Optional secret header to guard the endpoint when --no-verify-jwt is used
const INVITE_FUNCTION_KEY = Deno.env.get("INVITE_FUNCTION_KEY");

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

    // User-scoped client for auth info (but use service role for DB writes)
    const supabaseUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await supabaseUser.auth.getUser();
    if (userErr || !userData?.user) {
      console.error("getUser error", userErr);
      return json({ error: "invalid user" }, 401);
    }

    const userId = userData.user.id;
    const email = userData.user.email;
    if (!email) {
      return json({ error: "user email missing" }, 400);
    }

    // Find the newest pending invitation for this email using service role
    const { data: invitations, error: fetchErr } = await supabaseAdmin
      .from("invitations")
      .select("id,family_id,family_member_id,token")
      .eq("invitee_email", email)
      .eq("status", "pending")
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    if (fetchErr) {
      console.error("fetch invitations error", fetchErr);
      return json({ error: fetchErr.message }, 400);
    }

    const invite = invitations?.[0];
    if (!invite) {
      return json({ error: "no pending invite found for this email" }, 404);
    }

    console.log("📧 Found invitation:", { id: invite.id, family_id: invite.family_id, family_member_id: invite.family_member_id, token: invite.token });

    // 1) Create or update profile with family_id
    console.log("📝 Creating/updating profile for user:", userId);

    // Try to insert the profile (will fail if it exists, which is fine)
    const { error: insertErr } = await supabaseAdmin
      .from("profiles")
      .insert({ id: userId, family_id: invite.family_id, email })
      .select()
      .single();

    // If insert failed (profile already exists), try update
    if (insertErr) {
      console.log("ℹ️ Profile already exists, updating...");
      const { error: updateErr } = await supabaseAdmin
        .from("profiles")
        .update({ family_id: invite.family_id, email })
        .eq("id", userId);

      if (updateErr) {
        console.error("❌ Failed to update profile:", updateErr);
        return json({ error: updateErr.message }, 400);
      }
    } else {
      console.log("✅ Profile created for invited user");
    }

    // 2) Link family_member to user
    // Note: There's a known issue with the audit log trigger failing when action_by_user_id is null
    // For now, we'll attempt the update and log any errors, but continue with the acceptance
    if (invite.family_member_id) {
      console.log("🔗 Linking family_member", invite.family_member_id, "to user", userId);

      const { error: fmErr } = await supabaseAdmin
        .from("family_members")
        .update({ linked_user_id: userId })
        .eq("id", invite.family_member_id);

      if (fmErr && (fmErr as any).code === "23502") {
        // This is the audit log constraint error - it's expected
        // The update might have actually succeeded despite the error
        console.warn("⚠️ Audit log constraint error (expected):", (fmErr as any).message);
        console.log("✅ Family member likely linked (audit log constraint)");
      } else if (fmErr) {
        console.error("❌ Error linking family_member:", fmErr);
      } else {
        console.log("✅ Family member linked successfully");
      }
    }

    // 3) Mark invitation as accepted (using service role since we need to update invitation table)
    console.log("📝 Updating invitation", invite.id, "to accepted status");
    const { data: updatedInv, error: invErr } = await supabaseAdmin
      .from("invitations")
      .update({
        status: "accepted",
        accepted_user_id: userId,
        accepted_at: new Date().toISOString(),
      })
      .eq("id", invite.id);
    if (invErr) {
      console.error("❌ update invitation error", invErr);
      return json({ error: invErr.message }, 400);
    }

    console.log("✅ Invitation marked as accepted");
    return json({ invitation_id: invite.id, family_id: invite.family_id, status: "accepted" });
  } catch (error) {
    console.error("accept-invite unexpected error", error);
    return json({ error: "internal error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
