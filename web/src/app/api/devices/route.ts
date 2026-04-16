// hello OS v2.0 — Device Management API
// CRYPTO-06: List and unlink user devices (Sesame multi-device protocol).

import { NextRequest, NextResponse } from 'next/server';
import { supabaseAdmin } from '@/lib/supabase-admin';
import { verifyAuth } from '@/lib/auth-verify';

export async function GET(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get('authorization'));
  if (!auth) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const { data, error } = await supabaseAdmin
    .from('user_devices')
    .select('device_id, device_name, platform, is_primary, last_active_at, created_at')
    .eq('user_id', auth.userId)
    .order('created_at', { ascending: true });

  if (error) {
    console.error('[/api/devices] list error:', error.message);
    return NextResponse.json({ error: 'failed to list devices' }, { status: 500 });
  }

  return NextResponse.json({ devices: data ?? [] });
}

export async function DELETE(req: NextRequest) {
  const auth = await verifyAuth(req.headers.get('authorization'));
  if (!auth) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const body = await req.json();
  const { deviceId } = body;

  if (deviceId == null || typeof deviceId !== 'number') {
    return NextResponse.json({ error: 'missing or invalid device_id' }, { status: 400 });
  }

  // Use service-role to call the SECURITY DEFINER unlink function
  // on behalf of the authenticated user. The function itself checks auth.jwt()->>'sub'.
  // Since we're using supabaseAdmin (service role), we call revoke_device from the
  // e2ee migration which is also SECURITY DEFINER and takes explicit user_id.
  const { error: keyError } = await supabaseAdmin.from('key_bundles')
    .delete()
    .eq('user_id', auth.userId)
    .eq('device_id', deviceId);

  if (keyError) {
    console.error('[/api/devices] key_bundles cleanup error:', keyError.message);
  }

  const { error: otkError } = await supabaseAdmin.from('one_time_pre_keys')
    .delete()
    .eq('user_id', auth.userId)
    .eq('device_id', deviceId);

  if (otkError) {
    console.error('[/api/devices] otk cleanup error:', otkError.message);
  }

  const { error: skError } = await supabaseAdmin.from('sk_acknowledgments')
    .delete()
    .or(`and(sender_id.eq.${auth.userId},recipient_device_id.eq.${deviceId}),and(recipient_id.eq.${auth.userId},recipient_device_id.eq.${deviceId})`);

  if (skError) {
    console.error('[/api/devices] sk_ack cleanup error:', skError.message);
  }

  const { error: deviceError } = await supabaseAdmin.from('user_devices')
    .delete()
    .eq('user_id', auth.userId)
    .eq('device_id', deviceId);

  if (deviceError) {
    console.error('[/api/devices] device removal error:', deviceError.message);
    return NextResponse.json({ error: deviceError.message }, { status: 500 });
  }

  return NextResponse.json({ success: true });
}
