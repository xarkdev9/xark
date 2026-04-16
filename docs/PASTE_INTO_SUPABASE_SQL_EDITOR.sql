-- ============================================
-- ALL FORTRESS MIGRATIONS — CORRECTED FOR LIVE SCHEMA
-- Paste into Supabase SQL Editor and run
-- ============================================

-- 1. Add missing columns to messages table
ALTER TABLE messages ADD COLUMN IF NOT EXISTS server_seq BIGINT;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS reply_to_message_id UUID;
ALTER TABLE messages ADD COLUMN IF NOT EXISTS server_content TEXT;

-- 2. Add created_at to message_ciphertexts
ALTER TABLE message_ciphertexts ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ;

-- 3. Group sequences table
CREATE TABLE IF NOT EXISTS group_sequences (
  group_id TEXT PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
  seq BIGINT NOT NULL DEFAULT 0
);

-- 4. UUIDv7 helpers
CREATE OR REPLACE FUNCTION uuidv7_to_timestamptz(id UUID) RETURNS TIMESTAMPTZ AS $$
  SELECT to_timestamp(
    ('x' || left(replace(id::text, '-', ''), 12))::bit(48)::bigint / 1000.0
  );
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

CREATE OR REPLACE FUNCTION tombstone_message(p_message_id UUID) RETURNS VOID AS $$
DECLARE
  v_time TIMESTAMPTZ := uuidv7_to_timestamptz(p_message_id);
  v_caller TEXT := auth.jwt()->>'sub';
  v_owner TEXT;
BEGIN
  SELECT user_id INTO v_owner FROM messages WHERE id = p_message_id;
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'message_not_found';
  END IF;
  IF v_owner != v_caller THEN
    RAISE EXCEPTION 'not_message_owner';
  END IF;
  UPDATE messages SET message_type = 'tombstone' WHERE id = p_message_id;
  DELETE FROM message_ciphertexts
  WHERE message_id = p_message_id
    AND created_at >= date_trunc('month', v_time)
    AND created_at < date_trunc('month', v_time) + interval '1 month';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

REVOKE EXECUTE ON FUNCTION tombstone_message FROM PUBLIC;
GRANT EXECUTE ON FUNCTION tombstone_message TO authenticated;

