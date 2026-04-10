-- Enable pgcrypto in extensions schema (Supabase default location)
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

-- Wrapper so gen_random_bytes works in public schema
CREATE OR REPLACE FUNCTION public.gen_random_bytes(integer) RETURNS bytea
LANGUAGE sql STABLE AS $$ SELECT extensions.gen_random_bytes($1) $$;
