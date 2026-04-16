-- Fix all trigger functions that reference old table/column names
-- Run in Supabase SQL Editor

-- 1. Fix fn_update_space_activity: spaces → groups, space_id → group_id
CREATE OR REPLACE FUNCTION fn_update_space_activity() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE groups SET last_activity_at = now() WHERE id = NEW.group_id;
  RETURN NEW;
END;
$$;

-- 2. Refresh cache
NOTIFY pgrst, 'reload schema';
