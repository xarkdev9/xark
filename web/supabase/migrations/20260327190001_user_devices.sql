-- CRYPTO-06: Sesame Multi-Device Protocol — Device Registry
-- Each user can have up to 5 devices, each with its own cryptographic identity.

CREATE TABLE user_devices (
  user_id TEXT NOT NULL,
  device_id INTEGER NOT NULL,
  device_name TEXT,
  platform TEXT NOT NULL, -- 'ios' | 'android' | 'web' | 'macos' | 'windows' | 'linux'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_active_at TIMESTAMPTZ,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, device_id)
);

ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY ud_select ON user_devices FOR SELECT
  USING (user_id = auth.jwt()->>'sub'
    OR user_id IN (
      SELECT CASE
        WHEN gm1.user_id = auth.jwt()->>'sub' THEN gm2.user_id
        ELSE gm1.user_id
      END
      FROM group_members gm1
      JOIN group_members gm2 ON gm1.group_id = gm2.group_id
      WHERE gm1.user_id = auth.jwt()->>'sub' OR gm2.user_id = auth.jwt()->>'sub'
    )
  );

CREATE POLICY ud_insert ON user_devices FOR INSERT
  WITH CHECK (user_id = auth.jwt()->>'sub');
CREATE POLICY ud_update ON user_devices FOR UPDATE
  USING (user_id = auth.jwt()->>'sub');
CREATE POLICY ud_delete ON user_devices FOR DELETE
  USING (user_id = auth.jwt()->>'sub');

-- Max 5 devices per user (enforced via trigger)
CREATE OR REPLACE FUNCTION check_device_limit() RETURNS TRIGGER AS $$
BEGIN
  IF (SELECT COUNT(*) FROM user_devices WHERE user_id = NEW.user_id) >= 5 THEN
    RAISE EXCEPTION 'device_limit_exceeded';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_device_limit
  BEFORE INSERT ON user_devices
  FOR EACH ROW EXECUTE FUNCTION check_device_limit();

-- Get all devices for a user (used for fan-out encryption)
CREATE OR REPLACE FUNCTION get_user_devices(p_user_id TEXT)
RETURNS TABLE(device_id INTEGER, platform TEXT, is_primary BOOLEAN) AS $$
  SELECT device_id, platform, is_primary
  FROM user_devices
  WHERE user_id = p_user_id AND last_active_at > now() - interval '30 days';
$$ LANGUAGE sql SECURITY DEFINER;

-- Register or update a device
CREATE OR REPLACE FUNCTION register_device(
  p_device_id INTEGER,
  p_device_name TEXT,
  p_platform TEXT,
  p_is_primary BOOLEAN DEFAULT false
) RETURNS VOID AS $$
DECLARE
  v_user_id TEXT := auth.jwt()->>'sub';
BEGIN
  INSERT INTO user_devices (user_id, device_id, device_name, platform, is_primary, last_active_at)
  VALUES (v_user_id, p_device_id, p_device_name, p_platform, p_is_primary, now())
  ON CONFLICT (user_id, device_id) DO UPDATE
  SET device_name = p_device_name,
      platform = p_platform,
      last_active_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Unlink a device (revoke keys + remove from registry)
CREATE OR REPLACE FUNCTION unlink_device(p_device_id INTEGER)
RETURNS VOID AS $$
DECLARE
  v_user_id TEXT := auth.jwt()->>'sub';
BEGIN
  -- Delete key bundle for this device
  DELETE FROM key_bundles WHERE user_id = v_user_id AND device_id = p_device_id;
  -- Delete OTKs for this device
  DELETE FROM one_time_pre_keys WHERE user_id = v_user_id AND device_id = p_device_id;
  -- Delete SK acknowledgments involving this device
  DELETE FROM sk_acknowledgments WHERE
    (sender_id = v_user_id AND recipient_device_id = p_device_id) OR
    (recipient_id = v_user_id AND recipient_device_id = p_device_id);
  -- Remove from registry
  DELETE FROM user_devices WHERE user_id = v_user_id AND device_id = p_device_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
