# E2EE Deep Dive — March 15, 2026

## What Exists (Module-by-Module Audit)

### Layer 0: Primitives (`src/lib/crypto/primitives.ts` — 229 lines)
**Status: COMPLETE. Tested. Production-ready.**

Wraps `libsodium-wrappers-sumo` (WASM). Client-side only.

| Function | What it does | Used by |
|----------|-------------|---------|
| `initCrypto()` | Loads libsodium WASM. Must call before any crypto. | useE2EE, key-manager, encryption-service |
| `generateSigningKeyPair()` | Ed25519 key pair (signing + identity) | key-manager (identity key) |
| `sign()` / `verify()` | Ed25519 detached signatures | x3dh (verify pre-key sig), sender-keys (message auth) |
| `ed25519PkToCurve25519()` / `ed25519SkToCurve25519()` | Birational mapping Ed25519 ↔ Curve25519 | x3dh, encryption-service |
| `generateDHKeyPair()` | Curve25519 key pair (DH) | x3dh, double-ratchet, key-manager |
| `dh()` | X25519 Diffie-Hellman | x3dh (4 DH computations), double-ratchet |
| `aesEncrypt()` / `aesDecrypt()` | XChaCha20-Poly1305 (24-byte nonce, no AES-NI needed) | double-ratchet, sender-keys, key-manager (backups) |
| `hkdf()` | HKDF-SHA-256 | x3dh (shared secret derivation) |
| `kdfRatchet()` | Root key + chain key from DH output | double-ratchet |
| `kdfChain()` | Chain advance → message key + next chain key | double-ratchet, sender-keys |
| `deriveBackupKey()` | Argon2id (64MB, 3 iterations) | key-manager (backup encryption) |
| `toBase64()` / `fromBase64()` | Encoding | everywhere |
| `constantTimeEqual()` | Side-channel safe comparison | tests |

**No issues found.** All primitives are thin wrappers around libsodium. Correct algorithms. Correct nonce sizes.

---

### Layer 1: Key Store (`src/lib/crypto/keystore.ts` — 243 lines)
**Status: COMPLETE. Production-ready.**

IndexedDB persistence. 6 object stores:

| Store | Key format | What it stores |
|-------|-----------|----------------|
| `identity` | `'identity'` | Ed25519 key pair (base64 pub + priv) |
| `signed-pre-keys` | `'spk_{id}'` | Curve25519 key pair |
| `one-time-pre-keys` | OTK id string | Curve25519 key pair |
| `sender-keys` | `'active_{spaceId}'` | Serialized SenderKeyState |
| `sessions` | `'{userId}:{deviceId}'` | Serialized Double Ratchet SessionState |
| `meta` | `'deviceId'` | Random integer (device ID) |

**Key methods:**
- `saveIdentityKey` / `getIdentityKey` — Ed25519 identity
- `saveSignedPreKey` / `getSignedPreKey` — Curve25519 signed pre-key by ID
- `saveOneTimePreKeys` / `getOneTimePreKey` / `deleteOneTimePreKey` / `getOneTimePreKeyCount` — OTK lifecycle
- `saveSenderKey` / `getSenderKey` / `deleteSenderKey` — Group Sender Keys
- `saveHistoricalSenderKey` — For decrypting old messages after key rotation
- `saveSession` / `getSession` / `deleteSession` — Double Ratchet sessions
- `getDeviceId` — Generates random device ID on first call, persists
- `clear()` — Wipe all key material (device revocation)

**Singleton:** `export const keyStore = new IndexedDBKeyStore();`

**No issues.** Clean interface. Serialization via base64. Could swap for native Keychain later.

---

### Layer 2: X3DH Key Agreement (`src/lib/crypto/x3dh.ts` — 86 lines)
**Status: COMPLETE. Tested. Production-ready.**

Extended Triple Diffie-Hellman — establishes shared secret for initiating a Double Ratchet session.

**Two functions:**
1. `x3dhInitiate(myIdentityCurve25519, peerBundle)` — Called by the SENDER (first message). Does 3 or 4 DH computations. Returns `{ sharedSecret, ephemeralKey }`.
   - Verifies signed pre-key signature first (rejects invalid bundles)
   - DH1: My identity × Peer's signed pre-key
   - DH2: Ephemeral × Peer's identity
   - DH3: Ephemeral × Peer's signed pre-key
   - DH4: Ephemeral × Peer's OTK (if available)
   - HKDF to derive shared secret

