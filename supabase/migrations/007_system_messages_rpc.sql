-- 007_system_messages_rpc.sql
-- SECURITY DEFINER function to insert system messages (bypasses RLS role='user' check)
-- Already deployed in Supabase — this file is for version control only.

CREATE OR REPLACE FUNCTION insert_system_message(
  p_space_id text,
  p_content text
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO messages (id, space_id, role, content, user_id, created_at)
  VALUES (
    'msg_sys_' || gen_random_uuid()::text,
    p_space_id,
    'system',
    p_content,
    NULL,
    now()
  );
END;
$$;
