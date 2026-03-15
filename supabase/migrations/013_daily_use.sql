-- 013_daily_use.sql — Daily Use Foundation
-- Prerequisites: 012_perf_optimizations.sql must be applied first

-- Space invites for instant join links
CREATE TABLE IF NOT EXISTS space_invites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(6), 'hex'),
  space_id TEXT NOT NULL REFERENCES spaces(id),
  created_by TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '7 days',
  max_uses INTEGER DEFAULT NULL,
  use_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_space_invites_token ON space_invites(token);

-- User preferences (theme + layout)
ALTER TABLE users ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{"theme":"hearth","layout":"stream"}'::jsonb;

-- Space expiration for micro-space templates
ALTER TABLE spaces ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ DEFAULT NULL;

-- RLS for space_invites (uses auth_user_space_ids() SECURITY DEFINER function to avoid infinite recursion)
ALTER TABLE space_invites ENABLE ROW LEVEL SECURITY;
CREATE POLICY "space_invites_select" ON space_invites FOR SELECT
  USING (space_id IN (SELECT auth_user_space_ids()));
CREATE POLICY "space_invites_insert" ON space_invites FOR INSERT
  WITH CHECK (space_id IN (SELECT auth_user_space_ids()));
