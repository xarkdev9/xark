# Phase 0 — Foundation: Database Schema & Security

## Goal

Create the Supabase Postgres database schema, RLS policies, server-side functions, triggers, environment configuration, and dev-mode auth that unblocks all subsequent Xark OS development. Privacy and security are non-negotiable from day one.

## Approach

Firebase JWT verification in Supabase. Firebase handles auth (phone OTP in production, password bypass in dev). Supabase verifies the Firebase JWT, making `auth.uid()` available in every RLS policy. The client is untrusted — all sensitive mutations go through Postgres RPC functions, never direct table updates.

## Auth Model

- **Production:** Firebase phone OTP → Firebase JWT → Supabase verifies → `auth.uid()` = Firebase UID
- **Dev mode:** `dev_login(username, password)` Postgres function returns a JWT signed with Supabase's JWT secret, containing the test user ID as `sub`. RLS works identically.
- **Dev mode gate:** The `dev_login` function checks `current_setting('app.dev_mode', true) = 'true'` (Postgres custom config var set via Supabase dashboard: `ALTER DATABASE postgres SET app.dev_mode = 'true'`). The `/api/dev-auth` Next.js endpoint checks `process.env.DEV_MODE === 'true'`. Both gates must pass. Production sets neither.

### /api/dev-auth Endpoint

```
POST /api/dev-auth
Body: { "username": "ram", "password": "myna" }
Response: { "token": "eyJ...", "user": { "id": "name_ram", "displayName": "ram" } }
Error: { "error": "invalid credentials" } (401)
Gate: Returns 404 if DEV_MODE !== 'true'
```

### Test Users (dev mode only)

| username | password | user_id |
|----------|----------|---------|
| ram | myna | name_ram |
| myna | ram | name_myna |
| anjan | anjan9 | name_anjan |
| shiva | shiva9 | name_shiva |
| venky | venky9 | name_venky |

Passwords stored as bcrypt hashes in the `users.password_hash` column (nullable, unused in production).

---

## Database Schema

### users

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | text | PK | Firebase UID or `name_${username}` in dev |
| display_name | text | NOT NULL | |
| photo_url | text | nullable | |
| phone | text | nullable, unique | PII — never visible to non-self |
| password_hash | text | nullable | dev mode only, bcrypt |
| created_at | timestamptz | default now() | |

### spaces

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | text | PK | Client must provide. Format: `space_${slug}` from `getOptimisticSpaceId()`. No auto-generation. |
| title | text | NOT NULL | |
| owner_id | text | FK→users, NOT NULL | creator |
| atmosphere | text | nullable | cyan_horizon, sanctuary, amber_glow, gold_warmth |
| is_public | boolean | default false | reserved for future |
| photo_url | text | nullable | |
| last_activity_at | timestamptz | nullable | updated by trigger |
| created_at | timestamptz | default now() | |

**Note:** No `agreement_score` column on spaces. Agreement scores live on `decision_items` only.

### space_members

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| space_id | text | FK→spaces, PK | composite |
| user_id | text | FK→users, PK | composite |
| role | text | NOT NULL, default 'member' | 'owner' or 'member' |
| joined_at | timestamptz | default now() | |

### decision_items

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | text | PK | |
| space_id | text | FK→spaces, NOT NULL | |
| title | text | NOT NULL | |
| category | text | nullable | open string |
| description | text | nullable | |
| state | text | default 'proposed' | open string |
| proposed_by | text | FK→users | forced to auth.uid() on insert |
| proposed_at | timestamptz | default now() | |
| weighted_score | float | default 0 | computed by trigger from reactions |
| agreement_score | float | default 0 | computed by trigger from reactions |
| is_locked | boolean | default false | set only by lock_item() RPC |
| locked_at | timestamptz | nullable | set only by lock_item() RPC |
| commitment_proof | jsonb | nullable | set only by lock_item() RPC |
| ownership | jsonb | nullable | { ownerId, assignedAt, reason } |
| ownership_history | jsonb | default '[]' | append-only |
| version | integer | default 0 | optimistic concurrency |
| metadata | jsonb | default '{}' | { price, etc. } |
| created_at | timestamptz | default now() | |

### reactions

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| item_id | text | FK→decision_items, PK | composite |
| user_id | text | FK→users, PK | composite |
| signal | text | NOT NULL | love_it, works_for_me, not_for_me |
| weight | integer | NOT NULL | +5, +1, -3 |
| created_at | timestamptz | default now() | |

One reaction per user per item. INSERT ON CONFLICT (item_id, user_id) DO UPDATE SET signal, weight, created_at.

### messages

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | text | PK | |
| space_id | text | FK→spaces, NOT NULL | |
| role | text | NOT NULL | 'user' or 'xark' |
| content | text | NOT NULL | |
| user_id | text | nullable | null for @xark messages |
| sender_name | text | nullable | set by trigger, not client |
| created_at | timestamptz | default now() | |

### tasks

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| id | text | PK | |
| space_id | text | FK→spaces, NOT NULL | |
| title | text | NOT NULL | |
| assignee_id | text | FK→users, nullable | |
| created_at | timestamptz | default now() | |

