CREATE TABLE sk_acknowledgments (
  group_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  recipient_id TEXT NOT NULL,
  recipient_device_id INTEGER NOT NULL,
  epoch INTEGER NOT NULL DEFAULT 1,
  acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, sender_id, recipient_id, recipient_device_id)
);

ALTER TABLE sk_acknowledgments ENABLE ROW LEVEL SECURITY;

CREATE POLICY sk_ack_recipient_select ON sk_acknowledgments FOR SELECT
  USING (recipient_id = auth.jwt()->>'sub');
CREATE POLICY sk_ack_sender_select ON sk_acknowledgments FOR SELECT
  USING (sender_id = auth.jwt()->>'sub');
CREATE POLICY sk_ack_insert ON sk_acknowledgments FOR INSERT
  WITH CHECK (recipient_id = auth.jwt()->>'sub');
CREATE POLICY sk_ack_delete ON sk_acknowledgments FOR DELETE
  USING (sender_id = auth.jwt()->>'sub');

CREATE OR REPLACE FUNCTION batch_sk_ack(
  p_acks JSONB
) RETURNS VOID AS $$
DECLARE
  v_user_id TEXT := auth.jwt()->>'sub';
  v_device_id INTEGER := 0;
  v_ack JSONB;
BEGIN
  FOR v_ack IN SELECT * FROM jsonb_array_elements(p_acks) LOOP
    INSERT INTO sk_acknowledgments (group_id, sender_id, recipient_id, recipient_device_id)
    VALUES (v_ack->>'group_id', v_ack->>'sender_id', v_user_id, v_device_id)
    ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
