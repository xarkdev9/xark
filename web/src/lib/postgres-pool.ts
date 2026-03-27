// hello OS v2.0 — POSTGRES TCP POOL (via Supavisor)
// Singleton postgres.js connection pool for hot-path server-side queries.
// Uses Supavisor transaction-mode pooling (port 6543) for Vercel
// frozen-container safety. idle_timeout: 10s keeps connections short-lived.
// Used by: /api/message (atomic RPC), future hot-path endpoints.

import postgres from 'postgres';

const globalForPostgres = globalThis as unknown as { sql: postgres.Sql };

export const sql = globalForPostgres.sql || postgres(process.env.DATABASE_URL!, {
  max: 5,
  idle_timeout: 10,
  connect_timeout: 5,
});

if (process.env.NODE_ENV !== 'production') globalForPostgres.sql = sql;
