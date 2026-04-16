-- BACKEND-01: Read watermarks replacing unread_counts.
-- Per-user, per-group last_read_seq pointer. No concurrent UPDATE deadlock.
-- mark_group_read uses GREATEST to prevent watermark regression.

CREATE TABLE read_watermarks (
  group_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  last_read_seq BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

ALTER TABLE read_watermarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY rw_select ON read_watermarks FOR SELECT
  USING (user_id = auth.jwt()->>'sub');
CREATE POLICY rw_upsert ON read_watermarks FOR INSERT
  WITH CHECK (user_id = auth.jwt()->>'sub');
CREATE POLICY rw_update ON read_watermarks FOR UPDATE
  USING (user_id = auth.jwt()->>'sub');

CREATE OR REPLACE FUNCTION mark_group_read(p_group_id TEXT, p_seq BIGINT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO read_watermarks (group_id, user_id, last_read_seq, updated_at)
  VALUES (p_group_id, auth.jwt()->>'sub', p_seq, now())
  ON CONFLICT (group_id, user_id) DO UPDATE
  SET last_read_seq = GREATEST(read_watermarks.last_read_seq, p_seq),
      updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
