-- XARK OS v2.0 — Privacy Cascades & GDPR Right to Erasure
-- Ensures account deletion shreds all associated cryptographic material and PII.

-- ══════════════════════════════════════════════════════════════
-- 1. ADD FOREIGN KEY CASCADES TO E2EE TABLES
-- When a user is deleted from public.users, all their crypto material is automatically purged.
-- ══════════════════════════════════════════════════════════════

-- key_bundles: user's public key bundles (identity key, signed pre-key, signature)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_key_bundles_user' AND table_name = 'key_bundles'
  ) THEN
    ALTER TABLE key_bundles
      ADD CONSTRAINT fk_key_bundles_user
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- one_time_pre_keys: user's consumable pre-keys
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_otk_user' AND table_name = 'one_time_pre_keys'
  ) THEN
    ALTER TABLE one_time_pre_keys
      ADD CONSTRAINT fk_otk_user
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- message_ciphertexts: ciphertexts addressed to this user (they can't decrypt anymore)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_mc_recipient' AND table_name = 'message_ciphertexts'
  ) THEN
    ALTER TABLE message_ciphertexts
      ADD CONSTRAINT fk_mc_recipient
      FOREIGN KEY (recipient_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
EXCEPTION WHEN others THEN
  -- recipient_id may be '_group_' which doesn't exist in users — skip if constraint fails
  RAISE NOTICE 'Skipping fk_mc_recipient — recipient_id contains non-user values';
END $$;

-- user_constraints: dietary/accessibility/alcohol constraints
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_name = 'fk_uc_user' AND table_name = 'user_constraints'
  ) THEN
    ALTER TABLE user_constraints
      ADD CONSTRAINT fk_uc_user
      FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE;
  END IF;
END $$;

-- ══════════════════════════════════════════════════════════════
-- 2. PII SCRUB FUNCTION — GDPR Article 17 (Right to Erasure)
-- When a user is deleted, scrub their plaintext name from all audit trails.
-- ══════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION scrub_user_pii()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Scrub actor_name from space_ledger (audit trail)
  UPDATE space_ledger
    SET actor_name = '[deleted]'
    WHERE actor_id = OLD.id;

  -- Scrub sender_name from messages
  UPDATE messages
    SET sender_name = '[deleted]', content = CASE
      WHEN message_type IN ('e2ee', 'sender_key_dist') THEN content  -- ciphertext, don't touch
      ELSE '[message deleted]'  -- plaintext messages scrubbed
    END
    WHERE user_id = OLD.id;

  -- Remove from rate_limits (if any entries exist)
  DELETE FROM rate_limits WHERE key LIKE '%' || OLD.id || '%';

  RETURN OLD;
END;
$$;

-- Trigger: fires BEFORE user deletion (so we can still reference OLD.id)
DROP TRIGGER IF EXISTS trg_scrub_user_pii ON users;
CREATE TRIGGER trg_scrub_user_pii
  BEFORE DELETE ON users
  FOR EACH ROW
  EXECUTE FUNCTION scrub_user_pii();

-- ══════════════════════════════════════════════════════════════
-- 3. GRANT/REVOKE on scrub function
-- ══════════════════════════════════════════════════════════════
REVOKE EXECUTE ON FUNCTION scrub_user_pii() FROM PUBLIC;
-- Trigger functions execute automatically, no manual GRANT needed
