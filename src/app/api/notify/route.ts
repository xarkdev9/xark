// XARK OS v2.0 — Push Notification API Route
// Server-side push trigger. Called by lifecycle event handlers.
// Uses supabaseAdmin for service-role access to space_members and user_devices.
// Checks users.preferences.muted_spaces before sending.

import { NextRequest, NextResponse } from "next/server";
import { sendPush } from "@/lib/notifications";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";

export async function POST(req: NextRequest) {
  // ── Auth — prevent unauthenticated push notification delivery ──
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  // H6 fix: rate limit push notifications
  if (!checkRateLimit(`notify:${auth.userId}`, 15)) {
    return NextResponse.json({ error: "too many notifications" }, { status: 429 });
  }

  const { event, spaceId, title, body, excludeUserId } = await req.json();

  // Input validation
  if (!spaceId || typeof spaceId !== 'string') {
    return NextResponse.json({ error: 'spaceId required' }, { status: 400 });
  }
  if (title && (typeof title !== 'string' || title.length > 200)) {
    return NextResponse.json({ error: 'invalid title' }, { status: 400 });
  }
  if (body && (typeof body !== 'string' || body.length > 500)) {
    return NextResponse.json({ error: 'invalid body' }, { status: 400 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  // ── Space membership check ──
  const { data: membership } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("space_id", spaceId)
    .eq("user_id", auth.userId)
    .single();

  if (!membership) {
    return NextResponse.json({ error: "not a member of this space" }, { status: 403 });
  }

  // 1. Get all member user IDs for this space
  const { data: members } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("space_id", spaceId);

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
    if (Array.isArray(muted) && muted.includes(spaceId)) {
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

  await sendPush(tokens, title, body, { spaceId, event });
  return NextResponse.json({ sent: tokens.length });
}
