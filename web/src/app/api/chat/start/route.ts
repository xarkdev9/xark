// XARK OS v2.0 — POST /api/chat/start
// WhatsApp-style find-or-create 1:1 chat.
// Calls find_or_create_chat RPC atomically.

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) return NextResponse.json({ error: "unauthorized" }, { status: 401 });

  if (!checkRateLimit(`chat:${auth.userId}`, 20, 60_000)) {
    return NextResponse.json({ error: "rate limited" }, { status: 429 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: "not configured" }, { status: 500 });
  }

  let body: { otherUserId?: string };
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "invalid json" }, { status: 400 });
  }

  const { otherUserId } = body;
  if (!otherUserId || typeof otherUserId !== "string") {
    return NextResponse.json({ error: "otherUserId required" }, { status: 400 });
  }

  // Cannot chat with yourself
  if (otherUserId === auth.userId) {
    return NextResponse.json({ error: "cannot chat with yourself" }, { status: 400 });
  }

  const { data, error } = await supabaseAdmin.rpc("find_or_create_chat", {
    p_user_id: auth.userId,
    p_other_user_id: otherUserId,
  });

  if (error) {
    console.error("[chat/start] RPC failed:", error.message);
    return NextResponse.json({ error: error.message }, { status: 500 });
  }

  if (data?.error) {
    return NextResponse.json({ error: data.error }, { status: 400 });
  }

  return NextResponse.json({ spaceId: data.spaceId, created: data.created });
}
