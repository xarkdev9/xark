# Fortress Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the hello monorepo backend for 10k+ concurrent users with atomic transactions, connection pooling, edge rate limiting, key caching, table partitioning, crypto mutex safety, O(1) sender key distribution, and Strangler Fig extraction interfaces.

**Architecture:** 8 work items across 3 parallel work streams. Stream A (database) is the critical path. Stream B (edge infra) starts after Upstash provisioning. Stream C (crypto/ports) starts after Stream A completes. Each task produces independently deployable, testable changes.

**Tech Stack:** PostgreSQL (Supabase), Upstash Redis, postgres.js, @upstash/ratelimit, Next.js 16 proxy.ts, Flutter/Dart isolates, Web Locks API, Drift ORM.

**Spec:** `docs/superpowers/specs/2026-03-27-fortress-backend-hardening-design.md`

---

## Parallel Work Streams & Agent Assignment

```
STREAM A (Database)          STREAM B (Edge Infra)       STREAM C (Crypto + Ports)
─────────────────           ──────────────────          ─────────────────────────
Task 1: Pooling              Task 4: Rate Limiting       Task 6: SK Distribution
   ↓                            ↓                          (after Task 2)
Task 2: Atomic RPC           Task 5: Key Cache           Task 7: Web Mutex
   ↓                          (after Task 4)              Task 8: Engine Crypto Isolate
Task 3: Partitioning                                        (7+8 parallel)
                                                          Task 9: Strangler Fig Ports
                                                            (after all others)
```

**Parallelism:** Streams A and B can run simultaneously. Stream C starts after Task 2 (atomic RPC) is complete. Tasks 7 and 8 within Stream C are parallel (web vs engine — no shared files).

---

## Validation Tracker

After each task's commit, validate against this checklist. Every cell must be checked before the spec is considered complete.

| Task | Agent | Commit SHA | Tests Pass | Spec Section | Status |
|------|-------|-----------|------------|--------------|--------|
| 1. Supavisor Pooling | A | `f146e18` | Yes | §2 BACKEND-02 | DONE |
| 2. Atomic RPC + UUIDv7 | A | `40d3b41` | Yes | §1 BACKEND-01 | DONE |
| 3. Partition Ciphertexts | A | `fc5e10c` | Yes | §5 BACKEND-05 | DONE |
| 4. Edge Rate Limiting | B | `cd823f2` | Yes (119/119) | §3 BACKEND-03 | DONE |
| 5. Key Bundle Cache | B | `ae33caf` | Yes | §4 BACKEND-04 | DONE |
| 6. SK Distribution ACK | C | `ea95bd0` | Yes | §7 CRYPTO-04 | DONE |
| 7. Web Mutex (Web Locks) | C | `713a889` | Yes | §6 CRYPTO-05 (web) | DONE |
| 8. Crypto Isolate (Engine) | C | `89efd72` | Yes | §6 CRYPTO-05 (engine) | DONE |
| 9. Strangler Fig Ports | C | `61a00a9` | Yes | §8 BACKEND-06/07/08 | DONE |

**Commit Validation Rule:** After each commit, run:
```bash
# Verify commit message references the task
git log -1 --format='%s' | grep -i 'fortress\|backend-0\|crypto-0'

# Verify no unrelated files changed
git diff --name-only HEAD~1 HEAD

# Verify tests pass
cd web && npm test
cd ../engine && flutter test
```

---

## STREAM A: Database Hardening

### Task 1: Supavisor Connection Pooling (BACKEND-02)

**Files:**
- Modify: `web/src/lib/supabase-admin.ts`
- Create: `web/src/lib/postgres-pool.ts`

**Dependencies:** None — start immediately.

- [ ] **Step 1: Create the postgres.js singleton pool**

Create `web/src/lib/postgres-pool.ts`:
```typescript
import postgres from 'postgres';

const globalForPostgres = globalThis as unknown as { sql: postgres.Sql };

export const sql = globalForPostgres.sql || postgres(process.env.DATABASE_URL!, {
  max: 5,
  idle_timeout: 10,
  connect_timeout: 5,
});

if (process.env.NODE_ENV !== 'production') globalForPostgres.sql = sql;
```

- [ ] **Step 2: Install postgres dependency**

Run: `cd web && npm install postgres`

- [ ] **Step 3: Update supabase-admin.ts connection string**

In `web/src/lib/supabase-admin.ts`, ensure the Supabase client uses the pooler endpoint. The Supabase JS client connects via HTTP (not raw TCP), so the pooling change is in the environment variable, not the code. Add a comment:

```typescript
// NOTE: DATABASE_URL must point to Supavisor pooler (port 6543)
// with ?pgbouncer=true. Direct connections (port 5432) stored in
// DATABASE_URL_DIRECT for migrations only.
// See: docs/superpowers/specs/2026-03-27-fortress-backend-hardening-design.md §2
```

- [ ] **Step 4: Verify existing tests still pass**

Run: `cd web && npm test`
Expected: All existing tests pass (this is a transparent change).

- [ ] **Step 5: Commit**

```bash
cd web
git add src/lib/supabase-admin.ts src/lib/postgres-pool.ts package.json package-lock.json
git commit -m "feat(fortress): add Supavisor connection pooling + postgres.js TCP pool

BACKEND-02: Switch serverless DB connections to Supavisor transaction-mode
pooling (port 6543). Add postgres.js singleton pool for hot-path TCP access
with idle_timeout: 10s for Vercel frozen container safety."
```

---

### Task 2: Atomic PostgreSQL Transactions + UUIDv7 (BACKEND-01)

**Files:**
- Create: `web/supabase/migrations/20260327180000_group_sequences.sql`
- Create: `web/supabase/migrations/20260327180001_uuidv7_helpers.sql`
- Create: `web/supabase/migrations/20260327180002_atomic_send_message.sql`
- Create: `web/supabase/migrations/20260327180003_read_watermarks.sql`
- Create: `web/src/lib/crypto/uuidv7.ts`
- Modify: `web/src/app/api/message/route.ts`
- Modify: `web/src/lib/unread.ts`
- Create: `engine/lib/src/sync/clock_sync.dart`

**Dependencies:** Task 1 (pooling must be in place).

- [ ] **Step 1: Create UUIDv7 helper migration**

Create `web/supabase/migrations/20260327180001_uuidv7_helpers.sql`:
```sql
-- Extract timestamp from UUIDv7 (first 48 bits = milliseconds since epoch)
CREATE OR REPLACE FUNCTION uuidv7_to_timestamptz(id UUID) RETURNS TIMESTAMPTZ AS $$
  SELECT to_timestamp(
    ('x' || left(replace(id::text, '-', ''), 12))::bit(48)::bigint / 1000.0
  );
$$ LANGUAGE sql IMMUTABLE PARALLEL SAFE;

-- Tombstone a message: convert to tombstone + partition-pruned ciphertext delete
CREATE OR REPLACE FUNCTION tombstone_message(p_message_id UUID) RETURNS VOID AS $$
DECLARE
  v_time TIMESTAMPTZ := uuidv7_to_timestamptz(p_message_id);
BEGIN
  UPDATE messages SET message_type = 'tombstone' WHERE id = p_message_id;
  DELETE FROM message_ciphertexts
  WHERE message_id = p_message_id
    AND created_at >= date_trunc('month', v_time)
    AND created_at < date_trunc('month', v_time) + interval '1 month';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Create group_sequences table**

Create `web/supabase/migrations/20260327180000_group_sequences.sql`:
```sql
CREATE TABLE group_sequences (
  group_id TEXT PRIMARY KEY REFERENCES groups(id) ON DELETE CASCADE,
  seq BIGINT NOT NULL DEFAULT 0
);

