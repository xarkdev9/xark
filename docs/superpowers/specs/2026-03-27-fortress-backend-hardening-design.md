# Spec 1: "Fortress" — Backend Hardening + Core Security

**Date:** 2026-03-27
**Scope:** Backend database hardening, edge infrastructure, crypto correctness, Strangler Fig extraction seams
**Platform:** Web (Next.js) + Engine (Flutter/Dart) — both platforms updated in parallel
**Target:** Production-ready for 10k+ concurrent users before first user

---

## Context

This is the first of three specs in the planet-scale hardening initiative:

1. **Fortress** (this spec) — Backend + database + core security
2. **Vault** (next) — Full crypto hardening (hardware keys, push decrypt, multi-device, post-quantum)
3. **Engine** (last) — Offline-first mobile architecture (Drift, sync, outbox, background workers)

Fortress is the foundation. Both Vault and Engine depend on the hardened backend and extraction interfaces defined here.

## Decisions Already Made

- Server-authoritative with offline queue (no CRDTs)
- Harden current stack (Supabase + Firebase + Next.js) — no infrastructure replacement
- Architect Strangler Fig extraction points for future Go/Rust/Erlang services
- Infrastructure lock: Firebase (auth, storage, FCM) + Supabase (Postgres, Realtime) + Gemini 2.5 Flash

---

## 1. Atomic PostgreSQL E2EE Transactions (BACKEND-01)

### Problem

`/api/message/route.ts` performs 4 sequential database operations: membership check, message insert, ciphertexts insert, SK distribution insert. A Vercel cold-start crash between steps 2 and 3 creates a "ghost message" — a message record with no ciphertext, permanently undecryptable.

### Solution

New Supabase RPC function `send_e2ee_message` that wraps the entire pipeline in a single `BEGIN/COMMIT` transaction.

### RPC Signature

```sql
CREATE OR REPLACE FUNCTION send_e2ee_message(
  p_group_id       TEXT,
  p_sender_id      TEXT,
  p_sender_device_id INTEGER,
  p_message_type   TEXT,        -- 'e2ee' | 'sender_key_dist' | 'media' | 'hello'
  p_role           TEXT DEFAULT 'user',
  p_server_content TEXT DEFAULT NULL, -- only for system/hello messages
  p_reply_to_id    UUID DEFAULT NULL,
  p_ciphertexts    JSONB,       -- [{recipient_id, recipient_device_id, ciphertext, ratchet_header}]
  p_distributions  JSONB DEFAULT '[]'::JSONB  -- [{recipient_id, recipient_device_id, ciphertext, ratchet_header}]
) RETURNS JSONB  -- {message_id, server_seq, created_at}
LANGUAGE plpgsql SECURITY DEFINER AS $$
```

### Transaction Steps (inside the RPC)

1. **Membership guard:** `SELECT 1 FROM group_members WHERE group_id = p_group_id AND user_id = p_sender_id`. If not found, raise `EXCEPTION 'not_a_member'`.
2. **Message insert:** `INSERT INTO messages (id, group_id, user_id, sender_device_id, message_type, role, server_content, reply_to_message_id)` with UUID v7 generated server-side via `gen_random_uuid()`. Returns `id` and `server_seq` (auto-increment).
3. **Ciphertexts insert:** `INSERT INTO message_ciphertexts` — bulk insert from `p_ciphertexts` JSONB array. Each row references the message ID from step 2.
4. **SK distributions insert:** If `p_distributions` is non-empty, bulk insert into `message_ciphertexts` with `message_type = 'sender_key_dist'`.
5. **Unread count bump:** `UPDATE unread_counts SET unread_count = unread_count + 1 WHERE group_id = p_group_id AND user_id != p_sender_id`. Insert rows for members without existing unread_counts entries.
6. **Return:** `{message_id, server_seq, created_at}` as JSONB.

### Callers

- `web/src/app/api/message/route.ts` — Simplified to: parse body, validate auth, call `supabase.rpc('send_e2ee_message', ...)`, return result.
- `engine/lib/src/transport/supabase_client.dart` — `sendMessage()` updated to call the RPC instead of multiple REST calls.

### Error Handling

- `not_a_member` → HTTP 403
- `unique_violation` on ciphertexts → HTTP 409 (duplicate message, safe to ignore)
- Any other exception → automatic rollback, HTTP 500

