# Security Hardening Sprint — Design Spec

**Date:** 2026-04-10
**Status:** Approved
**Scope:** 10 critical fixes across 5 fully parallel work streams
**Execution:** 5 simultaneous agents in isolated git worktrees, ~30 minutes total

---

## Context

The forensic audit of 297 source files identified 7 SEV-1 and 5 SEV-2 security findings. This spec defines the exact fix for each finding with zero coupling between work streams.

---

## Stream A: Crypto Isolate Kill + Multi-Device Fan-out

**Items:** 1, 8
**Agent worktree:** `feat/crypto-isolate-kill`
**Files touched:** `engine/` only — `crypto/`, `domain/use_cases/`, `chat_engine_impl.dart`, `sync/`, `media/`

### Item 1: The Stateful/Stateless Split

**Problem:** `crypto_isolate.dart` echoes all encrypt/decrypt bytes unchanged. The isolate infrastructure (watchdogs, ports, respawn) works, but no ratchet or SK operation executes inside it.

**Solution:** Delete the persistent isolate. Split crypto into stateful (main thread) and stateless (`Isolate.run()`) paths.

**Architecture:**

```
STATEFUL (main thread, atomic):
  - DoubleRatchet.ratchetEncrypt/Decrypt() — steps the ratchet, derives MessageKey
  - GroupCipher.encrypt/decrypt() — steps the SK chain
  - KeyStore read/write — all DB transactions
  - Ratchet state persistence — atomic commit after successful encrypt/decrypt

STATELESS (Isolate.run(), fire-and-forget):
  - AES-256-GCM symmetric encryption of media file bytes
  - AES-256-GCM symmetric decryption of media file bytes
  - SHA-256 hash computation for file verification
```

**Conditional execution strategy:**

| Payload | Execution | Rationale |
|---------|-----------|-----------|
| Text message | Inline main thread | <1ms. Isolate spawn overhead exceeds crypto time. |
| Batch decrypt (reconnect) | Main thread + yield every 5 msgs | `await Future.delayed(Duration.zero)` after every 5 messages keeps UI at 60fps. |
| Media file (>64KB) | `Isolate.run()` | Pass raw bytes + derived AES key. Stateless. Isolate dies after return. |

**Exact changes:**

1. **DELETE** `engine/lib/src/crypto/crypto_isolate.dart`
2. **EDIT** `engine/lib/src/chat_engine_impl.dart`:
   - Remove `import 'crypto/crypto_isolate.dart'`
   - Remove `CryptoIsolateManager` field, constructor param, and `initialize()` call
   - Remove `_cryptoIsolate` references
3. **EDIT** `engine/lib/src/domain/use_cases/send_message_use_case.dart`:
   - Call `_ratchet.ratchetEncrypt(plaintext, session)` directly (was routing through isolate)
   - Call `_groupCipher.encrypt(plaintext, senderKey)` directly for groups
   - Save ratchet state atomically after successful encrypt
4. **EDIT** `engine/lib/src/domain/use_cases/receive_message_use_case.dart`:
   - Call `_ratchet.ratchetDecrypt(ciphertext, session)` directly
   - Call `_groupCipher.decrypt(ciphertext, senderKey)` directly for groups
5. **EDIT** `engine/lib/src/sync/sync_coordinator.dart`:
   - Add yield-loop in batch decrypt: `if (i % 5 == 0) await Future.delayed(Duration.zero)`
6. **EDIT** `engine/lib/src/media/upload_manager.dart`:
   - Wrap `MediaCrypto.encrypt()` in `Isolate.run(() => ...)`
7. **EDIT** `engine/lib/src/media/download_manager.dart`:
   - Wrap `MediaCrypto.decrypt()` in `Isolate.run(() => ...)`

### Item 8: Multi-Device Fan-out

**Problem:** `send_message_use_case.dart:141` hardcodes `const recipientDeviceId = 1`. Messages only reach one device per user.

**Solution:** Batch-fetch all missing key bundles up front, then encrypt in a tight loop with zero network I/O.

**Exact changes in `send_message_use_case.dart`:**

