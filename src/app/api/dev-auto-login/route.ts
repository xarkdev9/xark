// XARK OS v2.0 — DEV AUTO-LOGIN ENDPOINT
// POST /api/dev-auto-login — passwordless dev login for URL name param flow.
// Generates a JWT via jose (Node.js) for a test user without password verification.
// Gate: Returns 404 if DEV_MODE !== 'true'. NEVER enable in production.
// Use /api/dev-auth for full username+password testing.

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { SignJWT } from "jose";

export async function POST(request: NextRequest) {
  // Gate: dev mode only
  if (process.env.DEV_MODE !== "true") {
    return NextResponse.json({ error: "not found" }, { status: 404 });
  }

  const jwtSecret = process.env.SUPABASE_JWT_SECRET;
  if (!jwtSecret) {
    return NextResponse.json(
      { error: "SUPABASE_JWT_SECRET not configured" },
      { status: 500 }
    );
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

  // Sign JWT with jose — same payload structure as Supabase expects
  const secret = new TextEncoder().encode(jwtSecret);
  const now = Math.floor(Date.now() / 1000);

  const token = await new SignJWT({
    sub: user.id,
    role: "authenticated",
    aud: "authenticated",
    iss: "supabase",
    iat: now,
    exp: now + 86400, // 24h
  })
    .setProtectedHeader({ alg: "HS256", typ: "JWT" })
    .sign(secret);

  return NextResponse.json({
    token,
    user: {
      id: user.id,
      displayName: user.display_name,
    },
  });
}
