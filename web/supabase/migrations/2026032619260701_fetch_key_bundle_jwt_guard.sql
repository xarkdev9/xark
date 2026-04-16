-- XARK OS v2.0 — Harden fetch_key_bundle with JWT + co-membership assertion
-- SECURITY FIX: Prevents authenticated users from draining OTKs of arbitrary users.
-- The caller must share at least one space with the target user.
-- Without this, any authenticated user could exhaust a victim's one-time pre-keys
-- by repeatedly calling fetch_key_bundle(victim_id, device_id), degrading forward secrecy.

DROP FUNCTION IF EXISTS fetch_key_bundle(text, integer);

CREATE OR REPLACE FUNCTION fetch_key_bundle(p_user_id text, p_device_id integer)
RETURNS TABLE(identity_key text, signed_pre_key text, signed_pre_key_id integer, pre_key_sig text, otk_id text, otk_public text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_caller_id text;
  v_caller_role text;
  v_shared_space boolean;
  v_otk_id text;
  v_otk_key text;
BEGIN
  -- 1. Service role (supabaseAdmin backend calls) — always trusted, skip all guards
  v_caller_role := current_setting('request.jwt.claims', true)::json->>'role';
  IF v_caller_role = 'service_role' THEN
    -- Trusted backend — fall through to OTK consumption below
    NULL;
  ELSE
    -- 2. Extract caller identity from JWT
    v_caller_id := current_setting('request.jwt.claims', true)::json->>'sub';
    IF v_caller_id IS NULL THEN
      RAISE EXCEPTION 'unauthorized: no JWT subject';
    END IF;

    -- 3. Self-fetch always allowed (fetching your own bundle)
    IF v_caller_id != p_user_id THEN
      -- 4. Cross-user fetch: verify caller shares at least one space with target
      SELECT EXISTS (
        SELECT 1
        FROM space_members sm1
        INNER JOIN space_members sm2 ON sm1.space_id = sm2.space_id
        WHERE sm1.user_id = v_caller_id
          AND sm2.user_id = p_user_id
        LIMIT 1
      ) INTO v_shared_space;

      IF NOT v_shared_space THEN
        RAISE EXCEPTION 'forbidden: no shared space with target user';
      END IF;
    END IF;
  END IF;

  -- 5. Atomically consume one OTK (FOR UPDATE SKIP LOCKED prevents races)
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

-- Re-apply permission grants (DROP FUNCTION removes them)
REVOKE EXECUTE ON FUNCTION fetch_key_bundle(text, integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fetch_key_bundle(text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION fetch_key_bundle(text, integer) TO service_role;
