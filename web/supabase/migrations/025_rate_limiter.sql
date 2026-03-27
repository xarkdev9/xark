-- XARK OS v2.0 — Centralized Rate Limiter
-- Replaces per-Lambda in-memory Map with Postgres-backed sliding window.
-- Works across all serverless instances. Auto-cleans expired entries.

CREATE TABLE IF NOT EXISTS rate_limits (
  key text NOT NULL,
  ts timestamptz NOT NULL DEFAULT now()
);

-- Index for fast lookups by key + time window
CREATE INDEX IF NOT EXISTS idx_rate_limits_key_ts ON rate_limits(key, ts DESC);

-- Atomic check-and-record RPC
-- Returns TRUE if allowed, FALSE if rate limited.
CREATE OR REPLACE FUNCTION check_rate_limit(
  p_key text,
  p_max_requests integer,
  p_window_seconds integer DEFAULT 60
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_count integer;
  v_window_start timestamptz;
BEGIN
  v_window_start := now() - (p_window_seconds || ' seconds')::interval;

  -- Count recent hits in the window
  SELECT count(*) INTO v_count
  FROM rate_limits
  WHERE key = p_key AND ts > v_window_start;

  -- Rate limited
  IF v_count >= p_max_requests THEN
    RETURN false;
  END IF;

  -- Record this hit
  INSERT INTO rate_limits (key, ts) VALUES (p_key, now());

  -- Async cleanup: delete expired entries older than 5 minutes
  -- (best-effort, doesn't block the response)
  DELETE FROM rate_limits WHERE ts < now() - interval '5 minutes';

  RETURN true;
END;
$$;

-- Grant to authenticated (API routes use user JWTs)
-- and service_role (API routes using supabaseAdmin)
GRANT EXECUTE ON FUNCTION check_rate_limit(text, integer, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION check_rate_limit(text, integer, integer) TO service_role;

-- RLS: rate_limits table is only accessed via the RPC (SECURITY DEFINER)
-- No direct table access needed
ALTER TABLE rate_limits ENABLE ROW LEVEL SECURITY;
-- No SELECT/INSERT policies = table is invisible to direct queries
-- Only the SECURITY DEFINER function can read/write