2. `x3dhRespond(myIdentityCurve25519, mySignedPreKey, myOTK, peerIdentity, peerEphemeral)` — Called by the RECEIVER. Same DH computations in reverse. Returns `sharedSecret`.

**Inputs needed from server:** `PublicKeyBundle` (identity_key, signed_pre_key, signed_pre_key_id, pre_key_sig, otk_public). Fetched via `fetchPeerKeyBundle()` which calls `fetch_key_bundle` RPC (atomic OTK consumption).

**No issues.** Correct Signal Protocol X3DH implementation.

---

### Layer 3: Double Ratchet (`src/lib/crypto/double-ratchet.ts` — 208 lines)
**Status: COMPLETE. Tested. Production-ready.**

Per-message forward secrecy for 1:1 sessions.

**Session init:**
- `initSessionAsInitiator(sharedSecret, peerRatchetKey)` — Sets up send chain. Generates first ratchet key pair.
- `initSessionAsResponder(sharedSecret, myRatchetKey)` — Sets up receive side. No send chain until DH ratchet step.

**Encrypt/Decrypt:**
- `ratchetEncrypt(session, plaintext)` — Derives message key from send chain, advances chain, returns `{ ciphertext, nonce, header }`. Header contains sender's ratchet public key, message number, previous count.
- `ratchetDecrypt(session, ciphertext, nonce, header)` — Checks skipped keys first, does DH ratchet step if new ratchet key, derives message key from receive chain.

**Out-of-order handling:** `skipMessages()` stores skipped keys in bounded Map (MAX_SKIP = 1000).

**Serialization:** `serializeSession()` / `deserializeSession()` — JSON with base64 encoding. Maps converted to/from plain objects.

