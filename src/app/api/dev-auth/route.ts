// XARK OS v2.0 — DEV AUTH ENDPOINT
// POST /api/dev-auth — dev-mode login bypass
// Calls the dev_login() Postgres RPC function.
// Gate: Returns 404 if DEV_MODE !== 'true'

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(request: NextRequest) {
  // Gate: dev mode only
  if (process.env.DEV_MODE !== "true") {
    return NextResponse.json({ error: "not found" }, { status: 404 });
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

  const { data, error } = await supabaseAdmin.rpc("dev_login", {
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

  return NextResponse.json({
    token: data.token,
    user: {
      id: data.user_id,
      displayName: data.display_name,
    },
  });
}
