-- Fix media and user_devices RLS policies to use auth.jwt()->>'sub' instead of auth.uid()
-- Same fix as 20260313212810 but for tables that were missed.

-- ═══════════════════════════════════════
-- MEDIA
-- ═══════════════════════════════════════
DROP POLICY IF EXISTS media_select_member ON media;
DROP POLICY IF EXISTS media_insert_member ON media;

CREATE POLICY media_select_member ON media
  FOR SELECT USING (
    space_id IN (SELECT auth_user_space_ids())
  );

CREATE POLICY media_insert_member ON media
  FOR INSERT WITH CHECK (
    space_id IN (SELECT auth_user_space_ids())
    AND uploaded_by = (auth.jwt()->>'sub')
  );

-- ═══════════════════════════════════════
-- USER_DEVICES
-- ═══════════════════════════════════════
DROP POLICY IF EXISTS devices_select_own ON user_devices;
DROP POLICY IF EXISTS devices_insert_own ON user_devices;
DROP POLICY IF EXISTS devices_delete_own ON user_devices;

CREATE POLICY devices_select_own ON user_devices
  FOR SELECT USING (user_id = (auth.jwt()->>'sub'));

CREATE POLICY devices_insert_own ON user_devices
  FOR INSERT WITH CHECK (user_id = (auth.jwt()->>'sub'));

CREATE POLICY devices_delete_own ON user_devices
  FOR DELETE USING (user_id = (auth.jwt()->>'sub'));