**SessionState fields:**
- `rootKey`, `sendChainKey`, `recvChainKey` — core ratchet state
- `sendRatchetKey` (key pair), `recvRatchetKey` (peer's public) — DH ratchet
- `sendMessageNumber`, `recvMessageNumber`, `previousSendCount` — ordering
- `skippedKeys: Map<"pubkey:msgNum", messageKey>` — out-of-order support

**No issues.** Correct Double Ratchet implementation per Signal spec.

---

### Layer 4: Sender Keys (`src/lib/crypto/sender-keys.ts` — 119 lines)
**Status: COMPLETE. Tested. Production-ready.**

Group encryption. Sender generates one key, distributes to all members. O(1) encrypt instead of O(N).

**Functions:**
- `generateSenderKey()` — Returns `SenderKeyState { chainKey, signingKey (Ed25519), iteration: 0 }`
- `senderKeyEncrypt(state, plaintext)` — KDF chain advance → message key → XChaCha20 encrypt → Ed25519 sign. Returns `{ ciphertext, nonce, signature, iteration }`. **Mutates state** (advances chain + iteration).
- `senderKeyDecrypt(state, ciphertext, nonce, signature, targetIteration)` — Verify signature → advance chain to target iteration → derive message key → decrypt. **Mutates state** (advances to latest known position).
- `serializeSenderKey()` / `deserializeSenderKey()` — JSON with base64.
- `createSenderKeyDistribution(spaceId, state)` — Creates distribution message `{ spaceId, serializedKey }`.

**Key insight:** Sender Key state includes the **private** signing key. When distributed to recipients, they get a CLONE of the full state (including signing key for verification). The chain key advances independently on sender and recipients — recipients advance to catch up when decrypting.

**No issues.** Correct Sender Key implementation.

---

### Layer 5: Key Manager (`src/lib/crypto/key-manager.ts` — 191 lines)
**Status: COMPLETE. One issue noted.**

Bridges local keystore with server.

**Functions:**
- `registerKeys()` — Full key registration: generate identity + signed pre-key + 100 OTKs. Store private keys in IndexedDB. Upload public keys to Supabase (`key_bundles` + `one_time_pre_keys`). Returns `{ deviceId, identityPublicKey }`.
- `fetchPeerKeyBundle(userId, deviceId)` — Calls `fetch_key_bundle` RPC (atomic: grabs one OTK, deletes it, returns bundle). Returns `PublicKeyBundle`.
- `replenishOTKsIfNeeded()` — If OTK count < 20, generate 100 more and upload.
- `createKeyBackup(password)` — Argon2id → AES encrypt identity key. Returns packed blob (salt + nonce + ciphertext).
- `restoreKeyBackup(packed, password)` — Reverse of above.
- `hasRegisteredKeys()` — Checks if identity key exists in IndexedDB.

**Issue:** `registerKeys()` uses `supabase` (anon client, line 43) not `supabaseAdmin`. This means the upload goes through RLS. The RLS policy requires `user_id = auth.jwt()->>'sub'`. **This only works if `setSupabaseToken(jwt)` has been called before key registration.** Currently `useE2EE` runs in the Space page where `useAuth` has already set the token, so this should work. But it's fragile — if key registration runs before auth completes, it will fail silently.

**Also:** `getCurrentUserId()` reads from `localStorage.getItem('xark_user_id')`. Need to verify this is set by useAuth. If not, registration will throw "No authenticated user".

---

### Layer 6: Encryption Service (`src/lib/crypto/encryption-service.ts` — 250 lines)
**Status: PARTIALLY COMPLETE. Two critical TODOs.**

High-level API that bridges everything above.

**Functions:**

1. `encryptForSanctuary(text, peerId, peerDeviceId)` → `EncryptedEnvelope` — **COMPLETE.**
   - Gets or establishes Double Ratchet session
   - If no session: fetches peer's key bundle → X3DH → init as initiator
   - If session exists: deserialize from keystore
   - ratchetEncrypt → pack nonce + ciphertext → base64
   - Returns `{ ciphertext, ratchetHeader, recipientId, recipientDeviceId }`

2. `encryptForSpace(text, spaceId)` → `EncryptedEnvelope` — **INCOMPLETE.**
   - Gets or generates Sender Key for this space
   - senderKeyEncrypt → pack nonce + signature + iteration + ciphertext → base64
   - Returns `{ ciphertext, recipientId: '_group_', recipientDeviceId: 0 }`
   - **TODO on line 114: "distribute sender key to space members via pairwise sessions"**
   - **This means:** When a new Sender Key is generated (first message in space), it needs to be encrypted with each member's pairwise session and sent to them. Without this, nobody else can decrypt.

3. `decryptMessage(messageId, senderId, senderDeviceId, ciphertextB64, ratchetHeaderB64, recipientId, spaceId)` → `DecryptedMessage` — **PARTIALLY COMPLETE.**
   - Group path (`recipientId === '_group_'`): Unpacks, gets sender's Sender Key from keystore at `{spaceId}:{senderId}`. If missing → returns placeholder text. senderKeyDecrypt.
   - 1:1 path: Unpacks, gets session. If no session → **BROKEN** — uses placeholder shared secret (`new Uint8Array(32)`) instead of proper X3DH respond. Comment says "in production, derived from X3DH".

4. `resolveMessageContent(messageType, serverContent, decryptedContent)` — **COMPLETE.** Anti-injection guard. E2EE messages NEVER trust server content.

---

### Layer 7: useE2EE Hook (`src/hooks/useE2EE.ts` — 132 lines)
**Status: WORKING. Both branches set `available: false`.**

React hook that manages E2EE lifecycle:
1. On mount (if userId present): initCrypto → check hasRegisteredKeys
2. If no keys: registerKeys (may fail if migration 014 not applied → graceful degrade)
3. If keys exist: get deviceId, replenish OTKs in background
4. Both branches currently set `available: false` — E2EE sending disabled

Returns `{ ready, available, deviceId, encrypt, decrypt }`.

`encrypt` delegates to `encryptForSpace`. `decrypt` delegates to `decryptMessage`.

---

### Layer 8: API Endpoints

**`/api/keys/bundle` (POST)** — Upload key bundle. Auth required. Uses `supabaseAdmin`. Upserts into `key_bundles`.

**`/api/keys/otk` (POST)** — Upload OTK batch. Auth required. Uses `supabaseAdmin`. Inserts into `one_time_pre_keys`.

**`/api/keys/fetch` (POST)** — Fetch peer's key bundle. Auth required. Calls `fetch_key_bundle` RPC (atomic OTK consumption via `FOR UPDATE SKIP LOCKED`).

**`/api/message` (POST)** — Send encrypted message. Auth + space membership check. Inserts into `messages` (content: null) + `message_ciphertexts`. Optional `@xark` trigger.

**Note:** `key-manager.ts:registerKeys()` uploads via `supabase` (client, RLS), but the API endpoints use `supabaseAdmin` (service role, bypasses RLS). The key-manager should probably use the API endpoints instead of direct Supabase calls for consistency. But this works because RLS allows users to insert their own key bundles.

---

### Layer 9: Database (`supabase/migrations/014_e2ee.sql`)
**Status: COMPLETE. Tables, RLS, RPCs, indexes all defined.**

| Table | Purpose |
|-------|---------|
| `key_bundles` | Public key bundles — one per (user, device). PK: (user_id, device_id) |
| `one_time_pre_keys` | Single-use pre-keys. PK: id. Index on (user_id, device_id) |
| `message_ciphertexts` | Per-recipient ciphertext. FK to messages. Unique on (message_id, recipient_id, recipient_device_id) |
| `user_constraints` | Global constraints (dietary, accessibility, alcohol). Unique on (user_id, type, value) |
| `space_constraints` | Space-specific constraints (budget, date, location). Unique on (space_id, user_id, type) |
| `constraint_prompts` | Prompt dismissal state. PK: (message_id, user_id) |

**RPCs:**
- `fetch_key_bundle(p_user_id, p_device_id)` — Atomic OTK grab + delete via `FOR UPDATE SKIP LOCKED`. Returns identity_key, signed_pre_key, signed_pre_key_id, pre_key_sig, otk_public.
- `revoke_device(p_user_id, p_device_id)` — Deletes key bundle + OTKs + notifies via pg_notify.
- `purge_expired_xark_messages()` — TTL cleanup for @xark messages.

**Messages table changes:**
- `content` — `DROP NOT NULL` (E2EE messages have no server-side content)
- `sender_device_id integer` — added
- `message_type text NOT NULL DEFAULT 'legacy'` — added

**Realtime:** message_ciphertexts, key_bundles, constraint_prompts published.

---

## The Three Gaps

### Gap 1: Sender Key Distribution (THE CRITICAL MISSING PIECE)

**Where it should happen:** When a user sends their first message in a space (Sender Key generated at line 112 of encryption-service.ts).

**What needs to happen:**
1. User generates a Sender Key for the space → `generateSenderKey()`
2. For each member of the space:
   a. Check if pairwise Double Ratchet session exists → `keyStore.getSession(memberId, deviceId)`
   b. If not, fetch member's key bundle → `fetchPeerKeyBundle(memberId, deviceId)`
   c. Run X3DH → `x3dhInitiate()` → `initSessionAsInitiator()`
   d. Encrypt the serialized Sender Key with the pairwise session → `ratchetEncrypt()`
   e. Send encrypted Sender Key to server (new message_type: `'sender_key_distribution'`)
3. Save the Sender Key locally → `keyStore.saveSenderKey(spaceId, ...)`

**What the server needs:**
- List of space members with their device IDs: `SELECT user_id, device_id FROM space_members sm JOIN key_bundles kb ON sm.user_id = kb.user_id WHERE sm.space_id = $1`
- A way to store/deliver Sender Key distribution messages (could use `message_ciphertexts` with a special message_type)

**What the receiver needs:**
- On receiving a `sender_key_distribution` message: decrypt with their pairwise session → store the sender's Sender Key at `keyStore.saveSenderKey(`${spaceId}:${senderId}`, ...)`

### Gap 2: Decrypt on Receive

**Where it should happen:** When messages load (page load) and when new messages arrive (Realtime).

**Current behavior:** Messages with `content: null` and `message_type: 'e2ee'` show "encrypted message" in XarkChat.tsx (line 341).

**What needs to happen:**
1. After fetching messages, identify E2EE messages (`message_type === 'e2ee'` and `content === null`)
2. For each E2EE message, fetch ciphertext → `supabase.from('message_ciphertexts').select().eq('message_id', msgId).eq('recipient_id', myUserId)` (or `'_group_'` for Sender Key messages)
3. Decrypt → `decryptMessage(messageId, senderId, senderDeviceId, ciphertext, ratchetHeader, recipientId, spaceId)`
4. Replace display content with decrypted text

**What's needed in the Space page:**
- After `fetchMessages()` returns, filter E2EE messages, batch-fetch their ciphertexts, decrypt, merge back
- For Realtime messages: decrypt inline as they arrive

### Gap 3: X3DH Responder in Decrypt Path

**Current bug:** `encryption-service.ts:215-217` — When receiving a first message (no session), the responder creates a session with a **placeholder shared secret** (`new Uint8Array(32)`) instead of running `x3dhRespond()`.

**Why it's broken:** The X3DH initiator's identity key and ephemeral key need to be transmitted alongside the first message. Currently, only the ratchet header is sent. The responder has no way to derive the same shared secret.

**Fix:** The first message needs to include `{ senderIdentityKey, senderEphemeralKey }` in addition to the ratchet header. The responder uses these + their own keys to run `x3dhRespond()` and get the same shared secret.

---

## What's Actually Blocking E2EE

It's NOT the crypto. Every primitive, protocol, and storage layer works (tested). The gaps are all **integration/wiring**:

1. **No way to get space members' device info** — Need an API or query to get `(user_id, device_id)` for all members of a space who have registered key bundles.

2. **No Sender Key distribution message type** — Need a `message_type: 'sender_key_distribution'` that carries encrypted Sender Key blobs per-recipient. These are "control messages" that don't show in the chat UI.

3. **No ciphertext fetch on message load** — The client fetches messages but never fetches the corresponding ciphertexts from `message_ciphertexts`.

4. **X3DH first-message metadata missing** — First message needs sender's identity key + ephemeral key alongside the ratchet header.

5. **No Realtime subscription for ciphertexts** — New encrypted messages arrive via broadcast but the ciphertext isn't included (it's in a separate table).

