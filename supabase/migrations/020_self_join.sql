-- 020_self_join.sql
-- Allow users to add THEMSELVES as space members (for space creation + invite join).
-- The existing INSERT policy is WITH CHECK (false) which blocks all client-side inserts.
-- This adds a targeted policy: you can insert a row ONLY if user_id matches your JWT sub.

DROP POLICY IF EXISTS space_members_insert_system ON space_members;

-- Allow self-insert (user can add themselves to a space)
CREATE POLICY space_members_insert_self ON space_members
  FOR INSERT WITH CHECK (user_id = auth.jwt()->>'sub');
