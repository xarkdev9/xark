-- BACKEND-01: Group-scoped monotonic sequence counters.
-- Each group gets an independent sequence for gap-free server_seq assignment.
-- Backfills from existing messages to avoid sequence collisions.

CREATE TABLE group_sequences (
  group_id TEXT PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
  seq BIGINT NOT NULL DEFAULT 0
);

INSERT INTO group_sequences (group_id, seq)
SELECT group_id, COALESCE(MAX(server_seq), 0)
FROM messages
GROUP BY group_id
ON CONFLICT DO NOTHING;
