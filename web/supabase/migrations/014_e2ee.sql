-- XARK OS v2.0 — E2EE Migration
-- End-to-end encrypted chat: key distribution, encrypted message storage,
-- constraint detection, device management.

-- ══════════════════════════════════════════════════════════════
-- 1. KEY DISTRIBUTION TABLES
-- ══════════════════════════════════════════════════════════════

-- Public key bundles — one per (user, device). Server NEVER sees private keys.
CREATE TABLE IF NOT EXISTS key_bundles (
  user_id          text NOT NULL,
  device_id        integer NOT NULL,
  identity_key     text NOT NULL,          -- base64 Ed25519 public key
  signed_pre_key   text NOT NULL,          -- base64 Curve25519 public key, rotated monthly
  signed_pre_key_id integer NOT NULL,      -- numeric ID for session reference
  pre_key_sig      text NOT NULL,          -- Ed25519 signature over signed_pre_key
  updated_at       timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, device_id)
);

-- Single-use pre-keys, consumed atomically via fetch_key_bundle RPC
CREATE TABLE IF NOT EXISTS one_time_pre_keys (
  id               text PRIMARY KEY,
  user_id          text NOT NULL,
  device_id        integer NOT NULL,
  public_key       text NOT NULL           -- base64 Curve25519 public key
);

CREATE INDEX IF NOT EXISTS idx_otk_user_device ON one_time_pre_keys(user_id, device_id);

-- ══════════════════════════════════════════════════════════════
-- 2. MESSAGE SCHEMA CHANGES
-- ══════════════════════════════════════════════════════════════

-- Allow NULL content for E2EE messages (server never sees plaintext)
ALTER TABLE messages ALTER COLUMN content DROP NOT NULL;

-- Add E2EE columns to existing messages table
ALTER TABLE messages
  ADD COLUMN IF NOT EXISTS sender_device_id integer,
  ADD COLUMN IF NOT EXISTS message_type text NOT NULL DEFAULT 'legacy';

-- Backfill: existing messages with role='user' become 'legacy', role='xark' become 'xark', role='system' become 'system'
UPDATE messages SET message_type = 'legacy' WHERE message_type = 'legacy' AND role = 'user';
UPDATE messages SET message_type = 'xark' WHERE message_type = 'legacy' AND role = 'xark';
UPDATE messages SET message_type = 'system' WHERE message_type = 'legacy' AND role = 'system';

-- Ciphertext storage — per-device for 1:1, single row for groups
CREATE TABLE IF NOT EXISTS message_ciphertexts (
  id                  text PRIMARY KEY DEFAULT 'mc_' || gen_random_uuid()::text,
  message_id          text NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  recipient_id        text NOT NULL,        -- user_id for 1:1, '_group_' for Sender Key
  recipient_device_id integer NOT NULL,     -- device_id for 1:1, 0 for Sender Key
  ciphertext          text NOT NULL,        -- base64 AES-256-GCM ciphertext
  ratchet_header      text                  -- base64 Double Ratchet header (NULL for Sender Key)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mc_msg_recipient
  ON message_ciphertexts(message_id, recipient_id, recipient_device_id);
CREATE INDEX IF NOT EXISTS idx_mc_message_id ON message_ciphertexts(message_id);

-- ══════════════════════════════════════════════════════════════
-- 3. CONSTRAINT TABLES
-- ══════════════════════════════════════════════════════════════

-- Global constraints: travel with user across all spaces
CREATE TABLE IF NOT EXISTS user_constraints (
  id           text PRIMARY KEY DEFAULT 'uc_' || gen_random_uuid()::text,
  user_id      text NOT NULL,
  type         text NOT NULL,              -- 'dietary' | 'accessibility' | 'alcohol'
  value        text NOT NULL,              -- 'vegan' | 'no_shellfish' | 'wheelchair'
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, type, value)
);

-- Space-specific constraints
CREATE TABLE IF NOT EXISTS space_constraints (
  id           text PRIMARY KEY DEFAULT 'sc_' || gen_random_uuid()::text,
  space_id     text NOT NULL,
  user_id      text NOT NULL,
  type         text NOT NULL,              -- 'budget' | 'date' | 'location_pref'
  value        text NOT NULL,              -- '$150' | 'near beach'
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE(space_id, user_id, type)
);

-- Prompt dismissal state (cross-device sync)
CREATE TABLE IF NOT EXISTS constraint_prompts (
  message_id   text NOT NULL,
  user_id      text NOT NULL,
  action       text NOT NULL,              -- 'accepted' | 'dismissed'
  created_at   timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (message_id, user_id)
);

-- ══════════════════════════════════════════════════════════════
-- 4. RPCs
-- ══════════════════════════════════════════════════════════════

