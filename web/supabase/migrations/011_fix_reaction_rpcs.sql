-- Fix react_to_item: auth.uid()::text → auth.jwt()->>'sub'
-- Our user IDs are text (e.g., "name_ram"), not UUIDs.
-- auth.uid() requires UUID format and silently fails for text IDs.

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
  v_user_id text;
BEGIN
  v_user_id := auth.jwt()->>'sub';
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated: no user in JWT';
  END IF;

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

  IF v_is_locked THEN
    RAISE EXCEPTION 'item_locked: cannot react to a locked item';
  END IF;

  -- Verify membership
  IF NOT EXISTS (
    SELECT 1 FROM space_members
    WHERE space_id = v_space_id AND user_id = v_user_id
  ) THEN
    RAISE EXCEPTION 'not_a_member: you are not a member of this space';
  END IF;

  -- Upsert reaction
  INSERT INTO reactions (item_id, user_id, signal, weight, created_at)
  VALUES (p_item_id, v_user_id, p_signal, v_weight, now())
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

-- Recreate unreact_to_item with correct return type
DROP FUNCTION IF EXISTS unreact_to_item(text);
CREATE OR REPLACE FUNCTION unreact_to_item(p_item_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_space_id text;
  v_weighted_score float;
  v_agreement_score float;
  v_member_count integer;
  v_reactor_count integer;
  v_user_id text;
BEGIN
  v_user_id := auth.jwt()->>'sub';
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated: no user in JWT';
  END IF;

  -- Get space_id
  SELECT space_id INTO v_space_id
  FROM decision_items WHERE id = p_item_id;

  IF v_space_id IS NULL THEN
    RAISE EXCEPTION 'item_not_found: decision item does not exist';
  END IF;

  -- Delete reaction
  DELETE FROM reactions
  WHERE item_id = p_item_id AND user_id = v_user_id;

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
