-- ═══════════════════════════════════════════════════════════════════════════════
-- XARK OS — Apply Missing RPCs to Production Supabase
-- Paste this ENTIRE script into Supabase Dashboard → SQL Editor → Run
-- Safe to re-run (CREATE OR REPLACE, IF NOT EXISTS)
-- ═══════════════════════════════════════════════════════════════════════════════

-- 0. space_tombstones table
CREATE TABLE IF NOT EXISTS space_tombstones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id TEXT NOT NULL,
  kicked_user_id TEXT NOT NULL,
  tombstoned_device_ids INTEGER[] NOT NULL,
  signature TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 1. get_latest_messages_per_space
CREATE OR REPLACE FUNCTION get_latest_messages_per_space(p_space_ids text[])
RETURNS TABLE(space_id text, content text, sender_name text, created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT DISTINCT ON (m.space_id) m.space_id, m.content, m.sender_name, m.created_at
  FROM messages m WHERE m.space_id = ANY(p_space_ids)
  ORDER BY m.space_id, m.created_at DESC;
$$;

-- 2. mark_space_read
CREATE OR REPLACE FUNCTION mark_space_read(p_space_id text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE space_members SET last_read_at = now()
  WHERE space_id = p_space_id AND user_id = auth.jwt()->>'sub';
END;
$$;

-- 3. check_rate_limit
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_key text, p_max_requests integer, p_window_seconds integer DEFAULT 60
)
RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count integer; v_window_start timestamptz;
BEGIN
  v_window_start := now() - (p_window_seconds || ' seconds')::interval;
  SELECT count(*) INTO v_count FROM rate_limits WHERE key = p_key AND ts > v_window_start;
  IF v_count >= p_max_requests THEN RETURN false; END IF;
  INSERT INTO rate_limits (key, ts) VALUES (p_key, now());
  DELETE FROM rate_limits WHERE ts < now() - interval '5 minutes';
  RETURN true;
END;
$$;

-- 4. insert_system_message
CREATE OR REPLACE FUNCTION insert_system_message(p_space_id text, p_content text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO messages (id, space_id, role, content, user_id, created_at)
  VALUES ('msg_sys_' || gen_random_uuid()::text, p_space_id, 'system', p_content, NULL, now());
END;
$$;

-- 5. fetch_key_bundle (DROP first — return type changed in 015)
DROP FUNCTION IF EXISTS fetch_key_bundle(text, integer);

CREATE OR REPLACE FUNCTION fetch_key_bundle(p_user_id text, p_device_id integer)
RETURNS TABLE(identity_key text, signed_pre_key text, signed_pre_key_id integer, pre_key_sig text, otk_id text, otk_public text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_otk_id text; v_otk_key text;
BEGIN
  DELETE FROM one_time_pre_keys
  WHERE id = (
    SELECT id FROM one_time_pre_keys
    WHERE user_id = p_user_id AND device_id = p_device_id
    LIMIT 1 FOR UPDATE SKIP LOCKED
  ) RETURNING one_time_pre_keys.id, one_time_pre_keys.public_key INTO v_otk_id, v_otk_key;

  RETURN QUERY
  SELECT kb.identity_key, kb.signed_pre_key, kb.signed_pre_key_id, kb.pre_key_sig, v_otk_id, v_otk_key
  FROM key_bundles kb
  WHERE kb.user_id = p_user_id AND kb.device_id = p_device_id;
END; $$;

-- 6. react_to_item
CREATE OR REPLACE FUNCTION react_to_item(p_item_id text, p_signal text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_weight integer; v_space_id text; v_is_locked boolean;
  v_weighted_score float; v_agreement_score float;
  v_member_count integer; v_reactor_count integer; v_user_id text;
BEGIN
  v_user_id := auth.jwt()->>'sub';
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF p_signal NOT IN ('love_it', 'works_for_me', 'not_for_me') THEN RAISE EXCEPTION 'invalid_signal'; END IF;
  v_weight := CASE p_signal WHEN 'love_it' THEN 5 WHEN 'works_for_me' THEN 1 WHEN 'not_for_me' THEN -3 END;
  SELECT space_id, is_locked INTO v_space_id, v_is_locked FROM decision_items WHERE id = p_item_id;
  IF v_space_id IS NULL THEN RAISE EXCEPTION 'item_not_found'; END IF;
  IF v_is_locked THEN RAISE EXCEPTION 'item_locked'; END IF;
  IF NOT EXISTS (SELECT 1 FROM space_members WHERE space_id = v_space_id AND user_id = v_user_id) THEN
    RAISE EXCEPTION 'not_a_member';
  END IF;
  INSERT INTO reactions (item_id, user_id, signal, weight, created_at)
  VALUES (p_item_id, v_user_id, p_signal, v_weight, now())
  ON CONFLICT (item_id, user_id)
  DO UPDATE SET signal = EXCLUDED.signal, weight = EXCLUDED.weight, created_at = now();
  SELECT COALESCE(SUM(weight), 0) INTO v_weighted_score FROM reactions WHERE item_id = p_item_id;
  SELECT COUNT(DISTINCT user_id) INTO v_reactor_count FROM reactions WHERE item_id = p_item_id;
  SELECT COUNT(*) INTO v_member_count FROM space_members WHERE space_id = v_space_id;
  v_agreement_score := CASE WHEN v_member_count > 0 THEN v_reactor_count::float / v_member_count::float ELSE 0 END;
  UPDATE decision_items SET weighted_score = v_weighted_score, agreement_score = v_agreement_score WHERE id = p_item_id;
  RETURN jsonb_build_object('weighted_score', v_weighted_score, 'agreement_score', v_agreement_score);
END;
$$;

-- 7. unreact_to_item (DROP first — return type changed)
DROP FUNCTION IF EXISTS unreact_to_item(text);

CREATE OR REPLACE FUNCTION unreact_to_item(p_item_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_space_id text; v_weighted_score float; v_agreement_score float;
  v_member_count integer; v_reactor_count integer; v_user_id text;
BEGIN
  v_user_id := auth.jwt()->>'sub';
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT space_id INTO v_space_id FROM decision_items WHERE id = p_item_id;
  IF v_space_id IS NULL THEN RAISE EXCEPTION 'item_not_found'; END IF;
  DELETE FROM reactions WHERE item_id = p_item_id AND user_id = v_user_id;
  SELECT COALESCE(SUM(weight), 0) INTO v_weighted_score FROM reactions WHERE item_id = p_item_id;
  SELECT COUNT(DISTINCT user_id) INTO v_reactor_count FROM reactions WHERE item_id = p_item_id;
  SELECT COUNT(*) INTO v_member_count FROM space_members WHERE space_id = v_space_id;
  v_agreement_score := CASE WHEN v_member_count > 0 THEN v_reactor_count::float / v_member_count::float ELSE 0 END;
  UPDATE decision_items SET weighted_score = v_weighted_score, agreement_score = v_agreement_score WHERE id = p_item_id;
  RETURN jsonb_build_object('weighted_score', v_weighted_score, 'agreement_score', v_agreement_score);
END;
$$;

-- 8. get_space_member_devices
CREATE OR REPLACE FUNCTION get_space_member_devices(p_space_id text, p_exclude_user text DEFAULT NULL)
RETURNS TABLE(user_id text, device_id integer)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT DISTINCT kb.user_id, kb.device_id
  FROM space_members sm
  JOIN key_bundles kb ON sm.user_id = kb.user_id
  WHERE sm.space_id = p_space_id
    AND (p_exclude_user IS NULL OR sm.user_id != p_exclude_user)
  ORDER BY kb.user_id, kb.device_id;
$$;

-- 9. join_via_invite
CREATE OR REPLACE FUNCTION join_via_invite(p_space_id text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM spaces WHERE id = p_space_id) THEN RAISE EXCEPTION 'space_not_found'; END IF;
  IF EXISTS (SELECT 1 FROM space_members WHERE space_id = p_space_id AND user_id = auth.uid()::text) THEN RETURN; END IF;
  INSERT INTO space_members (space_id, user_id, role) VALUES (p_space_id, auth.uid()::text, 'member') ON CONFLICT DO NOTHING;
  INSERT INTO messages (id, space_id, role, content, user_id, created_at)
  VALUES ('msg_sys_' || gen_random_uuid()::text, p_space_id, 'system',
    (SELECT display_name FROM users WHERE id = auth.uid()::text) || ' joined the space', NULL, now());
END;
$$;

-- 10. find_or_create_chat
CREATE OR REPLACE FUNCTION find_or_create_chat(p_user_id text, p_other_user_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_space_id text; v_user users%ROWTYPE; v_other users%ROWTYPE;
BEGIN
  SELECT * INTO v_user FROM users WHERE id = p_user_id;
  SELECT * INTO v_other FROM users WHERE id = p_other_user_id;
  IF v_user IS NULL OR v_other IS NULL THEN RETURN jsonb_build_object('error', 'user not found'); END IF;
  SELECT sm1.space_id INTO v_space_id
  FROM space_members sm1
  JOIN space_members sm2 ON sm1.space_id = sm2.space_id
  JOIN spaces s ON s.id = sm1.space_id
  WHERE sm1.user_id = p_user_id AND sm2.user_id = p_other_user_id AND s.atmosphere = 'sanctuary'
  LIMIT 1;
  IF v_space_id IS NOT NULL THEN RETURN jsonb_build_object('spaceId', v_space_id, 'created', false); END IF;
  v_space_id := 'space_' || replace(gen_random_uuid()::text, '-', '');
  INSERT INTO spaces (id, title, owner_id, atmosphere)
  VALUES (v_space_id, v_user.display_name || ' & ' || v_other.display_name, p_user_id, 'sanctuary');
  INSERT INTO space_members (space_id, user_id, role)
  VALUES (v_space_id, p_user_id, 'owner'), (v_space_id, p_other_user_id, 'member') ON CONFLICT DO NOTHING;
  INSERT INTO messages (id, space_id, role, content, user_id, message_type)
  VALUES ('msg_' || gen_random_uuid()::text, v_space_id, 'system', 'connected. encrypted, always.', p_user_id, 'system');
  RETURN jsonb_build_object('spaceId', v_space_id, 'created', true);
END;
$$;
REVOKE EXECUTE ON FUNCTION find_or_create_chat(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION find_or_create_chat(text, text) TO service_role;

-- 11. dev_verify_password
CREATE OR REPLACE FUNCTION dev_verify_password(p_username text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions
AS $$
DECLARE v_user record;
BEGIN
  SELECT id, display_name, password_hash INTO v_user FROM users WHERE display_name = p_username AND password_hash IS NOT NULL;
  IF v_user IS NULL THEN RAISE EXCEPTION 'user_not_found'; END IF;
  IF v_user.password_hash != crypt(p_password, v_user.password_hash) THEN RAISE EXCEPTION 'invalid_credentials'; END IF;
  RETURN jsonb_build_object('user_id', v_user.id, 'display_name', v_user.display_name);
END;
$$;

-- 12. save_taste_profile
CREATE OR REPLACE FUNCTION save_taste_profile(p_user_id text, p_constraints jsonb, p_raw_text text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO user_taste_profiles (user_id, hard_constraints, onboarded, onboarding_raw)
  VALUES (p_user_id, p_constraints, true, p_raw_text)
  ON CONFLICT (user_id) DO UPDATE SET
    hard_constraints = p_constraints, onboarded = true, onboarding_raw = p_raw_text, updated_at = now();
END;
$$;
REVOKE EXECUTE ON FUNCTION save_taste_profile(text, jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION save_taste_profile(text, jsonb, text) TO service_role;

-- 13. get_space_taste_profiles
CREATE OR REPLACE FUNCTION get_space_taste_profiles(p_space_id text)
RETURNS TABLE(user_id text, hard_constraints jsonb, implicit_weights jsonb, onboarded boolean)
LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public
AS $$
  SELECT utp.user_id, utp.hard_constraints, utp.implicit_weights, utp.onboarded
  FROM user_taste_profiles utp
  INNER JOIN space_members sm ON sm.user_id = utp.user_id
  WHERE sm.space_id = p_space_id;
$$;
REVOKE EXECUTE ON FUNCTION get_space_taste_profiles(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_space_taste_profiles(text) TO service_role;

-- ═══════════════════════════════════════════════════════════════════════════════
-- DONE — 13 functions + 1 table. All safe to re-run.
-- ═══════════════════════════════════════════════════════════════════════════════
