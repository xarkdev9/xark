-- XARK OS v2.0 — E2EE Wiring Migration
-- Sender Key distribution support: device registry RPC, updated fetch_key_bundle,
-- recipient index for ciphertext lookups.

-- ══════════════════════════════════════════════════════════════
-- 1. SPACE MEMBER DEVICE REGISTRY
-- ══════════════════════════════════════════════════════════════

-- Returns all (user_id, device_id) pairs for space members who have
-- registered key bundles, excluding the caller.
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

-- ══════════════════════════════════════════════════════════════
-- 2. UPDATED fetch_key_bundle — returns OTK ID
-- ══════════════════════════════════════════════════════════════

-- Drop the old function to replace return type
DROP FUNCTION IF EXISTS fetch_key_bundle(text, integer);

CREATE OR REPLACE FUNCTION fetch_key_bundle(p_user_id text, p_device_id integer)
RETURNS TABLE(identity_key text, signed_pre_key text, signed_pre_key_id integer, pre_key_sig text, otk_id text, otk_public text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_otk_id text; v_otk_key text;
BEGIN
  -- Atomically consume one OTK (FOR UPDATE SKIP LOCKED prevents races)
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

-- ══════════════════════════════════════════════════════════════
-- 3. RECIPIENT INDEX FOR CIPHERTEXT LOOKUPS
-- ══════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_mc_recipient ON message_ciphertexts(recipient_id, recipient_device_id);
