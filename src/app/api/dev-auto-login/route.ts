// XARK OS v2.0 — PASSWORD-GATED LOGIN ENDPOINT
// POST /api/dev-auto-login — password-protected login for testing.
// Generates a JWT via jose (Node.js) for a user verified by shared password.
// Gate: Returns 401 if password doesn't match LOGIN_PASSWORD env var.

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { SignJWT } from "jose";

export async function POST(request: NextRequest) {
  const jwtSecret = process.env.SUPABASE_JWT_SECRET;
  if (!jwtSecret) {
    return NextResponse.json(
      { error: "SUPABASE_JWT_SECRET not configured" },
      { status: 500 }
    );
  }

  let body: { username?: string; password?: string };
  try {
    body = await request.json();
  } catch {
    return NextResponse.json(
      { error: "invalid request body" },
      { status: 400 }
    );
  }

  const { username, password } = body;

  // M5 fix: block ALL dev-auto-login in production regardless of DEV_MODE
  if (process.env.NODE_ENV === "production") {
    return NextResponse.json({ error: "not available" }, { status: 404 });
  }

  const isDevMode = process.env.DEV_MODE === "true";
  const loginPassword = process.env.LOGIN_PASSWORD;

  if (!isDevMode) {
    if (!loginPassword || !password || password !== loginPassword) {
      return NextResponse.json({ error: "unauthorized" }, { status: 401 });
    }
  }
  if (!username) {
    return NextResponse.json(
      { error: "username required" },
      { status: 400 }
    );
  }

  // Look up user by display_name (case-insensitive)
  const { data: user, error: userError } = await supabaseAdmin
    .from("users")
    .select("id, display_name")
    .ilike("display_name", username)
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
