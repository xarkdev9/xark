// XARK OS v2.0 — Daily Purge Cron
// Runs purge_expired_xark_messages() and purge_expired_summon_links() RPCs in parallel.
// Protected by CRON_SECRET to prevent unauthorized invocation.
// TODO: Set CRON_SECRET environment variable in Vercel dashboard before deploying.

import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';

export async function GET(req: NextRequest) {
  // Verify cron secret — Vercel sends this header for scheduled functions
  const authHeader = req.headers.get('authorization');
  const cronSecret = process.env.CRON_SECRET;

  if (!cronSecret || authHeader !== `Bearer ${cronSecret}`) {
    return NextResponse.json({ error: 'unauthorized' }, { status: 401 });
  }

  if (!supabaseAdmin) {
    return NextResponse.json({ error: 'not configured' }, { status: 500 });
  }

  const [purgeResult, summonResult] = await Promise.all([
    supabaseAdmin.rpc('purge_expired_xark_messages'),
    supabaseAdmin.rpc('purge_expired_summon_links'),
  ]);

  if (purgeResult.error) {
    console.error('[cron/purge] purge_expired_xark_messages error:', purgeResult.error.message);
  }

  if (summonResult.error) {
    console.error('[cron/purge] purge_expired_summon_links error:', summonResult.error.message);
  }

  if (purgeResult.error && summonResult.error) {
    return NextResponse.json({ error: 'purge failed' }, { status: 500 });
  }

  return NextResponse.json({
    purged: purgeResult.data ?? 0,
    summonsPurged: summonResult.data ?? 0,
  });
}
