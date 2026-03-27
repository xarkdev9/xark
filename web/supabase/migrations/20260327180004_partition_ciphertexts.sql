-- BACKEND-05: Partition message_ciphertexts by month (range partitions on created_at).
-- created_at is populated by the atomic RPC from UUIDv7 timestamp, not DEFAULT now().
-- Partition-key-inclusive unique constraint required by PostgreSQL.

CREATE TABLE message_ciphertexts_new (
  id UUID DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  recipient_id TEXT NOT NULL,
  recipient_device_id INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  ratchet_header TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  UNIQUE (message_id, recipient_id, recipient_device_id, created_at)
) PARTITION BY RANGE (created_at);

DO $$
DECLARE
  start_date DATE := date_trunc('month', now() - interval '6 months');
  end_date DATE := date_trunc('month', now() + interval '2 months');
  current_date_var DATE := start_date;
  next_date DATE;
  partition_name TEXT;
BEGIN
  WHILE current_date_var < end_date LOOP
    next_date := current_date_var + interval '1 month';
    partition_name := 'message_ciphertexts_' || to_char(current_date_var, 'YYYY_MM');
    EXECUTE format(
      'CREATE TABLE %I PARTITION OF message_ciphertexts_new
       FOR VALUES FROM (%L) TO (%L)',
      partition_name, current_date_var, next_date
    );
    current_date_var := next_date;
  END LOOP;
END $$;

CREATE INDEX idx_ct_recipient_sync ON message_ciphertexts_new
  (recipient_id, recipient_device_id, created_at);
CREATE INDEX idx_ct_message_time ON message_ciphertexts_new
  (message_id, created_at);

ALTER TABLE message_ciphertexts_new ENABLE ROW LEVEL SECURITY;

INSERT INTO message_ciphertexts_new (id, message_id, recipient_id, recipient_device_id,
  ciphertext, ratchet_header, created_at)
SELECT mc.id, mc.message_id, mc.recipient_id, mc.recipient_device_id,
  mc.ciphertext, mc.ratchet_header,
  COALESCE(mc.created_at, m.created_at, now())
FROM message_ciphertexts mc
JOIN messages m ON m.id = mc.message_id;

ALTER TABLE message_ciphertexts RENAME TO message_ciphertexts_old;
ALTER TABLE message_ciphertexts_new RENAME TO message_ciphertexts;
