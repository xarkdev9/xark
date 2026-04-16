// hello OS v2.0 — SUMMON LINK GENERATION
// POST /api/invite — generates a one-time summon link for authenticated users.
// Returns { code, url } on success.

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { randomBytes } from "crypto";

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  // Rate limiting moved to edge proxy (BACKEND-03)

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

  const base = process.env.NEXT_PUBLIC_APP_URL || "https://gethello.ai";
  return NextResponse.json({ code, url: `${base}/s/${code}` });
}