```dart
// BEFORE:
const recipientDeviceId = 1;

// AFTER:
// Step 1: Get all recipient devices (single API call)
final devices = await _apiClient.getUserDevices(recipientId);

// Step 2: Identify which devices need X3DH session establishment
final missingDeviceIds = <int>[];
final existingSessions = <int, RatchetSession>{};
for (final device in devices) {
  final session = await _keyStore.getSession(recipientId, device.deviceId);
  if (session != null) {
    existingSessions[device.deviceId] = session;
  } else {
    missingDeviceIds.add(device.deviceId);
  }
}

// Step 3: Bulk-fetch all missing key bundles in ONE network call
if (missingDeviceIds.isNotEmpty) {
  final bundles = await _apiClient.fetchKeyBundles(recipientId, missingDeviceIds);
  for (final bundle in bundles) {
    final session = await _x3dh.initiate(bundle);
    await _keyStore.saveSession(recipientId, bundle.deviceId, session);
    existingSessions[bundle.deviceId] = session;
  }
}

// Step 4: Encrypt per-device — pure CPU, zero network, zero blocking
for (final entry in existingSessions.entries) {
  final ciphertext = _ratchet.ratchetEncrypt(plaintext, entry.value);
  envelope.addCiphertext(entry.key, ciphertext);
}
```

**Backend addition:** Add `fetchKeyBundles(userId, List<int> deviceIds)` to `SupabaseClientWrapper` — single POST to a new `/api/keys/fetch-batch` endpoint or use existing `fetch_key_bundle` RPC with array parameter. Returns all bundles in one round-trip.

The `send_e2ee_message` RPC already accepts an array of `{device_id, ciphertext}` pairs — no backend changes needed for the send path.

---

## Stream B: WebCrypto Master Key + Media Cleanup

**Items:** 5, 6, 10
**Agent worktree:** `feat/web-crypto-hardening`
**Files touched:** `web/src/lib/crypto/encrypted-store.ts` (rewrite), `web/src/lib/crypto/CryptoProvider.ts` (delete), `web/src/components/os/MediaUpload.tsx` (delete), `web/src/components/os/EncryptedMedia.tsx` (1-line fix), `engine/lib/src/persistence/database/database_factory_web.dart` (delete), `engine/lib/src/persistence/database/database_factory.dart` (1-line edit)

### Item 5: Non-Extractable WebCrypto Master Key

**Problem:** `encrypted-store.ts` has an Argon2id PIN-based `unlockStore(pin)` that is never called. All IndexedDB writes use the unencrypted `plain:` fallback path. Browser-side ratchet state and identity keys are stored in plaintext.

**Solution:** Replace Argon2id PIN flow with a non-extractable `AES-GCM-256` CryptoKey stored in IndexedDB. Zero user friction. XSS-resistant (attacker cannot export the key).

**Critical API contract:** `encryptForStorage(Uint8Array): string` and `decryptFromStorage(string): Uint8Array` signatures MUST remain identical — `keystore.ts` has 14 call sites depending on these exact signatures.

**New `encrypted-store.ts` internals:**

```typescript
// Module-level cache (lives for tab lifetime)
let masterKey: CryptoKey | null = null;

async function getOrCreateMasterKey(): Promise<CryptoKey> {
  if (masterKey) return masterKey;
  
  const db = await idbOpen('hello-vault', 1);
  const existing = await idbGet(db, 'keys', 'master');
  if (existing) {
    masterKey = existing;
    return existing;
  }
  
  const key = await crypto.subtle.generateKey(
    { name: 'AES-GCM', length: 256 },
    false, // NON-EXTRACTABLE
    ['encrypt', 'decrypt']
  );
  await idbPut(db, 'keys', key, 'master');
  masterKey = key;
  return key;
}

// Same signature as before — drop-in replacement
export async function encryptForStorage(plaintext: Uint8Array): Promise<string> {
  const key = await getOrCreateMasterKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv }, key, plaintext
  ));
  return 'wcrypt:' + base64(concat(iv, ct));
}

export async function decryptFromStorage(stored: string): Promise<Uint8Array> {
  // Backward compat: handle legacy 'plain:' prefix
  if (stored.startsWith('plain:')) {
    return base64decode(stored.slice(6));
  }
  if (stored.startsWith('wcrypt:')) {
    const blob = base64decode(stored.slice(7));
    const iv = blob.slice(0, 12);
    const ct = blob.slice(12);
    const key = await getOrCreateMasterKey();
    return new Uint8Array(await crypto.subtle.decrypt(
      { name: 'AES-GCM', iv }, key, ct
    ));
  }
  // Legacy unencrypted format
  return new TextEncoder().encode(stored);
}
```

