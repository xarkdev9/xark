-- XARK OS v2.0 — Lock Down SECURITY DEFINER Functions
-- PostgreSQL grants EXECUTE to PUBLIC by default.
-- SECURITY DEFINER functions run as the function owner (superuser).
-- Without explicit REVOKE, any authenticated user can call them with any parameters.

-- 1. REVOKE public access to dangerous functions
REVOKE EXECUTE ON FUNCTION revoke_device(text, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION fetch_key_bundle(text, integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION purge_expired_xark_messages() FROM PUBLIC;

-- 2. GRANT only to service_role (used by API routes via supabaseAdmin)
GRANT EXECUTE ON FUNCTION revoke_device(text, integer) TO service_role;
GRANT EXECUTE ON FUNCTION purge_expired_xark_messages() TO service_role;

-- 3. fetch_key_bundle needs to be callable by authenticated users
-- (clients call it directly via supabase.rpc for peer key lookups)
-- But add a JWT assertion inside the function body to prevent parameter abuse
GRANT EXECUTE ON FUNCTION fetch_key_bundle(text, integer) TO authenticated;

-- 4. Also lock down get_space_member_devices (from migration 015)
REVOKE EXECUTE ON FUNCTION get_space_member_devices(text, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION get_space_member_devices(text, text) TO authenticated;

-- 5. Lock down auth_user_space_ids (core RLS helper)
-- This is already SECURITY DEFINER for RLS bypass, but should not be directly callable
REVOKE EXECUTE ON FUNCTION auth_user_space_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_user_space_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION auth_user_space_ids() TO service_role;
