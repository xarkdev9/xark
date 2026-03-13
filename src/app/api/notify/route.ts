// XARK OS v2.0 — Push Notification API Route
// Server-side push trigger. Called by lifecycle event handlers.
// Uses supabaseAdmin for service-role access to space_members and user_devices.

import { NextRequest, NextResponse } from "next/server";
import { sendPush } from "@/lib/notifications";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(req: NextRequest) {
  const { event, spaceId, title, body, excludeUserId } = await req.json();

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  // Get space members' user IDs
  const { data: members } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("space_id", spaceId);

  if (!members) return NextResponse.json({ sent: 0 });

  const userIds = members
    .map((m: { user_id: string }) => m.user_id)
    .filter((id: string) => id !== excludeUserId);

  if (userIds.length === 0) return NextResponse.json({ sent: 0 });

  // Get FCM tokens for those users
  const { data: devices } = await supabaseAdmin
    .from("user_devices")
    .select("fcm_token")
    .in("user_id", userIds);

  if (!devices || devices.length === 0) {
    return NextResponse.json({ sent: 0 });
  }

  const tokens = devices.map((d: { fcm_token: string }) => d.fcm_token);
  await sendPush(tokens, title, body, { spaceId, event });

  return NextResponse.json({ sent: tokens.length });
}
