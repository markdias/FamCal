import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.0"

interface FeedbackRequest {
  type: string
  message: string
  email?: string
}

interface FeedbackResponse {
  success: boolean
  message?: string
  error?: string
  data?: unknown
}

serve(async (req: Request): Promise<Response> => {
  // Only allow POST requests
  if (req.method !== "POST") {
    return new Response(
      JSON.stringify({ success: false, error: "Method not allowed" }),
      { status: 405, headers: { "Content-Type": "application/json" } }
    )
  }

  try {
    // Parse request body
    const body: FeedbackRequest = await req.json()

    // Validate required fields
    if (!body.type || !body.message) {
      return new Response(
        JSON.stringify({
          success: false,
          error: "Missing required fields: type and message",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    // Validate feedback type
    const validTypes = ["General Feedback", "Report a Bug", "Feature Request"]
    if (!validTypes.includes(body.type)) {
      return new Response(
        JSON.stringify({
          success: false,
          error: `Invalid feedback type. Must be one of: ${validTypes.join(", ")}`,
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    // Create Supabase client
    const supabaseUrl = Deno.env.get("SUPABASE_URL")
    const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")

    if (!supabaseUrl || !supabaseServiceRoleKey) {
      console.error("Missing Supabase environment variables")
      return new Response(
        JSON.stringify({
          success: false,
          error: "Server configuration error",
        }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      )
    }

    const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)

    // Get user ID from JWT token (if authenticated)
    let userId: string | null = null
    const authHeader = req.headers.get("Authorization")
    if (authHeader?.startsWith("Bearer ")) {
      try {
        const token = authHeader.substring(7)
        const { data } = await supabase.auth.getUser(token)
        if (data?.user?.id) {
          userId = data.user.id
        }
      } catch (error) {
        console.log("Could not extract user ID from token:", error)
        // Continue without user ID - feedback will be submitted anonymously
      }
    }

    // Insert feedback into database
    const { data, error } = await supabase
      .from("feedback")
      .insert([
        {
          user_id: userId,
          feedback_type: body.type,
          message: body.message.trim(),
          email: body.email?.trim() || null,
          created_at: new Date().toISOString(),
        },
      ])
      .select()

    if (error) {
      console.error("Database error:", error)
      return new Response(
        JSON.stringify({
          success: false,
          error: "Failed to save feedback",
        }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    console.log("Feedback submitted successfully:", {
      type: body.type,
      userId: userId || "anonymous",
      timestamp: new Date().toISOString(),
    })

    return new Response(
      JSON.stringify({
        success: true,
        message: "Thank you for your feedback!",
        data: data,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    console.error("Unexpected error:", error)
    return new Response(
      JSON.stringify({
        success: false,
        error: "An unexpected error occurred",
      }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    )
  }
})
