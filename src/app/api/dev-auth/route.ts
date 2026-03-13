// XARK OS v2.0 — DEV AUTH ENDPOINT
// POST /api/dev-auth — dev-mode login with password verification
// Calls dev_verify_password() Postgres RPC for bcrypt check,
// then signs JWT in Node.js via jose.
// Gate: Returns 404 if DEV_MODE !== 'true'

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

  if (!username || !password) {
    return NextResponse.json(
      { error: "username and password required" },
      { status: 400 }
    );
  }

  // Verify password via Postgres RPC (bcrypt check in SQL)
  const { data, error } = await supabaseAdmin.rpc("dev_verify_password", {
    p_username: username,
    p_password: password,
  });

  if (error) {
    const msg = error.message || "invalid credentials";
    const status =
      msg.includes("invalid_credentials") || msg.includes("user_not_found")
        ? 401
        : 500;
    return NextResponse.json({ error: msg }, { status });
  }

  // Sign JWT with jose
  const secret = new TextEncoder().encode(jwtSecret);
  const now = Math.floor(Date.now() / 1000);

  const token = await new SignJWT({
    sub: data.user_id,
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
      id: data.user_id,
      displayName: data.display_name,
    },
  });
}