-- 5. Atomic send_e2ee_message RPC
CREATE OR REPLACE FUNCTION send_e2ee_message(
  p_message_id       UUID,
  p_group_id         TEXT,
  p_sender_id        TEXT,
  p_sender_device_id INTEGER,
  p_message_type     TEXT,
  p_role             TEXT DEFAULT 'user',
  p_server_content   TEXT DEFAULT NULL,
  p_reply_to_id      UUID DEFAULT NULL,
  p_ciphertexts      JSONB DEFAULT '[]'::JSONB,
  p_distributions    JSONB DEFAULT '[]'::JSONB
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_time TIMESTAMPTZ := uuidv7_to_timestamptz(p_message_id);
  v_seq BIGINT;
  v_inserted_seq BIGINT;
  v_inserted_time TIMESTAMPTZ;
  v_ct JSONB;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM group_members WHERE group_id = p_group_id AND user_id = p_sender_id
  ) THEN
    RAISE EXCEPTION 'not_a_member';
  END IF;

  IF abs(extract(epoch FROM v_client_time) - extract(epoch FROM now())) > 300 THEN
    RAISE EXCEPTION 'invalid_clock_skew';
  END IF;

  UPDATE group_sequences SET seq = seq + 1
  WHERE group_id = p_group_id
  RETURNING seq INTO v_seq;

  IF v_seq IS NULL THEN
    INSERT INTO group_sequences (group_id, seq) VALUES (p_group_id, 1)
    ON CONFLICT (group_id) DO UPDATE SET seq = group_sequences.seq + 1
    RETURNING seq INTO v_seq;
  END IF;

  INSERT INTO messages (id, group_id, user_id, sender_device_id, message_type,
    role, server_content, reply_to_message_id, server_seq, created_at)
  VALUES (p_message_id, p_group_id, p_sender_id, p_sender_device_id,
    p_message_type, p_role, p_server_content, p_reply_to_id, v_seq, v_client_time)
  ON CONFLICT (id) DO NOTHING
  RETURNING server_seq, created_at INTO v_inserted_seq, v_inserted_time;

  IF v_inserted_seq IS NULL THEN
    SELECT server_seq, created_at INTO v_inserted_seq, v_inserted_time
    FROM messages WHERE id = p_message_id;
    RETURN jsonb_build_object(
      'message_id', p_message_id,
      'server_seq', v_inserted_seq,
      'created_at', v_inserted_time,
      'status', 'deduplicated'
    );
  END IF;

  FOR v_ct IN SELECT * FROM jsonb_array_elements(p_ciphertexts) LOOP
    INSERT INTO message_ciphertexts (
      message_id, recipient_id, recipient_device_id, ciphertext, ratchet_header, created_at
    ) VALUES (
      p_message_id,
      v_ct->>'recipient_id',
      (v_ct->>'recipient_device_id')::INTEGER,
      v_ct->>'ciphertext',
      v_ct->>'ratchet_header',
      v_client_time
    ) ON CONFLICT (message_id, recipient_id, recipient_device_id) DO NOTHING;
  END LOOP;

  FOR v_ct IN SELECT * FROM jsonb_array_elements(p_distributions) LOOP
    INSERT INTO message_ciphertexts (
      message_id, recipient_id, recipient_device_id, ciphertext, ratchet_header, created_at
    ) VALUES (
      p_message_id,
      v_ct->>'recipient_id',
      (v_ct->>'recipient_device_id')::INTEGER,
      v_ct->>'ciphertext',
      v_ct->>'ratchet_header',
      v_client_time
    ) ON CONFLICT (message_id, recipient_id, recipient_device_id) DO NOTHING;
  END LOOP;

  RETURN jsonb_build_object(
    'message_id', p_message_id,
    'server_seq', v_inserted_seq,
    'created_at', v_inserted_time,
    'status', 'inserted'
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION send_e2ee_message FROM PUBLIC;
GRANT EXECUTE ON FUNCTION send_e2ee_message TO authenticated;

-- 6. Read watermarks
CREATE TABLE IF NOT EXISTS read_watermarks (
  group_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  last_read_seq BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

ALTER TABLE read_watermarks ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY rw_select ON read_watermarks FOR SELECT USING (user_id = auth.jwt()->>'sub');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY rw_upsert ON read_watermarks FOR INSERT WITH CHECK (user_id = auth.jwt()->>'sub');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY rw_update ON read_watermarks FOR UPDATE USING (user_id = auth.jwt()->>'sub');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION mark_group_read(p_group_id TEXT, p_seq BIGINT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO read_watermarks (group_id, user_id, last_read_seq, updated_at)
  VALUES (p_group_id, auth.jwt()->>'sub', p_seq, now())
  ON CONFLICT (group_id, user_id) DO UPDATE
  SET last_read_seq = GREATEST(read_watermarks.last_read_seq, p_seq), updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Partition cron function
CREATE OR REPLACE FUNCTION create_next_ciphertext_partition()
RETURNS TEXT AS $$
DECLARE
  next_month DATE := date_trunc('month', now() + interval '1 month');
  following_month DATE := next_month + interval '1 month';
  partition_name TEXT := 'message_ciphertexts_' || to_char(next_month, 'YYYY_MM');
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relname = partition_name) THEN
    EXECUTE format('CREATE TABLE %I PARTITION OF message_ciphertexts FOR VALUES FROM (%L) TO (%L)', partition_name, next_month, following_month);
    RETURN 'Created partition: ' || partition_name;
  ELSE
    RETURN 'Partition already exists: ' || partition_name;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- 8. Drop old rate limiter
DROP TABLE IF EXISTS rate_limiter;

-- 9. SK acknowledgments
CREATE TABLE IF NOT EXISTS sk_acknowledgments (
  group_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  recipient_id TEXT NOT NULL,
  recipient_device_id INTEGER NOT NULL,
  epoch INTEGER NOT NULL DEFAULT 1,
  acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, sender_id, recipient_id, recipient_device_id)
);

ALTER TABLE sk_acknowledgments ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY sk_ack_recipient_select ON sk_acknowledgments FOR SELECT USING (recipient_id = auth.jwt()->>'sub');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY sk_ack_sender_select ON sk_acknowledgments FOR SELECT USING (sender_id = auth.jwt()->>'sub');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY sk_ack_insert ON sk_acknowledgments FOR INSERT WITH CHECK (recipient_id = auth.jwt()->>'sub');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  CREATE POLICY sk_ack_delete ON sk_acknowledgments FOR DELETE USING (sender_id = auth.jwt()->>'sub');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE OR REPLACE FUNCTION batch_sk_ack(p_acks JSONB) RETURNS VOID AS $$
DECLARE
  v_user_id TEXT := auth.jwt()->>'sub';
  v_ack JSONB;
BEGIN
  FOR v_ack IN SELECT * FROM jsonb_array_elements(p_acks) LOOP
    INSERT INTO sk_acknowledgments (group_id, sender_id, recipient_id, recipient_device_id)
    VALUES (v_ack->>'group_id', v_ack->>'sender_id', v_user_id, 0)
    ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. PQXDH columns
ALTER TABLE key_bundles ADD COLUMN IF NOT EXISTS kyber_pre_key TEXT;
ALTER TABLE key_bundles ADD COLUMN IF NOT EXISTS kyber_pre_key_sig TEXT;
ALTER TABLE one_time_pre_keys ADD COLUMN IF NOT EXISTS kyber_otk TEXT;

-- 11. Refresh PostgREST schema cache
NOTIFY pgrst, 'reload schema';