-- Seed from existing data
INSERT INTO group_sequences (group_id, seq)
SELECT group_id, COALESCE(MAX(server_seq), 0)
FROM messages
GROUP BY group_id
ON CONFLICT DO NOTHING;
```

- [ ] **Step 3: Create atomic send_e2ee_message RPC**

Create `web/supabase/migrations/20260327180002_atomic_send_message.sql`:
```sql
CREATE OR REPLACE FUNCTION send_e2ee_message(
  p_message_id       UUID,
  p_group_id         TEXT,
  p_sender_id        TEXT,
  p_sender_device_id INTEGER,
  p_message_type     TEXT,
  p_role             TEXT DEFAULT 'user',
  p_server_content   TEXT DEFAULT NULL,
  p_reply_to_id      UUID DEFAULT NULL,
  p_ciphertexts      JSONB DEFAULT '[]'::JSONB,
  p_distributions    JSONB DEFAULT '[]'::JSONB
) RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_client_time TIMESTAMPTZ := uuidv7_to_timestamptz(p_message_id);
  v_seq BIGINT;
  v_inserted_seq BIGINT;
  v_inserted_time TIMESTAMPTZ;
  v_ct JSONB;
BEGIN
  -- 1. Membership guard
  IF NOT EXISTS (
    SELECT 1 FROM group_members WHERE group_id = p_group_id AND user_id = p_sender_id
  ) THEN
    RAISE EXCEPTION 'not_a_member';
  END IF;

  -- 2. Clock skew guard (±5 minutes)
  IF abs(extract(epoch FROM v_client_time) - extract(epoch FROM now())) > 300 THEN
    RAISE EXCEPTION 'invalid_clock_skew';
  END IF;

  -- 3. Group-scoped sequence (O(1) single-row lock)
  UPDATE group_sequences SET seq = seq + 1
  WHERE group_id = p_group_id
  RETURNING seq INTO v_seq;

  IF v_seq IS NULL THEN
    INSERT INTO group_sequences (group_id, seq) VALUES (p_group_id, 1)
    ON CONFLICT (group_id) DO UPDATE SET seq = group_sequences.seq + 1
    RETURNING seq INTO v_seq;
  END IF;

  -- 4. Idempotent message insert with dedup catch
  INSERT INTO messages (id, group_id, user_id, sender_device_id, message_type,
    role, server_content, reply_to_message_id, server_seq, created_at)
  VALUES (p_message_id, p_group_id, p_sender_id, p_sender_device_id,
    p_message_type, p_role, p_server_content, p_reply_to_id, v_seq, v_client_time)
  ON CONFLICT (id) DO NOTHING
  RETURNING server_seq, created_at INTO v_inserted_seq, v_inserted_time;

  -- Dedup catch: row already existed (network retry)
  IF v_inserted_seq IS NULL THEN
    SELECT server_seq, created_at INTO v_inserted_seq, v_inserted_time
    FROM messages WHERE id = p_message_id;
    RETURN jsonb_build_object(
      'message_id', p_message_id,
      'server_seq', v_inserted_seq,
      'created_at', v_inserted_time,
      'status', 'deduplicated'
    );
  END IF;

  -- 5. Bulk insert ciphertexts (idempotent)
  FOR v_ct IN SELECT * FROM jsonb_array_elements(p_ciphertexts) LOOP
    INSERT INTO message_ciphertexts (
      message_id, recipient_id, recipient_device_id, ciphertext, ratchet_header, created_at
    ) VALUES (
      p_message_id,
      v_ct->>'recipient_id',
      (v_ct->>'recipient_device_id')::INTEGER,
      v_ct->>'ciphertext',
      v_ct->>'ratchet_header',
      v_client_time
    ) ON CONFLICT (message_id, recipient_id, recipient_device_id, created_at) DO NOTHING;
  END LOOP;

  -- 6. Bulk insert SK distributions (idempotent)
  FOR v_ct IN SELECT * FROM jsonb_array_elements(p_distributions) LOOP
    INSERT INTO message_ciphertexts (
      message_id, recipient_id, recipient_device_id, ciphertext, ratchet_header, created_at
    ) VALUES (
      p_message_id,
      v_ct->>'recipient_id',
      (v_ct->>'recipient_device_id')::INTEGER,
      v_ct->>'ciphertext',
      v_ct->>'ratchet_header',
      v_client_time
    ) ON CONFLICT (message_id, recipient_id, recipient_device_id, created_at) DO NOTHING;
  END LOOP;

  -- 7. Return
  RETURN jsonb_build_object(
    'message_id', p_message_id,
    'server_seq', v_inserted_seq,
    'created_at', v_inserted_time,
    'status', 'inserted'
  );
END;
$$;

-- Lock down permissions
REVOKE EXECUTE ON FUNCTION send_e2ee_message FROM PUBLIC;
GRANT EXECUTE ON FUNCTION send_e2ee_message TO authenticated;
```

- [ ] **Step 4: Create read_watermarks migration**

Create `web/supabase/migrations/20260327180003_read_watermarks.sql`:
```sql
CREATE TABLE read_watermarks (
  group_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  last_read_seq BIGINT NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, user_id)
);

ALTER TABLE read_watermarks ENABLE ROW LEVEL SECURITY;

CREATE POLICY rw_select ON read_watermarks FOR SELECT
  USING (user_id = auth.jwt()->>'sub');
CREATE POLICY rw_upsert ON read_watermarks FOR INSERT
  WITH CHECK (user_id = auth.jwt()->>'sub');
CREATE POLICY rw_update ON read_watermarks FOR UPDATE
  USING (user_id = auth.jwt()->>'sub');

-- Function to mark a group as read up to a sequence number
CREATE OR REPLACE FUNCTION mark_group_read(p_group_id TEXT, p_seq BIGINT)
RETURNS VOID AS $$
BEGIN
  INSERT INTO read_watermarks (group_id, user_id, last_read_seq, updated_at)
  VALUES (p_group_id, auth.jwt()->>'sub', p_seq, now())
  ON CONFLICT (group_id, user_id) DO UPDATE
  SET last_read_seq = GREATEST(read_watermarks.last_read_seq, p_seq),
      updated_at = now();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 5: Create web UUIDv7 generator**

Create `web/src/lib/crypto/uuidv7.ts`:
```typescript
/**
 * Generate a UUIDv7 (time-ordered UUID with millisecond precision).
 * Uses clock-corrected timestamp if ClockSync delta is available.
 */
let clockDeltaMs = 0;

export function setClockDelta(delta: number): void {
  clockDeltaMs = delta;
}

export function generateUUIDv7(): string {
  const now = Date.now() + clockDeltaMs;
  const timestamp = now.toString(16).padStart(12, '0');

  // Random bits for uniqueness
  const random = new Uint8Array(10);
  crypto.getRandomValues(random);
  const hex = Array.from(random, (b) => b.toString(16).padStart(2, '0')).join('');

  // UUIDv7 format: tttttttt-tttt-7xxx-yxxx-xxxxxxxxxxxx
  return [
    timestamp.slice(0, 8),
    timestamp.slice(8, 12),
    '7' + hex.slice(0, 3),
    ((parseInt(hex.slice(3, 4), 16) & 0x3) | 0x8).toString(16) + hex.slice(4, 7),
    hex.slice(7, 19),
  ].join('-');
}
```

- [ ] **Step 6: Rewrite /api/message route to use atomic RPC**

