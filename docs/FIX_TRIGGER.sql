-- Fix trigger that references old table name space_members
-- This trigger auto-adds the owner as a member when a group is created

CREATE OR REPLACE FUNCTION fn_auto_add_space_owner() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  INSERT INTO group_members (group_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner')
  ON CONFLICT (group_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- Refresh PostgREST cache
NOTIFY pgrst, 'reload schema';
