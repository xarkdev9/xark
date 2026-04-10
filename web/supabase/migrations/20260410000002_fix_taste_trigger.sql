DROP TRIGGER IF EXISTS trg_update_taste_on_reaction ON reactions;
DROP FUNCTION IF EXISTS update_taste_on_reaction();

CREATE OR REPLACE FUNCTION update_taste_on_reaction_v2()
RETURNS trigger AS $$
BEGIN
  INSERT INTO user_taste_profiles (user_id, signal_type, signal_value, weight)
  VALUES (
    auth.jwt()->>'sub',
    'reaction',
    NEW.reaction_type,
    CASE NEW.reaction_type
      WHEN 'love_it' THEN 5
      WHEN 'works_for_me' THEN 1
      WHEN 'not_for_me' THEN -3
    END
  )
  ON CONFLICT (user_id, signal_type, signal_value)
  DO UPDATE SET weight = user_taste_profiles.weight + EXCLUDED.weight;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_taste_on_reaction_v2
  AFTER INSERT ON reactions
  FOR EACH ROW EXECUTE FUNCTION update_taste_on_reaction_v2();