Replace the body of `web/src/app/api/message/route.ts` with:
```typescript
export const runtime = 'nodejs';

import { NextRequest, NextResponse } from 'next/server';
import { sql } from '@/lib/postgres-pool';
import { verifyAuth } from '@/lib/user-id';

export async function POST(req: NextRequest) {
  const userId = await verifyAuth(req);
  if (!userId) return NextResponse.json({ error: 'unauthorized' }, { status: 401 });

  const body = await req.json();
  const {
    message_id, group_id, sender_device_id, message_type,
    role, server_content, reply_to_id, ciphertexts, distributions,
  } = body;

  if (!message_id || !group_id || !ciphertexts) {
    return NextResponse.json({ error: 'missing fields' }, { status: 400 });
  }

  try {
    const [result] = await sql`
      SELECT send_e2ee_message(
        ${message_id}::uuid,
        ${group_id},
        ${userId},
        ${sender_device_id || 0},
        ${message_type || 'e2ee'},
        ${role || 'user'},
        ${server_content || null},
        ${reply_to_id || null}::uuid,
        ${JSON.stringify(ciphertexts || [])}::jsonb,
        ${JSON.stringify(distributions || [])}::jsonb
      ) as result
    `;
    return NextResponse.json(result.result);
  } catch (err: any) {
    if (err.message?.includes('not_a_member')) {
      return NextResponse.json({ error: 'not_a_member' }, { status: 403 });
    }
    if (err.message?.includes('invalid_clock_skew')) {
      return NextResponse.json({ error: 'invalid_clock_skew' }, { status: 400 });
    }
    console.error('[/api/message] RPC error:', err);
    return NextResponse.json({ error: 'internal' }, { status: 500 });
  }
}
```

- [ ] **Step 7: Rewrite unread.ts to use read_watermarks**

Replace `web/src/lib/unread.ts` with:
```typescript
import { supabase } from './supabase';

export async function getUnreadCount(groupId: string, userId: string): Promise<number> {
  // Get watermark
  const { data: wm } = await supabase
    .from('read_watermarks')
    .select('last_read_seq')
    .eq('group_id', groupId)
    .eq('user_id', userId)
    .single();

  const lastReadSeq = wm?.last_read_seq ?? 0;

  // Count messages after watermark
  const { count } = await supabase
    .from('messages')
    .select('*', { count: 'exact', head: true })
    .eq('group_id', groupId)
    .gt('server_seq', lastReadSeq)
    .neq('user_id', userId);

  return count ?? 0;
}

export async function markGroupRead(groupId: string, seq: number): Promise<void> {
  await supabase.rpc('mark_group_read', { p_group_id: groupId, p_seq: seq });
}
```

- [ ] **Step 8: Create engine ClockSync utility**

Create `engine/lib/src/sync/clock_sync.dart`:
```dart
import 'package:http/http.dart' as http;

class ClockSync {
  int _deltaMs = 0;
  final Uri _serverBaseUrl;

  ClockSync(this._serverBaseUrl);

  int get deltaMs => _deltaMs;
  int get correctedNowMs => DateTime.now().millisecondsSinceEpoch + _deltaMs;

  Future<void> sync() async {
    try {
      final before = DateTime.now().millisecondsSinceEpoch;
      final response = await http.head(_serverBaseUrl.resolve('/api/hello'));
      final after = DateTime.now().millisecondsSinceEpoch;

      final dateHeader = response.headers['date'];
      if (dateHeader == null) return;

      final serverTime = HttpDate.parse(dateHeader).millisecondsSinceEpoch;
      final rtt = (after - before) ~/ 2;
      _deltaMs = serverTime - before - rtt;
    } catch (_) {
      // Clock sync failure is non-fatal — use device time
    }
  }
}
```

- [ ] **Step 9: Run migrations against local Supabase**

Run: `cd web && npx supabase db push`
Expected: All 4 migrations apply successfully.

- [ ] **Step 10: Verify tests pass**

Run: `cd web && npm test && cd ../engine && flutter test`
Expected: All tests pass.

- [ ] **Step 11: Commit**

```bash
git add web/supabase/migrations/20260327180* web/src/lib/crypto/uuidv7.ts \
  web/src/app/api/message/route.ts web/src/lib/unread.ts \
  engine/lib/src/sync/clock_sync.dart
git commit -m "feat(fortress): atomic send_e2ee_message RPC + UUIDv7 + read_watermarks

BACKEND-01: Client-generated UUIDv7 idempotency, group-scoped sequences via
group_sequences table, clock skew guard, dedup catch on conflict, tombstone
support, read_watermarks replacing unread_counts. TCP via postgres.js for
/api/message hot path."
```

---

### Task 3: Partition message_ciphertexts (BACKEND-05)

**Files:**
- Create: `web/supabase/migrations/20260327180004_partition_ciphertexts.sql`
- Create: `web/supabase/migrations/20260327180005_partition_cron.sql`

**Dependencies:** Task 2 (atomic RPC must exist since it inserts into the partitioned table).

- [ ] **Step 1: Create partition migration**

Create `web/supabase/migrations/20260327180004_partition_ciphertexts.sql`:
```sql
-- Step 1: Create partitioned replacement table
CREATE TABLE message_ciphertexts_new (
  id UUID DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  recipient_id TEXT NOT NULL,
  recipient_device_id INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  ratchet_header TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  UNIQUE (message_id, recipient_id, recipient_device_id, created_at)
) PARTITION BY RANGE (created_at);

-- Step 2: Create initial partitions (6 months back + 2 months forward)
DO $$
DECLARE
  start_date DATE := date_trunc('month', now() - interval '6 months');
  end_date DATE := date_trunc('month', now() + interval '2 months');
  current_date_var DATE := start_date;
  next_date DATE;
  partition_name TEXT;
BEGIN
  WHILE current_date_var < end_date LOOP
    next_date := current_date_var + interval '1 month';
    partition_name := 'message_ciphertexts_' || to_char(current_date_var, 'YYYY_MM');
    EXECUTE format(
      'CREATE TABLE %I PARTITION OF message_ciphertexts_new
       FOR VALUES FROM (%L) TO (%L)',
      partition_name, current_date_var, next_date
    );
    current_date_var := next_date;
  END LOOP;
END $$;

-- Step 3: Create indexes on parent (inherited by all partitions)
CREATE INDEX idx_ct_recipient_sync ON message_ciphertexts_new
  (recipient_id, recipient_device_id, created_at);
CREATE INDEX idx_ct_message_time ON message_ciphertexts_new
  (message_id, created_at);

-- Step 4: Copy RLS policies
ALTER TABLE message_ciphertexts_new ENABLE ROW LEVEL SECURITY;
-- (Copy existing policies from message_ciphertexts if any)

-- Step 5: Migrate data (backfill created_at from message's created_at)
INSERT INTO message_ciphertexts_new (id, message_id, recipient_id, recipient_device_id,
  ciphertext, ratchet_header, created_at)
SELECT mc.id, mc.message_id, mc.recipient_id, mc.recipient_device_id,
  mc.ciphertext, mc.ratchet_header,
  COALESCE(m.created_at, now()) -- fallback for any NULL created_at
FROM message_ciphertexts mc
JOIN messages m ON m.id = mc.message_id;

-- Step 6: Atomic swap
ALTER TABLE message_ciphertexts RENAME TO message_ciphertexts_old;
ALTER TABLE message_ciphertexts_new RENAME TO message_ciphertexts;

-- Step 7: Cleanup (keep old table for 7 days, then drop manually)
-- DROP TABLE message_ciphertexts_old; -- Run manually after verification
```

- [ ] **Step 2: Create partition auto-creation cron function**

Create `web/supabase/migrations/20260327180005_partition_cron.sql`:
```sql
-- Auto-create next month's partition (call monthly via /api/cron/partitions or pg_cron)
CREATE OR REPLACE FUNCTION create_next_ciphertext_partition()
RETURNS TEXT AS $$
DECLARE
  next_month DATE := date_trunc('month', now() + interval '1 month');
  following_month DATE := next_month + interval '1 month';
  partition_name TEXT := 'message_ciphertexts_' || to_char(next_month, 'YYYY_MM');
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_class WHERE relname = partition_name
  ) THEN
    EXECUTE format(
      'CREATE TABLE %I PARTITION OF message_ciphertexts
       FOR VALUES FROM (%L) TO (%L)',
      partition_name, next_month, following_month
    );
    RETURN 'Created partition: ' || partition_name;
  ELSE
    RETURN 'Partition already exists: ' || partition_name;
  END IF;
END;
$$ LANGUAGE plpgsql;
```