---

## Indexes

```sql
CREATE INDEX idx_messages_space_created ON messages(space_id, created_at);
CREATE INDEX idx_decision_items_space ON decision_items(space_id);
CREATE INDEX idx_decision_items_space_locked ON decision_items(space_id, is_locked);
CREATE INDEX idx_reactions_item ON reactions(item_id);
CREATE INDEX idx_space_members_user ON space_members(user_id);
CREATE INDEX idx_tasks_space ON tasks(space_id);
```

---

## Postgres RPC Functions

### react_to_item(p_item_id text, p_signal text)

1. Verify caller is a member of the item's space (via space_members)
2. Validate signal is one of: `love_it`, `works_for_me`, `not_for_me`. Raise exception `invalid_signal` if not.
3. Map signal to weight: love_it→+5, works_for_me→+1, not_for_me→-3
4. Upsert into reactions (INSERT ON CONFLICT UPDATE)
5. Recompute weighted_score: SUM of all reaction weights for this item
6. Recompute agreement_score: COUNT(distinct reactors) / COUNT(distinct space members)
7. UPDATE decision_items SET weighted_score, agreement_score
8. Return new scores as JSON: `{ weighted_score, agreement_score }`

### lock_item(p_item_id text, p_proof_type text, p_proof_value text, p_expected_version integer)

1. Verify caller is a member of the item's space
2. Verify item is not already locked (raise exception `already_locked` if so)
3. Verify proof is not empty (raise exception `proof_required`)
4. Verify `p_expected_version` matches current item version (raise exception `version_conflict` if stale — optimistic concurrency)
5. Resolve terminal state from current state (proposed/ranked→locked, nominated→chosen, researching/shortlisted/negotiating→purchased, considering/leaning→decided)
6. Append current ownership to `ownership_history` via: `ownership_history || jsonb_build_array(ownership)`
7. UPDATE decision_items SET is_locked=true, locked_at=now(), state=terminal_state, commitment_proof=jsonb_build_object('type', p_proof_type, 'value', p_proof_value, 'submittedBy', auth.uid(), 'submittedAt', now()), ownership=jsonb_build_object('ownerId', auth.uid(), 'assignedAt', now()::text, 'reason', 'booker'), version=version+1
8. Return lock result as JSON

### transfer_ownership(p_item_id text, p_new_owner_id text)

1. Verify caller is current owner (ownership->>'ownerId' = auth.uid())
2. Verify new owner is different from caller
3. Verify item is locked
4. Verify new owner is a space member
5. Append old ownership to ownership_history
6. UPDATE ownership with new owner, reason='transfer'
7. Increment version

### invite_member(p_space_id text, p_user_id text)

1. Verify caller is space owner (spaces.owner_id = auth.uid())
2. Verify target user exists
3. INSERT into space_members with role='member'

### dev_login(p_username text, p_password text)

1. Check `current_setting('app.dev_mode', true) = 'true'`. Raise exception `dev_mode_disabled` if not.
2. Look up user by display_name = p_username. Raise exception `user_not_found` if missing.
3. Verify bcrypt hash matches via `crypt(p_password, password_hash) = password_hash`. Raise exception `invalid_credentials` if no match.
4. Build JWT payload: `{ sub: user.id, role: 'authenticated', iss: 'supabase', iat: extract(epoch from now()), exp: extract(epoch from now() + interval '24 hours') }`
5. Sign JWT using `current_setting('app.jwt_secret')` (Supabase JWT secret, set as Postgres config var)
6. Return JSON: `{ token, user_id: user.id, display_name: user.display_name }`

Requires: `pgcrypto` extension (for crypt/bcrypt) and `pgjwt` extension (for sign).

---

## Triggers

### trg_auto_add_space_owner

- **On:** AFTER INSERT to spaces
- **Action:** INSERT INTO space_members (space_id, user_id, role) VALUES (NEW.id, NEW.owner_id, 'owner'). Automatically makes the space creator a member with owner role.

### trg_update_space_activity

- **On:** AFTER INSERT to messages
- **Action:** UPDATE spaces SET last_activity_at = now() WHERE id = NEW.space_id

### trg_set_sender_name

- **On:** BEFORE INSERT to messages WHERE role = 'user'
- **Action:** Set NEW.sender_name = (SELECT display_name FROM users WHERE id = NEW.user_id)

### trg_enforce_xark_role

- **On:** BEFORE INSERT to messages
- **Action:** If NEW.role = 'xark' AND current_setting('request.jwt.claims', true)::json->>'role' != 'service_role', raise exception 'xark_impersonation_blocked'. The `request.jwt.claims` setting is populated by PostgREST from the JWT. When using the service_role key, the role claim is 'service_role'. Authenticated users have role='authenticated'. This prevents any client-side impersonation of @xark messages.

### trg_force_proposed_by

- **On:** BEFORE INSERT to decision_items
- **Action:** Set NEW.proposed_by = auth.uid(). Ignores any client-provided value. Ensures items are always attributed to the authenticated user, not spoofed.

---

## RLS Policies

All tables have RLS enabled. The anon key provides no access. Only authenticated users (with valid JWT) can query.

