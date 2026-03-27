-- XARK OS v2.0 — Taste Graph + Consensus Closer
-- Migration 027: The intelligence layer for XarkSpotlight.
--
-- 1. user_taste_profiles: Explicit hard_constraints (Day 1 Ghost Prompt) +
--    implicit_weights (accumulated from reactions over time).
-- 2. Postgres trigger on reactions: updates implicit_weights per-category.
-- 3. lock_deadline on decision_items: enables Consensus Closer countdown timer.
-- 4. RPC get_space_taste_profiles: single-query fetch for /api/xark search-time
--    group taste intersection.
-- 5. RPC auto_lock_expired_consensus: called by Vercel cron to fire Green-Lock
--    when countdown expires.
-- 6. RLS: taste profiles readable only by space co-members.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 1. USER TASTE PROFILES TABLE
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE user_taste_profiles (
  user_id text PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,

  -- Explicit constraints from Day 1 Ghost Prompt.
  -- Parsed by Gemini from natural language: "I'm vegan, hate tourist traps"
  -- → ["vegan", "no_chains", "no_tourist_traps"]
  -- These are HARD VETOES — one vegan in the group = no steakhouses.
  hard_constraints jsonb NOT NULL DEFAULT '[]'::jsonb,

  -- Implicit preference weights accumulated from reactions.
  -- Keys are decision_item categories (e.g., "local_restaurant", "hotel")
  -- and metadata tags (e.g., "japanese", "budget").
  -- Values are rolling sums: love_it = +5, works_for_me = +1, not_for_me = -3.
  -- Example: {"japanese": 12, "hotel": 3, "steakhouse": -6, "local_restaurant": 8}
  implicit_weights jsonb NOT NULL DEFAULT '{}'::jsonb,

  -- True after the user completes the Day 1 Ghost Prompt onboarding.
  onboarded boolean NOT NULL DEFAULT false,

  -- Raw text from the Day 1 Ghost Prompt for audit/re-parsing.
  -- "I'm a vegan, I hate tourist traps, and I'm a massive coffee snob."
  onboarding_raw text,

  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- NOTE: No separate index on user_id needed — PRIMARY KEY already creates a unique index.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 2. CONSENSUS CLOSER — Add lock_deadline to decision_items
-- ═══════════════════════════════════════════════════════════════════════════════
-- consensus_status is DERIVED, not stored:
--   is_locked = true                                         → 'locked'
--   lock_deadline IS NOT NULL AND lock_deadline > now()       → 'countdown'
--   else                                                      → 'open'

ALTER TABLE decision_items
  ADD COLUMN lock_deadline timestamptz DEFAULT NULL;

-- Index for the cron job that auto-locks expired countdowns.
CREATE INDEX idx_items_lock_deadline
  ON decision_items(lock_deadline)
  WHERE lock_deadline IS NOT NULL AND is_locked = false;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 3. TRIGGER: Update implicit_weights on reaction INSERT/UPDATE
-- ═══════════════════════════════════════════════════════════════════════════════
-- When a user reacts to a decision_item, extract the item's category and
-- adjust the user's implicit_weights by the signal weight.
-- On UPDATE (changed reaction): subtract old weight, add new weight.

CREATE OR REPLACE FUNCTION update_taste_on_reaction()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item_category text;
  item_tags text[];
  current_weights jsonb;
  tag text;
  old_val integer;
  new_val integer;
BEGIN
  -- Get the item's category from decision_items
  SELECT category INTO item_category
  FROM decision_items WHERE id = NEW.item_id;

  IF item_category IS NULL OR item_category = '' THEN
    RETURN NEW;
  END IF;

  -- Ensure the user has a taste profile (auto-create if missing)
  INSERT INTO user_taste_profiles (user_id, hard_constraints, implicit_weights)
  VALUES (NEW.user_id, '[]'::jsonb, '{}'::jsonb)
  ON CONFLICT (user_id) DO NOTHING;

  -- Fetch current weights
  SELECT implicit_weights INTO current_weights
  FROM user_taste_profiles WHERE user_id = NEW.user_id;

  -- Build tag list: always include the category, plus metadata tags if available
  item_tags := ARRAY[item_category];

  -- If item has metadata with specific tags (cuisine, type), include them
  -- This allows finer-grained preferences beyond just "local_restaurant"
  BEGIN
    SELECT array_agg(tag) INTO item_tags
    FROM (
      SELECT item_category AS tag
      UNION ALL
      SELECT metadata->>'cuisine' FROM decision_items
        WHERE id = NEW.item_id AND metadata->>'cuisine' IS NOT NULL
      UNION ALL
      SELECT metadata->>'type' FROM decision_items
        WHERE id = NEW.item_id AND metadata->>'type' IS NOT NULL
    ) tags;
  EXCEPTION WHEN OTHERS THEN
    item_tags := ARRAY[item_category];
  END;

  -- Apply weight changes for each tag
  FOREACH tag IN ARRAY item_tags LOOP
    IF tag IS NULL OR tag = '' THEN CONTINUE; END IF;

    old_val := COALESCE((current_weights->>tag)::integer, 0);

    IF TG_OP = 'UPDATE' THEN
      -- Subtract old reaction weight, add new
      new_val := old_val - OLD.weight + NEW.weight;
    ELSE
      -- INSERT: just add the new weight
      new_val := old_val + NEW.weight;
    END IF;

    current_weights := jsonb_set(
      current_weights,
      ARRAY[tag],
      to_jsonb(new_val)
    );
  END LOOP;

  -- Persist
  UPDATE user_taste_profiles
  SET implicit_weights = current_weights, updated_at = now()
  WHERE user_id = NEW.user_id;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_taste_on_reaction
  AFTER INSERT OR UPDATE ON reactions
  FOR EACH ROW
  EXECUTE FUNCTION update_taste_on_reaction();

-- ═══════════════════════════════════════════════════════════════════════════════
-- 4. TRIGGER: Start/cancel consensus countdown on agreement_score change
-- ═══════════════════════════════════════════════════════════════════════════════
-- When agreement_score crosses 0.80 upward → set lock_deadline to 10 minutes.
-- When agreement_score drops below 0.80 → cancel countdown (NULL deadline).
-- If item is already locked, do nothing.

CREATE OR REPLACE FUNCTION check_consensus_countdown()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- Skip if already locked
  IF NEW.is_locked = true THEN
    RETURN NEW;
  END IF;

  -- Consensus just reached: start 10-minute countdown
  IF NEW.agreement_score > 0.80
     AND (OLD.agreement_score IS NULL OR OLD.agreement_score <= 0.80)
     AND NEW.lock_deadline IS NULL THEN
    NEW.lock_deadline := now() + interval '10 minutes';
  END IF;

  -- Consensus lost (someone objected/changed vote): cancel countdown
  IF NEW.agreement_score <= 0.80
     AND OLD.lock_deadline IS NOT NULL THEN
    NEW.lock_deadline := NULL;
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_consensus_countdown
  BEFORE UPDATE ON decision_items
  FOR EACH ROW
  WHEN (OLD.agreement_score IS DISTINCT FROM NEW.agreement_score)
  EXECUTE FUNCTION check_consensus_countdown();

-- ═══════════════════════════════════════════════════════════════════════════════
-- 5. RPC: Get taste profiles for all members of a space (search-time query)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Called by /api/xark to build the group taste intersection in one query.
-- Returns hard_constraints and implicit_weights for every space member.

CREATE OR REPLACE FUNCTION get_space_taste_profiles(p_space_id text)
RETURNS TABLE(
  user_id text,
  hard_constraints jsonb,
  implicit_weights jsonb,
  onboarded boolean
)
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT
    utp.user_id,
    utp.hard_constraints,
    utp.implicit_weights,
    utp.onboarded
  FROM user_taste_profiles utp
  INNER JOIN space_members sm ON sm.user_id = utp.user_id
  WHERE sm.space_id = p_space_id;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 6. RPC: Auto-lock items with expired consensus countdowns
-- ═══════════════════════════════════════════════════════════════════════════════
-- Called by Vercel cron job (/api/cron/consensus). Fires Green-Lock on items
-- where the 10-minute countdown has expired and no one objected.

CREATE OR REPLACE FUNCTION auto_lock_expired_consensus()
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  locked_count integer;
BEGIN
  WITH locked AS (
    UPDATE decision_items
    SET
      is_locked = true,
      locked_at = now(),
      state = 'locked',
      lock_deadline = NULL,
      version = version + 1
    WHERE lock_deadline IS NOT NULL
      AND lock_deadline <= now()
      AND is_locked = false
    RETURNING id, space_id, title
  )
  SELECT count(*) INTO locked_count FROM locked;

  RETURN locked_count;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 7. RPC: Save parsed taste constraints from Day 1 Ghost Prompt
-- ═══════════════════════════════════════════════════════════════════════════════
-- Called by /api/xark when processing the onboarding response.
-- Gemini parses "I'm vegan, hate tourist traps" → ["vegan", "no_tourist_traps"]

CREATE OR REPLACE FUNCTION save_taste_profile(
  p_user_id text,
  p_constraints jsonb,
  p_raw_text text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO user_taste_profiles (user_id, hard_constraints, onboarded, onboarding_raw)
  VALUES (p_user_id, p_constraints, true, p_raw_text)
  ON CONFLICT (user_id) DO UPDATE SET
    hard_constraints = p_constraints,
    onboarded = true,
    onboarding_raw = p_raw_text,
    updated_at = now();
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 8. RPC: Cancel consensus countdown (user objected)
-- ═══════════════════════════════════════════════════════════════════════════════
-- Called when a user types an objection via Ghost Prompt.
-- Clears lock_deadline, returns the item to normal voting state.

CREATE OR REPLACE FUNCTION cancel_consensus_countdown(p_item_id text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE decision_items
  SET lock_deadline = NULL
  WHERE id = p_item_id
    AND is_locked = false
    AND lock_deadline IS NOT NULL;
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 9. ROW LEVEL SECURITY
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE user_taste_profiles ENABLE ROW LEVEL SECURITY;

-- SELECT: Users can read their own profile AND profiles of people
-- they share a space with (needed for group taste intersection at search time).
CREATE POLICY "taste_select_shared"
  ON user_taste_profiles FOR SELECT
  USING (
    user_id = (auth.jwt()->>'sub')
    OR user_id IN (
      SELECT sm.user_id FROM space_members sm
      WHERE sm.space_id IN (SELECT auth_user_space_ids())
    )
  );

-- INSERT: Users can only create their own profile.
CREATE POLICY "taste_insert_own"
  ON user_taste_profiles FOR INSERT
  WITH CHECK (user_id = (auth.jwt()->>'sub'));

-- UPDATE: Users can only update their own profile.
-- (The trigger function uses SECURITY DEFINER to bypass this for implicit weights.)
CREATE POLICY "taste_update_own"
  ON user_taste_profiles FOR UPDATE
  USING (user_id = (auth.jwt()->>'sub'));

-- DELETE: Users can only delete their own profile.
CREATE POLICY "taste_delete_own"
  ON user_taste_profiles FOR DELETE
  USING (user_id = (auth.jwt()->>'sub'));

-- ═══════════════════════════════════════════════════════════════════════════════
-- 10. SECURITY: Lock down new SECURITY DEFINER functions
-- ═══════════════════════════════════════════════════════════════════════════════

-- update_taste_on_reaction: trigger-only, no direct calls
REVOKE EXECUTE ON FUNCTION update_taste_on_reaction() FROM PUBLIC;

-- check_consensus_countdown: trigger-only, no direct calls
REVOKE EXECUTE ON FUNCTION check_consensus_countdown() FROM PUBLIC;

-- get_space_taste_profiles: called by /api/xark via supabaseAdmin (service_role)
REVOKE EXECUTE ON FUNCTION get_space_taste_profiles(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_space_taste_profiles(text) TO service_role;

-- auto_lock_expired_consensus: called by Vercel cron via supabaseAdmin (service_role)
REVOKE EXECUTE ON FUNCTION auto_lock_expired_consensus() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auto_lock_expired_consensus() TO service_role;

-- save_taste_profile: called by /api/xark via supabaseAdmin (service_role)
REVOKE EXECUTE ON FUNCTION save_taste_profile(text, jsonb, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION save_taste_profile(text, jsonb, text) TO service_role;

-- cancel_consensus_countdown: called by authenticated users via Spotlight
REVOKE EXECUTE ON FUNCTION cancel_consensus_countdown(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION cancel_consensus_countdown(text) TO authenticated;

-- ═══════════════════════════════════════════════════════════════════════════════
-- 11. REALTIME: Publish lock_deadline changes for live countdown in UI
-- ═══════════════════════════════════════════════════════════════════════════════
-- decision_items is already published (migration 012). The lock_deadline column
-- will automatically flow through the existing Realtime subscription in
-- PossibilityHorizon. No additional publication needed.

-- ═══════════════════════════════════════════════════════════════════════════════
-- 12. INDEXES
-- ═══════════════════════════════════════════════════════════════════════════════

-- GIN index on hard_constraints for containment queries (@> operator)
CREATE INDEX idx_taste_constraints ON user_taste_profiles
  USING GIN (hard_constraints);

-- GIN index on implicit_weights for key-existence queries (? operator)
CREATE INDEX idx_taste_weights ON user_taste_profiles
  USING GIN (implicit_weights);