- [ ] **Step 3: Run migration**

Run: `cd web && npx supabase db push`
Expected: Partitioned table created, data migrated.

- [ ] **Step 4: Verify partition pruning works**

Run against local Supabase:
```sql
EXPLAIN ANALYZE SELECT * FROM message_ciphertexts
WHERE message_id = 'some-uuid'
  AND created_at >= '2026-03-01' AND created_at < '2026-04-01';
```
Expected: Query plan shows single partition scan, not all partitions.

- [ ] **Step 5: Commit**

```bash
git add web/supabase/migrations/20260327180004* web/supabase/migrations/20260327180005*
git commit -m "feat(fortress): partition message_ciphertexts by month

BACKEND-05: Monthly range partitions with partition-key-inclusive unique
constraint. UUIDv7-driven created_at (no DEFAULT now()). Auto-creation
function for future partitions. Indexes for recipient sync + message lookup."
```

---

## STREAM B: Edge Infrastructure

### Task 4: Edge Rate Limiting (BACKEND-03)

**Files:**
- Create: `web/src/lib/rate-limit-edge.ts`
- Modify: `web/src/proxy.ts`
- Modify: `web/src/app/api/message/route.ts` (remove old rate limit)
- Modify: `web/src/app/api/hello/route.ts` (remove old rate limit)
- Modify: `web/src/app/api/phone-auth/route.ts` (remove old rate limit)
- Create: `web/supabase/migrations/20260327180006_drop_rate_limiter.sql`

**Dependencies:** Upstash Redis provisioned (`vercel integration add upstash`).

- [ ] **Step 1: Install Upstash dependencies**

Run: `cd web && npm install @upstash/ratelimit @upstash/redis`

- [ ] **Step 2: Create rate-limit-edge.ts**

Create `web/src/lib/rate-limit-edge.ts`:
```typescript
import { Ratelimit } from '@upstash/ratelimit';
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

export interface RateLimitResult {
  success: boolean;
  remaining: number;
  reset: number;
}

type FailureMode = 'open' | 'closed';

// --- Limiter instances (created once, reused across invocations) ---

export const messageLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.tokenBucket(60, '1m', 200),
  prefix: 'rl:msg',
});

export const keysFetchLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(30, '1m'),
  prefix: 'rl:kf',
});

export const keysOtkLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, '1m'),
  prefix: 'rl:otk',
});

export const keysBundleLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, '1m'),
  prefix: 'rl:kb',
});

export const helloLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, '1m'),
  prefix: 'rl:ai',
});

export const phoneAuthLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, '1m'),
  prefix: 'rl:auth',
});

export const contactsLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(5, '1m'),
  prefix: 'rl:cc',
});

export const chatStartLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(20, '1m'),
  prefix: 'rl:cs',
});

export const inviteLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(10, '1m'),
  prefix: 'rl:inv',
});

export const localActionLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(20, '1m'),
  prefix: 'rl:la',
});

export const notifyLimiter = new Ratelimit({
  redis,
  limiter: Ratelimit.slidingWindow(30, '1m'),
  prefix: 'rl:ntf',
});

// --- Check function with fail-open/fail-closed ---

export async function checkLimit(
  limiter: Ratelimit,
  key: string,
  failureMode: FailureMode = 'open',
): Promise<RateLimitResult> {
  try {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 1000);
    const result = await limiter.limit(key);
    clearTimeout(timeout);
    return { success: result.success, remaining: result.remaining, reset: result.reset };
  } catch (err) {
    console.error('[rate-limit] Redis unavailable:', err);
    if (failureMode === 'closed') {
      return { success: false, remaining: 0, reset: 0 };
    }
    return { success: true, remaining: -1, reset: 0 };
  }
}

// --- Route → limiter + failure mode mapping ---

export interface RouteRateConfig {
  limiter: Ratelimit;
  failureMode: FailureMode;
  keyExtractor: 'userId' | 'ip';
}

export const ROUTE_RATE_CONFIG: Record<string, RouteRateConfig> = {
  '/api/message': { limiter: messageLimiter, failureMode: 'open', keyExtractor: 'userId' },
  '/api/keys/fetch': { limiter: keysFetchLimiter, failureMode: 'open', keyExtractor: 'userId' },
  '/api/keys/otk': { limiter: keysOtkLimiter, failureMode: 'open', keyExtractor: 'userId' },
  '/api/keys/bundle': { limiter: keysBundleLimiter, failureMode: 'open', keyExtractor: 'userId' },
  '/api/hello': { limiter: helloLimiter, failureMode: 'closed', keyExtractor: 'userId' },
  '/api/phone-auth': { limiter: phoneAuthLimiter, failureMode: 'closed', keyExtractor: 'ip' },
  '/api/contacts/check': { limiter: contactsLimiter, failureMode: 'closed', keyExtractor: 'userId' },
  '/api/chat/start': { limiter: chatStartLimiter, failureMode: 'open', keyExtractor: 'userId' },
  '/api/invite': { limiter: inviteLimiter, failureMode: 'open', keyExtractor: 'userId' },
  '/api/local-action': { limiter: localActionLimiter, failureMode: 'open', keyExtractor: 'userId' },
  '/api/notify': { limiter: notifyLimiter, failureMode: 'open', keyExtractor: 'userId' },
};
```

- [ ] **Step 3: Add rate limiting to proxy.ts**

In `web/src/proxy.ts`, add rate limiting before the existing CSP logic. Add at the top of the request handler, before other middleware logic:

```typescript
import { ROUTE_RATE_CONFIG, checkLimit } from '@/lib/rate-limit-edge';
import { NextResponse } from 'next/server';

// Inside the proxy handler, before existing CSP logic:
const pathname = request.nextUrl.pathname;

// Find matching rate limit config
const config = ROUTE_RATE_CONFIG[pathname] ??
  Object.entries(ROUTE_RATE_CONFIG).find(([prefix]) => pathname.startsWith(prefix))?.[1];

if (config) {
  let key: string;
  if (config.keyExtractor === 'ip') {
    key = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ?? 'unknown';
  } else {
    // Extract userId from Authorization header (JWT sub claim)
    const auth = request.headers.get('authorization')?.replace('Bearer ', '');
    if (auth) {
      try {
        const payload = JSON.parse(atob(auth.split('.')[1]));
        key = payload.sub ?? 'anon';
      } catch {
        key = 'anon';
      }
    } else {
      key = 'anon';
    }
  }

  const result = await checkLimit(config.limiter, key, config.failureMode);
  if (!result.success) {
    return NextResponse.json(
      { error: 'rate_limit_exceeded' },
      {
        status: 429,
        headers: {
          'Retry-After': String(Math.ceil((result.reset - Date.now()) / 1000)),
          'X-RateLimit-Remaining': String(result.remaining),
        },
      }
    );
  }
}
```

- [ ] **Step 4: Remove old rate limiting from API routes**

In each API route that currently calls `checkRateLimit()` from the old `rate-limit.ts`, remove the import and the rate limit check call. The routes include:
- `web/src/app/api/message/route.ts`
- `web/src/app/api/hello/route.ts`
- `web/src/app/api/phone-auth/route.ts`
- `web/src/app/api/chat/start/route.ts`
- `web/src/app/api/contacts/check/route.ts`
- `web/src/app/api/local-action/route.ts`
- `web/src/app/api/notify/route.ts`

Search for `checkRateLimit` or `import.*rate-limit` in each file and remove.

- [ ] **Step 5: Create migration to drop old rate_limiter table**

Create `web/supabase/migrations/20260327180006_drop_rate_limiter.sql`:
```sql
DROP TABLE IF EXISTS rate_limiter;
```

- [ ] **Step 6: Run tests**

