// hello OS v2.0 — E2EE Message Endpoint (Atomic RPC)
// Single-transaction message persistence via send_e2ee_message postgres function.
// Client-generated UUIDv7 provides idempotency. TCP via postgres.js for hot path.
// No AI orchestration — @hello intelligence lives in the Spotlight layer.

export const runtime = 'nodejs';

import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { verifyAuth } from '@/lib/auth-verify';

// NOTE: Originally used postgres.js TCP pool for lower latency.
// Falls back to Supabase PostgREST RPC when DATABASE_URL is not set.
// Set DATABASE_URL to the Supavisor pooler endpoint (port 6543) for TCP mode.
// NOTE: JWT replay protection (jti check) intentionally NOT applied here.
// The message route relies on client retries for idempotency — the atomic RPC's
// ON CONFLICT (id) DO NOTHING handles dedup. Blocking retried JWTs would break
// the idempotency guarantee. JTI checks apply to /api/keys/* and /api/phone-auth.

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

    // ── Atomic RPC via Supabase PostgREST ──
    const { data, error } = await supabaseAdmin.rpc('send_e2ee_message', {
      p_message_id: message_id,
      p_group_id: group_id,
      p_sender_id: auth.userId,
      p_sender_device_id: sender_device_id ?? 0,
      p_message_type: msgType,
      p_role: role ?? 'user',
      p_server_content: server_content ?? null,
      p_reply_to_id: reply_to_id ?? null,
      p_ciphertexts: ciphertexts ?? [],
      p_distributions: distribution_ciphertexts ?? [],
    });

    if (error) {
      if (error.message?.includes('not_a_member')) {
        return NextResponse.json({ error: 'not a member of this group' }, { status: 403 });
      }
      if (error.message?.includes('invalid_clock_skew')) {
        return NextResponse.json({ error: 'clock skew exceeds 5 minute tolerance' }, { status: 400 });
      }
      throw new Error(error.message);
    }

    // The RPC returns JSONB — PostgREST may wrap it differently
    const result = typeof data === 'string' ? JSON.parse(data) : data;

    return NextResponse.json({
      message_id: result?.message_id ?? message_id,
      server_seq: result?.server_seq ?? null,
      created_at: result?.created_at ?? null,
      status: result?.status ?? 'unknown',
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