### Migration

New Supabase migration file. The RPC is `SECURITY DEFINER` to bypass RLS (it performs its own membership check). `REVOKE EXECUTE ON FUNCTION send_e2ee_message FROM PUBLIC; GRANT EXECUTE ON FUNCTION send_e2ee_message TO authenticated;`

---

## 2. Supavisor Connection Pooling (BACKEND-02)

### Problem

Every Vercel serverless function invocation opens a new direct Postgres connection. At 10k concurrent users, connection exhaustion (`FATAL: too many connections`) is guaranteed.

### Solution

Switch all server-side database connections from direct Postgres (port 5432) to Supavisor transaction-mode pooling (port 6543).

### Changes

- **`web/src/lib/supabase-admin.ts`**: Connection string updated to use pooler endpoint (port 6543) with `?pgbouncer=true` to disable prepared statements.
- **Environment variables on Vercel:**
  - `DATABASE_URL` → pooler endpoint (port 6543) — used by all serverless functions
  - `DATABASE_URL_DIRECT` → direct endpoint (port 5432) — used only for migrations
- **No code changes** to queries, RPCs, or PostgREST calls — Supavisor is transparent.

### Constraints

Supavisor transaction-mode pooling does NOT support:
- `SET` session-level commands (not used in our routes)
- `LISTEN/NOTIFY` on the same connection (Realtime uses separate WebSocket)
- Named prepared statements (disabled via `?pgbouncer=true`)

### Verification

- Run all existing API route tests against the pooler endpoint
- Load test: 100 concurrent `/api/message` calls — verify no connection errors

---

## 3. Edge Rate Limiting (BACKEND-03)

### Problem

Current Postgres-based rate limiter is a database bottleneck under DDoS. In-memory fallback doesn't share state across serverless instances.

### Solution

Replace with `@upstash/ratelimit` backed by Upstash Redis. Sliding window algorithm. Globally consistent counters.

### New Dependencies

```json
{
  "@upstash/ratelimit": "^2.x",
  "@upstash/redis": "^1.x"
}
```

### Rate Limit Configuration

| Route | Key | Window | Max | Rationale |
|-------|-----|--------|-----|-----------|
| `/api/message` | `msg:{userId}` | 1 min | 60 | Atomic RPC is cheaper; allow burst messaging |
| `/api/keys/fetch` | `kf:{userId}` | 1 min | 30 | Prevent key bundle enumeration |
| `/api/keys/otk` | `otk:{userId}` | 1 min | 10 | OTK upload is rare |
| `/api/keys/bundle` | `kb:{userId}` | 1 min | 5 | Bundle upload is once per rotation |
| `/api/hello` | `ai:{userId}` | 1 min | 10 | AI is expensive |
| `/api/phone-auth` | `auth:{ip}` | 1 min | 5 | Brute-force protection (by IP) |
| `/api/contacts/check` | `cc:{userId}` | 1 min | 5 | Enumeration protection |
| `/api/chat/start` | `cs:{userId}` | 1 min | 20 | DM creation |
| `/api/invite/*` | `inv:{userId}` | 1 min | 10 | Invite abuse |
| `/api/local-action` | `la:{userId}` | 1 min | 20 | Tier 1 mutations |
| `/api/notify` | `ntf:{userId}` | 1 min | 30 | Push notifications |

### New File: `web/src/lib/rate-limit-edge.ts`

```typescript
interface RateLimitResult {
  success: boolean;
  remaining: number;
  reset: number; // epoch ms
}

function createLimiter(config: { prefix: string; window: string; max: number }): Limiter;
function checkLimit(limiter: Limiter, key: string): Promise<RateLimitResult>;
```

### Migration

1. Deploy new rate limiter alongside old one (dual-write period)
2. Switch all routes to new limiter
3. Drop `rate_limiter` Postgres table via migration

### Environment Variables

- `UPSTASH_REDIS_REST_URL` — provisioned via Vercel Marketplace (`vercel integration add upstash`)
- `UPSTASH_REDIS_REST_TOKEN` — auto-provisioned

---

## 4. Edge-Cache Public Key Bundles (BACKEND-04)

### Problem

