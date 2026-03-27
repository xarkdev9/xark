-- Phase 0 Foundation: Password-only verification RPC
-- JWT signing moved to Node.js (jose). This function only verifies credentials.
-- Run AFTER 002_functions_triggers.sql

-- dev_verify_password: Verify username + bcrypt password, return user info.
-- No JWT signing. Node.js handles that via jose.
CREATE OR REPLACE FUNCTION dev_verify_password(p_username text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_user record;
BEGIN
  -- Look up user by display_name with a password_hash
  SELECT id, display_name, password_hash INTO v_user
  FROM users
  WHERE display_name = p_username AND password_hash IS NOT NULL;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'user_not_found: no dev user with username %', p_username;
  END IF;

  -- Verify bcrypt password
  IF v_user.password_hash != crypt(p_password, v_user.password_hash) THEN
    RAISE EXCEPTION 'invalid_credentials: wrong password';
  END IF;

  RETURN jsonb_build_object(
    'user_id', v_user.id,
    'display_name', v_user.display_name
  );
END;
$$;
