// XARK OS v2.0 — One-Time Pre-Key Upload
// Upload a batch of OTK public keys for key exchange.

import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { verifyAuth } from '@/lib/auth-verify';
import { checkRateLimit } from '@/lib/rate-limit';

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get('authorization'));
  if (!auth) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  if (!checkRateLimit(`keys:${auth.userId}`, 20)) {
    return NextResponse.json({ error: 'rate limited' }, { status: 429 });
  }

  const body = await req.json();
  const { device_id, keys } = body;

  if (!device_id || !Array.isArray(keys) || keys.length === 0) {
    return NextResponse.json({ error: 'device_id and keys[] required' }, { status: 400 });
  }

  // Security: cap batch size and validate key format
  if (keys.length > 200) {
    return NextResponse.json({ error: 'max 200 keys per batch' }, { status: 400 });
  }

  const base64Re = /^[A-Za-z0-9+/=]+$/;
  let rows;
  try {
    rows = keys.map((k: { id: string; public_key: string }) => {
      if (!k.id || typeof k.id !== 'string' || k.id.length > 128) {
        throw new Error('invalid key id');
      }
      if (!k.public_key || typeof k.public_key !== 'string' || k.public_key.length > 256 || !base64Re.test(k.public_key) || k.public_key.length % 4 !== 0) {
        throw new Error('invalid public_key');
      }
      return {
        id: k.id,
        user_id: auth.userId,
        device_id,
        public_key: k.public_key,
      };
    });
  } catch {
    return NextResponse.json({ error: 'invalid key format' }, { status: 400 });
  }

  const { error } = await supabaseAdmin.from('one_time_pre_keys').upsert(rows, { onConflict: 'id' });

  if (error) {
    console.error('[/api/keys/otk] error:', error.message);
    return NextResponse.json({ error: 'upload failed' }, { status: 500 });
  }

  return NextResponse.json({ ok: true, count: rows.length });
}
