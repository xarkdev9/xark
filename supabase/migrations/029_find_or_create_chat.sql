-- XARK OS v2.0 — Migration 029: WhatsApp-style find_or_create_chat
-- Atomic RPC: finds existing 1:1 sanctuary or creates a new one with both members.

CREATE OR REPLACE FUNCTION find_or_create_chat(
  p_user_id text,
  p_other_user_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_space_id text;
  v_user users%ROWTYPE;
  v_other users%ROWTYPE;
BEGIN
  -- Validate both users exist
  SELECT * INTO v_user FROM users WHERE id = p_user_id;
  SELECT * INTO v_other FROM users WHERE id = p_other_user_id;
  IF v_user IS NULL OR v_other IS NULL THEN
    RETURN jsonb_build_object('error', 'user not found');
  END IF;

  -- Check if a 1:1 sanctuary already exists between these two users
  SELECT sm1.space_id INTO v_space_id
  FROM space_members sm1
  JOIN space_members sm2 ON sm1.space_id = sm2.space_id
  JOIN spaces s ON s.id = sm1.space_id
  WHERE sm1.user_id = p_user_id
    AND sm2.user_id = p_other_user_id
    AND s.atmosphere = 'sanctuary'
  LIMIT 1;

  IF v_space_id IS NOT NULL THEN
    -- Chat already exists — return it
    RETURN jsonb_build_object('spaceId', v_space_id, 'created', false);
  END IF;

  -- Create new sanctuary space
  v_space_id := 'space_' || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO spaces (id, title, owner_id, atmosphere)
  VALUES (
    v_space_id,
    v_user.display_name || ' & ' || v_other.display_name,
    p_user_id,
    'sanctuary'
  );

  -- Add both as members
  INSERT INTO space_members (space_id, user_id, role)
  VALUES (v_space_id, p_user_id, 'owner'),
         (v_space_id, p_other_user_id, 'member')
  ON CONFLICT DO NOTHING;

  -- Seed message
  INSERT INTO messages (id, space_id, role, content, user_id, message_type)
  VALUES (
    'msg_' || gen_random_uuid()::text,
    v_space_id,
    'system',
    'connected. encrypted, always.',
    p_user_id,
    'system'
  );

  RETURN jsonb_build_object('spaceId', v_space_id, 'created', true);
END;
$$;

REVOKE EXECUTE ON FUNCTION find_or_create_chat(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION find_or_create_chat(text, text) TO service_role;
