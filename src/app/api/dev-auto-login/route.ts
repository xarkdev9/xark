// XARK OS v2.0 — DEV AUTO-LOGIN ENDPOINT
// POST /api/dev-auto-login — passwordless dev login for URL name param flow.
// Generates a JWT for a test user without password verification.
// Gate: Returns 404 if DEV_MODE !== 'true'. NEVER enable in production.
// Use /api/dev-auth for full username+password testing.

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(request: NextRequest) {
  // Gate: dev mode only
  if (process.env.DEV_MODE !== "true") {
    return NextResponse.json({ error: "not found" }, { status: 404 });
  }

  let body: { username?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "invalid request body" },
      { status: 400 }
    );
  }

  const { username } = body;
  if (!username) {
    return NextResponse.json(
      { error: "username required" },
      { status: 400 }
    );
  }

  // Look up user by display_name
  const { data: user, error: userError } = await supabaseAdmin
    .from("users")
    .select("id, display_name")
    .eq("display_name", username)
    .single();

  if (userError || !user) {
    return NextResponse.json(
      { error: "user not found" },
      { status: 404 }
    );
  }

  // Generate JWT via dev_login RPC — need the password.
  // Instead, we'll use a simple approach: call a custom RPC that generates
  // a JWT for any user without password (dev mode only).
  // For now, use the Supabase service role to sign a token.
  // The JWT must have the same structure as dev_login output.

  // Since we can't easily sign JWTs from Next.js without the JWT secret,
  // and the secret lives in Postgres, we'll call a helper function.
  const { data, error } = await supabaseAdmin.rpc("dev_auto_login", {
    p_username: username,
  });

  if (error) {
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  return NextResponse.json({
    token: data.token,
    user: {
      id: data.user_id,
      displayName: data.display_name,
    },
  });
}
