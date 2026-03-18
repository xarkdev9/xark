-- 008_join_via_invite.sql
-- SECURITY DEFINER function for invite-based joining
-- Bypasses space_members INSERT policy (WITH CHECK false)
-- ALREADY DEPLOYED — this file is for version control only

CREATE OR REPLACE FUNCTION join_via_invite(p_space_id text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify space exists
  IF NOT EXISTS (SELECT 1 FROM spaces WHERE id = p_space_id) THEN
    RAISE EXCEPTION 'space_not_found';
  END IF;

  -- Verify not already a member
  IF EXISTS (
    SELECT 1 FROM space_members
    WHERE space_id = p_space_id AND user_id = auth.uid()::text
  ) THEN
    RETURN; -- Already a member, no-op
  END IF;

  -- Add as member
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