**Note:** `encryptForStorage` and `decryptFromStorage` become `async`. `keystore.ts` call sites already `await` them (they were sync before but wrapped in async functions). Verify all 14 call sites handle the Promise correctly.

**What stays plaintext (by design):**
- `web/src/lib/crypto/message-cache.ts` — high-volume message cache. Browser sandbox + OS FDE is the security boundary.

**Deletions:**
- `unlockStore()`, `lockStore()`, `isStoreUnlocked()` — removed entirely
- Argon2id import and key derivation logic — removed
- `web/src/lib/crypto/CryptoProvider.ts` — orphaned ECDSA P-256 dead code, zero importers in live code
- `engine/lib/src/persistence/database/database_factory_web.dart` — phantom code for non-existent Flutter web deployment

**1-line edit in `engine/lib/src/persistence/database/database_factory.dart`:**
```dart
// BEFORE:
if (dart.library.js_interop) 'database_factory_web.dart'

// AFTER:
if (dart.library.js_interop) 'database_factory_stub.dart'
```

### Item 6: Kill Plaintext Uploads

**Problem:** `MediaUpload.tsx` uploads unencrypted media to Firebase alongside the E2EE `AddItemModal`. No UI differentiation.

**Solution:** Delete `MediaUpload.tsx`. Zero importers confirmed by grep — no parent component references it. The only upload path is `AddItemModal` with AES-256-GCM encryption.

### Item 10: Large File Decryption Fix

**Problem:** `EncryptedMedia.tsx` calls `decryptFile(blob, key)` which only handles single-chunk AES-GCM. Files >1MB encrypted with streaming AEAD (64KB chunks) fail to decrypt.

**Solution:** One-line change:
```typescript
// BEFORE:
const decrypted = await decryptFile(blob, metadata.key);
// AFTER:
const decrypted = await decryptFileAuto(blob, metadata);
```

`decryptFileAuto` (already exists in `file-encryption.ts`) dispatches to streaming or non-streaming based on `metadata.streamingKey` presence.

---

## Stream C: Concurrent Pointer Model + Webhook Signature

**Items:** 3, 4
**Agent worktree:** `feat/e2ee-media-keys`
**Files touched:** `web/src/components/os/AddItemModal.tsx`, `web/src/lib/crypto/file-encryption.ts`, `web/src/app/api/hello/webhook/route.ts`

### Item 3: AddItemModal AES Key Encryption

**Problem:** Image AES key, IV, and download URL stored as plaintext JSON in Supabase `decision_items.metadata`. Any Supabase admin or leaked service-role key decrypts every image.

**Solution:** Concurrent Pointer Model.

**Principles:**
- The IV belongs in the file, not the database. Prepend 12-byte IV to the encrypted blob.
- Only the 32-byte AES key goes inside the E2EE `ciphertextPayload` envelope.
- The URL stays in plaintext `metadata` for concurrent download (no sequential decrypt-then-download).
- GCM auth tag prevents tampered blob decryption even though URL is plaintext.

**New upload flow:**
```
1. aesKey = crypto.randomBytes(32)
2. iv = crypto.randomBytes(12)
3. encryptedBlob = [iv(12)] + [AES-GCM(fileBytes, aesKey, iv)] + [authTag(16)]
4. Upload encryptedBlob to Firebase → downloadUrl
5. payload = { title, description, category, imageKey: base64(aesKey) }
6. ciphertextPayload = encrypt(payload)  // E2EE via Double Ratchet or Sender Keys
7. INSERT decision_items: {
     ciphertextPayload, nonce,
     metadata: { imageUrl: downloadUrl }  // URL only, no key
   }
```

**New display flow (concurrent):**
```
1. Query returns: plaintext metadata.imageUrl + encrypted ciphertextPayload
2. PARALLEL:
   a. fetch(imageUrl) → start downloading encrypted blob immediately
   b. decrypt(ciphertextPayload) → extract { title, imageKey }
3. Blob arrives: iv = blob[0:12], ciphertext = blob[12:]
4. AES-GCM-decrypt(ciphertext, imageKey, iv) → render image
5. GCM auth tag mismatch on tampered blob → hard error, drop payload
```