### users

| Operation | Policy |
|-----------|--------|
| SELECT own row | WHERE id = auth.uid() — all columns |
| SELECT others | WHERE id IN (SELECT user_id FROM space_members WHERE space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid())) — only id, display_name, photo_url columns |
| UPDATE | WHERE id = auth.uid() — only display_name, photo_url |
| INSERT | via dev_login or server-side only |

**Phone column protection:** Implemented via a `SECURITY DEFINER` function `get_visible_users()` that returns only `(id, display_name, photo_url)` for co-members. The SELECT policy for "others" calls this function. Direct SELECT on users table only returns own row (all columns). This prevents any client from reading phone numbers of other users, regardless of RLS bypass attempts.

```sql
CREATE FUNCTION get_visible_users()
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
```

### spaces

| Operation | Policy |
|-----------|--------|
| SELECT | WHERE id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()) |
| INSERT | WHERE auth.uid() IS NOT NULL (any authenticated user) |
| UPDATE | WHERE owner_id = auth.uid() — only title, photo_url, atmosphere |
| DELETE | blocked |

### trg_auto_add_space_owner (defined in Triggers section)

On INSERT to spaces: auto-insert creator into space_members with role='owner'.

### space_members

| Operation | Policy |
|-----------|--------|
| SELECT | WHERE space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()) |
| INSERT | via invite_member() RPC only (owner check inside function) |
| DELETE | WHERE (space_id IN (SELECT id FROM spaces WHERE owner_id = auth.uid())) OR (user_id = auth.uid()) — space owner can remove anyone, user can self-leave |

### decision_items

| Operation | Policy |
|-----------|--------|
| SELECT | WHERE space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()) |
| INSERT | WHERE space_id IN (...member check) — proposed_by forced to auth.uid() |
| UPDATE | blocked for clients. All mutations via RPC (react_to_item, lock_item, transfer_ownership) |
| DELETE | blocked |

### reactions

| Operation | Policy |
|-----------|--------|
| SELECT | WHERE item_id IN (SELECT id FROM decision_items WHERE space_id IN (...member check)) |
| INSERT/UPDATE | via react_to_item() RPC only |
| DELETE | via RPC only (own reactions) |

### messages

| Operation | Policy |
|-----------|--------|
| SELECT | WHERE space_id IN (SELECT space_id FROM space_members WHERE user_id = auth.uid()) |
| INSERT | WHERE space_id IN (...member check) AND user_id = auth.uid() AND role = 'user' |
| UPDATE | blocked |
| DELETE | blocked |

**@xark messages** (role='xark') are inserted server-side using the service_role key, bypassing RLS. The trg_enforce_xark_role trigger provides a secondary guard.

### tasks

| Operation | Policy |
|-----------|--------|
| SELECT | WHERE space_id IN (...member check) |
| INSERT | WHERE space_id IN (...member check) |
| UPDATE | WHERE space_id IN (...member check) — only assignee_id |
| DELETE | blocked |

---

## Realtime Authorization

Supabase Realtime respects RLS when using the anon key with JWT. Subscriptions to:
- `messages` INSERT (filtered by space_id) — only fires for spaces user is a member of
- `decision_items` UPDATE (filtered by space_id) — same
- Presence channels — use `space_id` as channel name, verified against space_members

---

## Environment Variables

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

`.env.local` is gitignored. A `.env.example` file is committed with empty values as a template.

---

## Seed Data

The existing `src/lib/seed.ts` will be rewritten to:
1. Use the service_role key (bypasses RLS for seeding)
2. Create the 5 test users with bcrypt password hashes
3. Create spaces with explicit `space_${slug}` IDs (no auto-generation)
4. Insert space_members for each space
5. Update `proposed_by` values to use only the 5 test user IDs
6. Remove `agreement_score` from space inserts (it's on items only)

### Space Membership Map

| Space | Members | Owner |
|-------|---------|-------|
| san diego trip | ram (owner), myna, anjan, shiva, venky | ram |
| ananya (sanctuary) | ram (owner), myna | ram |
| tokyo neon nights | myna (owner), ram, anjan | myna |
| summer 2026 | ram (owner), myna, venky | ram |

### proposed_by Remapping

| Item | Old value | New value |
|------|-----------|-----------|
| hotel del coronado | name_ananya | name_myna |
| surf lessons | name_ananya | name_myna |
| balboa park tour | name_maya | name_anjan |
| gaslamp quarter dinner | name_jake | name_shiva |
| shibuya crossing | name_maya | name_anjan |
| teamlab borderless | name_jake | name_venky |

### ownership Remapping

Existing `user_ram` and `user_ananya` references in ownership/commitment_proof change to `name_ram` and `name_myna` respectively (matching test user ID format).

---

## What This Unblocks

- Multi-user testing (each user sees only their spaces)
- Reactions (write path via react_to_item RPC)
- Real awareness stream (fetchAwareness with membership filter)
- Handshake protocol (lock_item RPC replaces direct UPDATE)
- @xark intelligence (server-side message insertion)
- Presence (Realtime authorized via RLS)
- Everything in the app that currently falls back to demo data