Key bundle reads vastly outnumber writes. Every new chat initiation fetches the peer's key bundle from Postgres. Immutable data hitting the database on every read.

### Solution

Cache key bundles in Upstash Redis (same instance as rate limiter). OTK consumption remains atomic Postgres RPC.

### Split Fetch Operation

**Step 1 — Key bundle (cached):**
1. Check Redis: `GET kb:{userId}:{deviceId}`
2. Cache hit → parse and return
3. Cache miss → fetch from `key_bundles` table → store in Redis with 1-hour TTL → return

**Step 2 — OTK consumption (never cached):**
1. Call existing `fetch_key_bundle` RPC (atomically consumes one OTK via `FOR UPDATE SKIP LOCKED`)
2. Return the consumed OTK alongside the cached key bundle

### Cache Invalidation

When `/api/keys/bundle` receives a new key bundle upload:
1. Insert/upsert into `key_bundles` table
2. `DEL kb:{userId}:{deviceId}` from Redis

### New File: `web/src/lib/key-cache.ts`

```typescript
interface KeyBundleCache {
  getCachedBundle(userId: string, deviceId: number): Promise<KeyBundle | null>;
  cacheBundle(userId: string, deviceId: number, bundle: KeyBundle): Promise<void>;
  invalidateBundle(userId: string, deviceId: number): Promise<void>;
}
```

### Cache Entry Format

```json
{
  "identityKey": "base64...",
  "signedPreKey": "base64...",
  "signedPreKeyId": 1,
  "preKeySig": "base64...",
  "cachedAt": 1711555200000
}
```

---

## 5. Partition `message_ciphertexts` (BACKEND-05)

### Problem

E2EE fan-out: 1 message in a 10-person group = 20 ciphertext rows. At 10k users, ~10M rows/month. Index scans degrade, VACUUM stalls.

### Solution

PostgreSQL native range partitioning on `created_at` by month.

### Schema Change

```sql
-- Add created_at column (currently missing)
ALTER TABLE message_ciphertexts
  ADD COLUMN created_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Convert to partitioned table
-- (migration script handles: create new partitioned table, migrate data, swap names)
CREATE TABLE message_ciphertexts_partitioned (
  id UUID DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  recipient_id TEXT NOT NULL,
  recipient_device_id INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  ratchet_header TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (message_id, recipient_id, recipient_device_id)
) PARTITION BY RANGE (created_at);
```

### Partition Management

- **Initial partitions:** One per month from the earliest existing data through current month + 1 month ahead.
- **Auto-creation:** New cron job `/api/cron/partitions` (runs 1st of each month) or a Postgres function `create_next_ciphertext_partition()` called via `pg_cron`.
- **Partition naming:** `message_ciphertexts_2026_03`, `message_ciphertexts_2026_04`, etc.

### Migration Strategy

1. Create new partitioned table with initial partitions
2. `INSERT INTO message_ciphertexts_partitioned SELECT * FROM message_ciphertexts` (backfill)
3. In a transaction: rename old table to `_old`, rename new table to `message_ciphertexts`
4. Verify, then `DROP TABLE message_ciphertexts_old`

### Index Strategy

Each partition automatically inherits:
- `UNIQUE (message_id, recipient_id, recipient_device_id)` — per-partition unique constraint
- `INDEX ON (recipient_id, recipient_device_id, created_at)` — for sync queries ("give me ciphertexts for my device since timestamp X")

### RLS

Partitions inherit the parent's RLS policies automatically.

### Archival (Future)

After 6 months, `ALTER TABLE message_ciphertexts DETACH PARTITION message_ciphertexts_2026_03` → move to cold storage or drop. Only needed for device-linking history transfer (Vault spec).

---

## 6. Cross-Isolate Mutex Locks (CRYPTO-05)

### Problem

Concurrent ratchet access from multiple threads (UI + background sync, multiple browser tabs + service worker) can permanently corrupt Double Ratchet state by consuming the same chain index twice.

### Solution

Platform-specific mutex implementations behind a shared `CryptoMutex` interface.

### Web: Web Locks API

**New file: `web/src/lib/crypto/mutex.ts`**

