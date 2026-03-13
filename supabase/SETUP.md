# Supabase Setup — Phase 0 Foundation

## 1. Create Supabase Project

Create a project at https://supabase.com/dashboard

## 2. Set Postgres Config Vars

In SQL Editor, run:

```sql
-- Enable dev mode (development project only)
ALTER DATABASE postgres SET app.dev_mode = 'true';

-- Set JWT secret (copy from Dashboard → Settings → API → JWT Secret)
ALTER DATABASE postgres SET app.jwt_secret = 'your-jwt-secret-here';
```

## 3. Run Migrations (in order)

Execute each file in the Supabase SQL Editor:

1. `migrations/001_foundation_schema.sql` — Tables and indexes
2. `migrations/002_functions_triggers.sql` — Triggers and RPC functions
3. `migrations/003_rls_policies.sql` — Row Level Security policies

## 4. Enable Realtime

Dashboard → Database → Replication → Enable for:
- `messages` (INSERT)
- `decision_items` (UPDATE)

## 5. Configure .env.local

Copy `.env.example` to `.env.local` and fill in values from the Supabase dashboard:

```bash
cp .env.example .env.local
```

Get values from:
- **NEXT_PUBLIC_SUPABASE_URL**: Dashboard → Settings → API → URL
- **NEXT_PUBLIC_SUPABASE_ANON_KEY**: Dashboard → Settings → API → anon/public key
- **SUPABASE_SERVICE_ROLE_KEY**: Dashboard → Settings → API → service_role key

## 6. Seed Data

```bash
npx tsx src/lib/seed.ts
```

## 7. Verify

In SQL Editor:
```sql
SELECT count(*) FROM users;          -- 5
SELECT count(*) FROM spaces;         -- 4
SELECT count(*) FROM space_members;  -- 13
SELECT count(*) FROM decision_items; -- 6
SELECT count(*) FROM messages;       -- 15
```

## 8. Test Dev Login

```bash
curl -X POST http://localhost:3000/api/dev-auth \
  -H "Content-Type: application/json" \
  -d '{"username":"ram","password":"myna"}'
```
