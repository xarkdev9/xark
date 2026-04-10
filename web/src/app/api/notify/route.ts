// hello OS v2.0 — Push Notification API Route
// Server-side push trigger. Called by lifecycle event handlers.
// Uses supabaseAdmin for service-role access to space_members and user_devices.
// Checks users.preferences.muted_spaces before sending.
//
// SECURITY HARDENING (Stream E, Item 7):
// Embeds E2EE ciphertext directly in the FCM data payload (up to 4KB).
// The mobile client decrypts in background without any network fetch.
// For payloads exceeding 4KB (rare — media metadata only), falls back
// to a tickle that shows a generic notification.

import { NextRequest, NextResponse } from "next/server";
import { sendPush } from "@/lib/notifications";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { verifyAuth } from "@/lib/auth-verify";

/// FCM data payload size limit (4KB). Payloads exceeding this fall back
/// to a tickle notification.
const FCM_DATA_LIMIT_BYTES = 4096;

export async function POST(req: NextRequest) {
  // ── Auth — prevent unauthenticated push notification delivery ──
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) {
    return NextResponse.json({ error: "unauthorized" }, { status: 401 });
  }

  // Rate limiting moved to edge proxy (BACKEND-03)

  const {
    event,
    groupId,
    senderName,
    excludeUserId,
    messageId,
    senderId,
    ciphertext: ciphertextBase64,
    nonce: nonceBase64,
  } = await req.json();

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

  // Build the push data payload.
  // If ciphertext is provided and fits within FCM's 4KB data limit,
  // embed it directly so the client can decrypt without network I/O.
  // Otherwise, send a tickle that triggers a generic notification.
  let pushData: Record<string, string>;

  if (
    ciphertextBase64 &&
    nonceBase64 &&
    typeof ciphertextBase64 === 'string' &&
    typeof nonceBase64 === 'string'
  ) {
    // Estimate total data payload size (all fields combined)
    const estimatedSize =
      (ciphertextBase64?.length ?? 0) +
      (nonceBase64?.length ?? 0) +
      (messageId?.length ?? 0) +
      (senderId?.length ?? 0) +
      (groupId?.length ?? 0) +
      50; // overhead for field names and separators

    if (estimatedSize <= FCM_DATA_LIMIT_BYTES) {
      // E2EE ciphertext embedded — zero-network push decryption
      pushData = {
        type: 'e2ee_message',
        message_id: messageId ?? '',
        sender_id: senderId ?? '',
        group_id: groupId,
        ciphertext: ciphertextBase64,
        nonce: nonceBase64,
      };
    } else {
      // Ciphertext exceeds 4KB (rare — media metadata only).
      // Fall back to tickle. Client shows generic notification.
      // Full decrypt happens when the user opens the app.
      pushData = {
        type: 'tickle',
        groupId,
        event: event ?? 'new_message',
        senderName: senderName ?? 'someone',
      };
    }
  } else {
    // No ciphertext provided — legacy tickle path
    pushData = {
      type: 'tickle',
      groupId,
      event: event ?? 'new_message',
      senderName: senderName ?? 'someone',
    };
  }

  await sendPush(tokens, pushData);
  return NextResponse.json({ sent: tokens.length });
}
