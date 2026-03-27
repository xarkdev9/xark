-- XARK OS v2.0 — Summon Links
-- Single-use cryptographic invite links for 1-on-1 connections.

CREATE TABLE summon_links (
  code text PRIMARY KEY,
  creator_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_by text REFERENCES users(id) ON DELETE SET NULL,
  claimed_at timestamptz,
  space_id text REFERENCES spaces(id) ON DELETE SET NULL,
  expires_at timestamptz NOT NULL DEFAULT now() + interval '7 days'
);

CREATE INDEX idx_summon_creator ON summon_links(creator_id);
CREATE INDEX idx_summon_expires ON summon_links(expires_at) WHERE claimed_by IS NULL;

ALTER TABLE summon_links ENABLE ROW LEVEL SECURITY;

CREATE POLICY "summon_select_creator" ON summon_links
  FOR SELECT USING (creator_id = (auth.jwt()->>'sub'));

CREATE POLICY "summon_select_claimant" ON summon_links
  FOR SELECT USING (claimed_by = (auth.jwt()->>'sub'));

CREATE POLICY "summon_insert" ON summon_links
  FOR INSERT WITH CHECK (creator_id = (auth.jwt()->>'sub'));

CREATE OR REPLACE FUNCTION claim_summon_link(
  p_code text,
  p_claimant_id text
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_link summon_links%ROWTYPE;
  v_creator users%ROWTYPE;
  v_claimant users%ROWTYPE;
  v_space_id text;
BEGIN
  SELECT * INTO v_link FROM summon_links
    WHERE code = p_code AND claimed_by IS NULL AND expires_at > now()
    FOR UPDATE SKIP LOCKED;

  IF v_link IS NULL THEN
    RETURN jsonb_build_object('error', 'link expired or already claimed');
  END IF;

  IF v_link.creator_id = p_claimant_id THEN
    RETURN jsonb_build_object('error', 'cannot summon yourself');
  END IF;

  SELECT * INTO v_creator FROM users WHERE id = v_link.creator_id;
  SELECT * INTO v_claimant FROM users WHERE id = p_claimant_id;

  IF v_creator IS NULL OR v_claimant IS NULL THEN
    RETURN jsonb_build_object('error', 'user not found');
  END IF;

  v_space_id := 'space_' || replace(gen_random_uuid()::text, '-', '');

  INSERT INTO spaces (id, title, owner_id, atmosphere)
  VALUES (
    v_space_id,
    v_creator.display_name || ' & ' || v_claimant.display_name,
    v_link.creator_id,
    'sanctuary'
  );

  INSERT INTO space_members (space_id, user_id, role)
  VALUES (v_space_id, v_link.creator_id, 'owner'),
         (v_space_id, p_claimant_id, 'member')
  ON CONFLICT (space_id, user_id) DO NOTHING;

  INSERT INTO messages (id, space_id, role, content, user_id, message_type)
  VALUES (
    'msg_' || gen_random_uuid()::text,
    v_space_id,
    'system',
    'connected. encrypted, always.',
    v_link.creator_id,
    'system'
  );

  UPDATE summon_links
  SET claimed_by = p_claimant_id, claimed_at = now(), space_id = v_space_id
  WHERE code = p_code;

  RETURN jsonb_build_object(
    'spaceId', v_space_id,
    'creatorName', v_creator.display_name,
    'claimantName', v_claimant.display_name
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION claim_summon_link(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION claim_summon_link(text, text) TO service_role;

CREATE OR REPLACE FUNCTION purge_expired_summon_links()
RETURNS integer
LANGUAGE sql SECURITY DEFINER
SET search_path = public
AS $$
  WITH deleted AS (
    DELETE FROM summon_links
    WHERE expires_at < now() AND claimed_by IS NULL
    RETURNING code
  )
  SELECT count(*)::integer FROM deleted;
$$;

REVOKE EXECUTE ON FUNCTION purge_expired_summon_links() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION purge_expired_summon_links() TO service_role;
