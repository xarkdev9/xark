// hello OS v2.0 — E2EE Message Endpoint (Atomic RPC)
// Single-transaction message persistence via send_e2ee_message postgres function.
// Client-generated UUIDv7 provides idempotency. TCP via postgres.js for hot path.
// No AI orchestration — @hello intelligence lives in the Spotlight layer.

export const runtime = 'nodejs';

import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@/lib/postgres-pool';
import { verifyAuth } from '@/lib/auth-verify';

export async function POST(req: NextRequest) {
  try {
    // ── Auth ──
    const auth = await verifyAuth(req.headers.get('authorization'));
    if (!auth) {
      return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
    }

    const body = await req.json();
    const {
      message_id,
      group_id,
      sender_device_id,
      message_type,
      role,
      server_content,
      reply_to_id,
      ciphertexts,
      distribution_ciphertexts,
    } = body;

    // ── Input validation ──
    if (!message_id || typeof message_id !== 'string') {
      return NextResponse.json({ error: 'message_id required (UUIDv7)' }, { status: 400 });
    }
    if (!group_id || typeof group_id !== 'string') {
      return NextResponse.json({ error: 'group_id required' }, { status: 400 });
    }

    // Validate message_type against strict allowlist
    const ALLOWED_CLIENT_TYPES = ['e2ee', 'sender_key_dist'] as const;
    const msgType = message_type ?? 'e2ee';
    if (!ALLOWED_CLIENT_TYPES.includes(msgType as typeof ALLOWED_CLIENT_TYPES[number])) {
      return NextResponse.json({ error: 'invalid message_type' }, { status: 400 });
    }

    // ── Atomic RPC via postgres.js TCP ──
    const [result] = await sql`
      SELECT send_e2ee_message(
        ${message_id}::UUID,
        ${group_id}::TEXT,
        ${auth.userId}::TEXT,
        ${sender_device_id ?? 0}::INTEGER,
        ${msgType}::TEXT,
        ${role ?? 'user'}::TEXT,
        ${server_content ?? null}::TEXT,
        ${reply_to_id ?? null}::UUID,
        ${JSON.stringify(ciphertexts ?? [])}::JSONB,
        ${JSON.stringify(distribution_ciphertexts ?? [])}::JSONB
      ) AS result
    `;

    const data = result.result;

    return NextResponse.json({
      message_id: data.message_id,
      server_seq: data.server_seq,
      created_at: data.created_at,
      status: data.status,
    });

  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);

    if (errMsg.includes('not_a_member')) {
      return NextResponse.json({ error: 'not a member of this group' }, { status: 403 });
    }
    if (errMsg.includes('invalid_clock_skew')) {
      return NextResponse.json({ error: 'clock skew exceeds 5 minute tolerance' }, { status: 400 });
    }

    console.error('[/api/message] error:', errMsg);
    return NextResponse.json({ error: 'internal error' }, { status: 500 });
  }
}