```typescript
async function acquireRatchetLock<T>(
  sessionId: string,
  fn: () => Promise<T>
): Promise<T> {
  return navigator.locks.request(
    `ratchet:${sessionId}`,
    { mode: 'exclusive' },
    () => fn()
  );
}

async function acquireSenderKeyLock<T>(
  groupId: string,
  fn: () => Promise<T>
): Promise<T> {
  return navigator.locks.request(
    `sk:${groupId}`,
    { mode: 'exclusive' },
    () => fn()
  );
}
```

**Fallback:** For browsers without Web Locks API (Safari < 16.4), maintain existing in-tab async queue with `console.warn('Web Locks API unavailable — single-tab crypto safety only')`.

**Integration:** `encryption-service.ts` wraps all `encryptForSanctuary()`, `encryptForSpace()`, and `decryptMessage()` calls with the appropriate lock.

### Flutter: Dedicated Crypto Isolate

**New file: `engine/lib/src/crypto/crypto_isolate.dart`**

Architecture: Single dedicated isolate that owns all ratchet state. All other isolates (foreground UI, background sync, push decrypt) send requests via `SendPort` and await responses.

```dart
abstract class CryptoIsolateMessage {}

class EncryptRequest extends CryptoIsolateMessage {
  final String sessionId;
  final Uint8List plaintext;
  final SendPort replyPort;
}

class DecryptRequest extends CryptoIsolateMessage {
  final String sessionId;
  final Uint8List ciphertext;
  final Uint8List header;
  final SendPort replyPort;
}

class GroupEncryptRequest extends CryptoIsolateMessage {
  final String groupId;
  final Uint8List plaintext;
  final SendPort replyPort;
}

class GroupDecryptRequest extends CryptoIsolateMessage {
  final String groupId;
  final String senderId;
  final Uint8List ciphertext;
  final SendPort replyPort;
}
```

**Lifecycle:**
- `ChatEngineImpl.initialize()` spawns the crypto isolate
- Crypto isolate loads ratchet sessions from encrypted Drift database on startup
- All encrypt/decrypt calls route through message passing — sequential by design
- Periodic flush of ratchet state to Drift (every 10 operations or 5 seconds, whichever comes first)
- `ChatEngineImpl.dispose()` flushes final state and kills the isolate

**Why not OS-level mutexes?** Dart isolates don't share memory. `SendPort`/`ReceivePort` is the idiomatic Dart solution and is actually simpler — no deadlock risk, no mutex poisoning, no priority inversion.

---

## 7. O(1) Sender Key Distribution Caching (CRYPTO-04)

### Problem

Every group message currently piggybacks Sender Key distributions for all group members. In a 15-person group (30 devices), that's 30 extra encrypted payloads per message — ~60KB overhead that's redundant 99% of the time.

### Solution

Track which devices have acknowledged the current Sender Key epoch. Only distribute to unacknowledged devices.

### New Table: `sk_acknowledgments`

```sql
CREATE TABLE sk_acknowledgments (
  group_id   TEXT NOT NULL,
  sender_id  TEXT NOT NULL,
  recipient_id TEXT NOT NULL,
  recipient_device_id INTEGER NOT NULL,
  epoch      INTEGER NOT NULL DEFAULT 1,
  acknowledged_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (group_id, sender_id, recipient_id, recipient_device_id)
);

-- RLS: recipients can insert their own ACKs, senders can read ACKs for their distributions
ALTER TABLE sk_acknowledgments ENABLE ROW LEVEL SECURITY;
CREATE POLICY sk_ack_recipient_select ON sk_acknowledgments FOR SELECT
  USING (recipient_id = auth.jwt()->>'sub');
CREATE POLICY sk_ack_sender_select ON sk_acknowledgments FOR SELECT
  USING (sender_id = auth.jwt()->>'sub');
CREATE POLICY sk_ack_insert ON sk_acknowledgments FOR INSERT
  WITH CHECK (recipient_id = auth.jwt()->>'sub');
CREATE POLICY sk_ack_delete ON sk_acknowledgments FOR DELETE
  USING (sender_id = auth.jwt()->>'sub');  -- sender can clear ACKs on key rotation
```

### Epoch Rotation

When Sender Key rotation is needed (member joins/leaves):
```sql
DELETE FROM sk_acknowledgments
WHERE group_id = p_group_id AND sender_id = p_sender_id;
```
This forces full redistribution on the next message.

### Send-Side Logic

