-- 005_media_devices.sql
-- Media table for trip photos + user_devices for FCM tokens

CREATE TABLE IF NOT EXISTS media (
  id text PRIMARY KEY,
  space_id text REFERENCES spaces(id) ON DELETE CASCADE,
  uploaded_by text REFERENCES users(id),
  storage_path text NOT NULL,
  thumbnail_url text,
  mime_type text NOT NULL DEFAULT 'image/jpeg',
  caption text,
  created_at timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_devices (
  user_id text REFERENCES users(id) ON DELETE CASCADE,
  fcm_token text NOT NULL,
  platform text DEFAULT 'web',
  created_at timestamptz DEFAULT now(),
  PRIMARY KEY (user_id, fcm_token)
);

-- Add photo_url to users table if not exists
ALTER TABLE users ADD COLUMN IF NOT EXISTS photo_url text;

-- Enable RLS on new tables (Supabase blocks all access without policies)
ALTER TABLE media ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;

-- Media: space members can SELECT and INSERT
CREATE POLICY media_select_member ON media
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
  );

CREATE POLICY media_insert_member ON media
  FOR INSERT WITH CHECK (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()::text)
    AND uploaded_by = auth.uid()::text
  );

-- User devices: own rows only
CREATE POLICY devices_select_own ON user_devices
  FOR SELECT USING (user_id = auth.uid()::text);

CREATE POLICY devices_insert_own ON user_devices
  FOR INSERT WITH CHECK (user_id = auth.uid()::text);

CREATE POLICY devices_delete_own ON user_devices
  FOR DELETE USING (user_id = auth.uid()::text);

-- Enable Realtime for media
ALTER PUBLICATION supabase_realtime ADD TABLE media;
