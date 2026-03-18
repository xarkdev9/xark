// XARK OS v2.0 — SUMMON LINK GENERATION
// POST /api/summon — generates a one-time summon link for authenticated users.
// Returns { code, url } on success.

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";
import { randomBytes } from "crypto";

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  if (!checkRateLimit(`summon:${auth.userId}`, 10, 3600_000)) {
    return NextResponse.json({ error: "rate limited" }, { status: 429 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  const code = randomBytes(16).toString("hex");
  const { error } = await supabaseAdmin.from("summon_links").insert({
    code,
    creator_id: auth.userId,
  });

  if (error) {
    console.error("[summon] create failed:", error.message);
    return NextResponse.json({ error: "failed to create link" }, { status: 500 });
  }

  const base = process.env.NEXT_PUBLIC_APP_URL || "https://xark.app";
  return NextResponse.json({ code, url: `${base}/s/${code}` });
}
