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

  // Single RPC replaces 2-query chain (members → devices)
  const { data: tokenRows } = await supabaseAdmin.rpc("get_push_tokens_for_space", {
    p_space_id: spaceId,
    p_exclude_user: excludeUserId ?? null,
  });

  if (!tokenRows || tokenRows.length === 0) {
    return NextResponse.json({ sent: 0 });
  }

  const tokens = tokenRows.map((d: { fcm_token: string }) => d.fcm_token);
  await sendPush(tokens, title, body, { spaceId, event });

  return NextResponse.json({ sent: tokens.length });
}
