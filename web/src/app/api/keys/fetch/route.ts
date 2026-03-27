// XARK OS v2.0 — Fetch Key Bundle
// Atomically fetch a peer's key bundle + consume one OTK.

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
  const { user_id, device_id } = body;

  // Input validation
  if (!user_id || typeof user_id !== 'string' || !/^[a-zA-Z0-9_-]+$/.test(user_id)) {
    return NextResponse.json({ error: 'invalid user_id' }, { status: 400 });
  }
  if (device_id == null || !Number.isInteger(device_id) || device_id < 0 || device_id > 999999) {
    return NextResponse.json({ error: 'invalid device_id' }, { status: 400 });
  }

  const { data, error } = await supabaseAdmin.rpc('fetch_key_bundle', {
    p_user_id: user_id,
    p_device_id: device_id,
  });

  if (error) {
    console.error('[/api/keys/fetch] error:', error.message);
    return NextResponse.json({ error: 'fetch failed' }, { status: 500 });
  }

  if (!data || data.length === 0) {
    return NextResponse.json({ error: 'no key bundle found' }, { status: 404 });
  }

  return NextResponse.json(data[0]);
}
