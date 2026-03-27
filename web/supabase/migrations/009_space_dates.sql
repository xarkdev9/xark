-- 009_space_dates.sql
-- Spec: docs/superpowers/specs/2026-03-13-xark-capabilities-design.md (Section 1)
-- First-class trip dates entity. One row per space. Versioned for optimistic concurrency.

CREATE TABLE IF NOT EXISTS space_dates (
  space_id    text PRIMARY KEY REFERENCES spaces(id) ON DELETE CASCADE,
  start_date  date NOT NULL,
  end_date    date NOT NULL,
  destination text,
  label       text,
  set_by      text REFERENCES users(id),
  version     integer NOT NULL DEFAULT 1,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now(),
  CONSTRAINT valid_range CHECK (end_date >= start_date)
);

-- RLS: auth.uid()::text pattern per 003_rls_policies.sql (Firebase UID via JWT bridge)
ALTER TABLE space_dates ENABLE ROW LEVEL SECURITY;

CREATE POLICY sd_read ON space_dates FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM space_members sm
    WHERE sm.space_id = space_dates.space_id
    AND sm.user_id = auth.uid()::text
  )
);

-- All writes via supabaseAdmin (service role) in API routes.
-- Separate policies per operation (consistent with 003_rls_policies.sql pattern).
-- NOTE: service_role key bypasses RLS entirely, so these are defense-in-depth.
CREATE POLICY sd_insert ON space_dates FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY sd_update ON space_dates FOR UPDATE USING (
  auth.role() = 'service_role'
) WITH CHECK (auth.role() = 'service_role');

CREATE POLICY sd_delete ON space_dates FOR DELETE USING (
  auth.role() = 'service_role'
);
