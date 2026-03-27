-- XARK OS v2.0 — Security Hardening Migration
-- Fixes: member_logistics JWT sub, decision_items DELETE block, mc_insert lockdown
-- Created: 2026-03-15

-- ══════════════════════════════════════
-- 1. Fix member_logistics RLS: auth.uid()::text → auth.jwt()->>'sub'
--    (Missed in 20260313212810_fix_rls_jwt_sub.sql)
-- ══════════════════════════════════════

DROP POLICY IF EXISTS ml_read ON member_logistics;
CREATE POLICY ml_read ON member_logistics FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM space_members sm
    WHERE sm.space_id = member_logistics.space_id
    AND sm.user_id = (auth.jwt()->>'sub')
  )
);

DROP POLICY IF EXISTS ml_update_own ON member_logistics;
CREATE POLICY ml_update_own ON member_logistics FOR UPDATE
  USING (user_id = (auth.jwt()->>'sub'))
  WITH CHECK (user_id = (auth.jwt()->>'sub'));

DROP POLICY IF EXISTS ml_insert ON member_logistics;
CREATE POLICY ml_insert ON member_logistics FOR INSERT WITH CHECK (
  auth.role() = 'service_role'
  OR (
    user_id = (auth.jwt()->>'sub')
    AND EXISTS (
      SELECT 1 FROM space_members sm
      WHERE sm.space_id = member_logistics.space_id
      AND sm.user_id = (auth.jwt()->>'sub')
    )
  )
);

DROP POLICY IF EXISTS ml_delete_own ON member_logistics;
CREATE POLICY ml_delete_own ON member_logistics FOR DELETE
  USING (user_id = (auth.jwt()->>'sub'));

-- ══════════════════════════════════════
-- 2. Explicit DELETE block on decision_items
--    (Default deny is safe, but explicit is defense-in-depth)
-- ══════════════════════════════════════

CREATE POLICY items_delete_blocked ON decision_items
  FOR DELETE USING (false);

-- ══════════════════════════════════════
-- 3. Lock down message_ciphertexts INSERT
--    (Only service role in /api/message can insert)
--    NOTE: 014_e2ee.sql originally had WITH CHECK (true).
--    This migration overrides it.
-- ══════════════════════════════════════

DROP POLICY IF EXISTS mc_insert ON message_ciphertexts;
CREATE POLICY mc_insert ON message_ciphertexts FOR INSERT
  WITH CHECK (false);
