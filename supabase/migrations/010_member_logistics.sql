-- 010_member_logistics.sql
-- Spec: docs/superpowers/specs/2026-03-13-xark-capabilities-design.md (Section 3)
-- Per-user scoped logistics. Three-source passive assembly model.

-- ══════════════════════════════════════
-- 1. Add home_city to users table
-- ══════════════════════════════════════

ALTER TABLE users ADD COLUMN IF NOT EXISTS home_city text;

-- NOTE: fn_restrict_user_update (003_rls_policies.sql) freezes id, phone,
-- password_hash, created_at via allowlist. home_city passes through by design
-- (new columns not in the freeze list are mutable). This is intentional.

-- ══════════════════════════════════════
-- 2. Create member_logistics table
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS member_logistics (
  space_id    text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  user_id     text NOT NULL REFERENCES users(id),
  category    text NOT NULL CHECK (category IN (
    'flight_outbound', 'flight_return', 'ground_transport', 'visa', 'insurance'
  )),
  origin      text,
  destination text,
  state       text NOT NULL DEFAULT 'missing' CHECK (state IN (
    'missing', 'searching', 'proposed', 'locked', 'needs_review'
  )),
  item_id     text REFERENCES decision_items(id) ON DELETE SET NULL,
  source      text CHECK (source IN ('profile', 'creator', 'chat', 'manual')),
  confidence  real CHECK (confidence >= 0 AND confidence <= 1),
  version     integer NOT NULL DEFAULT 1,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  PRIMARY KEY (space_id, user_id, category)
);

CREATE INDEX IF NOT EXISTS idx_ml_space ON member_logistics(space_id);
CREATE INDEX IF NOT EXISTS idx_ml_user  ON member_logistics(user_id, state);

-- ══════════════════════════════════════
-- 3. RLS Policies (auth.uid()::text per 003_rls_policies.sql pattern)
-- ══════════════════════════════════════

ALTER TABLE member_logistics ENABLE ROW LEVEL SECURITY;

-- Read: space members only
CREATE POLICY ml_read ON member_logistics FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM space_members sm
    WHERE sm.space_id = member_logistics.space_id
    AND sm.user_id = auth.uid()::text
  )
);

-- Update own rows only
CREATE POLICY ml_update_own ON member_logistics FOR UPDATE USING (
  user_id = auth.uid()::text
) WITH CHECK (user_id = auth.uid()::text);

-- Insert: service role (onMemberJoin) OR own rows by space members
CREATE POLICY ml_insert ON member_logistics FOR INSERT WITH CHECK (
  auth.role() = 'service_role'
  OR (
    user_id = auth.uid()::text
    AND EXISTS (
      SELECT 1 FROM space_members sm
      WHERE sm.space_id = member_logistics.space_id
      AND sm.user_id = auth.uid()::text
    )
  )
);

-- Delete own rows (self-correction)
CREATE POLICY ml_delete_own ON member_logistics FOR DELETE USING (
  user_id = auth.uid()::text
);
