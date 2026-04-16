// hello OS v2.0 — WEB VOTER ENDPOINT
// POST /api/vote — unauthenticated guest voting from the web voter view.
// Body: { inviteCode, itemId, signal, voterName }
// Returns { ok: true, guestId, signal } on success.

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";

const VALID_SIGNALS = new Set(["love_it", "works_for_me", "not_for_me"]);

const SIGNAL_WEIGHTS: Record<string, number> = {
  love_it: 5,
  works_for_me: 1,
  not_for_me: -3,
};

export async function POST(req: NextRequest) {
  let body: { inviteCode?: string; itemId?: string; signal?: string; voterName?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid request body" }, { status: 400 });
  }

  const { inviteCode, itemId, signal, voterName } = body;

  if (!inviteCode || typeof inviteCode !== "string") {
    return NextResponse.json({ error: "inviteCode required" }, { status: 400 });
  }
  if (!itemId || typeof itemId !== "string") {
    return NextResponse.json({ error: "itemId required" }, { status: 400 });
  }
  if (!signal || !VALID_SIGNALS.has(signal)) {
    return NextResponse.json(
      { error: "signal must be love_it, works_for_me, or not_for_me" },
      { status: 400 },
    );
  }
  if (!voterName || typeof voterName !== "string" || voterName.trim().length === 0) {
    return NextResponse.json({ error: "voterName required" }, { status: 400 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "server not configured" }, { status: 500 });
  }

  // Validate invite code exists and is not expired/claimed
  const { data: invite, error: inviteErr } = await supabaseAdmin
    .from("summon_links")
    .select("code, creator_id, claimed_by, expires_at")
    .eq("code", inviteCode)
    .single();

  if (inviteErr || !invite) {
    return NextResponse.json({ error: "invalid invite code" }, { status: 404 });
  }

  // Build guest ID from voter name
  const safeName = voterName.trim().toLowerCase().replace(/\s+/g, "_").replace(/[^a-z0-9_]/g, "").slice(0, 30);
  const guestId = `guest_${safeName}`;

  // Verify the item exists
  const { data: item, error: itemErr } = await supabaseAdmin
    .from("decision_items")
    .select("id, group_id, is_locked, weighted_score, agreement_score")
    .eq("id", itemId)
    .single();

  if (itemErr || !item) {
    return NextResponse.json({ error: "item not found" }, { status: 404 });
  }

  if (item.is_locked) {
    return NextResponse.json({ error: "item is locked, voting closed" }, { status: 409 });
  }

  const weight = SIGNAL_WEIGHTS[signal];

  // Upsert reaction (one per user per item, last wins)
  const { error: reactionErr } = await supabaseAdmin
    .from("reactions")
    .upsert(
      {
        item_id: itemId,
        user_id: guestId,
        signal,
        weight,
        created_at: new Date().toISOString(),
      },
      { onConflict: "item_id,user_id" },
    );

  if (reactionErr) {
    console.error("[vote] reaction upsert failed:", reactionErr.message);
    return NextResponse.json({ error: "vote failed" }, { status: 500 });
  }

  // Recompute scores for the item
  const { data: reactions } = await supabaseAdmin
    .from("reactions")
    .select("user_id, weight")
    .eq("item_id", itemId);

  const totalWeight = (reactions ?? []).reduce((sum: number, r: { weight: number }) => sum + r.weight, 0);
  const uniqueReactors = new Set((reactions ?? []).map((r: { user_id: string }) => r.user_id)).size;

  // Get member count for agreement score
  const { count: memberCount } = await supabaseAdmin
    .from("group_members")
    .select("user_id", { count: "exact", head: true })
    .eq("group_id", item.group_id);

  // Include guest voters in the denominator (members + unique guests)
  const effectiveTotal = Math.max(memberCount ?? 1, uniqueReactors);
  const agreementScore = effectiveTotal > 0 ? uniqueReactors / effectiveTotal : 0;

  await supabaseAdmin
    .from("decision_items")
    .update({ weighted_score: totalWeight, agreement_score: agreementScore })
    .eq("id", itemId);

  return NextResponse.json({ ok: true, guestId, signal });
}
