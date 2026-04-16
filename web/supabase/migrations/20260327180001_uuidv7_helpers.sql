-- BACKEND-01: UUIDv7 server-side helpers.
-- uuidv7_to_timestamptz: extract millisecond-precision timestamp from UUIDv7.
-- tombstone_message: redact message content + delete ciphertexts (GDPR / right-to-delete).

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
  -- Authorization: only the message sender can tombstone their own message
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
