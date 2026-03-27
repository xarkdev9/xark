-- Phase 0 Foundation: Row Level Security + Column Protection Triggers
-- Run AFTER 002_functions_triggers.sql
-- All tables have RLS enabled. anon key = no access.
-- Only authenticated users with valid JWT can query.
-- Spec: docs/superpowers/specs/2026-03-12-phase0-foundation-design.md

-- ══════════════════════════════════════
-- ENABLE RLS ON ALL TABLES
-- ══════════════════════════════════════

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE space_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE decision_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- ══════════════════════════════════════
-- SECURITY DEFINER: Phone column protection
-- This is the ONLY way to look up other users.
-- Returns only safe columns (id, display_name, photo_url).
-- The users table SELECT policy only returns own row.
-- ══════════════════════════════════════

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
      WHERE sm2.user_id = auth.uid()::text
    )
  ) AND u.id != auth.uid()::text;
$$;

-- ══════════════════════════════════════
-- COLUMN PROTECTION TRIGGERS
-- RLS cannot restrict columns, so triggers enforce immutability
-- ══════════════════════════════════════

-- Users: only display_name and photo_url are mutable
CREATE OR REPLACE FUNCTION fn_restrict_user_update()
RETURNS TRIGGER AS $$
BEGIN
  NEW.id := OLD.id;
  NEW.phone := OLD.phone;
  NEW.password_hash := OLD.password_hash;
  NEW.created_at := OLD.created_at;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_restrict_user_update ON users;
CREATE TRIGGER trg_restrict_user_update
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION fn_restrict_user_update();

-- Tasks: only assignee_id is mutable by members
CREATE OR REPLACE FUNCTION fn_restrict_task_update()
RETURNS TRIGGER AS $$
BEGIN
  NEW.id := OLD.id;
  NEW.space_id := OLD.space_id;
  NEW.title := OLD.title;
  NEW.created_at := OLD.created_at;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_restrict_task_update ON tasks;
CREATE TRIGGER trg_restrict_task_update
  BEFORE UPDATE ON tasks
  FOR EACH ROW
  EXECUTE FUNCTION fn_restrict_task_update();

-- Spaces: force owner_id to auth.uid() on INSERT
CREATE OR REPLACE FUNCTION fn_force_space_owner()
RETURNS TRIGGER AS $$
DECLARE
  jwt_role text;
BEGIN
  -- Service role can set owner_id directly (for seeding)
  BEGIN
    jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
  EXCEPTION WHEN OTHERS THEN
    jwt_role := NULL;
  END;

  IF jwt_role = 'service_role' THEN
    RETURN NEW;
  END IF;

  NEW.owner_id := auth.uid()::text;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_force_space_owner ON spaces;
CREATE TRIGGER trg_force_space_owner
  BEFORE INSERT ON spaces
  FOR EACH ROW
  EXECUTE FUNCTION fn_force_space_owner();

-- ══════════════════════════════════════
-- USERS
-- ══════════════════════════════════════

-- Select own row ONLY (all columns including phone).
-- For co-members, use get_visible_users() RPC which returns safe columns only.
-- NO co-member SELECT policy on users table — this prevents phone/password_hash leakage.
CREATE POLICY users_select_self ON users
  FOR SELECT USING (id = auth.uid()::text);

-- Update own profile only (column restriction via trigger above)
CREATE POLICY users_update_self ON users
  FOR UPDATE USING (id = auth.uid()::text)
  WITH CHECK (id = auth.uid()::text);

-- ══════════════════════════════════════
-- SPACES
-- ══════════════════════════════════════

CREATE POLICY spaces_select_member ON spaces
  FOR SELECT USING (
    id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

-- owner_id is forced to auth.uid() by trg_force_space_owner trigger
CREATE POLICY spaces_insert_auth ON spaces
  FOR INSERT WITH CHECK (auth.uid()::text IS NOT NULL);

CREATE POLICY spaces_update_owner ON spaces
  FOR UPDATE USING (owner_id = auth.uid()::text)
  WITH CHECK (owner_id = auth.uid()::text);

-- ══════════════════════════════════════
-- SPACE_MEMBERS
-- ══════════════════════════════════════

CREATE POLICY space_members_select ON space_members
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

-- INSERT via SECURITY DEFINER functions only (invite_member, fn_auto_add_space_owner).
-- WITH CHECK (false) is safe because those functions run as the DB owner, bypassing RLS.
CREATE POLICY space_members_insert_system ON space_members
  FOR INSERT WITH CHECK (false);

CREATE POLICY space_members_delete ON space_members
  FOR DELETE USING (
    -- Space owner can remove anyone
    space_id IN (SELECT id FROM spaces WHERE owner_id = auth.uid()::text)
    OR
    -- Self-leave
    user_id = auth.uid()::text
  );

-- ══════════════════════════════════════
-- DECISION_ITEMS
-- ══════════════════════════════════════

CREATE POLICY items_select_member ON decision_items
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

CREATE POLICY items_insert_member ON decision_items
  FOR INSERT WITH CHECK (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

-- No direct UPDATE — all via SECURITY DEFINER RPCs (react_to_item, lock_item, transfer_ownership)
-- No DELETE

-- ══════════════════════════════════════
-- REACTIONS
-- ══════════════════════════════════════

CREATE POLICY reactions_select_member ON reactions
  FOR SELECT USING (
    item_id IN (
      SELECT id FROM decision_items
      WHERE space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
    )
  );

-- INSERT/UPDATE via react_to_item() SECURITY DEFINER only
CREATE POLICY reactions_insert_system ON reactions
  FOR INSERT WITH CHECK (false);

CREATE POLICY reactions_update_system ON reactions
  FOR UPDATE USING (false);

-- ══════════════════════════════════════
-- MESSAGES
-- ══════════════════════════════════════

CREATE POLICY messages_select_member ON messages
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

-- Only user messages from authenticated members
-- @xark messages are inserted via service_role key (bypasses RLS)
CREATE POLICY messages_insert_user ON messages
  FOR INSERT WITH CHECK (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
    AND user_id = auth.uid()::text
    AND role = 'user'
  );

-- No UPDATE, no DELETE

-- ══════════════════════════════════════
-- TASKS
-- ══════════════════════════════════════

CREATE POLICY tasks_select_member ON tasks
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

CREATE POLICY tasks_insert_member ON tasks
  FOR INSERT WITH CHECK (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

-- Column restriction via trg_restrict_task_update (only assignee_id mutable)
CREATE POLICY tasks_update_member ON tasks
  FOR UPDATE USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

-- No DELETE
