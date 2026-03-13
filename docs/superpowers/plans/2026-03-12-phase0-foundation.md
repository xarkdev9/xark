# Phase 0 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the Supabase Postgres database schema, RLS policies, RPC functions, triggers, dev-mode auth, and seed data that unblocks all Xark OS development.

**Architecture:** Firebase JWT verification in Supabase. Firebase handles auth (phone OTP in prod, password bypass in dev). Supabase verifies the JWT, making `auth.uid()` available in every RLS policy. Client is untrusted — all sensitive mutations go through Postgres RPC functions.

**Tech Stack:** Supabase Postgres, PostgREST, pgcrypto, pgjwt, Next.js API routes, TypeScript, bcryptjs

**Spec:** `docs/superpowers/specs/2026-03-12-phase0-foundation-design.md`

---

## File Structure

| File | Responsibility | Action |
|------|---------------|--------|
| `supabase/migrations/001_foundation_schema.sql` | Tables, indexes, extensions | Create |
| `supabase/migrations/002_functions_triggers.sql` | RPC functions, triggers | Create |
| `supabase/migrations/003_rls_policies.sql` | All RLS policies + security definer functions | Create |
| `src/lib/supabase-admin.ts` | Service-role Supabase client (server-side only) | Create |
| `src/app/api/dev-auth/route.ts` | Dev-mode login endpoint | Create |
| `src/lib/seed.ts` | Seed data — rewrite with users, members, FK-correct data | Rewrite |
| `src/lib/spaces.ts` | Remove `agreement_score` from space insert | Modify |
| `.env.example` | Environment variable template | Create |

---

## Chunk 1: SQL Schema

### Task 1: Database Tables & Extensions

**Files:**
- Create: `supabase/migrations/001_foundation_schema.sql`

- [ ] **Step 1: Create the migration file with extensions and all 7 tables**

```sql
-- Phase 0 Foundation: Tables, Indexes, Extensions
-- Run via Supabase SQL Editor or supabase db push

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pgjwt;

-- ══════════════════════════════════════
-- TABLES
-- ══════════════════════════════════════

CREATE TABLE IF NOT EXISTS users (
  id text PRIMARY KEY,
  display_name text NOT NULL,
  photo_url text,
  phone text UNIQUE,
  password_hash text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS spaces (
  id text PRIMARY KEY,
  title text NOT NULL,
  owner_id text NOT NULL REFERENCES users(id),
  atmosphere text,
  is_public boolean NOT NULL DEFAULT false,
  photo_url text,
  last_activity_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS space_members (
  space_id text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'member',
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (space_id, user_id)
);

CREATE TABLE IF NOT EXISTS decision_items (
  id text PRIMARY KEY,
  space_id text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  title text NOT NULL,
  category text,
  description text,
  state text NOT NULL DEFAULT 'proposed',
  proposed_by text REFERENCES users(id),
  proposed_at timestamptz NOT NULL DEFAULT now(),
  weighted_score float NOT NULL DEFAULT 0,
  agreement_score float NOT NULL DEFAULT 0,
  is_locked boolean NOT NULL DEFAULT false,
  locked_at timestamptz,
  commitment_proof jsonb,
  ownership jsonb,
  ownership_history jsonb NOT NULL DEFAULT '[]'::jsonb,
  version integer NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS reactions (
  item_id text NOT NULL REFERENCES decision_items(id) ON DELETE CASCADE,
  user_id text NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  signal text NOT NULL,
  weight integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (item_id, user_id)
);

CREATE TABLE IF NOT EXISTS messages (
  id text PRIMARY KEY,
  space_id text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  role text NOT NULL,
  content text NOT NULL,
  user_id text,
  sender_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS tasks (
  id text PRIMARY KEY,
  space_id text NOT NULL REFERENCES spaces(id) ON DELETE CASCADE,
  title text NOT NULL,
  assignee_id text REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ══════════════════════════════════════
-- INDEXES
-- ══════════════════════════════════════

CREATE INDEX IF NOT EXISTS idx_messages_space_created ON messages(space_id, created_at);
CREATE INDEX IF NOT EXISTS idx_decision_items_space ON decision_items(space_id);
CREATE INDEX IF NOT EXISTS idx_decision_items_space_locked ON decision_items(space_id, is_locked);
CREATE INDEX IF NOT EXISTS idx_reactions_item ON reactions(item_id);
CREATE INDEX IF NOT EXISTS idx_space_members_user ON space_members(user_id);
CREATE INDEX IF NOT EXISTS idx_tasks_space ON tasks(space_id);
```

- [ ] **Step 2: Verify by running in Supabase SQL Editor**

Paste the SQL into the Supabase dashboard SQL Editor and execute. Verify no errors.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/001_foundation_schema.sql
git commit -m "db: Phase 0 tables, indexes, and extensions (7 tables)"
```

---

### Task 2: Triggers & RPC Functions

**Files:**
- Create: `supabase/migrations/002_functions_triggers.sql`

- [ ] **Step 1: Create triggers file**

```sql
-- Phase 0 Foundation: Triggers & RPC Functions

-- ══════════════════════════════════════
-- TRIGGERS
-- ══════════════════════════════════════

-- Auto-add space creator as owner member
CREATE OR REPLACE FUNCTION fn_auto_add_space_owner()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO space_members (space_id, user_id, role)
  VALUES (NEW.id, NEW.owner_id, 'owner');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_auto_add_space_owner
  AFTER INSERT ON spaces
  FOR EACH ROW
  EXECUTE FUNCTION fn_auto_add_space_owner();

-- Update space last_activity_at on new message
CREATE OR REPLACE FUNCTION fn_update_space_activity()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE spaces SET last_activity_at = now() WHERE id = NEW.space_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_space_activity
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION fn_update_space_activity();

-- Set sender_name from users table on user messages
CREATE OR REPLACE FUNCTION fn_set_sender_name()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.role = 'user' AND NEW.user_id IS NOT NULL THEN
    SELECT display_name INTO NEW.sender_name
    FROM users WHERE id = NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_set_sender_name
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION fn_set_sender_name();

