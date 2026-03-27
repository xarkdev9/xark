# XARK OS: Cloud Security & Infrastructure Audit Report

**Target Scope**: Next.js Serverless API (`src/app/api/...`), Supabase SQL Schema & RPCs (`supabase/migrations/...`)
**Perspective**: Offensive Exploitation & Tenant Isolation

---

## 1. THE EXPLOIT PATH (P0/P1)
Your architecture commits a cardinal sin of backend authorization: trusting raw user input as a database Primary Key constraint evaluated through an Admin client.

### P0 — Cross-Tenant Hijacking (The Restrict-Bypass Sinkhole)
**Location:** [src/app/api/local-action/route.ts](file:///Users/ramchitturi/xark9/src/app/api/local-action/route.ts) (Lines 173-186)
**The Vulnerability:** 
Your `/api/local-action` endpoint correctly verifies group membership for most actions. However, you added an explicit bypass for the `create_space` action (Line 30: `if (action !== "create_space")`). 
Down in the payload logic, you convert a user-supplied `title` string into a `spaceId` deterministic slug, and then you execute a `supabaseAdmin` (service_role) `upsert` with `{ onConflict: "id" }`. 
**The Exploit Chain:**
1. Attacker discovers the `slug` of a Private Space (e.g., `space_vacation`).
2. Attacker sends an authenticated `POST /api/local-action` with payload: `{ "action": "create_space", "payload": { "title": "vacation" } }`.
3. The API calculates `newSpaceId = "space_vacation"`.
4. The API executes the administrative Upsert, blindly overwriting the `owner_id` of the existing space to the Attacker's UUID. 
5. The API writes an `owner` role for the Attacker into the `space_members` table.
6. The Attacker has now successfully stolen total administrative control of the space, bypassed all Select/Update RLS protections, and merged into the tenant boundary.

### P1 — The SECURITY DEFINER Trojan (E2EE Denial of Service)
**Location:** [supabase/migrations/014_e2ee.sql](file:///Users/ramchitturi/xark9/supabase/migrations/014_e2ee.sql)
**The Vulnerability:** 
You have two crucial Postgres RPC functions — `revoke_device()` and `fetch_key_bundle()`. Both are marked `LANGUAGE plpgsql SECURITY DEFINER`. 
You wrote a comment: `-- Device revocation — SECURITY DEFINER, service-role only`. 
The database does not read comments. Functions in PostgreSQL are `EXECUTE` granted to `PUBLIC` by default. There is no `IF (current_setting('request.jwt.claims')::json->>'role') = 'service_role'` clause inside the function body.
**The Exploit Chain:**
1. Attacker connects via standard Supabase Javascript client with their normal User JWT.
2. Attacker executes `supabase.rpc('revoke_device', { p_user_id: 'VICTIM_USER_ID', p_device_id: 1 })`.
3. The function elevates to Postgres Superuser (SECURITY DEFINER) and instantly annihilates the victim's public key bundles.
4. The Victim's Double Ratchet E2EE sessions permanently fail. 
(A secondary attack abuses the same flaw on `fetch_key_bundle` via a `while(true)` loop to silently consume and delete every single One-Time Pre-Key (OTK) the victim has uploaded, degrading their X3DH forward secrecy).

---

## 2. THE MELTDOWN VECTOR (P2)
### Serverless DDoS via In-Memory Isolation
**Location:** [src/lib/rate-limit.ts](file:///Users/ramchitturi/xark9/src/lib/rate-limit.ts)
**The Vulnerability:** 
Your rate limiter instantiates a local JavaScript `Map<string, number[]>()`. 
**The Meltdown:** 
Next.js API routes deploy to Vercel/AWS Lambda as isolated, ephemeral edge functions. If an attacker floods `/api/message` or `/api/local-action` with 10,000 requests per second, the cloud provider will instantiate 1,000 parallel lambda functions to handle the load. Each lambda instance boots with an entirely empty, isolated `Map()`. The rate limiter logic allows 20 requests *per isolate*. 
The database connection pool (PgBouncer/Supavisor) will be subjected to the full unmitigated 10,000 rps brunt, exhausting the Postgres worker threads and causing a total P0 database crash (`503 Service Unavailable` for all legitimate clients). You must use a centralized Redis store (like Upstash) for sliding window limiters in Serverless environments.

---

## 3. THE SUPABASE VERDICT
You have established a robust outer wall for your RLS using the custom `auth_user_space_ids()` abstraction, successfully mitigating infinite recursion and isolating rows. 
However, your internal defenses completely collapse because you casually hand out `service_role` (via `supabaseAdmin`) inside Serverless functions to execute untrusted input, and you failed to manually assert JWT claims inside your `SECURITY DEFINER` RPCs. Your architecture is fundamentally failing the Principle of Least Privilege.

---

## 4. THE INTERROGATION
*(Technical Repercussions You Must Address)*
1. **The Upsert Threat Definition**: Why are you using `upsert()` with `onConflict: "id"` for space initialization? Should an API route generating a new entity not strictly use an `insert()` and catch the Unique Constraint Violation to prevent overwriting?
2. **PL/pgSQL Context Escapes**: Will you immediately deploy a patching migration to add explicit JWT role asserts inside the body of every `SECURITY DEFINER` function, or will you `REVOKE EXECUTE ON FUNCTION FROM PUBLIC; GRANT EXECUTE TO service_role;`?
3. **Database Concurrency**: If 5,000 legitimate users simultaneously hit `fetch_key_bundle()` leading to a heavy spike of `FOR UPDATE SKIP LOCKED` row-level locks on `one_time_pre_keys`, what is your Supavisor database connection pool limit? Have you disabled prepared statements for PgBouncer compatibility?