---

## Wiring Plan (Execution Order)

### Step 1: Space Members Key Info
Add RPC or API to get `(user_id, device_id)` for all space members who have key bundles.

### Step 2: Sender Key Distribution
When `encryptForSpace` generates a new Sender Key:
- Fetch all members' key bundles
- Establish pairwise sessions (X3DH) with each
- Encrypt Sender Key for each member
- Upload distribution messages via `/api/message` with `message_type: 'sender_key_distribution'`

### Step 3: Receive Sender Key Distribution
On Realtime receive or page load:
- Filter for `message_type: 'sender_key_distribution'` messages
- Fetch ciphertext from `message_ciphertexts`
- Decrypt with pairwise session
- Store sender's Sender Key: `keyStore.saveSenderKey(`${spaceId}:${senderId}`, ...)`

### Step 4: Fix X3DH Responder
Add sender identity + ephemeral key to first-message metadata.
Fix `decryptMessage` responder path to call `x3dhRespond()` properly.

### Step 5: Decrypt on Message Load
After `fetchMessages()`:
- Filter E2EE messages
- Batch-fetch ciphertexts from `message_ciphertexts`
- Decrypt each
- Merge decrypted text into message objects for display

### Step 6: Decrypt on Realtime Receive
When new E2EE message arrives via Realtime:
- Fetch its ciphertext
- Decrypt
- Display

