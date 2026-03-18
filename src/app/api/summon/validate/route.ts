// XARK OS v2.0 — SUMMON LINK VALIDATION
// GET /api/summon/validate?code=<code> — validates a summon link (public, no auth).
// Returns { valid: true, creatorName } or { valid: false, reason }.

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function GET(req: NextRequest) {
  const code = req.nextUrl.searchParams.get("code");
  if (!code) return NextResponse.json({ valid: false, reason: "missing code" });

  if (!supabaseAdmin) {
    return NextResponse.json({ valid: false, reason: "server error" }, { status: 500 });
  }

  const { data, error } = await supabaseAdmin
    .from("summon_links")
    .select("creator_id, claimed_by, expires_at")
    .eq("code", code)
    .single();

  if (error || !data) {
    return NextResponse.json({ valid: false, reason: "link not found" });
  }

  if (data.claimed_by) {
    return NextResponse.json({ valid: false, reason: "already claimed" });
  }

  if (new Date(data.expires_at) < new Date()) {
    return NextResponse.json({ valid: false, reason: "expired" });
  }

  // Fetch creator display name
  const { data: creator } = await supabaseAdmin
    .from("users")
    .select("display_name")
    .eq("id", data.creator_id)
    .single();

  return NextResponse.json({
    valid: true,
    creatorName: creator?.display_name ?? "someone",
  });
}
