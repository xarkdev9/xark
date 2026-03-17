// XARK OS v2.0 — E2EE Message Endpoint
// Pure encrypted message persistence + Sender Key distribution.
// No AI orchestration — @xark intelligence lives in the Spotlight layer.

import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { verifyAuth } from '@/lib/auth-verify';
import { checkRateLimit } from '@/lib/rate-limit';

export async function POST(req: NextRequest) {
  try {
    if (!supabaseAdmin) {
      return NextResponse.json({ error: 'server not configured' }, { status: 500 });
    }

    // ── Auth ──
    const auth = await verifyAuth(req.headers.get('authorization'));
    if (!auth) {
      return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
    }

    // ── Rate limit ──
    if (!checkRateLimit(`msg:${auth.userId}`, 10)) {
      return NextResponse.json({ error: 'rate limited' }, { status: 429 });
    }

    const body = await req.json();
    const {
      space_id,
      sender_device_id,
      ciphertext,
      ratchet_header,
      recipient_id,
      recipient_device_id,
      distribution_ciphertexts,
    } = body;

    // ── Input validation ──
    if (!space_id || typeof space_id !== 'string') {
      return NextResponse.json({ error: 'space_id required' }, { status: 400 });
    }
    if (!ciphertext || typeof ciphertext !== 'string') {
      return NextResponse.json({ error: 'ciphertext required' }, { status: 400 });
    }
    if (ciphertext.length > 65536) {
      return NextResponse.json({ error: 'ciphertext too large' }, { status: 400 });
    }

    // ── Validate message_type against strict allowlist ──
    const ALLOWED_CLIENT_TYPES = ['e2ee', 'sender_key_dist'] as const;
    const message_type = body.message_type;
    if (message_type && !ALLOWED_CLIENT_TYPES.includes(message_type as typeof ALLOWED_CLIENT_TYPES[number])) {
      return NextResponse.json({ error: 'invalid message_type' }, { status: 400 });
    }

    // ── Space membership check — prevent cross-space injection ──
    const { data: membership } = await supabaseAdmin
      .from('space_members')
      .select('user_id')
      .eq('space_id', space_id)
      .eq('user_id', auth.userId)
      .single();

    if (!membership) {
      return NextResponse.json({ error: 'not a member of this space' }, { status: 403 });
    }

    // ── Step 1: Insert encrypted message envelope ──
    const msgId = `msg_${crypto.randomUUID()}`;

    const { error: msgError } = await supabaseAdmin.from('messages').insert({
      id: msgId,
      space_id,
      user_id: auth.userId,
      sender_device_id: sender_device_id ?? null,
      message_type: message_type ?? 'e2ee',
      role: 'user',
      content: null,       // E2EE — server never sees plaintext
      sender_name: null,   // resolved client-side from space_members
      created_at: new Date().toISOString(),
    });

    if (msgError) {
      console.error('[/api/message] insert message failed:', msgError.message);
      return NextResponse.json({ error: 'message insert failed' }, { status: 500 });
    }

    // ── Step 2: Insert ciphertext ──
    const { error: cipherError } = await supabaseAdmin.from('message_ciphertexts').insert({
      id: `mc_${crypto.randomUUID()}`,
      message_id: msgId,
      recipient_id: recipient_id ?? '_group_',
      recipient_device_id: recipient_device_id ?? 0,
      ciphertext,
      ratchet_header: ratchet_header ?? null,
    });

    if (cipherError) {
      console.error('[/api/message] insert ciphertext failed:', cipherError.message);
      // Rollback the message
      await supabaseAdmin.from('messages').delete().eq('id', msgId);
      return NextResponse.json({ error: 'ciphertext insert failed' }, { status: 500 });
    }

    // ── Step 3: Insert per-recipient distribution ciphertexts (Sender Key dist) ──
    if (distribution_ciphertexts && Array.isArray(distribution_ciphertexts) && distribution_ciphertexts.length > 0) {
      if (distribution_ciphertexts.length > 100) {
        return NextResponse.json({ error: 'too many distribution ciphertexts (max 100)' }, { status: 400 });
      }
      const distRows = distribution_ciphertexts.map((ct: Record<string, unknown>) => ({
        id: typeof ct.id === 'string' ? ct.id : `mc_${crypto.randomUUID()}`,
        message_id: msgId,
        recipient_id: typeof ct.recipient_id === 'string' ? ct.recipient_id : '_group_',
        recipient_device_id: typeof ct.recipient_device_id === 'number' ? ct.recipient_device_id : 0,
        ciphertext: typeof ct.ciphertext === 'string' ? ct.ciphertext : '',
        ratchet_header: typeof ct.ratchet_header === 'string' ? ct.ratchet_header : null,
      }));
      const { error: distError } = await supabaseAdmin.from('message_ciphertexts').insert(distRows);
      if (distError) {
        console.warn('[/api/message] distribution ciphertext insert failed:', distError.message);
        // Non-fatal — some members may not get the key, they'll request it later
      }
    }

    return NextResponse.json({ messageId: msgId });

  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    console.error('[/api/message] error:', errMsg);
    return NextResponse.json({ error: 'internal error' }, { status: 500 });
  }
}