**Web (`encryption-service.ts`):**
```
1. Fetch ACKed devices: SELECT recipient_id, recipient_device_id
   FROM sk_acknowledgments
   WHERE group_id = ? AND sender_id = ?
2. Fetch all group devices: existing group member device query
3. Unacked = all_devices - acked_devices
4. Generate distributions ONLY for unacked devices
5. Attach to message envelope
```

**Engine (`group_cipher.dart`):** Same logic, using local Drift table as cache of ACK state.

### Receive-Side Logic

After successfully decrypting a Sender Key message:
1. Write ACK: `INSERT INTO sk_acknowledgments ... ON CONFLICT DO NOTHING`
2. Batch ACKs: accumulate locally, flush every 5 seconds or on app background

### ACK Delivery

Two options (implement both, prefer option A):
- **A) Piggyback on next outgoing message:** Add `sk_acks: [{groupId, senderId}]` to the message envelope metadata. Zero extra round trips.
- **B) Dedicated endpoint:** `POST /api/keys/sk-ack` for batch ACK flush when no outgoing messages are pending.

### Performance Impact

| Scenario | Before | After |
|----------|--------|-------|
| Steady-state message (15-person group) | 30 distributions (~60KB) | 0 distributions (~0KB) |
| New member joins | 30 distributions | 30 distributions (one-time) |
| Second message after join | 30 distributions | 0 distributions |

---

## 8. Strangler Fig Extraction Interfaces (BACKEND-06/07/08 Preparation)

### Problem

Future extraction of hot paths to dedicated services (Go/Rust message relay, Erlang WebSocket tier, Redis transient queue) requires clean seams in the current code. Without these, extraction means rewriting callers.

### Solution

Three port interfaces — one per future extraction target. Current implementations use Supabase. Future implementations swap in without changing callers.

### Port 1: MessageGateway

**Purpose:** Abstracts message persistence and retrieval. Future: Go/Rust microservice.

**Web: `web/src/lib/ports/message-gateway.ts`**
```typescript
export interface MessageGateway {
  sendMessage(envelope: MessageEnvelope): Promise<SendResult>;
  fetchMessages(groupId: string, sinceSeq: number, limit?: number): Promise<MessageRecord[]>;
  fetchCiphertexts(messageId: string, recipientId: string, deviceId: number): Promise<Ciphertext[]>;
  acknowledgeDelivery(messageId: string, deviceId: number): Promise<void>;
}

export interface SendResult {
  messageId: string;
  serverSeq: number;
  createdAt: string;
}
```

**Engine: `engine/lib/src/ports/message_gateway.dart`**
```dart
abstract class MessageGateway {
  Future<SendResult> sendMessage(MessageEnvelope envelope);
  Future<List<MessageRecord>> fetchMessages(String groupId, {required int sinceSeq, int limit = 50});
  Future<List<Ciphertext>> fetchCiphertexts(String messageId, String recipientId, int deviceId);
  Future<void> acknowledgeDelivery(String messageId, int deviceId);
}
```

**Current implementation:** `SupabaseMessageGateway` — calls `send_e2ee_message` RPC (from Section 1) and PostgREST queries.

### Port 2: RealtimeGateway

**Purpose:** Abstracts real-time event subscriptions. Future: Erlang/Go WebSocket tier.

**Web: `web/src/lib/ports/realtime-gateway.ts`**
```typescript
export interface RealtimeGateway {
  subscribe(groupId: string, handler: (event: RealtimeEvent) => void): Subscription;
  unsubscribe(subscription: Subscription): void;
  publishPresence(groupId: string, userId: string, state: PresenceState): void;
  publishTyping(groupId: string, userId: string): void;
}

export interface Subscription {
  id: string;
  groupId: string;
  unsubscribe(): void;
}

export type RealtimeEvent =
  | { type: 'message'; payload: MessageRecord }
  | { type: 'presence'; payload: PresenceState }
  | { type: 'typing'; payload: { userId: string } }
  | { type: 'sk_recovery'; payload: { groupId: string; senderId: string } };
```

**Engine: `engine/lib/src/ports/realtime_gateway.dart`**
```dart
abstract class RealtimeGateway {
  Stream<RealtimeEvent> subscribe(String groupId);
  Future<void> unsubscribe(String groupId);
  Future<void> publishPresence(String groupId, String userId, PresenceState state);
  Future<void> publishTyping(String groupId, String userId);
}
```

