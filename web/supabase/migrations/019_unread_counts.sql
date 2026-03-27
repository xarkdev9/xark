-- 019_unread_counts.sql
-- Unread message counts: last_read_at per user per space

-- Add last_read_at to space_members
ALTER TABLE space_members ADD COLUMN IF NOT EXISTS last_read_at timestamptz DEFAULT now();

-- RPC: get unread counts for all spaces a user belongs to
-- Returns: [{ space_id, unread_count }]
CREATE OR REPLACE FUNCTION get_unread_counts()
RETURNS TABLE(space_id text, unread_count bigint)
LANGUAGE sql SECURITY DEFINER STABLE
SET search_path = public
AS $$
  SELECT
    sm.space_id,
    COUNT(m.id) AS unread_count
  FROM space_members sm
  LEFT JOIN messages m
    ON m.space_id = sm.space_id
    AND m.created_at > sm.last_read_at
    AND m.user_id IS DISTINCT FROM (auth.jwt()->>'sub')  -- don't count own messages
    AND m.role != 'system'
  WHERE sm.user_id = auth.jwt()->>'sub'
  GROUP BY sm.space_id;
$$;

-- RPC: mark a space as read (update last_read_at to now)
CREATE OR REPLACE FUNCTION mark_space_read(p_space_id text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE space_members
  SET last_read_at = now()
  WHERE space_id = p_space_id
    AND user_id = auth.jwt()->>'sub';
END;
$$;