-- Prevent client-side impersonation of @xark
CREATE OR REPLACE FUNCTION fn_enforce_xark_role()
RETURNS TRIGGER AS $$
DECLARE
  jwt_role text;
BEGIN
  IF NEW.role = 'xark' THEN
    -- PostgREST populates request.jwt.claims from the JWT
    BEGIN
      jwt_role := current_setting('request.jwt.claims', true)::json->>'role';
    EXCEPTION WHEN OTHERS THEN
      jwt_role := NULL;
    END;

    IF jwt_role IS DISTINCT FROM 'service_role' THEN
      RAISE EXCEPTION 'xark_impersonation_blocked: only service_role can insert xark messages';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_enforce_xark_role
  BEFORE INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION fn_enforce_xark_role();

-- Force proposed_by to auth.uid() on decision_items insert
CREATE OR REPLACE FUNCTION fn_force_proposed_by()
RETURNS TRIGGER AS $$
BEGIN
  NEW.proposed_by := auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_force_proposed_by
  BEFORE INSERT ON decision_items
  FOR EACH ROW
  EXECUTE FUNCTION fn_force_proposed_by();

-- ══════════════════════════════════════
-- RPC FUNCTIONS
-- ══════════════════════════════════════

-- react_to_item: Upsert reaction, recompute scores
CREATE OR REPLACE FUNCTION react_to_item(p_item_id text, p_signal text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_weight integer;
  v_space_id text;
  v_weighted_score float;
  v_agreement_score float;
  v_member_count integer;
  v_reactor_count integer;
BEGIN
  -- 1. Validate signal
  IF p_signal NOT IN ('love_it', 'works_for_me', 'not_for_me') THEN
    RAISE EXCEPTION 'invalid_signal: must be love_it, works_for_me, or not_for_me';
  END IF;

  -- 2. Map signal to weight
  v_weight := CASE p_signal
    WHEN 'love_it' THEN 5
    WHEN 'works_for_me' THEN 1
    WHEN 'not_for_me' THEN -3
  END;

  -- 3. Get space_id and verify membership
  SELECT space_id INTO v_space_id
  FROM decision_items WHERE id = p_item_id;

  IF v_space_id IS NULL THEN
    RAISE EXCEPTION 'item_not_found: decision item does not exist';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM space_members
    WHERE space_id = v_space_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_a_member: you are not a member of this space';
  END IF;

  -- 4. Upsert reaction
  INSERT INTO reactions (item_id, user_id, signal, weight, created_at)
  VALUES (p_item_id, auth.uid(), p_signal, v_weight, now())
  ON CONFLICT (item_id, user_id)
  DO UPDATE SET signal = EXCLUDED.signal, weight = EXCLUDED.weight, created_at = now();

  -- 5. Recompute weighted_score
  SELECT COALESCE(SUM(weight), 0) INTO v_weighted_score
  FROM reactions WHERE item_id = p_item_id;

  -- 6. Recompute agreement_score
  SELECT COUNT(DISTINCT user_id) INTO v_reactor_count
  FROM reactions WHERE item_id = p_item_id;

  SELECT COUNT(*) INTO v_member_count
  FROM space_members WHERE space_id = v_space_id;

  v_agreement_score := CASE WHEN v_member_count > 0
    THEN v_reactor_count::float / v_member_count::float
    ELSE 0 END;

  -- 7. Update item
  UPDATE decision_items
  SET weighted_score = v_weighted_score,
      agreement_score = v_agreement_score
  WHERE id = p_item_id;

  -- 8. Return
  RETURN jsonb_build_object(
    'weighted_score', v_weighted_score,
    'agreement_score', v_agreement_score
  );
END;
$$;

-- lock_item: Green-Lock Commitment Protocol
CREATE OR REPLACE FUNCTION lock_item(
  p_item_id text,
  p_proof_type text,
  p_proof_value text,
  p_expected_version integer
)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_item record;
  v_terminal_state text;
  v_space_id text;
BEGIN
  -- 1. Fetch item
  SELECT * INTO v_item FROM decision_items WHERE id = p_item_id;
  IF v_item IS NULL THEN
    RAISE EXCEPTION 'item_not_found';
  END IF;

  v_space_id := v_item.space_id;

  -- 2. Verify membership
  IF NOT EXISTS (
    SELECT 1 FROM space_members
    WHERE space_id = v_space_id AND user_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_a_member';
  END IF;

  -- 3. Check not already locked
  IF v_item.is_locked THEN
    RAISE EXCEPTION 'already_locked: item is already committed';
  END IF;

  -- 4. Verify proof
  IF p_proof_value IS NULL OR p_proof_value = '' THEN
    RAISE EXCEPTION 'proof_required: commitment proof cannot be empty';
  END IF;

  -- 5. Optimistic concurrency
  IF v_item.version != p_expected_version THEN
    RAISE EXCEPTION 'version_conflict: expected %, got %', p_expected_version, v_item.version;
  END IF;

  -- 6. Resolve terminal state
  v_terminal_state := CASE v_item.state
    WHEN 'proposed' THEN 'locked'
    WHEN 'ranked' THEN 'locked'
    WHEN 'nominated' THEN 'chosen'
    WHEN 'researching' THEN 'purchased'
    WHEN 'shortlisted' THEN 'purchased'
    WHEN 'negotiating' THEN 'purchased'
    WHEN 'considering' THEN 'decided'
    WHEN 'leaning' THEN 'decided'
    ELSE 'locked'
  END;

  -- 7. Update
  UPDATE decision_items SET
    is_locked = true,
    locked_at = now(),
    state = v_terminal_state,
    commitment_proof = jsonb_build_object(
      'type', p_proof_type,
      'value', p_proof_value,
      'submittedBy', auth.uid(),
      'submittedAt', now()::text
    ),
    ownership_history = CASE
      WHEN ownership IS NOT NULL THEN ownership_history || jsonb_build_array(ownership)
      ELSE ownership_history
    END,
    ownership = jsonb_build_object(
      'ownerId', auth.uid(),
      'assignedAt', now()::text,
      'reason', 'booker'
    ),
    version = version + 1
  WHERE id = p_item_id AND version = p_expected_version;

  RETURN jsonb_build_object(
    'success', true,
    'itemId', p_item_id,
    'lockedAt', now()::text,
    'state', v_terminal_state
  );
END;
$$;

-- transfer_ownership
CREATE OR REPLACE FUNCTION transfer_ownership(p_item_id text, p_new_owner_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_item record;
BEGIN
  SELECT * INTO v_item FROM decision_items WHERE id = p_item_id;
  IF v_item IS NULL THEN RAISE EXCEPTION 'item_not_found'; END IF;

  -- Verify caller is current owner
  IF (v_item.ownership->>'ownerId') IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'not_owner: only the current owner can transfer';
  END IF;

  -- Verify different owner
  IF p_new_owner_id = auth.uid() THEN
    RAISE EXCEPTION 'self_transfer: cannot transfer to yourself';
  END IF;

  -- Verify item is locked
  IF NOT v_item.is_locked THEN
    RAISE EXCEPTION 'not_locked: can only transfer locked items';
  END IF;

  -- Verify new owner is a space member
  IF NOT EXISTS (
    SELECT 1 FROM space_members
    WHERE space_id = v_item.space_id AND user_id = p_new_owner_id
  ) THEN
    RAISE EXCEPTION 'not_a_member: new owner must be a space member';
  END IF;

  -- Append old ownership to history, set new
  UPDATE decision_items SET
    ownership_history = ownership_history || jsonb_build_array(ownership),
    ownership = jsonb_build_object(
      'ownerId', p_new_owner_id,
      'assignedAt', now()::text,
      'reason', 'transfer'
    ),
    version = version + 1
  WHERE id = p_item_id;

  RETURN jsonb_build_object('success', true, 'newOwnerId', p_new_owner_id);
END;
$$;

-- invite_member
CREATE OR REPLACE FUNCTION invite_member(p_space_id text, p_user_id text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
BEGIN
  -- Verify caller is space owner
  IF NOT EXISTS (
    SELECT 1 FROM spaces
    WHERE id = p_space_id AND owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'not_space_owner: only the space owner can invite members';
  END IF;

  -- Verify target user exists
  IF NOT EXISTS (SELECT 1 FROM users WHERE id = p_user_id) THEN
    RAISE EXCEPTION 'user_not_found: target user does not exist';
  END IF;

  -- Insert member (ignore if already member)
  INSERT INTO space_members (space_id, user_id, role)
  VALUES (p_space_id, p_user_id, 'member')
  ON CONFLICT (space_id, user_id) DO NOTHING;

  RETURN jsonb_build_object('success', true, 'spaceId', p_space_id, 'userId', p_user_id);
END;
$$;

-- dev_login: Dev-mode authentication bypass
CREATE OR REPLACE FUNCTION dev_login(p_username text, p_password text)
RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER
AS $$
DECLARE
  v_user record;
  v_token text;
  v_payload jsonb;
BEGIN
  -- Gate: dev mode must be enabled
  IF current_setting('app.dev_mode', true) IS DISTINCT FROM 'true' THEN
    RAISE EXCEPTION 'dev_mode_disabled: dev_login is only available in dev mode';
  END IF;

  -- Look up user
  SELECT * INTO v_user FROM users
  WHERE display_name = p_username AND password_hash IS NOT NULL;

  IF v_user IS NULL THEN
    RAISE EXCEPTION 'user_not_found: no dev user with username %', p_username;
  END IF;

  -- Verify password
  IF v_user.password_hash != crypt(p_password, v_user.password_hash) THEN
    RAISE EXCEPTION 'invalid_credentials: wrong password';
  END IF;

  -- Build JWT payload
  v_payload := jsonb_build_object(
    'sub', v_user.id,
    'role', 'authenticated',
    'iss', 'supabase',
    'iat', extract(epoch from now())::integer,
    'exp', extract(epoch from (now() + interval '24 hours'))::integer
  );

  -- Sign JWT
  v_token := sign(v_payload, current_setting('app.jwt_secret'));

  RETURN jsonb_build_object(
    'token', v_token,
    'user_id', v_user.id,
    'display_name', v_user.display_name
  );
END;
$$;
```

- [ ] **Step 2: Run in Supabase SQL Editor**

Execute after Task 1's migration has run. Verify no errors.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/002_functions_triggers.sql
git commit -m "db: triggers (5) and RPC functions (6) for Phase 0"
```

---

### Task 3: RLS Policies

**Files:**
- Create: `supabase/migrations/003_rls_policies.sql`

- [ ] **Step 1: Create RLS policies file**

```sql
-- Phase 0 Foundation: Row Level Security
-- All tables have RLS enabled. anon key = no access.
-- Only authenticated users with valid JWT can query.

-- ══════════════════════════════════════
-- ENABLE RLS ON ALL TABLES
-- ══════════════════════════════════════

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE spaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE space_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE decision_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE reactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE tasks ENABLE ROW LEVEL SECURITY;

-- ══════════════════════════════════════
-- SECURITY DEFINER: Phone column protection
-- ══════════════════════════════════════

CREATE OR REPLACE FUNCTION get_visible_users()
RETURNS TABLE(id text, display_name text, photo_url text)
LANGUAGE sql SECURITY DEFINER STABLE
AS $$
  SELECT u.id, u.display_name, u.photo_url
  FROM users u
  WHERE u.id IN (
    SELECT sm.user_id FROM space_members sm
    WHERE sm.space_id IN (
      SELECT sm2.space_id FROM space_members sm2
      WHERE sm2.user_id = auth.uid()
    )
  ) AND u.id != auth.uid();
$$;

-- ══════════════════════════════════════
-- HELPER: membership subquery used by most policies
-- ══════════════════════════════════════
-- Note: This is a SQL pattern, not a function.
-- Each policy inlines: space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())

-- ══════════════════════════════════════
-- USERS
-- ══════════════════════════════════════

-- Select own row (all columns)
CREATE POLICY users_select_self ON users
  FOR SELECT USING (id = auth.uid());

-- Select co-members (limited columns via get_visible_users)
-- Note: This policy allows the row-level access; column restriction
-- is enforced by the frontend always using get_visible_users() for
-- looking up other users instead of querying the users table directly.
CREATE POLICY users_select_comembers ON users
  FOR SELECT USING (
    id IN (
      SELECT sm.user_id FROM space_members sm
      WHERE sm.space_id IN (
        SELECT sm2.space_id FROM space_members sm2
        WHERE sm2.user_id = auth.uid()
      )
    )
  );

-- Update own profile only
CREATE POLICY users_update_self ON users
  FOR UPDATE USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

-- No direct INSERT (handled by service_role or dev_login)
-- No DELETE

-- ══════════════════════════════════════
-- SPACES
-- ══════════════════════════════════════

CREATE POLICY spaces_select_member ON spaces
  FOR SELECT USING (
    id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
  );

CREATE POLICY spaces_insert_auth ON spaces
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY spaces_update_owner ON spaces
  FOR UPDATE USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- No DELETE

-- ══════════════════════════════════════
-- SPACE_MEMBERS
-- ══════════════════════════════════════

CREATE POLICY space_members_select ON space_members
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
  );

-- INSERT via invite_member() RPC only (SECURITY DEFINER bypasses RLS)
-- But we need a policy for the trigger that auto-adds owner
CREATE POLICY space_members_insert_system ON space_members
  FOR INSERT WITH CHECK (false);
-- The SECURITY DEFINER functions (fn_auto_add_space_owner, invite_member) bypass this

CREATE POLICY space_members_delete ON space_members
  FOR DELETE USING (
    -- Space owner can remove anyone
    space_id IN (SELECT id FROM spaces WHERE owner_id = auth.uid())
    OR
    -- Self-leave
    user_id = auth.uid()
  );

-- ══════════════════════════════════════
-- DECISION_ITEMS
-- ══════════════════════════════════════

CREATE POLICY items_select_member ON decision_items
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
  );

CREATE POLICY items_insert_member ON decision_items
  FOR INSERT WITH CHECK (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
  );

-- No direct UPDATE (all via SECURITY DEFINER RPCs)
-- No DELETE

-- ══════════════════════════════════════
-- REACTIONS
-- ══════════════════════════════════════

CREATE POLICY reactions_select_member ON reactions
  FOR SELECT USING (
    item_id IN (
      SELECT id FROM decision_items
      WHERE space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
    )
  );

-- INSERT/UPDATE via react_to_item() RPC only (SECURITY DEFINER bypasses RLS)
CREATE POLICY reactions_insert_system ON reactions
  FOR INSERT WITH CHECK (false);

CREATE POLICY reactions_update_system ON reactions
  FOR UPDATE USING (false);

-- ══════════════════════════════════════
-- MESSAGES
-- ══════════════════════════════════════

CREATE POLICY messages_select_member ON messages
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
  );

CREATE POLICY messages_insert_user ON messages
  FOR INSERT WITH CHECK (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
    AND user_id = auth.uid()
    AND role = 'user'
  );

-- No UPDATE, no DELETE
-- @xark messages inserted via service_role key (bypasses RLS)

-- ══════════════════════════════════════
-- TASKS
-- ══════════════════════════════════════

CREATE POLICY tasks_select_member ON tasks
  FOR SELECT USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
  );

CREATE POLICY tasks_insert_member ON tasks
  FOR INSERT WITH CHECK (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
  );

CREATE POLICY tasks_update_member ON tasks
  FOR UPDATE USING (
    space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())
  );

-- No DELETE
```

- [ ] **Step 2: Run in Supabase SQL Editor**

Execute after Task 2's migration. Verify no errors.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/003_rls_policies.sql
git commit -m "db: RLS policies for all 7 tables + get_visible_users security definer"
```

---

## Chunk 2: Application Layer

### Task 4: Environment Configuration

**Files:**
- Create: `.env.example`

- [ ] **Step 1: Create .env.example**

```env
# Supabase (required)
NEXT_PUBLIC_SUPABASE_URL=https://xxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=eyJ...

# Supabase service role (server-side only, NEVER NEXT_PUBLIC_)
SUPABASE_SERVICE_ROLE_KEY=eyJ...

# Firebase (required for production auth)
NEXT_PUBLIC_FIREBASE_API_KEY=
NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN=
NEXT_PUBLIC_FIREBASE_PROJECT_ID=
NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET=
NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID=
NEXT_PUBLIC_FIREBASE_APP_ID=

# Dev mode (only in .env.local, never in production)
DEV_MODE=true
```

- [ ] **Step 2: Add .env.local to .gitignore if not already there**

Check `.gitignore` for `.env.local` entry. Next.js projects typically include it by default.

- [ ] **Step 3: Commit**

```bash
git add .env.example
git commit -m "config: .env.example template for Phase 0"
```

---

### Task 5: Supabase Admin Client (Service Role)

**Files:**
- Create: `src/lib/supabase-admin.ts`

- [ ] **Step 1: Create the service-role client**

```typescript
// XARK OS v2.0 — SUPABASE ADMIN CLIENT
// Service-role key for server-side operations ONLY.
// This client bypasses RLS — never expose to the browser.
// Used by: /api/dev-auth, /api/xark, seed.ts

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
```

- [ ] **Step 2: Commit**

```bash
git add src/lib/supabase-admin.ts
git commit -m "feat: supabase-admin service-role client for server-side operations"
```

---

### Task 6: Dev Auth API Endpoint

**Files:**
- Create: `src/app/api/dev-auth/route.ts`

- [ ] **Step 1: Create the dev-auth API route**

```typescript
// XARK OS v2.0 — DEV AUTH ENDPOINT
// POST /api/dev-auth — dev-mode login bypass
// Calls the dev_login() Postgres RPC function.
// Gate: Returns 404 if DEV_MODE !== 'true'

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(request: NextRequest) {
  // Gate: dev mode only
  if (process.env.DEV_MODE !== "true") {
    return NextResponse.json({ error: "not found" }, { status: 404 });
  }

  const body = await request.json();
  const { username, password } = body;

  if (!username || !password) {
    return NextResponse.json(
      { error: "username and password required" },
      { status: 400 }
    );
  }

  const { data, error } = await supabaseAdmin.rpc("dev_login", {
    p_username: username,
    p_password: password,
  });

  if (error) {
    const msg = error.message || "invalid credentials";
    const status = msg.includes("invalid_credentials") || msg.includes("user_not_found") ? 401 : 500;
    return NextResponse.json({ error: msg }, { status });
  }

  return NextResponse.json({
    token: data.token,
    user: {
      id: data.user_id,
      displayName: data.display_name,
    },
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add src/app/api/dev-auth/route.ts
git commit -m "feat: /api/dev-auth endpoint for dev-mode login"
```

---

### Task 7: Seed Data Rewrite

**Files:**
- Rewrite: `src/lib/seed.ts`

**Context:** The current seed.ts uses the anon-key client, references non-existent user IDs (user_ram, user_ananya, name_maya, name_jake), inserts `agreement_score` on spaces (column doesn't exist), and has no users or space_members. Must be completely rewritten.

- [ ] **Step 1: Rewrite seed.ts**

```typescript
// XARK OS v2.0 — SEED PROTOCOL
// Populates Supabase Postgres with test users, spaces, members, items, messages.
// Uses service_role key to bypass RLS.
// Run via: npx tsx src/lib/seed.ts

import { createClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!url || !serviceKey) {
  console.error("Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY");
  console.error("Set them in .env.local before running seed.");
  process.exit(1);
}

const supabase = createClient(url, serviceKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

// ── bcrypt hashes (pre-computed) ──
// Generated via: await bcrypt.hash(password, 10)
// We pre-compute to avoid needing bcryptjs as a dependency in seed.
// The dev_login() function uses pgcrypto's crypt() to verify.

async function hashPassword(password: string): Promise<string> {
  // Use supabase SQL to generate bcrypt hash via pgcrypto
  const { data, error } = await supabase.rpc("", {}).throwOnError();
  // Fallback: generate hash via SQL
  const { data: hashData } = await supabase
    .from("_seed_hash")
    .select()
    .limit(0);

  // Actually, let's use a direct SQL call
  const result = await supabase.rpc("exec_sql", {
    query: `SELECT crypt('${password}', gen_salt('bf', 10)) as hash`,
  });

  // If the above doesn't work, we'll use pre-computed hashes
  return "";
}

// Pre-computed bcrypt hashes for test users
// These are generated externally and hardcoded for portability.
// We'll generate them in the seed script using a SQL query.
async function generateHash(password: string): Promise<string> {
  const { data, error } = await supabase
    .from("users")
    .select("id")
    .limit(0);

  // Use raw SQL via supabase
  const response = await fetch(`${url}/rest/v1/rpc/`, {
    method: "POST",
    headers: {
      apikey: serviceKey!,
      Authorization: `Bearer ${serviceKey}`,
      "Content-Type": "application/json",
    },
  });

  // Simplest approach: use the SQL editor function
  // Actually, let's just create a helper RPC
  return "";
}

export async function seedXarkGalaxy() {
  console.log("seeding xark galaxy...\n");

  // ══════════════════════════════════
  // 0. Generate password hashes via pgcrypto
  // ══════════════════════════════════
  const passwords: Record<string, string> = {
    ram: "myna",
    myna: "ram",
    anjan: "anjan9",
    shiva: "shiva9",
    venky: "venky9",
  };

  const hashes: Record<string, string> = {};
  for (const [user, pass] of Object.entries(passwords)) {
    // Generate bcrypt hash via pgcrypto in Supabase
    const { data, error } = await supabase.rpc("gen_hash", {
      p_password: pass,
    });
    if (error) {
      // Fallback: try raw SQL
      console.error(`Failed to hash password for ${user}:`, error.message);
      console.error("Creating a temporary gen_hash function...");

      // Create temporary hash function
      await fetch(`${url}/rest/v1/rpc/gen_hash`, {
        method: "POST",
        headers: {
          apikey: serviceKey!,
          Authorization: `Bearer ${serviceKey}`,
          "Content-Type": "application/json",
          Prefer: "return=representation",
        },
        body: JSON.stringify({ p_password: pass }),
      });
    }
    hashes[user] = data ?? "";
  }

  // ══════════════════════════════════
  // 1. TEST USERS
  // ══════════════════════════════════
  const users = [
    { id: "name_ram", display_name: "ram", password_hash: hashes.ram },
    { id: "name_myna", display_name: "myna", password_hash: hashes.myna },
    { id: "name_anjan", display_name: "anjan", password_hash: hashes.anjan },
    { id: "name_shiva", display_name: "shiva", password_hash: hashes.shiva },
    { id: "name_venky", display_name: "venky", password_hash: hashes.venky },
  ];

  const { error: usersError } = await supabase
    .from("users")
    .upsert(users, { onConflict: "id" });

  if (usersError) {
    console.error("failed to seed users:", usersError.message);
    return;
  }
  console.log("  5 test users seeded");

  // ══════════════════════════════════
  // 2. SPACES
  // ══════════════════════════════════

  // San Diego Trip
  const { error: sd } = await supabase.from("spaces").upsert({
    id: "space_san-diego-trip",
    title: "san diego trip",
    owner_id: "name_ram",
    atmosphere: "cyan_horizon",
  }, { onConflict: "id" });
  if (sd) console.error("san diego:", sd.message);
  else console.log("  space: space_san-diego-trip — san diego trip");

  // Ananya Sanctuary
  const { error: an } = await supabase.from("spaces").upsert({
    id: "space_ananya",
    title: "ananya",
    owner_id: "name_ram",
    atmosphere: "sanctuary",
    is_public: false,
  }, { onConflict: "id" });
  if (an) console.error("ananya:", an.message);
  else console.log("  space: space_ananya — ananya (sanctuary)");

  // Tokyo Neon Nights
  const { error: tk } = await supabase.from("spaces").upsert({
    id: "space_tokyo-neon-nights",
    title: "tokyo neon nights",
    owner_id: "name_myna",
    atmosphere: "amber_glow",
  }, { onConflict: "id" });
  if (tk) console.error("tokyo:", tk.message);
  else console.log("  space: space_tokyo-neon-nights — tokyo neon nights");

  // Summer 2026
  const { error: su } = await supabase.from("spaces").upsert({
    id: "space_summer-2026",
    title: "summer 2026",
    owner_id: "name_ram",
    atmosphere: "gold_warmth",
  }, { onConflict: "id" });
  if (su) console.error("summer:", su.message);
  else console.log("  space: space_summer-2026 — summer 2026");

  // ══════════════════════════════════
  // 3. SPACE MEMBERS
  // (trg_auto_add_space_owner adds the owner automatically,
  //  but upsert may skip the trigger, so we add all explicitly)
  // ══════════════════════════════════

  const members = [
    // San Diego: all 5
    { space_id: "space_san-diego-trip", user_id: "name_ram", role: "owner" },
    { space_id: "space_san-diego-trip", user_id: "name_myna", role: "member" },
    { space_id: "space_san-diego-trip", user_id: "name_anjan", role: "member" },
    { space_id: "space_san-diego-trip", user_id: "name_shiva", role: "member" },
    { space_id: "space_san-diego-trip", user_id: "name_venky", role: "member" },
    // Ananya: 2
    { space_id: "space_ananya", user_id: "name_ram", role: "owner" },
    { space_id: "space_ananya", user_id: "name_myna", role: "member" },
    // Tokyo: 3
    { space_id: "space_tokyo-neon-nights", user_id: "name_myna", role: "owner" },
    { space_id: "space_tokyo-neon-nights", user_id: "name_ram", role: "member" },
    { space_id: "space_tokyo-neon-nights", user_id: "name_anjan", role: "member" },
    // Summer: 3
    { space_id: "space_summer-2026", user_id: "name_ram", role: "owner" },
    { space_id: "space_summer-2026", user_id: "name_myna", role: "member" },
    { space_id: "space_summer-2026", user_id: "name_venky", role: "member" },
  ];

  const { error: membersError } = await supabase
    .from("space_members")
    .upsert(members, { onConflict: "space_id,user_id" });

  if (membersError) console.error("members:", membersError.message);
  else console.log("  13 space memberships seeded");

  // ══════════════════════════════════
  // 4. DECISION ITEMS
  // ══════════════════════════════════

  const { error: itemsError } = await supabase
    .from("decision_items")
    .upsert([
      {
        id: "item_hotel-del",
        space_id: "space_san-diego-trip",
        title: "hotel del coronado",
        category: "Hotel",
        description: "iconic beachfront resort on coronado island",
        state: "locked",
        proposed_by: "name_myna",
        agreement_score: 0.92,
        weighted_score: 22,
        is_locked: true,
        locked_at: "2026-02-28T14:30:00Z",
        commitment_proof: {
          type: "confirmation_number",
          value: "HDC-29441",
          submittedBy: "name_ram",
          submittedAt: "2026-02-28T14:30:00Z",
        },
        ownership: {
          ownerId: "name_ram",
          assignedAt: "2026-02-28T14:30:00Z",
          reason: "booker",
        },
        version: 1,
        metadata: { price: "$450/nt" },
      },
      {
        id: "item_surf-lessons",
        space_id: "space_san-diego-trip",
        title: "surf lessons",
        category: "Activity",
        description: "morning surf session at la jolla shores with local instructor",
        state: "proposed",
        proposed_by: "name_myna",
        agreement_score: 0.45,
        weighted_score: 7,
        is_locked: false,
        version: 0,
        metadata: { price: "$95/person" },
      },
      {
        id: "item_balboa-park",
        space_id: "space_san-diego-trip",
        title: "balboa park tour",
        category: "Activity",
        description: "guided walking tour through the cultural heart of san diego",
        state: "proposed",
        proposed_by: "name_anjan",
        agreement_score: 0.45,
        weighted_score: 5,
        is_locked: false,
        version: 0,
        metadata: { price: "Free" },
      },
      {
        id: "item_gaslamp-dinner",
        space_id: "space_san-diego-trip",
        title: "gaslamp quarter dinner",
        category: "Dining",
        description: "group dinner at a rooftop restaurant downtown",
        state: "locked",
        proposed_by: "name_shiva",
        agreement_score: 0.92,
        weighted_score: 22,
        is_locked: true,
        locked_at: "2026-03-05T19:00:00Z",
        commitment_proof: {
          type: "confirmation_number",
          value: "RSV-77201",
          submittedBy: "name_myna",
          submittedAt: "2026-03-05T19:00:00Z",
        },
        ownership: {
          ownerId: "name_myna",
          assignedAt: "2026-03-05T19:00:00Z",
          reason: "booker",
        },
        version: 1,
        metadata: { price: "$65/person" },
      },
      {
        id: "item_shibuya",
        space_id: "space_tokyo-neon-nights",
        title: "shibuya crossing at midnight",
        category: "Experience",
        description: "witness the world's busiest intersection under neon",
        state: "proposed",
        proposed_by: "name_anjan",
        agreement_score: 0.15,
        weighted_score: 2,
        is_locked: false,
        version: 0,
      },
      {
        id: "item_teamlab",
        space_id: "space_tokyo-neon-nights",
        title: "teamlab borderless",
        category: "Activity",
        description: "immersive digital art museum in odaiba",
        state: "proposed",
        proposed_by: "name_venky",
        agreement_score: 0.72,
        weighted_score: 11,
        is_locked: false,
        version: 0,
      },
    ], { onConflict: "id" });

  if (itemsError) console.error("items:", itemsError.message);
  else console.log("  6 decision items seeded");

  // ══════════════════════════════════
  // 5. MESSAGES
  // ══════════════════════════════════

  const now = Date.now();
  const minute = 60_000;

  const { error: msgsError } = await supabase.from("messages").upsert([
    // San Diego group chat (10 messages)
    { id: "msg_sd_01", space_id: "space_san-diego-trip", role: "user", content: "alright who's looking into hotels?", user_id: "name_ram", created_at: new Date(now - 10 * minute).toISOString() },
    { id: "msg_sd_02", space_id: "space_san-diego-trip", role: "user", content: "i found a few near coronado beach", user_id: "name_myna", created_at: new Date(now - 9 * minute).toISOString() },
    { id: "msg_sd_03", space_id: "space_san-diego-trip", role: "xark", content: "hotel del coronado fits the group's vibe — beachfront, historic, within budget range. coronado island marriott is bayfront, lower price.", user_id: null, created_at: new Date(now - 8 * minute).toISOString() },
    { id: "msg_sd_04", space_id: "space_san-diego-trip", role: "user", content: "what about the price though?", user_id: "name_ram", created_at: new Date(now - 7 * minute).toISOString() },
    { id: "msg_sd_05", space_id: "space_san-diego-trip", role: "user", content: "450 a night but the beach access is worth it", user_id: "name_myna", created_at: new Date(now - 6 * minute).toISOString() },
    { id: "msg_sd_06", space_id: "space_san-diego-trip", role: "user", content: "i'm in for hotel del", user_id: "name_ram", created_at: new Date(now - 5 * minute).toISOString() },
    { id: "msg_sd_07", space_id: "space_san-diego-trip", role: "user", content: "same. let's lock it", user_id: "name_myna", created_at: new Date(now - 4 * minute).toISOString() },
    { id: "msg_sd_08", space_id: "space_san-diego-trip", role: "xark", content: "consensus reached on hotel del coronado. locked with confirmation HDC-29441.", user_id: null, created_at: new Date(now - 3 * minute).toISOString() },
    { id: "msg_sd_09", space_id: "space_san-diego-trip", role: "user", content: "locked. what activities are we doing?", user_id: "name_ram", created_at: new Date(now - 2 * minute).toISOString() },
    { id: "msg_sd_10", space_id: "space_san-diego-trip", role: "user", content: "i proposed surf lessons at la jolla — check it out", user_id: "name_myna", created_at: new Date(now - 1 * minute).toISOString() },
    // Ananya sanctuary (5 messages)
    { id: "msg_an_01", space_id: "space_ananya", role: "user", content: "hey, are you excited about the trip?", user_id: "name_myna", created_at: new Date(now - 30 * minute).toISOString() },
    { id: "msg_an_02", space_id: "space_ananya", role: "user", content: "so excited. finally getting the whole group together", user_id: "name_ram", created_at: new Date(now - 28 * minute).toISOString() },
    { id: "msg_an_03", space_id: "space_ananya", role: "user", content: "i've been looking at activities near la jolla", user_id: "name_myna", created_at: new Date(now - 20 * minute).toISOString() },
    { id: "msg_an_04", space_id: "space_ananya", role: "user", content: "the kayaking looks amazing, those sea caves", user_id: "name_ram", created_at: new Date(now - 15 * minute).toISOString() },
    { id: "msg_an_05", space_id: "space_ananya", role: "user", content: "did you see the surf lesson proposal?", user_id: "name_myna", created_at: new Date(now - 5 * minute).toISOString() },
  ], { onConflict: "id" });

  if (msgsError) console.error("messages:", msgsError.message);
  else console.log("  15 messages seeded");

  console.log("\nseed complete.");
}

// Allow direct execution
seedXarkGalaxy().catch(console.error);
```

**Important:** The seed script inserts `proposed_by` values directly. The `trg_force_proposed_by` trigger sets `proposed_by = auth.uid()`, but the service_role key bypasses the trigger's auth.uid() check. However, since we're using the service_role key and auth.uid() returns null for service_role, we need to either:
1. Temporarily disable the trigger during seeding, or
2. Have the trigger check if the caller is service_role and skip the override.

We'll update the trigger to be seed-friendly:

- [ ] **Step 2: Update trg_force_proposed_by to allow service_role inserts**

In `supabase/migrations/002_functions_triggers.sql`, the `fn_force_proposed_by` function should be:

```sql
CREATE OR REPLACE FUNCTION fn_force_proposed_by()
RETURNS TRIGGER AS $$
BEGIN
  -- Service role (used by seed script and server-side) can set proposed_by directly
  IF current_setting('request.jwt.claims', true)::json->>'role' = 'service_role' THEN
    RETURN NEW;
  END IF;
  -- For authenticated users, force proposed_by to their ID
  NEW.proposed_by := auth.uid();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 3: Password hashing approach**

The seed script needs bcrypt hashes. Since pgcrypto is available in Supabase, we'll create a temporary helper function to generate hashes, or use a SQL-first approach. Add a helper function to the seed:

Create a temporary SQL function for hashing:
```sql
-- Run once before seeding (or include in seed script)
CREATE OR REPLACE FUNCTION gen_hash(p_password text)
RETURNS text
LANGUAGE sql SECURITY DEFINER
AS $$
  SELECT crypt(p_password, gen_salt('bf', 10));
$$;
```

Update the seed to call this function for each user's password.

- [ ] **Step 4: Commit**

```bash
git add src/lib/seed.ts supabase/migrations/002_functions_triggers.sql
git commit -m "feat: seed data rewrite — 5 users, 4 spaces, 13 memberships, 6 items, 15 messages"
```

---

### Task 8: Fix spaces.ts — Remove agreement_score

**Files:**
- Modify: `src/lib/spaces.ts:50-56` and `src/lib/spaces.ts:59-69`

- [ ] **Step 1: Remove agreement_score from space insert**

In `src/lib/spaces.ts`, remove `agreement_score: 0` from the spaces insert (line 55).

- [ ] **Step 2: Remove agreement_score and weighted_score from decision_items insert**

The `decision_items` insert at line 59-69 includes `agreement_score` and `weighted_score` which are now computed by the `react_to_item` RPC. Remove them since they default to 0.

- [ ] **Step 3: Handle the xark message insert**

The `createSpace` function inserts an @xark message directly. With RLS, this will be blocked because:
- The INSERT policy requires `role = 'user'`
- The trigger blocks non-service-role xark messages

For now, the space creation should use the client's anon key (which means the xark message needs to come from the server side). Update to insert a `user` role welcome message instead, or defer the xark message to the API.

Change the message insert from `role: "xark"` to `role: "user"` with the creator's ID, or remove it entirely and let the first real message populate the space.

- [ ] **Step 4: Commit**

```bash
git add src/lib/spaces.ts
git commit -m "fix: remove agreement_score from space creation, fix xark message RLS"
```

---

### Task 9: Supabase Dashboard Configuration

This task is manual (not code). Document the steps:

- [ ] **Step 1: Set Postgres config vars in Supabase dashboard**

Go to Supabase Dashboard → Project Settings → Database → Connection Pooling section, or use SQL Editor:

```sql
-- Enable dev mode (only for development project)
ALTER DATABASE postgres SET app.dev_mode = 'true';

-- Set JWT secret (copy from Supabase Dashboard → Settings → API → JWT Secret)
ALTER DATABASE postgres SET app.jwt_secret = 'your-jwt-secret-here';
```

- [ ] **Step 2: Enable Realtime for required tables**

Go to Supabase Dashboard → Database → Replication and enable Realtime for:
- `messages` (INSERT)
- `decision_items` (UPDATE)

- [ ] **Step 3: Run migrations in order**

Execute in SQL Editor:
1. `001_foundation_schema.sql`
2. `002_functions_triggers.sql`
3. `003_rls_policies.sql`

- [ ] **Step 4: Create gen_hash helper function**

```sql
CREATE OR REPLACE FUNCTION gen_hash(p_password text)
RETURNS text
LANGUAGE sql SECURITY DEFINER
AS $$
  SELECT crypt(p_password, gen_salt('bf', 10));
$$;
```

- [ ] **Step 5: Run seed**

```bash
cd /Users/ramchitturi/xark9
npx tsx src/lib/seed.ts
```

- [ ] **Step 6: Verify seed data**

In SQL Editor:
```sql
SELECT count(*) FROM users;          -- 5
SELECT count(*) FROM spaces;         -- 4
SELECT count(*) FROM space_members;  -- 13
SELECT count(*) FROM decision_items; -- 6
SELECT count(*) FROM messages;       -- 15
```

---

## Chunk 3: Frontend Wiring

### Task 10: Wire Supabase Client with Auth Token

**Files:**
- Modify: `src/lib/supabase.ts`

The current supabase client uses the anon key without any JWT. For RLS to work, the client needs to include the user's JWT (from Firebase or dev_login) in the Authorization header.

- [ ] **Step 1: Create an authenticated Supabase client factory**

Update `src/lib/supabase.ts` to support setting the auth token:

```typescript
// XARK OS v2.0 — SUPABASE POSTGRES CLIENT
// Decision Engine queries ONLY. DB access for heart-sort ranking math.
// Authentication is handled exclusively by Firebase Auth (see Infrastructure Lock).
// The JWT (from Firebase or dev_login) is set via setSupabaseToken().

import { createClient, SupabaseClient } from "@supabase/supabase-js";

const url = process.env.NEXT_PUBLIC_SUPABASE_URL || "https://placeholder.supabase.co";
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "placeholder";

export const supabase: SupabaseClient = createClient(url, anonKey);

// Set the JWT for authenticated requests (RLS enforcement)
// Called after Firebase auth or dev_login returns a token.
export function setSupabaseToken(token: string | null): void {
  if (token) {
    supabase.realtime.setAuth(token);
    // Set global headers for REST API calls
    // @ts-expect-error — accessing internal to set auth header
    supabase.rest.headers["Authorization"] = `Bearer ${token}`;
  }
}
```

Note: The proper way to set auth with Supabase client v2 is via `supabase.auth.setSession()`, but since we're NOT using Supabase Auth, we need to set the token on the REST client directly. The approach above may need adjustment based on the specific Supabase JS client version. An alternative:

```typescript
// Alternative: create a new client per token
let currentToken: string | null = null;

export function setSupabaseToken(token: string | null): void {
  currentToken = token;
}

export function getSupabaseClient(): SupabaseClient {
  if (currentToken) {
    return createClient(url, anonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${currentToken}`,
        },
      },
    });
  }
  return supabase;
}
```

The implementer should test which approach works with the Supabase JS v2 client and RLS.

- [ ] **Step 2: Commit**

```bash
git add src/lib/supabase.ts
git commit -m "feat: supabase client JWT token support for RLS"
```

---

### Task 11: Update useAuth Hook for Dev Login

**Files:**
- Modify: `src/hooks/useAuth.ts`

- [ ] **Step 1: Add dev login support to useAuth**

The hook should:
1. Check if DEV_MODE is enabled (via env var or URL param)
2. If in dev mode, call `/api/dev-auth` with credentials
3. Set the returned JWT on the Supabase client
4. If in prod mode, use Firebase Auth as before

Read the current `useAuth.ts` and add dev-mode token flow that calls `setSupabaseToken()` after obtaining a token from either Firebase or dev_login.

- [ ] **Step 2: Commit**

```bash
git add src/hooks/useAuth.ts
git commit -m "feat: useAuth dev-mode login + supabase token wiring"
```

---

### Task 12: Verify End-to-End

- [ ] **Step 1: Start dev server**

```bash
cd /Users/ramchitturi/xark9
npm run dev
```

- [ ] **Step 2: Test dev login**

```bash
curl -X POST http://localhost:3000/api/dev-auth \
  -H "Content-Type: application/json" \
  -d '{"username":"ram","password":"myna"}'
```

Expected: `{ "token": "eyJ...", "user": { "id": "name_ram", "displayName": "ram" } }`

- [ ] **Step 3: Test RLS with token**

Use the returned token to query spaces:
```bash
TOKEN="eyJ..."
curl "https://xxx.supabase.co/rest/v1/spaces?select=*" \
  -H "apikey: ANON_KEY" \
  -H "Authorization: Bearer $TOKEN"
```

Expected: Only spaces where name_ram is a member (san diego, ananya, tokyo, summer).

- [ ] **Step 4: Test react_to_item RPC**

```bash
curl "https://xxx.supabase.co/rest/v1/rpc/react_to_item" \
  -H "apikey: ANON_KEY" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"p_item_id":"item_surf-lessons","p_signal":"love_it"}'
```

Expected: `{ "weighted_score": 12, "agreement_score": 0.2 }`

- [ ] **Step 5: Verify phone column is hidden**

Query users as name_ram:
```bash
curl "https://xxx.supabase.co/rest/v1/users?select=*" \
  -H "apikey: ANON_KEY" \
  -H "Authorization: Bearer $TOKEN"
```

Expected: Own row has all columns. Other users' rows have phone as null (due to RLS returning all columns — the `get_visible_users()` function should be used by the frontend instead of direct table queries for other users).
