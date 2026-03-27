// hello OS v2.0 — Push Notification API Route
// Server-side push trigger. Called by lifecycle event handlers.
// Uses supabaseAdmin for service-role access to space_members and user_devices.
// Checks users.preferences.muted_spaces before sending.

import { NextRequest, NextResponse } from "next/server";
import { sendPush } from "@/lib/notifications";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";

export async function POST(req: NextRequest) {
  // ── Auth — prevent unauthenticated push notification delivery ──
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  // Rate limiting moved to edge proxy (BACKEND-03)

  const { event, groupId, senderName, excludeUserId } = await req.json();

  // Input validation — E2EE COMPLIANT: no `body` field accepted (no plaintext in push)
  if (!groupId || typeof groupId !== 'string') {
    return NextResponse.json({ error: 'groupId required' }, { status: 400 });
  }
  if (senderName && (typeof senderName !== 'string' || senderName.length > 50)) {
    return NextResponse.json({ error: 'invalid senderName' }, { status: 400 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  // ── Space membership check ──
  const { data: membership } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("group_id", groupId)
    .eq("user_id", auth.userId)
    .single();

  if (!membership) {
    return NextResponse.json({ error: "not a member of this space" }, { status: 403 });
  }

  // 1. Get all member user IDs for this space
  const { data: members } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("group_id", groupId);

  const memberUserIds = (members ?? [])
    .map((m: { user_id: string }) => m.user_id)
    .filter((id: string) => id !== excludeUserId);

  if (memberUserIds.length === 0) {
    return NextResponse.json({ sent: 0 });
  }

  // 2. Fetch preferences to find who muted this space
  const { data: userPrefs } = await supabaseAdmin
    .from("users")
    .select("id, preferences")
    .in("id", memberUserIds);

  const mutedUserIds = new Set<string>();
  for (const u of userPrefs ?? []) {
    const prefs = u.preferences as Record<string, unknown> | null;
    const muted = prefs?.muted_spaces;
    if (Array.isArray(muted) && muted.includes(groupId)) {
      mutedUserIds.add(u.id as string);
    }
  }

  // 3. Get devices for non-muted members
  const eligibleUserIds = memberUserIds.filter((id: string) => !mutedUserIds.has(id));
  if (eligibleUserIds.length === 0) {
    return NextResponse.json({ sent: 0 });
  }

  const { data: deviceRows } = await supabaseAdmin
    .from("user_devices")
    .select("fcm_token")
    .in("user_id", eligibleUserIds);

  const tokens = (deviceRows ?? []).map((d: { fcm_token: string }) => d.fcm_token);

  if (tokens.length === 0) {
    return NextResponse.json({ sent: 0 });
  }

  // E2EE COMPLIANT: metadata only — no message plaintext in push payload
  await sendPush(tokens, {
    groupId,
    event: event ?? "new_message",
    senderName: senderName ?? "someone",
  });
  return NextResponse.json({ sent: tokens.length });
}
