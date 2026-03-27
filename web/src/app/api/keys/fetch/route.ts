// hello OS v2.0 — Fetch Key Bundle
// Atomically fetch a peer's key bundle + consume one OTK.
// BACKEND-04: Redis cache layer (5-min TTL, SETNX) with X-Bypass-Cache header.

import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { verifyAuth } from '@/lib/auth-verify';
import { getCachedBundle, cacheBundle, forceUpdateBundle, CachedKeyBundle } from '@/lib/key-cache';

export async function POST(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get('authorization'));
  if (!auth) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  // Rate limiting moved to edge proxy (BACKEND-03)

  const body = await req.json();
  const { user_id, device_id } = body;

  // Input validation
  if (!user_id || typeof user_id !== 'string' || !/^[a-zA-Z0-9_-]+$/.test(user_id)) {
    return NextResponse.json({ error: 'invalid user_id' }, { status: 400 });
  }
  if (device_id == null || !Number.isInteger(device_id) || device_id < 0 || device_id > 999999) {
    return NextResponse.json({ error: 'invalid device_id' }, { status: 400 });
  }

  const bypassCache = req.headers.get('x-bypass-cache') === 'true';

  // --- Cache layer: serve identity/signed-pre-key from Redis when possible ---
  if (!bypassCache) {
    const cached = await getCachedBundle(user_id, device_id);
    if (cached) {
      // OTK still needs atomic Postgres consumption
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

      // Merge cached identity/signed keys with fresh OTK from Postgres
      return NextResponse.json({
        ...data[0],
        identity_key: cached.identityKey,
        signed_pre_key: cached.signedPreKey,
        signed_pre_key_id: cached.signedPreKeyId,
        pre_key_sig: cached.preKeySig,
      });
    }
  }

  // --- Cache miss or bypass: full Postgres fetch ---
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

  const row = data[0];
  const bundle: CachedKeyBundle = {
    identityKey: row.identity_key,
    signedPreKey: row.signed_pre_key,
    signedPreKeyId: row.signed_pre_key_id,
    preKeySig: row.pre_key_sig,
    cachedAt: Date.now(),
  };

  if (bypassCache) {
    await forceUpdateBundle(user_id, device_id, bundle);
  } else {
    await cacheBundle(user_id, device_id, bundle);
  }

  return NextResponse.json(row);
}
