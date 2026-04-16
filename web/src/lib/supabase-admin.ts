// hello OS v2.0 — SUPABASE ADMIN CLIENT
// Service-role key for server-side operations ONLY.
// This client bypasses RLS — never expose to the browser.
// Used by: /api/dev-auth, /api/hello, seed.ts
//
// NOTE: DATABASE_URL must point to Supavisor pooler (port 6543)
// with ?pgbouncer=true. Direct connections (port 5432) stored in
// DATABASE_URL_DIRECT for migrations only.
// See: docs/superpowers/specs/2026-03-27-fortress-backend-hardening-design.md §2

import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceRoleKey) {
  console.warn(
    "supabase-admin: NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY missing. Admin client will not function."
  );
}

export const supabaseAdmin = createClient(
  url || "https://placeholder.supabase.co",
  serviceRoleKey || "placeholder",
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  }
);
