import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.resolve(__dirname, '.env.local') });

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !key) {
  console.error("Missing SUPABASE credentials in .env.local");
  process.exit(1);
}

const supabase = createClient(url, key);

async function main() {
  console.log("Applying join_via_invite ON CONFLICT DO NOTHING patch...");
  
  const joinFunc = `
  CREATE OR REPLACE FUNCTION join_via_invite(p_space_id text)
  RETURNS void
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path = public
  AS $$
  BEGIN
    IF NOT EXISTS (SELECT 1 FROM spaces WHERE id = p_space_id) THEN
      RAISE EXCEPTION 'space_not_found';
    END IF;

    -- Add as member with conflict handling
    INSERT INTO space_members (space_id, user_id, role)
    VALUES (p_space_id, auth.uid()::text, 'member')
    ON CONFLICT (space_id, user_id) DO NOTHING;

    -- Insert system message
    INSERT INTO messages (id, space_id, role, content, user_id, created_at)
    VALUES (
      'msg_sys_' || gen_random_uuid()::text,
      p_space_id,
      'system',
      (SELECT display_name FROM users WHERE id = auth.uid()::text) || ' joined the space',
      NULL,
      now()
    );
  END;
  $$;
  `;

  // We can't strictly execute raw SQL through supabase js without using the postgres meta endpoints or an existing RPC
  // Wait, I will use fetch to the REST API? No, the REST API doesn't support raw SQL.
  // We can use a script and output instructions.
  // Wait, local development! I have full CLI access!
  console.log("Since local DB is used or remotely linked, we will use the Supabase CLI.");
}

main();