-- Atomic OTK fetching — prevents race conditions at scale
CREATE OR REPLACE FUNCTION fetch_key_bundle(p_user_id text, p_device_id integer)
RETURNS TABLE(identity_key text, signed_pre_key text, signed_pre_key_id integer, pre_key_sig text, otk_public text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_otk_key text;
BEGIN
  -- Atomic: grab one OTK, lock it, delete it
  DELETE FROM one_time_pre_keys
  WHERE id = (
    SELECT id FROM one_time_pre_keys
    WHERE user_id = p_user_id AND device_id = p_device_id
    LIMIT 1 FOR UPDATE SKIP LOCKED
  ) RETURNING public_key INTO v_otk_key;

  RETURN QUERY
  SELECT kb.identity_key, kb.signed_pre_key, kb.signed_pre_key_id, kb.pre_key_sig, v_otk_key
  FROM key_bundles kb
  WHERE kb.user_id = p_user_id AND kb.device_id = p_device_id;
END; $$;

-- Device revocation — SECURITY DEFINER, service-role only
CREATE OR REPLACE FUNCTION revoke_device(p_user_id text, p_device_id integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM key_bundles
    WHERE user_id = p_user_id AND device_id = p_device_id;
  DELETE FROM one_time_pre_keys
    WHERE user_id = p_user_id AND device_id = p_device_id;
  PERFORM pg_notify('device_revoked',
    json_build_object('user_id', p_user_id, 'device_id', p_device_id)::text);
END; $$;

-- @xark plaintext TTL auto-purge
CREATE OR REPLACE FUNCTION purge_expired_xark_messages()
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE deleted_count integer;
BEGIN
  DELETE FROM messages
  WHERE message_type = 'xark'
    AND (
      (space_id IN (
        SELECT space_id FROM space_dates
        WHERE end_date < CURRENT_DATE - INTERVAL '30 days'
      ))
      OR
      (space_id NOT IN (SELECT space_id FROM space_dates)
       AND created_at < NOW() - INTERVAL '90 days')
    );
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END; $$;

-- ══════════════════════════════════════════════════════════════
-- 5. RLS POLICIES
-- ══════════════════════════════════════════════════════════════

ALTER TABLE key_bundles ENABLE ROW LEVEL SECURITY;
ALTER TABLE one_time_pre_keys ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_ciphertexts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_constraints ENABLE ROW LEVEL SECURITY;
ALTER TABLE space_constraints ENABLE ROW LEVEL SECURITY;
ALTER TABLE constraint_prompts ENABLE ROW LEVEL SECURITY;

-- Key bundles: anyone can read (public keys), only owner can write
CREATE POLICY key_bundles_select ON key_bundles FOR SELECT USING (true);
CREATE POLICY key_bundles_insert ON key_bundles FOR INSERT
  WITH CHECK (user_id = auth.jwt()->>'sub');
CREATE POLICY key_bundles_update ON key_bundles FOR UPDATE
  USING (user_id = auth.jwt()->>'sub');
CREATE POLICY key_bundles_delete ON key_bundles FOR DELETE
  USING (user_id = auth.jwt()->>'sub');

-- OTKs: anyone can read (needed for key exchange), only owner can insert
CREATE POLICY otk_select ON one_time_pre_keys FOR SELECT USING (true);
CREATE POLICY otk_insert ON one_time_pre_keys FOR INSERT
  WITH CHECK (user_id = auth.jwt()->>'sub');

-- Ciphertexts: recipients can read their own, sender can insert
CREATE POLICY mc_select ON message_ciphertexts FOR SELECT
  USING (
    recipient_id = auth.jwt()->>'sub'
    OR recipient_id = '_group_'
    OR message_id IN (
      SELECT id FROM messages WHERE user_id = auth.jwt()->>'sub'
    )
  );
CREATE POLICY mc_insert ON message_ciphertexts FOR INSERT
  WITH CHECK (false);  -- Inserts ONLY via service role in /api/message — deny all client-side inserts

-- User constraints: owner can CRUD
CREATE POLICY uc_select ON user_constraints FOR SELECT
  USING (user_id = auth.jwt()->>'sub');
CREATE POLICY uc_insert ON user_constraints FOR INSERT
  WITH CHECK (user_id = auth.jwt()->>'sub');
CREATE POLICY uc_update ON user_constraints FOR UPDATE
  USING (user_id = auth.jwt()->>'sub');
CREATE POLICY uc_delete ON user_constraints FOR DELETE
  USING (user_id = auth.jwt()->>'sub');

-- Space constraints: space members can read, owner can write
CREATE POLICY sc_select ON space_constraints FOR SELECT
  USING (space_id IN (SELECT auth_user_space_ids()));
CREATE POLICY sc_insert ON space_constraints FOR INSERT
  WITH CHECK (user_id = auth.jwt()->>'sub');
CREATE POLICY sc_update ON space_constraints FOR UPDATE
  USING (user_id = auth.jwt()->>'sub');
CREATE POLICY sc_delete ON space_constraints FOR DELETE
  USING (user_id = auth.jwt()->>'sub');

-- Constraint prompts: owner can CRUD
CREATE POLICY cp_select ON constraint_prompts FOR SELECT
  USING (user_id = auth.jwt()->>'sub');
CREATE POLICY cp_insert ON constraint_prompts FOR INSERT
  WITH CHECK (user_id = auth.jwt()->>'sub');
CREATE POLICY cp_update ON constraint_prompts FOR UPDATE
  USING (user_id = auth.jwt()->>'sub');

-- ══════════════════════════════════════════════════════════════
-- 6. REALTIME PUBLICATION
-- ══════════════════════════════════════════════════════════════

ALTER PUBLICATION supabase_realtime ADD TABLE message_ciphertexts;
ALTER PUBLICATION supabase_realtime ADD TABLE key_bundles;
ALTER PUBLICATION supabase_realtime ADD TABLE constraint_prompts;

-- ══════════════════════════════════════════════════════════════
-- 7. INDEXES
-- ══════════════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_messages_type ON messages(message_type);
CREATE INDEX IF NOT EXISTS idx_uc_user ON user_constraints(user_id);
CREATE INDEX IF NOT EXISTS idx_sc_space ON space_constraints(space_id);