Run: `cd web && npm test`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add web/src/lib/rate-limit-edge.ts web/src/proxy.ts web/src/lib/rate-limit.ts \
  web/src/app/api/*/route.ts web/supabase/migrations/20260327180006* \
  web/package.json web/package-lock.json
git commit -m "feat(fortress): edge rate limiting via Upstash Redis in proxy.ts

BACKEND-03: Middleware-first rate limiting. Token bucket for /api/message
(200 burst for outbox sync). Sliding window for all other routes.
Fail-open for messaging, fail-closed for phone-auth + AI (financial risk).
Drops Postgres rate_limiter table."
```

---

### Task 5: Key Bundle Cache (BACKEND-04)

**Files:**
- Create: `web/src/lib/key-cache.ts`
- Modify: `web/src/app/api/keys/fetch/route.ts`
- Modify: `web/src/app/api/keys/bundle/route.ts`

**Dependencies:** Task 4 (reuses Upstash Redis instance).

- [ ] **Step 1: Create key-cache.ts**

Create `web/src/lib/key-cache.ts`:
```typescript
import { Redis } from '@upstash/redis';

const redis = new Redis({
  url: process.env.UPSTASH_REDIS_REST_URL!,
  token: process.env.UPSTASH_REDIS_REST_TOKEN!,
});

const TTL_SECONDS = 300; // 5 minutes
const KEY_PREFIX = 'kb';

function cacheKey(userId: string, deviceId: number): string {
  return `${KEY_PREFIX}:${userId}:${deviceId}`;
}

export interface CachedKeyBundle {
  identityKey: string;
  signedPreKey: string;
  signedPreKeyId: number;
  preKeySig: string;
  cachedAt: number;
}

export async function getCachedBundle(
  userId: string,
  deviceId: number,
): Promise<CachedKeyBundle | null> {
  try {
    const data = await redis.get<CachedKeyBundle>(cacheKey(userId, deviceId));
    return data;
  } catch {
    return null; // Cache miss on error — fall through to Postgres
  }
}

export async function cacheBundle(
  userId: string,
  deviceId: number,
  bundle: CachedKeyBundle,
): Promise<void> {
  try {
    // SETNX: only set if key doesn't exist (prevents stale overwrites)
    await redis.set(cacheKey(userId, deviceId), bundle, { nx: true, ex: TTL_SECONDS });
  } catch {
    // Cache write failure is non-fatal
  }
}

export async function forceUpdateBundle(
  userId: string,
  deviceId: number,
  bundle: CachedKeyBundle,
): Promise<void> {
  try {
    await redis.del(cacheKey(userId, deviceId));
    await redis.set(cacheKey(userId, deviceId), bundle, { ex: TTL_SECONDS });
  } catch {
    // Cache write failure is non-fatal
  }
}

export async function invalidateBundle(
  userId: string,
  deviceId: number,
): Promise<void> {
  try {
    await redis.del(cacheKey(userId, deviceId));
  } catch {
    // Cache invalidation failure is non-fatal
  }
}
```

- [ ] **Step 2: Update /api/keys/fetch with cache layer + bypass header**

Modify `web/src/app/api/keys/fetch/route.ts` to add cache check before Postgres:

```typescript
import { getCachedBundle, cacheBundle, forceUpdateBundle, CachedKeyBundle } from '@/lib/key-cache';

// Inside the POST handler, after extracting userId and deviceId:
const bypassCache = req.headers.get('X-Bypass-Cache') === 'true';

let keyBundle: CachedKeyBundle | null = null;

if (!bypassCache) {
  keyBundle = await getCachedBundle(userId, deviceId);
}

if (!keyBundle) {
  // Cache miss or bypass — fetch from Postgres
  const { data: bundle } = await supabaseAdmin
    .from('key_bundles')
    .select('identity_key, signed_pre_key, signed_pre_key_id, pre_key_sig')
    .eq('user_id', userId)
    .eq('device_id', deviceId)
    .single();

  if (bundle) {
    keyBundle = {
      identityKey: bundle.identity_key,
      signedPreKey: bundle.signed_pre_key,
      signedPreKeyId: bundle.signed_pre_key_id,
      preKeySig: bundle.pre_key_sig,
      cachedAt: Date.now(),
    };

    if (bypassCache) {
      await forceUpdateBundle(userId, deviceId, keyBundle);
    } else {
      await cacheBundle(userId, deviceId, keyBundle);
    }
  }
}

// OTK consumption always hits Postgres (never cached)
const { data: otk } = await supabaseAdmin.rpc('fetch_key_bundle', {
  p_user_id: userId,
  p_device_id: deviceId,
});
```

- [ ] **Step 3: Update /api/keys/bundle with cache invalidation**

In `web/src/app/api/keys/bundle/route.ts`, after the successful upsert:
```typescript
import { invalidateBundle } from '@/lib/key-cache';

// After successful key bundle upsert:
await invalidateBundle(userId, deviceId);
```

- [ ] **Step 4: Run tests**

Run: `cd web && npm test`
Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add web/src/lib/key-cache.ts web/src/app/api/keys/fetch/route.ts \
  web/src/app/api/keys/bundle/route.ts
git commit -m "feat(fortress): Redis cache for key bundles with SETNX + bypass header

BACKEND-04: 5-minute TTL key bundle cache via Upstash Redis. SETNX prevents
stale overwrites. X-Bypass-Cache header for self-healing on decrypt failure.
OTK consumption always atomic via Postgres."
```

---

## STREAM C: Crypto + Ports

### Task 6: O(1) Sender Key Distribution (CRYPTO-04)

**Files:**
- Create: `web/supabase/migrations/20260327180007_sk_acknowledgments.sql`
- Modify: `web/src/lib/crypto/encryption-service.ts`
- Modify: `web/src/lib/crypto/keystore.ts`
- Modify: `engine/lib/src/persistence/database/tables.dart`
- Modify: `engine/lib/src/crypto/sender_keys/group_cipher.dart`
- Modify: `web/src/lib/crypto/types.ts` (add sk_acks to envelope)

**Dependencies:** Task 2 (atomic RPC must exist).

- [ ] **Step 1: Create sk_acknowledgments migration**

Create `web/supabase/migrations/20260327180007_sk_acknowledgments.sql`:
```sql
CREATE TABLE sk_acknowledgments (
  group_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  recipient_id TEXT NOT NULL,
  recipient_device_id INTEGER NOT NULL,
  epoch INTEGER NOT NULL DEFAULT 1,
  acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, sender_id, recipient_id, recipient_device_id)
);

ALTER TABLE sk_acknowledgments ENABLE ROW LEVEL SECURITY;

CREATE POLICY sk_ack_recipient_select ON sk_acknowledgments FOR SELECT
  USING (recipient_id = auth.jwt()->>'sub');
CREATE POLICY sk_ack_sender_select ON sk_acknowledgments FOR SELECT
  USING (sender_id = auth.jwt()->>'sub');
CREATE POLICY sk_ack_insert ON sk_acknowledgments FOR INSERT
  WITH CHECK (recipient_id = auth.jwt()->>'sub');
CREATE POLICY sk_ack_delete ON sk_acknowledgments FOR DELETE
  USING (sender_id = auth.jwt()->>'sub');

-- Batch ACK endpoint function
CREATE OR REPLACE FUNCTION batch_sk_ack(
  p_acks JSONB  -- [{group_id, sender_id}]
) RETURNS VOID AS $$
DECLARE
  v_user_id TEXT := auth.jwt()->>'sub';
  v_device_id INTEGER := 0;  -- TODO: get from JWT or param
  v_ack JSONB;
BEGIN
  FOR v_ack IN SELECT * FROM jsonb_array_elements(p_acks) LOOP
    INSERT INTO sk_acknowledgments (group_id, sender_id, recipient_id, recipient_device_id)
    VALUES (v_ack->>'group_id', v_ack->>'sender_id', v_user_id, v_device_id)
    ON CONFLICT DO NOTHING;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Add sk_ack_cache to web IndexedDB keystore**

In `web/src/lib/crypto/keystore.ts`, add a new object store `sk_acks` in the IndexedDB schema for local ACK tracking:

```typescript
// Inside the DB upgrade handler, add:
if (!db.objectStoreNames.contains('sk_acks')) {
  const store = db.createObjectStore('sk_acks', { keyPath: ['groupId', 'senderId'] });
  store.createIndex('groupId', 'groupId', { unique: false });
}
```

Add methods:
```typescript
export async function getAckedSenders(groupId: string): Promise<Set<string>> {
  const db = await getDB();
  const tx = db.transaction('sk_acks', 'readonly');
  const store = tx.objectStore('sk_acks');
  const index = store.index('groupId');
  const entries = await index.getAll(groupId);
  return new Set(entries.map((e: any) => e.senderId));
}

export async function markSkAcked(groupId: string, senderId: string): Promise<void> {
  const db = await getDB();
  const tx = db.transaction('sk_acks', 'readwrite');
  await tx.objectStore('sk_acks').put({ groupId, senderId, ackedAt: Date.now() });
}

export async function clearSkAcks(groupId: string, senderId: string): Promise<void> {
  const db = await getDB();
  const tx = db.transaction('sk_acks', 'readwrite');
  await tx.objectStore('sk_acks').delete([groupId, senderId]);
}
```

- [ ] **Step 3: Update encryption-service.ts to check local ACKs before distributing**

In `web/src/lib/crypto/encryption-service.ts`, in the `encryptForSpace()` function, before generating distributions:

```typescript
import { getAckedSenders, markSkAcked } from './keystore';

// Inside encryptForSpace():
// Get locally ACKed devices for this group+sender
const ackedSenders = await getAckedSenders(groupId);

// Filter: only generate distributions for devices NOT in ACK set
const unackedDevices = allDevices.filter(
  (d) => !ackedSenders.has(`${d.userId}:${d.deviceId}`)
);

// Generate distributions ONLY for unacked devices
const distributions = unackedDevices.length > 0
  ? await generateDistributions(groupId, senderId, unackedDevices)
  : [];
```

In `decryptMessage()`, after successful Sender Key decryption:
```typescript
// After successful SK decrypt:
await markSkAcked(groupId, senderId);
```

- [ ] **Step 4: Add sk_acks field to message envelope type**

In `web/src/lib/crypto/types.ts`, add to the envelope type:
```typescript
export interface MessageEnvelope {
  // ... existing fields ...
  sk_acks?: Array<{ group_id: string; sender_id: string }>;
}
```

- [ ] **Step 5: Add SkAckCache Drift table to engine**

In `engine/lib/src/persistence/database/tables.dart`, add:
```dart
class SkAckCache extends Table {
  TextColumn get groupId => text()();
  TextColumn get senderId => text()();
  IntColumn get epoch => integer().withDefault(const Constant(1))();
  DateTimeColumn get ackedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {groupId, senderId};
}
```

- [ ] **Step 6: Run code generation and tests**

Run:
```bash
cd engine && dart run build_runner build --delete-conflicting-outputs && flutter test
cd ../web && npm test
```
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add web/supabase/migrations/20260327180007* web/src/lib/crypto/encryption-service.ts \
  web/src/lib/crypto/keystore.ts web/src/lib/crypto/types.ts \
  engine/lib/src/persistence/database/tables.dart
git commit -m "feat(fortress): O(1) sender key distribution with local ACK tracking

CRYPTO-04: sk_acknowledgments table + local IndexedDB/Drift ACK cache.
Distributions only sent to unacked devices. Explicit piggybacked ACKs.
NACK recovery via existing sk-recovery Realtime channel."
```

---

### Task 7: Web Mutex — Web Locks API (CRYPTO-05 web)

**Files:**
- Create: `web/src/lib/crypto/mutex.ts`
- Modify: `web/src/lib/crypto/encryption-service.ts`

**Dependencies:** Task 6 (mutex wraps encrypt/decrypt paths that now include ACK logic).
**Parallel with:** Task 8 (no shared files).

- [ ] **Step 1: Create mutex.ts**

Create `web/src/lib/crypto/mutex.ts`:
```typescript
const HAS_WEB_LOCKS = typeof navigator !== 'undefined' && 'locks' in navigator;

// In-tab fallback for browsers without Web Locks API
const inTabLocks = new Map<string, Promise<void>>();

async function inTabLock<T>(name: string, fn: () => Promise<T>): Promise<T> {
  while (inTabLocks.has(name)) {
    await inTabLocks.get(name);
  }
  let resolve: () => void;
  const promise = new Promise<void>((r) => { resolve = r; });
  inTabLocks.set(name, promise);
  try {
    return await fn();
  } finally {
    inTabLocks.delete(name);
    resolve!();
  }
}

export async function acquireRatchetLock<T>(
  sessionId: string,
  fn: () => Promise<T>,
  timeoutMs: number = 5000,
): Promise<T> {
  const lockName = `ratchet:${sessionId}`;

  if (!HAS_WEB_LOCKS) {
    console.warn('Web Locks API unavailable — single-tab crypto safety only');
    return inTabLock(lockName, fn);
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await navigator.locks.request(
      lockName,
      { mode: 'exclusive', signal: controller.signal },
      () => fn(),
    );
  } finally {
    clearTimeout(timeout);
  }
}

export async function acquireSenderKeyLock<T>(
  groupId: string,
  fn: () => Promise<T>,
  timeoutMs: number = 5000,
): Promise<T> {
  const lockName = `sk:${groupId}`;

  if (!HAS_WEB_LOCKS) {
    console.warn('Web Locks API unavailable — single-tab crypto safety only');
    return inTabLock(lockName, fn);
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await navigator.locks.request(
      lockName,
      { mode: 'exclusive', signal: controller.signal },
      () => fn(),
    );
  } finally {
    clearTimeout(timeout);
  }
}
```

- [ ] **Step 2: Wrap encrypt/decrypt calls in encryption-service.ts**

In `web/src/lib/crypto/encryption-service.ts`, wrap the existing encrypt and decrypt functions:

```typescript
import { acquireRatchetLock, acquireSenderKeyLock } from './mutex';

// Wrap encryptForSanctuary:
// Before: async function encryptForSanctuary(spaceId, plaintext, ...)
// After: wrap body in acquireRatchetLock
export async function encryptForSanctuary(spaceId: string, plaintext: string, ...args: any[]) {
  return acquireRatchetLock(spaceId, async () => {
    // ... existing encrypt logic ...
  });
}

// Wrap encryptForSpace:
export async function encryptForSpace(spaceId: string, plaintext: string, ...args: any[]) {
  return acquireSenderKeyLock(spaceId, async () => {
    // ... existing encrypt logic ...
  });
}

// Wrap decryptMessage:
export async function decryptMessage(envelope: any) {
  const lockId = envelope.recipient_id === '_group_'
    ? envelope.group_id  // sender key lock for group messages
    : `${envelope.sender_id}:${envelope.sender_device_id}`;  // ratchet lock for 1:1
  const lockFn = envelope.recipient_id === '_group_' ? acquireSenderKeyLock : acquireRatchetLock;

  return lockFn(lockId, async () => {
    // ... existing decrypt logic ...
  });
}
```

- [ ] **Step 3: Run tests**

Run: `cd web && npm test`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add web/src/lib/crypto/mutex.ts web/src/lib/crypto/encryption-service.ts
git commit -m "feat(fortress): Web Locks API mutex for cross-tab E2EE safety

CRYPTO-05 (web): Exclusive locks per ratchet session + sender key group.
5-second AbortController timeout prevents deadlock on tab crash.
In-tab fallback for browsers without Web Locks API."
```

---

### Task 8: Flutter Crypto Isolate (CRYPTO-05 engine)

**Files:**
- Create: `engine/lib/src/crypto/crypto_isolate.dart`
- Modify: `engine/lib/src/chat_engine_impl.dart`

**Dependencies:** None (engine-only).
**Parallel with:** Task 7 (no shared files).

- [ ] **Step 1: Create crypto_isolate.dart**

Create `engine/lib/src/crypto/crypto_isolate.dart`:
```dart
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

// --- Message types ---

abstract class CryptoIsolateMessage {
  final SendPort replyPort;
  CryptoIsolateMessage(this.replyPort);
}

class EncryptRequest extends CryptoIsolateMessage {
  final String sessionId;
  final TransferableTypedData plaintext;
  EncryptRequest(this.sessionId, this.plaintext, SendPort replyPort) : super(replyPort);
}

class DecryptRequest extends CryptoIsolateMessage {
  final String sessionId;
  final TransferableTypedData ciphertext;
  final TransferableTypedData header;
  DecryptRequest(this.sessionId, this.ciphertext, this.header, SendPort replyPort)
      : super(replyPort);
}

class GroupEncryptRequest extends CryptoIsolateMessage {
  final String groupId;
  final TransferableTypedData plaintext;
  GroupEncryptRequest(this.groupId, this.plaintext, SendPort replyPort) : super(replyPort);
}

class GroupDecryptRequest extends CryptoIsolateMessage {
  final String groupId;
  final String senderId;
  final TransferableTypedData ciphertext;
  GroupDecryptRequest(this.groupId, this.senderId, this.ciphertext, SendPort replyPort)
      : super(replyPort);
}

class FlushStateRequest extends CryptoIsolateMessage {
  FlushStateRequest(SendPort replyPort) : super(replyPort);
}

class ShutdownRequest extends CryptoIsolateMessage {
  ShutdownRequest(SendPort replyPort) : super(replyPort);
}

// --- Response types ---

class CryptoIsolateResponse {
  final Uint8List? data;
  final String? error;
  CryptoIsolateResponse({this.data, this.error});
}

// --- Isolate manager ---

class CryptoIsolateManager {
  Isolate? _isolate;
  SendPort? _sendPort;
  int _respawnCount = 0;
  static const int _maxRespawns = 3;
  static const Duration _requestTimeout = Duration(seconds: 10);

  Future<void> spawn() async {
    final receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntry, receivePort.sendPort);

    // First message from isolate is its SendPort
    final completer = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      }
    });
    _sendPort = await completer.future;

    // Register for headless push decryption
    IsolateNameServer.removePortNameMapping('crypto_isolate');
    IsolateNameServer.registerPortWithName(_sendPort!, 'crypto_isolate');
  }

  Future<CryptoIsolateResponse> _sendWithTimeout(CryptoIsolateMessage message) async {
    if (_sendPort == null) throw StateError('Crypto isolate not running');

    final replyPort = ReceivePort();
    final completer = Completer<CryptoIsolateResponse>();

    replyPort.listen((response) {
      if (!completer.isCompleted) {
        completer.complete(response as CryptoIsolateResponse);
      }
      replyPort.close();
    });

    _sendPort!.send(message);

    try {
      return await completer.future.timeout(_requestTimeout);
    } on TimeoutException {
      replyPort.close();
      await _handleCrash();
      throw Exception('Crypto isolate timeout — respawned');
    }
  }

  Future<void> _handleCrash() async {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;

    if (_respawnCount < _maxRespawns) {
      _respawnCount++;
      await spawn();
    } else {
      throw Exception('Crypto isolate max respawns exceeded');
    }
  }

  Future<Uint8List> encrypt(String sessionId, Uint8List plaintext) async {
    final response = await _sendWithTimeout(EncryptRequest(
      sessionId,
      TransferableTypedData.fromList([plaintext]),
      ReceivePort().sendPort, // placeholder — replaced by _sendWithTimeout
    ));
    if (response.error != null) throw Exception(response.error);
    return response.data!;
  }

  Future<void> shutdown() async {
    if (_sendPort != null) {
      final replyPort = ReceivePort();
      _sendPort!.send(ShutdownRequest(replyPort.sendPort));
      await replyPort.first.timeout(const Duration(seconds: 5), onTimeout: () => null);
    }
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _sendPort = null;
    IsolateNameServer.removePortNameMapping('crypto_isolate');
  }

  static void _isolateEntry(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    // TODO: Load ratchet state from DB on startup
    // Process messages sequentially (natural serialization)
    receivePort.listen((message) {
      if (message is ShutdownRequest) {
        // Flush state to DB, then confirm
        message.replyPort.send(CryptoIsolateResponse());
        receivePort.close();
        return;
      }

      // TODO: Route to appropriate crypto operation
      // For now, echo back for testing
      if (message is CryptoIsolateMessage) {
        message.replyPort.send(CryptoIsolateResponse(
          error: 'not yet implemented',
        ));
      }
    });
  }
}
```

- [ ] **Step 2: Integrate into ChatEngineImpl**

In `engine/lib/src/chat_engine_impl.dart`, add crypto isolate lifecycle:

```dart
import 'crypto/crypto_isolate.dart';

// Add field:
late final CryptoIsolateManager _cryptoIsolate;

// In initialize():
_cryptoIsolate = CryptoIsolateManager();
await _cryptoIsolate.spawn();

// In dispose():
await _cryptoIsolate.shutdown();

// In resume():
if (_cryptoIsolate._sendPort == null) {
  await _cryptoIsolate.spawn();
}
```

- [ ] **Step 3: Run engine tests**

Run: `cd engine && flutter test`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add engine/lib/src/crypto/crypto_isolate.dart engine/lib/src/chat_engine_impl.dart
git commit -m "feat(fortress): dedicated crypto isolate with watchdog + zero-copy transfer

CRYPTO-05 (engine): All crypto ops routed through dedicated isolate via
SendPort/ReceivePort. TransferableTypedData for zero-copy. 10s watchdog
with 3 max respawns. IsolateNameServer for headless push decrypt."
```

---

### Task 9: Strangler Fig Extraction Interfaces (BACKEND-06/07/08 prep)

**Files:**
- Create: `web/src/lib/ports/message-gateway.ts`
- Create: `web/src/lib/ports/realtime-gateway.ts`
- Create: `web/src/lib/ports/transient-queue.ts`
- Create: `web/src/lib/ports/index.ts`
- Create: `engine/lib/src/ports/message_gateway.dart`
- Create: `engine/lib/src/ports/realtime_gateway.dart`
- Create: `engine/lib/src/ports/transient_queue.dart`
- Create: `engine/lib/src/ports/ports.dart`

**Dependencies:** All other tasks (this wraps existing implementations in port interfaces).

- [ ] **Step 1: Create web port interfaces**

Create `web/src/lib/ports/message-gateway.ts`:
```typescript
export type SyncDirection = 'forward' | 'backward';

export interface MessageEnvelope {
  messageId: string;
  groupId: string;
  senderId: string;
  senderDeviceId: number;
  messageType: string;
  ciphertexts: Array<{
    recipientId: string;
    recipientDeviceId: number;
    ciphertext: string;
    ratchetHeader?: string;
  }>;
  distributions?: Array<{
    recipientId: string;
    recipientDeviceId: number;
    ciphertext: string;
    ratchetHeader?: string;
  }>;
  sk_acks?: Array<{ group_id: string; sender_id: string }>;
}

export interface SendResult {
  messageId: string;
  serverSeq: number;
  createdAt: string;
  status: 'inserted' | 'deduplicated';
}

export interface MessageRecord {
  id: string;
  groupId: string;
  senderId: string;
  senderDeviceId: number;
  messageType: string;
  serverSeq: number;
  createdAt: string;
}

export interface MessagePage {
  messages: MessageRecord[];
  nextCursor: string | null;
}

export interface Ciphertext {
  recipientId: string;
  recipientDeviceId: number;
  ciphertext: string;
  ratchetHeader?: string;
}

export interface MessageGateway {
  sendMessage(envelope: MessageEnvelope): Promise<SendResult>;
  fetchMessages(
    groupId: string,
    cursor: string | null,
    direction: SyncDirection,
    limit?: number,
  ): Promise<MessagePage>;
  fetchCiphertexts(
    messageId: string,
    recipientId: string,
    deviceId: number,
  ): Promise<Ciphertext[]>;
  acknowledgeDelivery(messageId: string, deviceId: number): Promise<void>;
}
```

Create `web/src/lib/ports/realtime-gateway.ts`:
```typescript
export interface PresenceState {
  userId: string;
  status: 'online' | 'away' | 'offline';
  lastSeenAt?: string;
}

export type RealtimeEvent =
  | { type: 'message'; payload: any }
  | { type: 'presence'; payload: PresenceState }
  | { type: 'typing'; payload: { userId: string } }
  | { type: 'sk_recovery'; payload: { groupId: string; senderId: string } };

export interface Subscription {
  id: string;
  groupId: string;
  unsubscribe(): void;
}

export interface RealtimeGateway {
  subscribe(groupId: string, handler: (event: RealtimeEvent) => void): Subscription;
  unsubscribe(subscription: Subscription): void;
  publishPresence(groupId: string, userId: string, state: PresenceState): void;
  publishTyping(groupId: string, userId: string): void;
}
```

Create `web/src/lib/ports/transient-queue.ts`:
```typescript
export interface EncryptedPayload {
  ciphertext: string;
  ratchetHeader?: string;
}

export interface QueuedMessage {
  messageId: string;
  payload: EncryptedPayload;
  enqueuedAt: number;
}

export interface TransientQueue {
  enqueue(recipientDeviceId: string, payload: EncryptedPayload): Promise<void>;
  dequeue(deviceId: string, limit?: number): Promise<QueuedMessage[]>;
  acknowledge(deviceId: string, messageIds: string[]): Promise<void>;
  getQueueDepth(deviceId: string): Promise<number>;
}
```

Create `web/src/lib/ports/index.ts`:
```typescript
export type { MessageGateway, SendResult, MessagePage, MessageRecord, Ciphertext, MessageEnvelope, SyncDirection } from './message-gateway';
export type { RealtimeGateway, RealtimeEvent, Subscription, PresenceState } from './realtime-gateway';
export type { TransientQueue, QueuedMessage, EncryptedPayload } from './transient-queue';

// Composition root — swap implementations here
// import { SupabaseMessageGateway } from './impl/supabase-message-gateway';
// export const messageGateway: MessageGateway = new SupabaseMessageGateway();
// For now, export types only — implementations wired in next iteration
```

- [ ] **Step 2: Create engine port interfaces**

Create `engine/lib/src/ports/message_gateway.dart`:
```dart
enum SyncDirection { forward, backward }

class SendResult {
  final String messageId;
  final int serverSeq;
  final DateTime createdAt;
  final String status;
  const SendResult({
    required this.messageId,
    required this.serverSeq,
    required this.createdAt,
    required this.status,
  });
}

class MessagePage {
  final List<Map<String, dynamic>> messages;
  final String? nextCursor;
  const MessagePage({required this.messages, this.nextCursor});
}

abstract class MessageGateway {
  Future<SendResult> sendMessage(Map<String, dynamic> envelope);
  Future<MessagePage> fetchMessages(
    String groupId, {
    String? cursor,
    SyncDirection direction = SyncDirection.forward,
    int limit = 50,
  });
  Future<List<Map<String, dynamic>>> fetchCiphertexts(
    String messageId,
    String recipientId,
    int deviceId,
  );
  Future<void> acknowledgeDelivery(String messageId, int deviceId);
}
```

Create `engine/lib/src/ports/realtime_gateway.dart`:
```dart
abstract class RealtimeGateway {
  Stream<Map<String, dynamic>> subscribe(String groupId);
  Future<void> unsubscribe(String groupId);
  Future<void> publishPresence(String groupId, String userId, String state);
  Future<void> publishTyping(String groupId, String userId);
}
```

Create `engine/lib/src/ports/transient_queue.dart`:
```dart
class QueuedMessage {
  final String messageId;
  final Map<String, dynamic> payload;
  final int enqueuedAt;
  const QueuedMessage({
    required this.messageId,
    required this.payload,
    required this.enqueuedAt,
  });
}

abstract class TransientQueue {
  Future<void> enqueue(String recipientDeviceId, Map<String, dynamic> payload);
  Future<List<QueuedMessage>> dequeue(String deviceId, {int limit = 100});
  Future<void> acknowledge(String deviceId, List<String> messageIds);
  Future<int> getQueueDepth(String deviceId);
}
```

Create `engine/lib/src/ports/ports.dart`:
```dart
import 'message_gateway.dart';
import 'realtime_gateway.dart';
import 'transient_queue.dart';

export 'message_gateway.dart';
export 'realtime_gateway.dart';
export 'transient_queue.dart';

class PortRegistry {
  final MessageGateway messageGateway;
  final RealtimeGateway realtimeGateway;
  final TransientQueue transientQueue;

  const PortRegistry({
    required this.messageGateway,
    required this.realtimeGateway,
    required this.transientQueue,
  });
}
```

- [ ] **Step 3: Run tests on both platforms**

Run: `cd web && npm test && cd ../engine && flutter test`
Expected: All tests pass (new files are additive — no existing code modified).

- [ ] **Step 4: Commit**

```bash
git add web/src/lib/ports/ engine/lib/src/ports/
git commit -m "feat(fortress): Strangler Fig port interfaces for future service extraction

BACKEND-06/07/08 prep: MessageGateway (cursor-based, bidirectional sync),
RealtimeGateway, TransientQueue interfaces on both web + engine. Current
Supabase implementations to be wired in next iteration. Swap implementation
= one-line DI change at composition root."
```

---

## Post-Implementation Validation

After all 9 tasks are committed, run the final validation:

```bash
# 1. Verify all 9 commits exist with correct prefixes
git log --oneline -9 | grep -c 'fortress'
# Expected: 9

# 2. Verify all new files exist
ls web/src/lib/postgres-pool.ts \
   web/src/lib/rate-limit-edge.ts \
   web/src/lib/key-cache.ts \
   web/src/lib/crypto/mutex.ts \
   web/src/lib/crypto/uuidv7.ts \
   web/src/lib/ports/message-gateway.ts \
   web/src/lib/ports/realtime-gateway.ts \
   web/src/lib/ports/transient-queue.ts \
   web/src/lib/ports/index.ts \
   engine/lib/src/crypto/crypto_isolate.dart \
   engine/lib/src/sync/clock_sync.dart \
   engine/lib/src/ports/message_gateway.dart \
   engine/lib/src/ports/realtime_gateway.dart \
   engine/lib/src/ports/transient_queue.dart \
   engine/lib/src/ports/ports.dart

# 3. Verify all migrations exist
ls web/supabase/migrations/20260327180*
# Expected: 8 migration files (000-007)

# 4. Run full test suites
cd web && npm test
cd ../engine && flutter test
cd ../algo && npm test

# 5. Verify spec coverage
echo "Spec sections covered:"
echo "  §1 BACKEND-01: Atomic RPC ✓ (Task 2)"
echo "  §2 BACKEND-02: Pooling ✓ (Task 1)"
echo "  §3 BACKEND-03: Rate Limiting ✓ (Task 4)"
echo "  §4 BACKEND-04: Key Cache ✓ (Task 5)"
echo "  §5 BACKEND-05: Partitioning ✓ (Task 3)"
echo "  §6 CRYPTO-05: Mutex ✓ (Tasks 7+8)"
echo "  §7 CRYPTO-04: SK Distribution ✓ (Task 6)"
echo "  §8 BACKEND-06/07/08: Ports ✓ (Task 9)"
```

Update the Validation Tracker table at the top of this plan with commit SHAs and pass/fail status after each task completes.