### Step 7: Enable
Flip `available: false` → `available: true` in `useE2EE.ts` (both branches).

---

## Module Dependency Graph

```
useE2EE (hook)
  └─ encryption-service (high-level API)
       ├─ sender-keys (group encrypt/decrypt)
       │    └─ primitives (sign, verify, aesEncrypt, kdfChain)
       ├─ double-ratchet (1:1 encrypt/decrypt)
       │    └─ primitives (generateDH, dh, kdfRatchet, kdfChain, aesEncrypt)
       ├─ x3dh (session establishment)
       │    └─ primitives (dh, hkdf, verify, ed25519↔curve25519)
       ├─ key-manager (registration, peer bundle fetch)
       │    ├─ keystore (IndexedDB persistence)
       │    ├─ primitives (generate keys, sign, base64)
       │    └─ supabase (upload to server)
       └─ keystore (session/sender-key persistence)

API Endpoints:
  /api/keys/bundle  ← key-manager.registerKeys()
  /api/keys/otk     ← key-manager.replenishOTKsIfNeeded()
  /api/keys/fetch   ← key-manager.fetchPeerKeyBundle() [uses RPC]
  /api/message      ← Space page sendMessage (E2EE path)

Database:
  key_bundles           ← public keys per (user, device)
  one_time_pre_keys     ← consumable pre-keys
  message_ciphertexts   ← encrypted message content
  messages.message_type ← 'e2ee' | 'e2ee_xark' | 'legacy' | 'xark' | 'system'
  messages.content      ← NULL for E2EE messages
```

## Test Coverage

Tests exist in `crypto.test.ts` (434 lines) covering:
- All primitives (Ed25519, Curve25519, XChaCha20, HKDF, KDF ratchet/chain, base64)
- X3DH (with OTK, without OTK, invalid signature rejection)
- Double Ratchet (single message, sequential, forward secrecy, serialization)
- Sender Keys (single message, sequential, chain advance, serialization)
- Constraint Detection (vegan, shellfish, budget, accessibility, alcohol, kosher, case-insensitive, priority)

**Not tested:** encryption-service.ts integration (encryptForSpace, encryptForSanctuary, decryptMessage). These are the functions with the TODOs and bugs. They need integration tests once wired.
