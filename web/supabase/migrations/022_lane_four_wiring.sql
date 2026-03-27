-- 022_lane_four_wiring.sql
-- Tombstones for Decentralized Healing (Lazy Sender Key Rotation)

CREATE TABLE IF NOT EXISTS space_tombstones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id TEXT NOT NULL,
  kicked_user_id TEXT NOT NULL,
  tombstoned_device_ids INTEGER[] NOT NULL,
  signature TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE space_tombstones ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read tombstones"
  ON space_tombstones FOR SELECT
  USING (true);

CREATE POLICY "Only space members can insert tombstones"
  ON space_tombstones FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM space_members
      WHERE space_members.space_id = space_tombstones.space_id
      AND space_members.user_id = auth.uid()::text
    )
  );

-- Placeholder for guest_votes if needed by Lane C
CREATE TABLE IF NOT EXISTS guest_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  space_id TEXT NOT NULL,
  guest_token TEXT NOT NULL,
  encrypted_payload TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  processed_at TIMESTAMPTZ
);

ALTER TABLE guest_votes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Guests can insert votes"
  ON guest_votes FOR INSERT
  WITH CHECK (true);

CREATE POLICY "Space members can read and process guest votes"
  ON guest_votes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM space_members
      WHERE space_members.space_id = guest_votes.space_id
      AND space_members.user_id = auth.uid()::text
    )
  );
CREATE POLICY "Space members can update guest votes"
  ON guest_votes FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM space_members
      WHERE space_members.space_id = guest_votes.space_id
      AND space_members.user_id = auth.uid()::text
    )
  );

-- Lane A Secondary Device Linking
CREATE TABLE IF NOT EXISTS linked_devices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  public_key TEXT NOT NULL,
  primary_signature TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE linked_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their linked devices"
  ON linked_devices FOR ALL
  USING (user_id = auth.uid()::text)
  WITH CHECK (user_id = auth.uid()::text);
