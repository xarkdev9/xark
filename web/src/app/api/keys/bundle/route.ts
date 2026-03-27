// hello OS v2.0 — Key Bundle Upload
// Upload or update a device's public key bundle.

import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { verifyAuth } from '@/lib/auth-verify';
import { invalidateBundle } from '@/lib/key-cache';
import { checkJtiReplay, extractJti } from '@/lib/jwt-replay';

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get('authorization'));
  if (!auth) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  // ── JWT Replay Protection (crypto.md #15) ──
  const authHeader = req.headers.get('authorization')?.replace('Bearer ', '');
  if (authHeader) {
    const jti = extractJti(authHeader);
    const { fresh } = await checkJtiReplay(jti);
    if (!fresh) {
      return NextResponse.json({ error: 'jwt_replay_detected' }, { status: 403 });
    }
  }

  // Rate limiting moved to edge proxy (BACKEND-03)

  const body = await req.json();
  const { device_id, identity_key, signed_pre_key, signed_pre_key_id, pre_key_sig } = body;

  if (!device_id || !identity_key || !signed_pre_key || signed_pre_key_id == null || !pre_key_sig) {
    return NextResponse.json({ error: 'missing fields' }, { status: 400 });
  }

  // Field length validation — prevent oversized cryptographic payloads
  if (typeof identity_key !== 'string' || identity_key.length > 256 ||
      typeof signed_pre_key !== 'string' || signed_pre_key.length > 256 ||
      typeof pre_key_sig !== 'string' || pre_key_sig.length > 512) {
    return NextResponse.json({ error: 'invalid key format' }, { status: 400 });
  }

  const { error } = await supabaseAdmin.from('key_bundles').upsert({
    user_id: auth.userId,
    device_id,
    identity_key,
    signed_pre_key,
    signed_pre_key_id,
    pre_key_sig,
    updated_at: new Date().toISOString(),
  });

  if (error) {
    console.error('[/api/keys/bundle] error:', error.message);
    return NextResponse.json({ error: 'upload failed' }, { status: 500 });
  }

  // BACKEND-04: Invalidate cached bundle so next fetch gets fresh keys
  await invalidateBundle(auth.userId, device_id);

  return NextResponse.json({ ok: true });
}
