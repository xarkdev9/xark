-- Migration 030: Rename space terminology to group terminology
-- Safe for empty database (no real users beyond test accounts)
-- ALTER TABLE RENAME = zero downtime, no data moved

-- TABLES
ALTER TABLE IF EXISTS spaces RENAME TO groups;
ALTER TABLE IF EXISTS space_members RENAME TO group_members;
ALTER TABLE IF EXISTS space_dates RENAME TO group_dates;
ALTER TABLE IF EXISTS space_ledger RENAME TO group_ledger;
ALTER TABLE IF EXISTS space_invites RENAME TO group_invites;
ALTER TABLE IF EXISTS space_tombstones RENAME TO group_tombstones;
ALTER TABLE IF EXISTS space_constraints RENAME TO group_constraints;
ALTER TABLE IF EXISTS summon_links RENAME TO invite_links;
ALTER TABLE IF EXISTS user_taste_profiles RENAME TO user_onboarding_profiles;

-- COLUMNS: atmosphere → type on groups
ALTER TABLE groups RENAME COLUMN atmosphere TO type;
ALTER TABLE groups DROP CONSTRAINT IF EXISTS spaces_atmosphere_check;
-- Update data BEFORE adding constraint (rows have 'sanctuary', 'cyan_horizon', etc.)
UPDATE groups SET type = 'dm' WHERE type = 'sanctuary';
UPDATE groups SET type = 'group' WHERE type NOT IN ('dm', 'group');
-- Now all rows are 'dm' or 'group' — safe to add constraint
ALTER TABLE groups ADD CONSTRAINT groups_type_check
  CHECK (type IN ('group', 'dm'));

-- COLUMNS: space_id → group_id (all FK tables)
ALTER TABLE group_members    RENAME COLUMN space_id TO group_id;
ALTER TABLE group_dates      RENAME COLUMN space_id TO group_id;
ALTER TABLE group_ledger     RENAME COLUMN space_id TO group_id;
ALTER TABLE group_invites    RENAME COLUMN space_id TO group_id;
ALTER TABLE group_tombstones RENAME COLUMN space_id TO group_id;
ALTER TABLE group_constraints RENAME COLUMN space_id TO group_id;
ALTER TABLE decision_items   RENAME COLUMN space_id TO group_id;
ALTER TABLE messages         RENAME COLUMN space_id TO group_id;
ALTER TABLE media            RENAME COLUMN space_id TO group_id;
ALTER TABLE member_logistics RENAME COLUMN space_id TO group_id;

-- INDEXES: rename to match new table names
DO $$
DECLARE idx RECORD;
BEGIN
  FOR idx IN
    SELECT indexname, tablename FROM pg_indexes
    WHERE indexname LIKE '%space%'
    AND tablename IN ('groups','group_members','group_dates',
      'group_ledger','group_invites','group_tombstones',
      'group_constraints','invite_links','decision_items',
      'messages','media','member_logistics')
  LOOP
    EXECUTE format('ALTER INDEX IF EXISTS %I RENAME TO %I',
      idx.indexname,
      replace(idx.indexname, 'space', 'group'));
  END LOOP;
END $$;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION auth_user_group_ids()
RETURNS TABLE(group_id text) LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT group_id FROM group_members
  WHERE user_id = auth.jwt()->>'sub';
$$;
REVOKE EXECUTE ON FUNCTION auth_user_group_ids FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_user_group_ids TO authenticated;

-- Backwards-compat alias (remove in migration 031)
CREATE OR REPLACE FUNCTION auth_user_space_ids()
RETURNS TABLE(space_id text) LANGUAGE sql STABLE SECURITY DEFINER AS $$
  SELECT group_id AS space_id FROM group_members
  WHERE user_id = auth.jwt()->>'sub';
$$;

-- Update find_or_create_chat (DROP + recreate because return type changed)
DROP FUNCTION IF EXISTS find_or_create_chat(text, text);
CREATE OR REPLACE FUNCTION find_or_create_chat(
  p_user_id text, p_other_user_id text
) RETURNS text LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_group_id text;
BEGIN
  SELECT gm1.group_id INTO v_group_id
  FROM group_members gm1
  JOIN group_members gm2 ON gm1.group_id = gm2.group_id
  JOIN groups g ON g.id = gm1.group_id
  WHERE gm1.user_id = p_user_id
    AND gm2.user_id = p_other_user_id
    AND g.type = 'dm'
  LIMIT 1;
  IF v_group_id IS NOT NULL THEN RETURN v_group_id; END IF;
  INSERT INTO groups (id, type, owner_id)
  VALUES (gen_random_uuid()::text, 'dm', p_user_id)
  RETURNING id INTO v_group_id;
  INSERT INTO group_members (group_id, user_id)
  VALUES (v_group_id, p_user_id), (v_group_id, p_other_user_id);
  RETURN v_group_id;
END;
$$;

COMMENT ON TABLE groups IS 'Chat groups and DMs. type=group for group chats, type=dm for 1:1.';
COMMENT ON TABLE invite_links IS 'Invite links for joining groups.';
