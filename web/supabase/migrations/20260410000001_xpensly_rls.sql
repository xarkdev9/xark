-- 1. Denormalize participants
ALTER TABLE xp_trips ADD COLUMN participant_ids UUID[] DEFAULT '{}';

-- 2. Backfill
UPDATE xp_trips t SET participant_ids = (
  SELECT COALESCE(array_agg(m.user_id), '{}')
  FROM xp_trip_members m WHERE m.trip_id = t.id
);

-- 3. Keep in sync
CREATE OR REPLACE FUNCTION sync_xp_trip_participants()
RETURNS trigger AS $$
BEGIN
  UPDATE xp_trips SET participant_ids = (
    SELECT COALESCE(array_agg(user_id), '{}')
    FROM xp_trip_members
    WHERE trip_id = COALESCE(NEW.trip_id, OLD.trip_id)
  ) WHERE id = COALESCE(NEW.trip_id, OLD.trip_id);
  RETURN NULL;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_sync_xp_participants
  AFTER INSERT OR DELETE ON xp_trip_members
  FOR EACH ROW EXECUTE FUNCTION sync_xp_trip_participants();

-- 4. RLS on all tables
ALTER TABLE xp_trips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_trip_access" ON xp_trips
  FOR ALL USING (auth.uid() = ANY(participant_ids));

ALTER TABLE xp_trip_phases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_phase_access" ON xp_trip_phases
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_trip_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_member_access" ON xp_trip_members
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_expense_access" ON xp_expenses
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

-- Denormalize trip_id onto payers and splits to flatten the RLS join
ALTER TABLE xp_expense_payers ADD COLUMN IF NOT EXISTS trip_id UUID
  REFERENCES xp_trips(id) ON DELETE CASCADE;
ALTER TABLE xp_expense_splits ADD COLUMN IF NOT EXISTS trip_id UUID
  REFERENCES xp_trips(id) ON DELETE CASCADE;

-- Backfill trip_id from parent expense
UPDATE xp_expense_payers p SET trip_id = (
  SELECT e.trip_id FROM xp_expenses e WHERE e.id = p.expense_id
) WHERE p.trip_id IS NULL;
UPDATE xp_expense_splits s SET trip_id = (
  SELECT e.trip_id FROM xp_expenses e WHERE e.id = s.expense_id
) WHERE s.trip_id IS NULL;

-- Auto-populate trip_id on insert
CREATE OR REPLACE FUNCTION set_xp_child_trip_id()
RETURNS trigger AS $$
BEGIN
  NEW.trip_id := (SELECT trip_id FROM xp_expenses WHERE id = NEW.expense_id);
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_set_payer_trip_id BEFORE INSERT ON xp_expense_payers
  FOR EACH ROW EXECUTE FUNCTION set_xp_child_trip_id();
CREATE TRIGGER trg_set_split_trip_id BEFORE INSERT ON xp_expense_splits
  FOR EACH ROW EXECUTE FUNCTION set_xp_child_trip_id();

-- Flat single-jump RLS (no double-nested subqueries)
ALTER TABLE xp_expense_payers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_payer_access" ON xp_expense_payers
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_expense_splits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_split_access" ON xp_expense_splits
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_settlements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_settlement_access" ON xp_settlements
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_refunds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_refund_access" ON xp_refunds
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

-- 5. Indexes
CREATE INDEX idx_xp_trips_participants ON xp_trips USING GIN (participant_ids);
