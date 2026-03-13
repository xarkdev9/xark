-- Phase 0 Foundation: Triggers & RPC Functions
-- Run AFTER 001_foundation_schema.sql
-- Spec: docs/superpowers/specs/2026-03-12-phase0-foundation-design.md

-- ══════════════════════════════════════
-- HELPER: Password hash generator (used by seed script)
-- ══════════════════════════════════════

-- gen_hash: only callable by service_role (for seeding).
-- Any other caller gets an exception.
CREATE OR REPLACE FUNCTION gen_hash(p_password text)
RETURNS text
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  jwt_role text;
BEGIN
  BEGIN
    jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
  EXCEPTION WHEN OTHERS THEN
    jwt_role := NULL;
  END;

  IF jwt_role IS DISTINCT FROM 'service_role' THEN
    RAISE EXCEPTION 'gen_hash: only callable by service_role';
  END IF;

  RETURN crypt(p_password, gen_salt('bf', 10));
END;
$$;

-- ══════════════════════════════════════
-- TRIGGERS
-- ══════════════════════════════════════

-- Auto-add space creator as owner member
CREATE OR REPLACE FUNCTION fn_auto_add_space_owner()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO space_members (space_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner')
  ON CONFLICT (space_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_auto_add_space_owner ON spaces;
CREATE TRIGGER trg_auto_add_space_owner
  AFTER INSERT ON spaces
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_add_space_owner();

-- Update space last_activity_at on new message
CREATE OR REPLACE FUNCTION fn_update_space_activity()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE spaces SET last_activity_at = now() WHERE id = NEW.space_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_update_space_activity ON messages;
CREATE TRIGGER trg_update_space_activity
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_space_activity();

-- Set sender_name from users table on user messages
CREATE OR REPLACE FUNCTION fn_set_sender_name()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'user' AND NEW.user_id IS NOT NULL THEN
    SELECT display_name INTO NEW.sender_name
    FROM users WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_set_sender_name ON messages;
CREATE TRIGGER trg_set_sender_name
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION fn_set_sender_name();

-- Prevent client-side impersonation of @xark
CREATE OR REPLACE FUNCTION fn_enforce_xark_role()
RETURNS TRIGGER AS $$
DECLARE
  jwt_role text;
BEGIN
  IF NEW.role = 'xark' THEN
    BEGIN
      jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
    EXCEPTION WHEN OTHERS THEN
      jwt_role := NULL;
    END;

    IF jwt_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'xark_impersonation_blocked: only service_role can insert xark messages';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_enforce_xark_role ON messages;
CREATE TRIGGER trg_enforce_xark_role
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION fn_enforce_xark_role();

-- Force proposed_by to auth.uid() on decision_items insert
-- Service role can set proposed_by directly (for seeding)
CREATE OR REPLACE FUNCTION fn_force_proposed_by()
RETURNS TRIGGER AS $$
DECLARE
  jwt_role text;
BEGIN
  -- Service role (seed script, server-side) can set proposed_by directly
  BEGIN
    jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
  EXCEPTION WHEN OTHERS THEN
    jwt_role := NULL;
  END;

  IF jwt_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  -- For authenticated users, force proposed_by to their ID
  NEW.proposed_by := auth.uid()::text;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_force_proposed_by ON decision_items;
CREATE TRIGGER trg_force_proposed_by
  BEFORE INSERT ON decision_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_force_proposed_by();

-- ══════════════════════════════════════
-- RPC FUNCTIONS
-- ══════════════════════════════════════

-- react_to_item: Upsert reaction, recompute scores
CREATE OR REPLACE FUNCTION react_to_item(p_item_id text, p_signal text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_weight integer;
  v_space_id text;
  v_is_locked boolean;
  v_weighted_score float;
  v_agreement_score float;
  v_member_count integer;
  v_reactor_count integer;
BEGIN
  -- Validate signal
  IF p_signal NOT IN ('love_it', 'works_for_me', 'not_for_me') THEN
    RAISE EXCEPTION 'invalid_signal: must be love_it, works_for_me, or not_for_me';
  END IF;

  -- Map signal to weight
  v_weight := CASE p_signal
    WHEN 'love_it' THEN 5
    WHEN 'works_for_me' THEN 1
    WHEN 'not_for_me' THEN -3
  END;

  -- Get space_id, lock status, and verify item exists
  SELECT space_id, is_locked INTO v_space_id, v_is_locked
  FROM decision_items WHERE id = p_item_id;

  IF v_space_id IS NULL THEN
    RAISE EXCEPTION 'item_not_found: decision item does not exist';
  END IF;

  -- Cannot react to locked items (Constitution Section 7d)
  IF v_is_locked THEN
    RAISE EXCEPTION 'item_locked: cannot react to a locked item';
  END IF;

  -- Verify membership
  IF NOT EXISTS (
    SELECT 1 FROM space_members
    WHERE space_id = v_space_id AND user_id = auth.uid()::text
  ) THEN
    RAISE EXCEPTION 'not_a_member: you are not a member of this space';
  END IF;

  -- Upsert reaction
  INSERT INTO reactions (item_id, user_id, signal, weight, created_at)
  VALUES (p_item_id, auth.uid()::text, p_signal, v_weight, now())
  ON CONFLICT (item_id, user_id)
  DO UPDATE SET signal = EXCLUDED.signal, weight = EXCLUDED.weight, created_at = now();

  -- Recompute weighted_score
  SELECT COALESCE(SUM(weight), 0) INTO v_weighted_score
  FROM reactions WHERE item_id = p_item_id;

  -- Recompute agreement_score
  SELECT COUNT(DISTINCT user_id) INTO v_reactor_count
  FROM reactions WHERE item_id = p_item_id;

  SELECT COUNT(*) INTO v_member_count
  FROM space_members WHERE space_id = v_space_id;

  v_agreement_score := CASE WHEN v_member_count > 0
    THEN v_reactor_count::float / v_member_count::float
    ELSE 0 END;

  -- Update item scores
  UPDATE decision_items
  SET weighted_score = v_weighted_score,
      agreement_score = v_agreement_score
  WHERE id = p_item_id;

  RETURN jsonb_build_object(
    'weighted_score', v_weighted_score,
    'agreement_score', v_agreement_score
  );
END;
$$;

-- lock_item: Green-Lock Commitment Protocol
CREATE OR REPLACE FUNCTION lock_item(
  p_item_id text,
  p_proof_type text,
  p_proof_value text,
  p_expected_version integer
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item record;
  v_terminal_state text;
  v_rows_affected integer;
BEGIN
  -- Fetch item
  SELECT * INTO v_item FROM decision_items WHERE id = p_item_id;
  IF v_item IS NULL THEN
    RAISE EXCEPTION 'item_not_found';
  END IF;

  -- Verify membership
  IF NOT EXISTS (
    SELECT 1 FROM space_members
    WHERE space_id = v_item.space_id AND user_id = auth.uid()::text
  ) THEN
    RAISE EXCEPTION 'not_a_member';
  END IF;

  -- Check not already locked
  IF v_item.is_locked THEN
    RAISE EXCEPTION 'already_locked: item is already committed';
  END IF;

  -- Verify proof
  IF p_proof_value IS NULL OR p_proof_value = '' THEN
    RAISE EXCEPTION 'proof_required: commitment proof cannot be empty';
  END IF;

  -- Optimistic concurrency
  IF v_item.version != p_expected_version THEN
    RAISE EXCEPTION 'version_conflict: expected %, got %', p_expected_version, v_item.version;
  END IF;

  -- Resolve terminal state
  v_terminal_state := CASE v_item.state
    WHEN 'proposed' THEN 'locked'
    WHEN 'ranked' THEN 'locked'
    WHEN 'nominated' THEN 'chosen'
    WHEN 'researching' THEN 'purchased'
    WHEN 'shortlisted' THEN 'purchased'
    WHEN 'negotiating' THEN 'purchased'
    WHEN 'considering' THEN 'decided'
    WHEN 'leaning' THEN 'decided'
    ELSE 'locked'
  END;

  -- Commit
  UPDATE decision_items SET
    is_locked = true,
    locked_at = now(),
    state = v_terminal_state,
    commitment_proof = jsonb_build_object(
      'type', p_proof_type,
      'value', p_proof_value,
      'submittedBy', auth.uid()::text,
      'submittedAt', now()::text
    ),
    ownership_history = CASE
      WHEN ownership IS NOT NULL THEN ownership_history || jsonb_build_array(ownership)
      ELSE ownership_history
    END,
    ownership = jsonb_build_object(
      'ownerId', auth.uid()::text,
      'assignedAt', now()::text,
      'reason', 'booker'
    ),
    version = version + 1
  WHERE id = p_item_id AND version = p_expected_version;

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;
  IF v_rows_affected = 0 THEN
    RAISE EXCEPTION 'version_conflict: concurrent modification detected';
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'itemId', p_item_id,
    'lockedAt', now()::text,
    'state', v_terminal_state
  );
END;
$$;

-- transfer_ownership
CREATE OR REPLACE FUNCTION transfer_ownership(p_item_id text, p_new_owner_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item record;
BEGIN
  SELECT * INTO v_item FROM decision_items WHERE id = p_item_id;
  IF v_item IS NULL THEN
    RAISE EXCEPTION 'item_not_found';
  END IF;

  -- Verify caller is current owner
  IF (v_item.ownership->>'ownerId') IS DISTINCT FROM auth.uid()::text THEN
    RAISE EXCEPTION 'not_owner: only the current owner can transfer';
  END IF;

  -- Verify different owner
  IF p_new_owner_id = auth.uid()::text THEN
    RAISE EXCEPTION 'self_transfer: cannot transfer to yourself';
  END IF;

  -- Verify item is locked
  IF NOT v_item.is_locked THEN
    RAISE EXCEPTION 'not_locked: can only transfer locked items';
  END IF;

  -- Verify new owner is a space member
  IF NOT EXISTS (
    SELECT 1 FROM space_members
    WHERE space_id = v_item.space_id AND user_id = p_new_owner_id
  ) THEN
    RAISE EXCEPTION 'not_a_member: new owner must be a space member';
  END IF;

  -- Append old ownership to history, set new
  UPDATE decision_items SET
    ownership_history = ownership_history || jsonb_build_array(ownership),
    ownership = jsonb_build_object(
      'ownerId', p_new_owner_id,
      'assignedAt', now()::text,
      'reason', 'transfer'
    ),
    version = version + 1
  WHERE id = p_item_id;

  RETURN jsonb_build_object('success', true, 'newOwnerId', p_new_owner_id);
END;
$$;

-- invite_member
CREATE OR REPLACE FUNCTION invite_member(p_space_id text, p_user_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Verify caller is space owner
  IF NOT EXISTS (
    SELECT 1 FROM spaces
    WHERE id = p_space_id AND owner_id = auth.uid()::text
  ) THEN
    RAISE EXCEPTION 'not_space_owner: only the space owner can invite members';
  END IF;

  -- Verify target user exists
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'user_not_found: target user does not exist';
  END IF;

  -- Insert member (ignore if already member)
  INSERT INTO space_members (space_id, user_id, role)
  VALUES (p_space_id, p_user_id, 'member')
  ON CONFLICT (space_id, user_id) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'spaceId', p_space_id, 'userId', p_user_id);
END;
$$;

-- dev_login: Dev-mode authentication bypass
CREATE OR REPLACE FUNCTION dev_login(p_username text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user record;
  v_token text;
  v_payload jsonb;
BEGIN
  -- Gate: dev mode must be enabled
  IF current_setting('app.dev_mode', true) IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'dev_mode_disabled: dev_login is only available in dev mode';
  END IF;

  -- Look up user
  SELECT * INTO v_user FROM users
  WHERE display_name = p_username AND password_hash IS NOT NULL;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'user_not_found: no dev user with username %', p_username;
  END IF;

  -- Verify password
  IF v_user.password_hash != crypt(p_password, v_user.password_hash) THEN
    RAISE EXCEPTION 'invalid_credentials: wrong password';
  END IF;

  -- Build JWT payload (aud claim required by PostgREST)
  v_payload := jsonb_build_object(
    'sub', v_user.id,
    'role', 'authenticated',
    'aud', 'authenticated',
    'iss', 'supabase',
    'iat', extract(epoch from now())::integer,
    'exp', extract(epoch from (now() + interval '24 hours'))::integer
  );

  -- Sign JWT with Supabase JWT secret
  v_token := sign(v_payload, current_setting('app.jwt_secret'));

  RETURN jsonb_build_object(
    'token', v_token,
    'user_id', v_user.id,
    'display_name', v_user.display_name
  );
END;
$$;

-- dev_auto_login: Passwordless dev login for URL name param flow.
-- Only works in dev mode. No password check — just generates a JWT for the user.
CREATE OR REPLACE FUNCTION dev_auto_login(p_username text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user record;
  v_token text;
  v_payload jsonb;
BEGIN
  -- Gate: dev mode must be enabled
  IF current_setting('app.dev_mode', true) IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'dev_mode_disabled: dev_auto_login is only available in dev mode';
  END IF;

  -- Look up user by display_name
  SELECT * INTO v_user FROM users WHERE display_name = p_username;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'user_not_found: no user with username %', p_username;
  END IF;

  -- Build JWT payload
  v_payload := jsonb_build_object(
    'sub', v_user.id,
    'role', 'authenticated',
    'aud', 'authenticated',
    'iss', 'supabase',
    'iat', extract(epoch from now())::integer,
    'exp', extract(epoch from (now() + interval '24 hours'))::integer
  );

  -- Sign JWT
  v_token := sign(v_payload, current_setting('app.jwt_secret'));

  RETURN jsonb_build_object(
    'token', v_token,
    'user_id', v_user.id,
    'display_name', v_user.display_name
  );
END;
$$;
