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

// Optional secret header to guard the endpoint
const DELETE_ACCOUNT_FUNCTION_KEY = Deno.env.get(
  "DELETE_ACCOUNT_FUNCTION_KEY"
);

Deno.serve(async (req) => {
  try {
    if (DELETE_ACCOUNT_FUNCTION_KEY) {
      const headerKey = req.headers.get("x-delete-account-fn-key");
      if (headerKey !== DELETE_ACCOUNT_FUNCTION_KEY) {
        return json({ error: "unauthorized" }, 401);
      }
    }

    if (req.method !== "POST") {
      return json({ error: "method not allowed" }, 405);
    }

    const authHeader = req.headers.get("authorization") ??
      req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "missing auth" }, 401);
    }

    // User-scoped client for auth info
    const supabaseUser = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userErr } = await supabaseUser.auth
      .getUser();
    if (userErr || !userData?.user) {
      console.error("getUser error", userErr);
      return json({ error: "invalid user" }, 401);
    }

    const userId = userData.user.id;
    console.log(`Deleting account for user: ${userId}`);

    // Delete the user from auth.users using admin client
    const { error: deleteErr } = await supabaseAdmin.auth.admin.deleteUser(
      userId
    );

    if (deleteErr) {
      console.error("delete user error", deleteErr);
      return json({ error: deleteErr.message }, 400);
    }

    console.log(`Successfully deleted user: ${userId}`);
    return json({ status: "deleted", user_id: userId });
  } catch (error) {
    console.error("delete-account unexpected error", error);
    return json({ error: "internal error" }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
