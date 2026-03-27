-- BACKEND-05: Auto-creation function for future ciphertext partitions.
-- Call monthly via pg_cron or application-level scheduler to ensure
-- next month's partition exists before any writes land in it.

CREATE OR REPLACE FUNCTION create_next_ciphertext_partition()
RETURNS TEXT AS $$
DECLARE
  next_month DATE := date_trunc('month', now() + interval '1 month');
  following_month DATE := next_month + interval '1 month';
  partition_name TEXT := 'message_ciphertexts_' || to_char(next_month, 'YYYY_MM');
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = partition_name
  ) THEN
    EXECUTE format(
      'CREATE TABLE %I PARTITION OF message_ciphertexts
       FOR VALUES FROM (%L) TO (%L)',
      partition_name, next_month, following_month
    );
    RETURN 'Created partition: ' || partition_name;
  ELSE
    RETURN 'Partition already exists: ' || partition_name;
  END IF;
END;
$$ LANGUAGE plpgsql;
