import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import { resolve } from 'path';
dotenv.config({ path: resolve('/Users/ramchitturi/xark9', '.env.local') });
const s = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY, { auth: { autoRefreshToken: false, persistSession: false } });

async function debug() {
  const { data: users } = await s.from('users').select('*');
  console.log('=== USERS ===');
  for (const u of users ?? []) console.log(`  ${u.id} | name="${u.display_name}" | phone=${u.phone} | created=${u.created_at}`);

  const { data: spaces } = await s.from('spaces').select('*');
  console.log('\n=== SPACES ===');
  for (const sp of spaces ?? []) console.log(`  ${sp.id} | title="${sp.title}" | atmo=${sp.atmosphere} | owner=${sp.owner_id}`);

  const { data: members } = await s.from('space_members').select('*');
  console.log('\n=== SPACE MEMBERS ===');
  for (const m of members ?? []) console.log(`  space=${m.space_id} | user=${m.user_id} | role=${m.role}`);

  const { data: msgs } = await s.from('messages').select('id, space_id, user_id, sender_name, content, message_type, created_at').order('created_at', { ascending: false }).limit(20);
  console.log('\n=== MESSAGES (last 20) ===');
  for (const m of msgs ?? []) console.log(`  ${m.id?.slice(0,12)} | space=${m.space_id?.slice(0,30)} | from=${m.user_id} | name=${m.sender_name} | type=${m.message_type} | content=${(m.content ?? '[null]').slice(0,50)}`);

  const { data: keys } = await s.from('key_bundles').select('user_id, device_id, updated_at');
  console.log('\n=== KEY BUNDLES ===');
  for (const k of keys ?? []) console.log(`  user=${k.user_id} | device=${k.device_id} | updated=${k.updated_at}`);

  const { data: otks } = await s.from('one_time_pre_keys').select('user_id, device_id').limit(5);
  const { count: otkCount } = await s.from('one_time_pre_keys').select('id', { count: 'exact', head: true });
  console.log(`\n=== OTKs: ${otkCount} total ===`);
  
  const { data: ciphertexts } = await s.from('message_ciphertexts').select('message_id, recipient_id, recipient_device_id').limit(10);
  console.log('\n=== CIPHERTEXTS (first 10) ===');
  for (const c of ciphertexts ?? []) console.log(`  msg=${c.message_id?.slice(0,12)} | to=${c.recipient_id} | device=${c.recipient_device_id}`);
}
debug().catch(console.error);
