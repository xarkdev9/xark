-- XARK OS v2.0 — E2EE RLS Performance Fix
-- Replace the N+1 sub-query in message_ciphertexts SELECT policy
-- with a direct indexed column check + minimal sub-query for group messages only.

-- Drop existing policy
DROP POLICY IF EXISTS mc_select ON message_ciphertexts;
DROP POLICY IF EXISTS "message_ciphertexts_select" ON message_ciphertexts;

-- New performant policy:
-- 1:1 messages: direct column check (no sub-query, uses idx_mc_recipient index)
-- Group messages: minimal sub-query only for _group_ recipient (5% of traffic)
CREATE POLICY mc_select_v2 ON message_ciphertexts
  FOR SELECT USING (
    recipient_id = auth.jwt()->>'sub'
    OR (
      recipient_id = '_group_'
      AND message_id IN (
        SELECT id FROM messages
        WHERE space_id = ANY(auth_user_space_ids())
      )
    )
  );

-- Ensure index exists for the direct column check
CREATE INDEX IF NOT EXISTS idx_mc_recipient_id ON message_ciphertexts(recipient_id);
