-- BACKEND-01: Atomic send_e2ee_message RPC.
-- Single transaction: membership check -> clock skew guard -> sequence bump ->
-- message insert (idempotent) -> ciphertext fan-out -> distribution fan-out.
-- Fixes ghost messages, duplicate ciphertexts, and retry-bricking bugs.

-- Ensure message_ciphertexts has created_at for partition-readiness (Task 3).
ALTER TABLE message_ciphertexts ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ;

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
  -- Membership guard: prevent cross-group injection
  IF NOT EXISTS (
    SELECT 1 FROM group_members WHERE group_id = p_group_id AND user_id = p_sender_id
  ) THEN
    RAISE EXCEPTION 'not_a_member';
  END IF;

  -- Clock skew guard: reject messages with >5min drift
  IF abs(extract(epoch FROM v_client_time) - extract(epoch FROM now())) > 300 THEN
    RAISE EXCEPTION 'invalid_clock_skew';
  END IF;

  -- Bump group sequence (UPSERT handles first message in new group)
  UPDATE group_sequences SET seq = seq + 1
  WHERE group_id = p_group_id
  RETURNING seq INTO v_seq;

  IF v_seq IS NULL THEN
    INSERT INTO group_sequences (group_id, seq) VALUES (p_group_id, 1)
    ON CONFLICT (group_id) DO UPDATE SET seq = group_sequences.seq + 1
    RETURNING seq INTO v_seq;
  END IF;

  -- Idempotent message insert (client-generated UUIDv7 dedup)
  INSERT INTO messages (id, group_id, user_id, sender_device_id, message_type,
    role, server_content, reply_to_message_id, server_seq, created_at)
  VALUES (p_message_id, p_group_id, p_sender_id, p_sender_device_id,
    p_message_type, p_role, p_server_content, p_reply_to_id, v_seq, v_client_time)
  ON CONFLICT (id) DO NOTHING
  RETURNING server_seq, created_at INTO v_inserted_seq, v_inserted_time;

  -- Dedup path: message already existed, return existing data
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

  -- Fan-out ciphertexts (per-recipient encrypted payloads)
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

  -- Fan-out Sender Key distribution ciphertexts
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
