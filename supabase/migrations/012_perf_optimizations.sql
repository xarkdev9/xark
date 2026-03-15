-- XARK OS v2.0 — Performance Optimizations Migration
-- RPCs for batched queries, indexes, and Realtime publication.

-- ═══════════════════════════════════════════════════════
-- RPC: Get latest message per space (replaces N+1 pattern)
-- ═══════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION get_latest_messages_per_space(p_space_ids text[])
RETURNS TABLE(space_id text, content text, sender_name text, created_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT DISTINCT ON (m.space_id) m.space_id, m.content, m.sender_name, m.created_at
  FROM messages m WHERE m.space_id = ANY(p_space_ids)
  ORDER BY m.space_id, m.created_at DESC;
$$;

-- ═══════════════════════════════════════════════════════
-- RPC: Get push tokens for a space (replaces 2-query chain)
-- ═══════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION get_push_tokens_for_space(p_space_id text, p_exclude_user text DEFAULT NULL)
RETURNS TABLE(fcm_token text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT d.fcm_token FROM space_members sm
  JOIN user_devices d ON d.user_id = sm.user_id
  WHERE sm.space_id = p_space_id
    AND (p_exclude_user IS NULL OR sm.user_id != p_exclude_user);
$$;

-- ═══════════════════════════════════════════════════════
-- Indexes for common query patterns
-- ═══════════════════════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_reactions_user ON reactions(user_id);
CREATE INDEX IF NOT EXISTS idx_messages_space_created_desc ON messages(space_id, created_at DESC);

-- ═══════════════════════════════════════════════════════
-- Enable Realtime publication for core tables
-- ═══════════════════════════════════════════════════════

ALTER PUBLICATION supabase_realtime ADD TABLE messages;
ALTER PUBLICATION supabase_realtime ADD TABLE decision_items;
ALTER PUBLICATION supabase_realtime ADD TABLE space_members;