**New function in `file-encryption.ts`:**
```typescript
export async function encryptWithPrependedIV(
  plaintext: Uint8Array, key: Uint8Array
): Promise<Uint8Array> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const cryptoKey = await crypto.subtle.importKey(
    'raw', key, 'AES-GCM', false, ['encrypt']
  );
  const ct = new Uint8Array(await crypto.subtle.encrypt(
    { name: 'AES-GCM', iv }, cryptoKey, plaintext
  ));
  return concat(iv, ct); // [iv(12)][ct+tag(16)]
}

export async function decryptWithPrependedIV(
  blob: Uint8Array, key: Uint8Array
): Promise<Uint8Array> {
  const iv = blob.slice(0, 12);
  const ct = blob.slice(12);
  const cryptoKey = await crypto.subtle.importKey(
    'raw', key, 'AES-GCM', false, ['decrypt']
  );
  return new Uint8Array(await crypto.subtle.decrypt(
    { name: 'AES-GCM', iv }, cryptoKey, ct
  ));
}
```

**Data migration (surgical key removal — preserves all other metadata fields):**
```sql
-- Uses JSONB minus operator to remove ONLY the compromised keys
-- Preserves width, height, fileSize, mimeType, and any other fields
UPDATE decision_items
SET metadata = metadata - 'imageKey' - 'imageIv'
WHERE metadata ? 'imageKey';
```

### Item 4: Webhook Signature Verification

**Problem:** `api/hello/webhook/route.ts` accepts Apify results with zero authentication. Attacker can inject decision items by guessing valid `groupId` + `msgId`.

**Solution:** HMAC-SHA256 with `APIFY_WEBHOOK_SECRET` env var + `timingSafeEqual`.

**Exact change at top of POST handler:**
```typescript
import { createHmac, timingSafeEqual } from 'crypto';

const secret = process.env.APIFY_WEBHOOK_SECRET;
if (!secret) {
  return NextResponse.json({ error: 'webhook not configured' }, { status: 500 });
}

const signature = request.headers.get('x-apify-signature');
const body = await request.text();
const expected = createHmac('sha256', secret).update(body).digest('hex');

if (!signature || !timingSafeEqual(
  Buffer.from(signature, 'utf8'),
  Buffer.from(expected, 'utf8')
)) {
  return NextResponse.json({ error: 'invalid signature' }, { status: 403 });
}

const data = JSON.parse(body); // parse after verification
```

---

## Stream D: Xpensly RLS + SDK BYOD + Trigger Fix

**Items:** 2, 9
**Agent worktree:** `feat/xpensly-rls-hardening`
**Files touched:** `web/supabase/migrations/` (new files), `xpensly/xpensly_core/lib/src/adapters/supabase_data_source.dart` (delete), `xpensly/xpensly_core/pubspec.yaml` (remove supabase dep)

### Item 2: Xpensly RLS via Array Containment

**Problem:** All 8 `xp_*` tables have zero RLS. Any authenticated user can SELECT all data.

**Solution:** Denormalize `participant_ids UUID[]` onto `xp_trips`. Array-containment RLS policy with O(1) per-row check.

**New migration `20260410000001_xpensly_rls.sql`:**