**Current implementation:** `SupabaseRealtimeGateway` — wraps existing Supabase Realtime channel subscriptions.

### Port 3: TransientQueue

**Purpose:** Abstracts offline message queuing with delivery ACK and auto-delete. Future: Redis/ScyllaDB queue.

**Web: `web/src/lib/ports/transient-queue.ts`**
```typescript
export interface TransientQueue {
  enqueue(recipientDeviceId: string, payload: EncryptedPayload): Promise<void>;
  dequeue(deviceId: string, limit?: number): Promise<QueuedMessage[]>;
  acknowledge(deviceId: string, messageIds: string[]): Promise<void>;
  getQueueDepth(deviceId: string): Promise<number>;
}

export interface QueuedMessage {
  messageId: string;
  payload: EncryptedPayload;
  enqueuedAt: number;
}
```

**Engine: `engine/lib/src/ports/transient_queue.dart`**
```dart
abstract class TransientQueue {
  Future<void> enqueue(String recipientDeviceId, EncryptedPayload payload);
  Future<List<QueuedMessage>> dequeue(String deviceId, {int limit = 100});
  Future<void> acknowledge(String deviceId, List<String> messageIds);
  Future<int> getQueueDepth(String deviceId);
}
```

**Current implementation:** `SupabaseTransientQueue` — messages sit in `message_ciphertexts` table, "dequeue" is a SELECT query filtered by recipient, "acknowledge" marks as delivered (or relies on read receipts). No auto-delete yet (that's a future Redis optimization).

### Dependency Injection

**Web (`web/src/lib/ports/index.ts`):**
```typescript
// Composition root — swap implementations here
export const messageGateway: MessageGateway = new SupabaseMessageGateway(supabaseAdmin);
export const realtimeGateway: RealtimeGateway = new SupabaseRealtimeGateway(supabaseClient);
export const transientQueue: TransientQueue = new SupabaseTransientQueue(supabaseAdmin);
```

**Engine (`engine/lib/src/ports/ports.dart`):**
```dart
// Composition root — swap implementations here
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

Injected during `ChatEngineImpl.initialize()`. API routes import from the composition root.

---

## Build Order

```
Step 1: Supavisor Connection Pooling (BACKEND-02)
  └── Foundation — all subsequent DB work benefits from pooling

Step 2: Atomic PostgreSQL Transactions (BACKEND-01)
  └── Depends on: pooled connections
  └── Blocks: MessageGateway port wraps this RPC

Step 3: Partition message_ciphertexts (BACKEND-05)
  └── Depends on: atomic transactions (ensures no mid-transaction partition issues)
  └── Independent of other items

Step 4: Edge Rate Limiting (BACKEND-03)
  └── Depends on: Upstash Redis provisioned
  └── Blocks: key cache (reuses same Redis)

Step 5: Edge-Cache Key Bundles (BACKEND-04)
  └── Depends on: Upstash Redis (from step 4)

Step 6: O(1) SK Distribution Caching (CRYPTO-04)
  └── Depends on: atomic transactions, partitioned table
  └── Web + Engine changes in parallel

Step 7: Cross-Isolate Mutex Locks (CRYPTO-05)
  └── Independent but best done after SK caching (mutex wraps encrypt/decrypt paths that now include ACK logic)
  └── Web + Engine changes in parallel

Step 8: Strangler Fig Interfaces (BACKEND-06/07/08 prep)
  └── Depends on: all implementations exist (wraps them in ports)
  └── Must be last — refactors callers to use port interfaces
```

---

## Testing Strategy

### Unit Tests
- Atomic RPC: Test with invalid membership, duplicate messages, concurrent sends
- Rate limiter: Test sliding window behavior, verify limits per route
- Key cache: Test hit/miss/invalidation, TTL expiry
- SK ACK tracking: Test epoch rotation, partial ACK states
- Mutex (web): Test concurrent decrypt attempts resolve sequentially
- Mutex (engine): Test multi-isolate message ordering

### Integration Tests
- Full message send pipeline through atomic RPC (web + engine)
- Connection pooling under concurrent load (100 parallel requests)
- Rate limiting across multiple serverless instances
- Key bundle cache hit rate under simulated chat-start burst
- Partition query routing (insert into current month, query spanning months)

### Load Tests
- 1000 concurrent message sends → verify zero ghost messages
- 500 concurrent key bundle fetches → verify cache hit rate > 90%
- Rate limit saturation → verify graceful 429 responses
- 10k message_ciphertexts inserts → verify partition routing

---

## Rollback Strategy

Each step is independently deployable and rollbackable:

1. **Pooling:** Revert `DATABASE_URL` env var to direct connection
2. **Atomic RPC:** API route can fall back to sequential inserts (keep old code behind feature flag during migration)
3. **Partitioning:** Table rename is atomic; keep `_old` table until verified
4. **Rate limiting:** Dual-write period; revert to Postgres rate_limiter if Redis issues
5. **Key cache:** Cache miss falls through to Postgres — disable cache = slightly slower, still correct
6. **SK caching:** Worst case = send distributions to everyone (current behavior, just wasteful)
7. **Mutexes:** Fallback = existing in-process locking (less safe but functional)
8. **Interfaces:** Pure refactor — no behavior change, revert is mechanical

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Ghost messages under concurrent load | 0 |
| Postgres connections under 1k concurrent requests | < 20 (pooled) |
| Rate limit check latency | < 5ms (Redis) |
| Key bundle cache hit rate (steady state) | > 90% |
| message_ciphertexts query time (100M rows) | < 10ms (partitioned) |
| Concurrent ratchet corruption incidents | 0 |
| SK distribution overhead (steady state group message) | 0 bytes |
| Time to swap a port implementation | < 1 hour (interface change + DI swap) |

---

## Files Changed / Created

### New Files
- `web/supabase/migrations/XXXXXX_atomic_send_message.sql`
- `web/supabase/migrations/XXXXXX_partition_ciphertexts.sql`
- `web/supabase/migrations/XXXXXX_sk_acknowledgments.sql`
- `web/supabase/migrations/XXXXXX_drop_rate_limiter.sql`
- `web/src/lib/rate-limit-edge.ts`
- `web/src/lib/key-cache.ts`
- `web/src/lib/crypto/mutex.ts`
- `web/src/lib/ports/message-gateway.ts`
- `web/src/lib/ports/realtime-gateway.ts`
- `web/src/lib/ports/transient-queue.ts`
- `web/src/lib/ports/index.ts`
- `engine/lib/src/crypto/crypto_isolate.dart`
- `engine/lib/src/ports/message_gateway.dart`
- `engine/lib/src/ports/realtime_gateway.dart`
- `engine/lib/src/ports/transient_queue.dart`
- `engine/lib/src/ports/ports.dart`

### Modified Files
- `web/src/app/api/message/route.ts` — use atomic RPC + MessageGateway port
- `web/src/app/api/keys/fetch/route.ts` — add cache layer
- `web/src/app/api/keys/bundle/route.ts` — add cache invalidation
- `web/src/app/api/hello/route.ts` — use new rate limiter
- `web/src/app/api/phone-auth/route.ts` — use new rate limiter
- `web/src/app/api/chat/start/route.ts` — use new rate limiter
- `web/src/app/api/contacts/check/route.ts` — use new rate limiter
- `web/src/app/api/local-action/route.ts` — use new rate limiter
- `web/src/app/api/notify/route.ts` — use new rate limiter
- `web/src/app/api/invite/*/route.ts` — use new rate limiter
- `web/src/lib/supabase-admin.ts` — pooler connection string
- `web/src/lib/crypto/encryption-service.ts` — mutex locks + SK ACK logic
- `engine/lib/src/transport/supabase_client.dart` — use atomic RPC
- `engine/lib/src/crypto/sender_keys/group_cipher.dart` — SK ACK logic
- `engine/lib/src/chat_engine_impl.dart` — spawn crypto isolate, inject ports

### New Dependencies
- `@upstash/ratelimit` (web)
- `@upstash/redis` (web)

### New Environment Variables
- `UPSTASH_REDIS_REST_URL`
- `UPSTASH_REDIS_REST_TOKEN`
- `DATABASE_URL` (updated to pooler)
- `DATABASE_URL_DIRECT` (new, for migrations)
