-- Fix RLS policies: replace auth.uid()::text with (auth.jwt()->>'sub')
-- Reason: User IDs are text (e.g., "name_ram"), not UUIDs.
-- auth.uid() returns NULL for non-UUID subjects, breaking all RLS checks.
-- auth.jwt()->>'sub' reads the text subject directly from the JWT.

-- ══════════════════════════════════════
-- SHARED SECURITY DEFINER FUNCTION
-- Avoids infinite recursion on space_members self-referencing queries.
-- ══════════════════════════════════════

CREATE OR REPLACE FUNCTION auth_user_space_ids()
RETURNS SETOF text
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT space_id FROM space_members
  WHERE user_id = (auth.jwt()->>'sub');
$$;

-- ══════════════════════════════════════
-- DROP + RECREATE ALL POLICIES
-- ══════════════════════════════════════

-- ── USERS ──
DROP POLICY IF EXISTS users_select_self ON users;
CREATE POLICY users_select_self ON users
  FOR SELECT USING (id = (auth.jwt()->>'sub'));

DROP POLICY IF EXISTS users_update_self ON users;
CREATE POLICY users_update_self ON users
  FOR UPDATE USING (id = (auth.jwt()->>'sub'))
  WITH CHECK (id = (auth.jwt()->>'sub'));

-- ── SPACES ──
DROP POLICY IF EXISTS spaces_select_member ON spaces;
CREATE POLICY spaces_select_member ON spaces
  FOR SELECT USING (id IN (SELECT auth_user_space_ids()));

DROP POLICY IF EXISTS spaces_insert_auth ON spaces;
CREATE POLICY spaces_insert_auth ON spaces
  FOR INSERT WITH CHECK ((auth.jwt()->>'sub') IS NOT NULL);

DROP POLICY IF EXISTS spaces_update_owner ON spaces;
CREATE POLICY spaces_update_owner ON spaces
  FOR UPDATE USING (owner_id = (auth.jwt()->>'sub'))
  WITH CHECK (owner_id = (auth.jwt()->>'sub'));

-- ── SPACE_MEMBERS ──
DROP POLICY IF EXISTS space_members_select ON space_members;
CREATE POLICY space_members_select ON space_members
  FOR SELECT USING (space_id IN (SELECT auth_user_space_ids()));

DROP POLICY IF EXISTS space_members_insert_system ON space_members;
CREATE POLICY space_members_insert_system ON space_members
  FOR INSERT WITH CHECK (false);

DROP POLICY IF EXISTS space_members_delete ON space_members;
CREATE POLICY space_members_delete ON space_members
  FOR DELETE USING (
    space_id IN (SELECT id FROM spaces WHERE owner_id = (auth.jwt()->>'sub'))
    OR user_id = (auth.jwt()->>'sub')
  );

-- ── DECISION_ITEMS ──
DROP POLICY IF EXISTS items_select_member ON decision_items;
CREATE POLICY items_select_member ON decision_items
  FOR SELECT USING (space_id IN (SELECT auth_user_space_ids()));

DROP POLICY IF EXISTS items_insert_member ON decision_items;
CREATE POLICY items_insert_member ON decision_items
  FOR INSERT WITH CHECK (space_id IN (SELECT auth_user_space_ids()));

-- ── REACTIONS ──
DROP POLICY IF EXISTS reactions_select_member ON reactions;
CREATE POLICY reactions_select_member ON reactions
  FOR SELECT USING (
    item_id IN (
      SELECT id FROM decision_items
      WHERE space_id IN (SELECT auth_user_space_ids())
    )
  );

DROP POLICY IF EXISTS reactions_insert_system ON reactions;
CREATE POLICY reactions_insert_system ON reactions
  FOR INSERT WITH CHECK (false);

DROP POLICY IF EXISTS reactions_update_system ON reactions;
CREATE POLICY reactions_update_system ON reactions
  FOR UPDATE USING (false);

-- ── MESSAGES ──
DROP POLICY IF EXISTS messages_select_member ON messages;
CREATE POLICY messages_select_member ON messages
  FOR SELECT USING (space_id IN (SELECT auth_user_space_ids()));

DROP POLICY IF EXISTS messages_insert_user ON messages;
CREATE POLICY messages_insert_user ON messages
  FOR INSERT WITH CHECK (
    space_id IN (SELECT auth_user_space_ids())
    AND user_id = (auth.jwt()->>'sub')
    AND role = 'user'
  );

-- ── TASKS ──
DROP POLICY IF EXISTS tasks_select_member ON tasks;
CREATE POLICY tasks_select_member ON tasks
  FOR SELECT USING (space_id IN (SELECT auth_user_space_ids()));

DROP POLICY IF EXISTS tasks_insert_member ON tasks;
CREATE POLICY tasks_insert_member ON tasks
  FOR INSERT WITH CHECK (space_id IN (SELECT auth_user_space_ids()));

DROP POLICY IF EXISTS tasks_update_member ON tasks;
CREATE POLICY tasks_update_member ON tasks
  FOR UPDATE USING (space_id IN (SELECT auth_user_space_ids()));

-- ── Fix get_visible_users to use jwt sub ──
CREATE OR REPLACE FUNCTION get_visible_users()
RETURNS TABLE(id text, display_name text, photo_url text)
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT u.id, u.display_name, u.photo_url
  FROM users u
  WHERE u.id IN (
    SELECT sm.user_id FROM space_members sm
    WHERE sm.space_id IN (
      SELECT sm2.space_id FROM space_members sm2
      WHERE sm2.user_id = (auth.jwt()->>'sub')
    )
  ) AND u.id != (auth.jwt()->>'sub');
$$;

-- ── Fix force_space_owner trigger ──
CREATE OR REPLACE FUNCTION fn_force_space_owner()
RETURNS TRIGGER AS $$
DECLARE
  jwt_role text;
BEGIN
  BEGIN
    jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
  EXCEPTION WHEN OTHERS THEN
    jwt_role := NULL;
  END;

  IF jwt_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  NEW.owner_id := (auth.jwt()->>'sub');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