```sql
-- 1. Denormalize participants
ALTER TABLE xp_trips ADD COLUMN participant_ids UUID[] DEFAULT '{}';

-- 2. Backfill
UPDATE xp_trips t SET participant_ids = (
  SELECT COALESCE(array_agg(m.user_id), '{}')
  FROM xp_trip_members m WHERE m.trip_id = t.id
);

-- 3. Keep in sync
CREATE OR REPLACE FUNCTION sync_xp_trip_participants()
RETURNS trigger AS $$
BEGIN
  UPDATE xp_trips SET participant_ids = (
    SELECT COALESCE(array_agg(user_id), '{}')
    FROM xp_trip_members
    WHERE trip_id = COALESCE(NEW.trip_id, OLD.trip_id)
  ) WHERE id = COALESCE(NEW.trip_id, OLD.trip_id);
  RETURN NULL;
END; $$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_sync_xp_participants
  AFTER INSERT OR DELETE ON xp_trip_members
  FOR EACH ROW EXECUTE FUNCTION sync_xp_trip_participants();

-- 4. RLS on all tables
ALTER TABLE xp_trips ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_trip_access" ON xp_trips
  FOR ALL USING (auth.uid() = ANY(participant_ids));

ALTER TABLE xp_trip_phases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_phase_access" ON xp_trip_phases
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_trip_members ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_member_access" ON xp_trip_members
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_expenses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_expense_access" ON xp_expenses
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

-- Denormalize trip_id onto payers and splits to flatten the RLS join
ALTER TABLE xp_expense_payers ADD COLUMN IF NOT EXISTS trip_id UUID
  REFERENCES xp_trips(id) ON DELETE CASCADE;
ALTER TABLE xp_expense_splits ADD COLUMN IF NOT EXISTS trip_id UUID
  REFERENCES xp_trips(id) ON DELETE CASCADE;

-- Backfill trip_id from parent expense
UPDATE xp_expense_payers p SET trip_id = (
  SELECT e.trip_id FROM xp_expenses e WHERE e.id = p.expense_id
) WHERE p.trip_id IS NULL;
UPDATE xp_expense_splits s SET trip_id = (
  SELECT e.trip_id FROM xp_expenses e WHERE e.id = s.expense_id
) WHERE s.trip_id IS NULL;

-- Auto-populate trip_id on insert
CREATE OR REPLACE FUNCTION set_xp_child_trip_id()
RETURNS trigger AS $$
BEGIN
  NEW.trip_id := (SELECT trip_id FROM xp_expenses WHERE id = NEW.expense_id);
  RETURN NEW;
END; $$ LANGUAGE plpgsql;
CREATE TRIGGER trg_set_payer_trip_id BEFORE INSERT ON xp_expense_payers
  FOR EACH ROW EXECUTE FUNCTION set_xp_child_trip_id();
CREATE TRIGGER trg_set_split_trip_id BEFORE INSERT ON xp_expense_splits
  FOR EACH ROW EXECUTE FUNCTION set_xp_child_trip_id();

-- Flat single-jump RLS (no double-nested subqueries)
ALTER TABLE xp_expense_payers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_payer_access" ON xp_expense_payers
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_expense_splits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_split_access" ON xp_expense_splits
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_settlements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_settlement_access" ON xp_settlements
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

ALTER TABLE xp_refunds ENABLE ROW LEVEL SECURITY;
CREATE POLICY "xp_refund_access" ON xp_refunds
  FOR ALL USING (trip_id IN (
    SELECT id FROM xp_trips WHERE auth.uid() = ANY(participant_ids)));

-- 5. Indexes
CREATE INDEX idx_xp_trips_participants ON xp_trips USING GIN (participant_ids);
```

**SDK cleanup (Plan D — BYOD):**
- **MOVE** (not delete) `xpensly/xpensly_core/lib/src/adapters/supabase_data_source.dart` → `engine/lib/src/adapters/xpensly/supabase_xpensly_data_source.dart`
  - The hello monorepo retains its own Supabase adapter for the hello app
  - The `xpensly_core` SDK package becomes pure Dart with zero Supabase coupling
- Remove `supabase: ^2.10.4` from `xpensly/xpensly_core/pubspec.yaml`
- The SDK ships with `XpenslyDataSource` interface + `InMemoryDataSource` only
- Host apps (including hello's own `engine/`) implement the interface against their own database

### Item 9: Migration 031/027 Trigger Fix

**Problem:** Migration 031 drops `decision_items.category` column. Migration 027's `update_taste_on_reaction` trigger references that column. Trigger silently fails (caught by EXCEPTION WHEN OTHERS).

**New migration `20260410000002_fix_taste_trigger.sql`:**

```sql
DROP TRIGGER IF EXISTS trg_update_taste_on_reaction ON reactions;
DROP FUNCTION IF EXISTS update_taste_on_reaction();

CREATE OR REPLACE FUNCTION update_taste_on_reaction_v2()
RETURNS trigger AS $$
BEGIN
  INSERT INTO user_taste_profiles (user_id, signal_type, signal_value, weight)
  VALUES (
    auth.jwt()->>'sub',
    'reaction',
    NEW.reaction_type,
    CASE NEW.reaction_type
      WHEN 'love_it' THEN 5
      WHEN 'works_for_me' THEN 1
      WHEN 'not_for_me' THEN -3
    END
  )
  ON CONFLICT (user_id, signal_type, signal_value)
  DO UPDATE SET weight = user_taste_profiles.weight + EXCLUDED.weight;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_update_taste_on_reaction_v2
  AFTER INSERT ON reactions
  FOR EACH ROW EXECUTE FUNCTION update_taste_on_reaction_v2();
```

---

## Stream E: Push Notification Rebuild

**Item:** 7
**Agent worktree:** `feat/push-decrypt`
**Files touched:** `engine/lib/src/notifications/` (new + rewrite), `app/pubspec.yaml`

### Item 7: Zero-Network Push Decryption with Port Hand-off

**Problem:** `push_decryptor.dart` is a full TODO stub. Every push notification shows "You may have new messages." The old `tickle_handler.dart` (deleted this session) was broken and referenced missing dependencies.

**Two critical risks of the naive "fetch ciphertext in background" approach:**
1. **OS Kill Trap:** Making a Supabase REST call inside a background isolate risks exceeding iOS/Android background execution limits on slow networks. The OS will kill the process.
2. **Ratchet Fork Bomb:** If the main app is suspended in RAM and the background isolate independently steps the ratchet and saves to SQLite, the main app wakes with stale ratchet state. The next message send produces a chain mismatch — chat permanently bricked.

**Solution:** Zero-network push + IsolateNameServer port hand-off.

**Backend change (Next.js `/api/notify/route.ts`):**
The server MUST inject the E2EE ciphertext directly into the FCM data payload (up to 4KB allowed by FCM). No background network fetch needed.

```typescript
// BEFORE: data-only tickle
await sendPush(deviceToken, { type: 'tickle', message_id: msgId });

// AFTER: ciphertext embedded in push payload
await sendPush(deviceToken, {
  type: 'e2ee_message',
  message_id: msgId,
  sender_id: senderId,
  group_id: groupId,
  ciphertext: ciphertextBase64,  // Already stored from send_e2ee_message
  nonce: nonceBase64,
});
```

**Architecture (zero network I/O in background):**
```
FCM data-only push arrives (ciphertext already in payload)
  → @pragma('vm:entry-point') top-level function
  → Firebase.initializeApp()
  
  → Step 1: Check if main app is alive via IsolateNameServer
    port = IsolateNameServer.lookupPortByName('main_engine_port')
    
  → Step 2A (main app alive — HAND OFF):
    Send ciphertext to main isolate via port.send(pushData)
    Main thread decrypts atomically (ratchet state stays consistent)
    Main thread fires local notification with decrypted preview
    Background handler returns immediately
    
  → Step 2B (main app dead — DECRYPT LOCALLY):
    DatabaseKeyManager.getOrCreateKey() (from platform keychain)
    Open SQLCipher DB (NativeDatabase, same factory as main app)
    Load ratchet session from local DB
    DoubleRatchet.ratchetDecrypt(ciphertext, session)
    Extract sender name + preview text
    flutter_local_notifications.show(senderName, previewText)
    Save updated ratchet state to DB
    Close DB connection
    Return
```

**Why this eliminates the ratchet fork bomb:**
- If the main app is alive (suspended but in RAM), the background handler NEVER touches the DB. It sends the ciphertext over the IsolateNameServer port. The main thread wakes, decrypts with its own in-memory ratchet state, saves atomically.
- If the main app is dead (killed by OS), the background handler owns the DB exclusively. No fork possible.
- The IsolateNameServer check is a single in-memory lookup — microseconds, zero network.

**Main app registration (in `ChatEngineImpl.initialize()`):**
```dart
final receivePort = ReceivePort();
IsolateNameServer.removePortNameMapping('main_engine_port');
IsolateNameServer.registerPortWithName(receivePort.sendPort, 'main_engine_port');
receivePort.listen((data) {
  // Decrypt and show notification using the live engine
  _handlePushDecrypt(data as Map<String, dynamic>);
});
```

**Fallback chain:** Any exception at any step → show "You may have new messages". Never expose error details. Never block.

**Key design decisions:**
- **Zero network I/O in background.** Ciphertext travels inside the FCM payload (4KB limit covers all text messages).
- **Port hand-off prevents ratchet forks.** Background handler never touches the DB when main app is alive.
- **No persistent isolate.** The FCM background handler IS an isolate — Dart spawns one automatically.
- For messages exceeding 4KB (rare — media metadata only), the push payload carries only `{ type: 'tickle' }` and falls back to generic notification. Full decrypt happens when the user opens the app.

**Dependency additions to `app/pubspec.yaml`:**
```yaml
flutter_local_notifications: ^18.0.0
```

**Files:**
- New: `engine/lib/src/notifications/push_handler.dart`
- Rewrite: `engine/lib/src/notifications/push_decryptor.dart` (real decrypt logic)
- Edit: `engine/lib/src/notifications/push_method_channel.dart` (wire to real decryptor)
- Edit: `engine/lib/src/chat_engine_impl.dart` (register IsolateNameServer port) — **Note:** this edit is in `initialize()` only, adding the port registration. Stream A edits the same file but only removes CryptoIsolateManager references. The edits are in different sections of the file and do not conflict.
- Edit: `web/src/app/api/notify/route.ts` (embed ciphertext in FCM payload)

---

## Parallel Execution Matrix

```
┌───────────┬──────────────────────────────┬────────────────────────────────┬──────────┐
│ Stream    │ Items                        │ Files (exclusive to stream)    │ Blocking │
├───────────┼──────────────────────────────┼────────────────────────────────┼──────────┤
│ A         │ 1 (isolate kill)             │ engine/crypto/crypto_isolate   │ NONE     │
│           │ 8 (multi-device)             │ engine/domain/use_cases/*      │          │
│           │                              │ engine/chat_engine_impl        │          │
│           │                              │ engine/sync/sync_coordinator   │          │
│           │                              │ engine/media/upload_manager    │          │
│           │                              │ engine/media/download_manager  │          │
├───────────┼──────────────────────────────┼────────────────────────────────┼──────────┤
│ B         │ 5 (WebCrypto key)            │ web/lib/crypto/encrypted-store │ NONE     │
│           │ 6 (kill MediaUpload)         │ web/lib/crypto/CryptoProvider  │          │
│           │ 10 (EncryptedMedia fix)      │ web/components/os/MediaUpload  │          │
│           │                              │ web/components/os/EncryptedMedia│         │
│           │                              │ engine/persistence/db_factory* │          │
├───────────┼──────────────────────────────┼────────────────────────────────┼──────────┤
│ C         │ 3 (AES key in envelope)      │ web/components/os/AddItemModal │ NONE     │
│           │ 4 (webhook signature)        │ web/lib/crypto/file-encryption │          │
│           │                              │ web/app/api/hello/webhook      │          │
├───────────┼──────────────────────────────┼────────────────────────────────┼──────────┤
│ D         │ 2 (Xpensly RLS)             │ web/supabase/migrations/ (new) │ NONE     │
│           │ 9 (taste trigger fix)        │ xpensly/adapters/supabase_ds   │          │
│           │                              │ xpensly/pubspec.yaml           │          │
│           │                              │ engine/adapters/xpensly/ (new) │          │
├───────────┼──────────────────────────────┼────────────────────────────────┼──────────┤
│ E         │ 7 (push notification)        │ engine/notifications/* (new)   │ NONE     │
│           │                              │ web/app/api/notify/route.ts    │          │
│           │                              │ app/pubspec.yaml               │          │
└───────────┴──────────────────────────────┴────────────────────────────────┴──────────┘

File overlap between streams: ZERO
Sequential dependencies: ZERO
All 5 agents launch simultaneously.
```

---

## Verification Checklist (Post-Merge)

After all 5 streams merge to main:

- [ ] `cd engine && dart analyze` — 0 errors
- [ ] `cd engine && flutter test` — all tests pass (crypto, sync, domain, transport)
- [ ] `cd app && dart analyze` — 0 errors
- [ ] `cd web && npm run build` — 0 TypeScript errors
- [ ] `cd web && npm test` — crypto tests pass
- [ ] `cd algo && npm test` — 232 tests pass
- [ ] `cd xpensly/xpensly_core && dart test` — 69 tests pass
- [ ] `cd xpensly/xpensly_core && dart analyze` — no supabase import errors
- [ ] SQL migrations apply cleanly to Supabase
- [ ] Verify RLS: authenticated user cannot SELECT from `xp_trips` they're not a participant of
- [ ] Verify webhook: POST to `/api/hello/webhook` without signature returns 403
- [ ] Verify EncryptedMedia: >1MB file decrypts correctly
- [ ] Verify AddItemModal: `metadata` column contains only `imageUrl`, no key material
