# Codebase Context — E2EE Migration Reference

**Generated:** 2026-03-25
**Source:** ~/xark9/ (React/Next.js 16, TypeScript, libsodium-wrappers-sumo)
**Flutter target:** ~/fe2ee/
**Discovery agent findings:** Read this file completely before writing any Dart code.

---

## 1. Crypto Implementation (Source of Truth)

### 1.1 Libraries in Use
| Library | Version | Purpose | Flutter equivalent |
|---------|---------|---------|-------------------|
| libsodium-wrappers-sumo | WASM bundle | All crypto primitives (XChaCha20, Ed25519, Curve25519, HKDF, Argon2id) | `cryptography` package (pure Dart) |
| Web Crypto API (native) | Browser built-in | AES-256-GCM file encryption, non-extractable Ed25519 CryptoKeys | `cryptography` package |

### 1.2 X3DH Key Agreement
- **Curve used:** Curve25519 (via Ed25519 birational mapping: `ed25519PkToCurve25519`, `ed25519SkToCurve25519`)
- **Info string:** `'XarkE2EE-x3dh'`
- **Salt:** 32 zero bytes (`new Uint8Array(32)`)
- **Output:** 32 bytes shared secret
- **Initiator steps (exact order):**
  1. Verify peer's signed pre-key signature (Ed25519 verify)
  2. Convert peer's Ed25519 identity key to Curve25519
  3. Generate ephemeral Curve25519 key pair
  4. DH1: `crypto_scalarmult(myIdentityPrivate, peerSignedPreKey)`
  5. DH2: `crypto_scalarmult(ephemeralPrivate, peerIdentityCurve25519)`
  6. DH3: `crypto_scalarmult(ephemeralPrivate, peerSignedPreKey)`
  7. DH4 (if OTK available): `crypto_scalarmult(ephemeralPrivate, peerOneTimePreKey)`
  8. IKM = concat(DH1, DH2, DH3 [, DH4])
  9. `sharedSecret = HKDF(ikm, salt=zeros(32), info='XarkE2EE-x3dh', len=32)`
- **Responder steps:** Mirror — same DH operations with swapped roles, produces identical shared secret
- **Wire format:** Initiator sends `{ identityKey (base64 Ed25519 pub), ephemeralKey (base64 Curve25519 pub), otkId (string) }` in ratchet header envelope
- **Deviations from Signal spec:** Uses `'XarkE2EE-x3dh'` instead of Signal's standard info string. Zero-byte salt instead of Signal's FF-padded input.

### 1.3 Double Ratchet
- **State fields (exact):**
  ```
  rootKey: Uint8Array (32 bytes)
  sendChainKey: Uint8Array | null
  recvChainKey: Uint8Array | null
  sendRatchetKey: { publicKey, privateKey } | null  (Curve25519)
  recvRatchetKey: Uint8Array | null                 (peer's Curve25519 pub)
  sendMessageNumber: number
  recvMessageNumber: number
  previousSendCount: number
  skippedKeys: Map<string, Uint8Array>              (key format: "base64(pubKey):msgNum")
  headerSecret: Uint8Array (32 bytes)               (derived once from shared secret)
  ```
- **Ratchet KDF:** `HKDF(ikm=dhOutput, salt=rootKey, info='XarkE2EE-ratchet', len=64)` → first 32 = newRootKey, last 32 = chainKey
- **Chain KDF:** `HMAC-SHA256(chainKey, [0x01])` → messageKey; `HMAC-SHA256(chainKey, [0x02])` → nextChainKey
- **Header secret:** `HKDF(sharedSecret, zeros(32), 'XarkE2EE-header-secret', 32)` — computed once at session init
- **Header key:** `HKDF(headerSecret, zeros(32), 'XarkE2EE-header-key', 32)` — derived for each encrypt/decrypt
- **Header format:** JSON `{ publicKey (base64), previousCount, messageNumber }` → encrypted with XChaCha20-Poly1305 using header key → packed as `nonce(24) + headerCiphertext`
- **Message cipher:** XChaCha20-Poly1305 AEAD (24-byte nonce, random per message)
- **Max skipped keys:** 1000 (FIFO eviction)
- **Serialization:** JSON with base64-encoded byte arrays, Map serialized as object
- **Deviations from Signal spec:** Header encryption (Signal spec sends headers in cleartext). Custom info strings. XChaCha20-Poly1305 instead of AES-256-CBC.

### 1.4 Group Messaging
- **Mechanism:** Sender Keys (Signal-style, not MLS)
- **State fields:**
  ```
  chainKey: Uint8Array (32 bytes)
  signingKey: { publicKey, privateKey }  (Ed25519)
  iteration: number                      (1-indexed, post-increment)
  createdAt?: number                     (timestamp ms)
  ```
- **Distribution flow:** Serialized Sender Key (chainKey + signing public, NO private) encrypted via pairwise Double Ratchet to each member device. Piggybacked atomically on message POST.
- **Wire format (group message):** `nonce(24) + signature(64) + iteration(4 bytes big-endian) + ciphertext`
- **Encrypt:** chain advance via kdfChain → XChaCha20-Poly1305 encrypt → Ed25519 sign over `ciphertext || nonce`
- **Decrypt:** verify Ed25519 signature first → advance chain to target iteration (caching skipped keys) → decrypt
- **SK Recovery:** On missing Sender Key, broadcasts `sk_request` via Supabase Realtime channel. Peers verify membership + key bundle before re-distributing. 10s timeout.
- **Tombstone rotation:** On member leave, remaining members check `space_tombstones` table and regenerate Sender Key if tombstone is newer than current key.

### 1.5 Media Encryption
- **Algorithm:** AES-256-GCM via Web Crypto API (NOT libsodium)
- **Key generation:** `crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, true, ['encrypt', 'decrypt'])`
- **IV:** 12 bytes random (`crypto.getRandomValues`)
- **Key transport:** `{ aesKeyBase64, ivBase64, mimeType }` fields inside the E2EE message payload (travels through Double Ratchet or Sender Key)
- **Thumbnail handling:** `inlineThumbnail` field — base64 JPEG thumbnail embedded directly in the E2EE message payload (not separately encrypted/uploaded)
- **No SHA-256 hash verification** in current React impl — Flutter should add this

### 1.6 Local Key Storage
- **Mechanism:** IndexedDB (`xark-keystore`, version 4)
- **Object stores:** identity, signed-pre-keys, one-time-pre-keys, sender-keys, sessions, meta, unacked-ratchet, decrypted-messages, processed-distributions, local-contacts
- **Encryption at rest:** XChaCha20-Poly1305 with Argon2id-derived key (3 iterations, 64MB, from user PIN). Format: `"enc:" + base64(nonce(24) + ciphertext)` or `"plain:"` prefix for unencrypted fallback
- **Key derivation for storage:** Argon2id(pin, salt from localStorage, 3 iters, 64MB)

### 1.7 Known Crypto Issues or TODOs
- No SHA-256 hash verification on media download (should be added in Flutter)
- Thumbnails are inline base64, not separately encrypted/uploaded (CLAUDE.md spec says separate pipeline — Flutter should follow spec)
- WebCrypto non-extractable keys don't port to Flutter — use `cryptography` package equivalent
- SK recovery uses Supabase Realtime broadcast — Flutter equivalent needs WebSocket channel
- Two-phase ratchet commit survives tab close via IndexedDB — Flutter needs equivalent in SQLCipher

---

## 2. Backend Contract (Verified from Code)

### 2.1 Server Configuration
- **Base URL:** Supabase project URL (from `NEXT_PUBLIC_SUPABASE_URL` env var)
- **REST:** Supabase PostgREST (auto-generated from Postgres schema)
- **WebSocket:** Supabase Realtime (`wss://{project}.supabase.co/realtime/v1/websocket`)
- **Auth mechanism:** JWT Bearer token in Authorization header
- **Token format:** JWT signed with Supabase JWT secret. Claims: `sub` = user_id (text, not UUID)
- **RLS enforcement:** All tables use `auth.jwt()->>'sub'` (not `auth.uid()`)

### 2.2 REST Endpoints
| Method | Path | Auth | Request Body | Response | Notes |
|--------|------|------|-------------|----------|-------|
| POST | /api/keys/bundle | JWT | `{ device_id, identity_key, signed_pre_key, signed_pre_key_id, pre_key_sig }` | `{ ok: true }` | Upsert to key_bundles |
| POST | /api/keys/otk | JWT | `{ device_id, keys: [{ id, public_key }] }` max 200 | `{ ok: true, count }` | Batch upsert |
| POST | /api/keys/fetch | JWT | `{ user_id, device_id }` | `{ identity_key, signed_pre_key, signed_pre_key_id, pre_key_sig, otk_public?, otk_id? }` | Atomic OTK consume via FOR UPDATE SKIP LOCKED |
| POST | /api/message | JWT | See 2.5 | `{ messageId, distribution_written }` | Atomic message + ciphertexts + SK distribution |
| POST | /api/chat/start | JWT | `{ peer_id }` | `{ space_id }` | Find-or-create 1:1 chat |
| POST | /api/contacts/check | JWT | `{ phones: string[] }` max 500 | `{ registered: [{ phone, userId }] }` | Phone lookup |
| POST | /api/phone-auth | — | Firebase OTP token | `{ token (JWT), userId }` | Firebase → Supabase JWT |
| POST | /api/notify | JWT | `{ space_id, title, body }` | `{ ok }` | FCM push to space members |

### 2.3 WebSocket Protocol
- **Connection:** Supabase Realtime client (`@supabase/supabase-js`)
- **Channel format:** `chat:{spaceId}` for messages, `sk-recovery:{spaceId}` for SK requests
- **Message delivery:** NOT via WebSocket frames — messages are POSTed to /api/message, then Supabase Realtime's Postgres NOTIFY delivers to subscribers
- **Frame format:** Supabase Realtime protocol (JSON-based, not custom binary)
- **ACK mechanism:** HTTP 200 from /api/message POST = ACK. Client calls `commit()` to persist ratchet state.
- **Heartbeat:** Handled by Supabase Realtime client internally
- **Reconnection:** Handled by Supabase Realtime client (exponential backoff built-in)

### 2.4 PreKey Protocol
- **Registration:** POST /api/keys/bundle (identity + SPK + signature) + POST /api/keys/otk (100 keys)
- **Fetch:** POST /api/keys/fetch → Supabase RPC `fetch_key_bundle` with `FOR UPDATE SKIP LOCKED` (atomic OTK consume)
- **OTK format:** `{ id: string, public_key: base64(Curve25519 pub) }`
- **Replenishment:** When server count < 20, generate 100 new OTKs, POST /api/keys/otk

### 2.5 Message Envelope (Wire Format)
```json
{
  "space_id": "string",
  "sender_device_id": 1,
  "ciphertext": "base64(nonce(24) + ciphertext)",
  "ratchet_header": "base64(JSON envelope with encrypted header + optional x3dh metadata)",
  "recipient_id": "userId or '_group_'",
  "recipient_device_id": 0,
  "distribution_ciphertexts": [
    {
      "id": "mc_uuid",
      "recipient_id": "userId",
      "recipient_device_id": 1,
      "ciphertext": "base64(nonce(24) + ciphertext)",
      "ratchet_header": "base64(JSON envelope)"
    }
  ],
  "message_type": "e2ee",
  "id": "optional client-generated UUID"
}
```

### 2.6 Error Response Format
```json
{ "error": "string description" }
```
HTTP status codes: 400 (validation), 401 (auth), 403 (RLS), 429 (rate limit), 500 (server)

---

## 3. Data Models (Exact Field Names)

### 3.1 Message (Postgres: messages table)
```
id: text PK (UUID, client-generated or server-generated)
space_id: text NOT NULL
user_id: text NOT NULL (from JWT sub)
sender_device_id: integer (nullable)
message_type: text ('e2ee' | 'xark' | 'system' | 'legacy' | 'sender_key_dist')
role: text ('user' | 'assistant')
content: text NULL (always null for E2EE — server never sees plaintext)
sender_name: text NULL
created_at: timestamptz
```

### 3.2 Message Ciphertext (Postgres: message_ciphertexts table)
```
id: text PK ('mc_' + UUID)
message_id: text FK → messages
recipient_id: text ('_group_' for group, userId for 1:1)
recipient_device_id: integer (0 for group)
ciphertext: text (base64)
ratchet_header: text (base64 JSON envelope, nullable)
```

### 3.3 Key Bundle (Postgres: key_bundles table)
```
user_id: text
device_id: integer
identity_key: text (base64 Ed25519 public)
signed_pre_key: text (base64 Curve25519 public)
signed_pre_key_id: integer
pre_key_sig: text (base64 Ed25519 signature)
updated_at: timestamptz
PK: (user_id, device_id)
```

### 3.4 One-Time Pre-Key (Postgres: one_time_pre_keys table)
```
id: text PK
user_id: text
device_id: integer
public_key: text (base64 Curve25519 public)
```

### 3.5 DecryptedMessage (Client-side only, never on server)
```typescript
{
  text: string;
  replyTo: string | null;
  mediaUrl: string | null;          // Firebase Storage URL of encrypted blob
  type: 'message' | 'media';
  aesKeyBase64?: string;            // AES-256-GCM key (media only)
  ivBase64?: string;                // AES-GCM IV (media only)
  mimeType?: string;
  inlineThumbnail?: string;         // base64 JPEG (inline, not separate upload)
  linkPreview?: {
    url, title?, description?,
    mediaUrl?, aesKeyBase64?, ivBase64?, mimeType?, inlineThumbnail?
  }
}
```

---

## 4. Send Pipeline (Exact Flow)

### 4.1 Send Text (1:1 Sanctuary)
```
Step 1: User types message in ChatInput
Step 2: encryptForSanctuary(text, peerId, peerDeviceId) called with mutex lock
Step 3: Build DecryptedMessage JSON payload
Step 4: Get/establish Double Ratchet session (X3DH if first message)
Step 5: ratchetEncrypt(session, payload) → ciphertext + nonce + encrypted header
Step 6: TWO-PHASE: Save unacked ratchet state to IndexedDB BEFORE network call
Step 7: Pack: nonce(24) + ciphertext → base64
Step 8: POST /api/message { space_id, ciphertext, ratchet_header, recipient_id, recipient_device_id }
Step 9: On 200 OK: call commit() → persist session to main store, delete unacked entry
```

### 4.2 Send Text (Group Space)
```
Step 1: User types message
Step 2: encryptForSpace(text, spaceId) called with mutex lock
Step 3: Get/generate Sender Key (check tombstones for rotation)
Step 4: prepareSenderKeyDistribution() → encrypt SK via pairwise ratchet for each member device
Step 5: senderKeyEncrypt(senderKey, payload) → ciphertext + nonce + signature + iteration
Step 6: Eagerly persist advanced Sender Key state
Step 7: Pack: nonce(24) + signature(64) + iteration(4) + ciphertext → base64
Step 8: POST /api/message { space_id, ciphertext, recipient_id='_group_', distribution_ciphertexts }
Step 9: On 200 OK: call commit()
```

### 4.3 Receive Message
```
Step 1: Supabase Realtime delivers new row notification
Step 2: Client fetches message_ciphertexts for new message
Step 3: decryptMessage() called with mutex lock
Step 4: Check plaintext cache (idempotency guard)
Step 5A (group): Unpack nonce(24) + sig(64) + iter(4) + ct. Get Sender Key (SK recovery if missing). Decrypt.
Step 5B (1:1): Unpack nonce(24) + ct. Parse header envelope. Get/establish session (X3DH responder if first). Decrypt.
Step 6: Parse JSON → DecryptedMessage. Validate fields.
Step 7: Cache plaintext in IndexedDB (encrypted at rest)
Step 8: Return to UI for display
```

### 4.4 Key Exchange (First Contact)
```
Step 1: Alice wants to message Bob for the first time
Step 2: POST /api/keys/fetch { user_id: bob, device_id: 1 } → gets Bob's PreKey bundle
Step 3: x3dhInitiate(aliceIdentity, bobBundle) → sharedSecret + ephemeralKey
Step 4: initSessionAsInitiator(sharedSecret, bobBundle.signedPreKey) → Double Ratchet session
Step 5: ratchetEncrypt(session, plaintext) → first encrypted message
Step 6: X3DH metadata (identityKey, ephemeralKey, otkId) included in ratchet header envelope
Step 7: Bob receives → parses X3DH metadata → x3dhRespond() → initSessionAsResponder() → decrypt
```

---

## 5. Gap Analysis

### 5.1 Spec vs Reality
| CLAUDE.md Section | React Status | Match? | Flutter Agent Guidance |
|-------------------|--------------|--------|----------------------|
| Signal Protocol (X3DH) | Fully implemented | ⚠️ Custom info strings | Use React's `'XarkE2EE-x3dh'` info string, not Signal's standard |
| Double Ratchet | Fully implemented | ⚠️ Header encryption + custom KDF strings | Use React's `'XarkE2EE-ratchet'`, `'XarkE2EE-header-secret'`, `'XarkE2EE-header-key'` |
| Sender Keys | Fully implemented | ✅ | Match React's wire format: `nonce(24)+sig(64)+iter(4)+ct` |
| Media pipeline | Implemented differently | ⚠️ AES-GCM not XChaCha20, no SHA-256 verify, inline thumbnails | Follow CLAUDE.md spec (add SHA-256 hash), but match React's AES-256-GCM for media |
| Multi-device | NOT implemented | ❌ | React is single-device only. Flutter deferred to Phase 2. |
| Push notifications | Basic FCM only | ⚠️ No background decrypt | React uses basic FCM. Flutter CLAUDE.md specifies native decrypt extensions — Phase 2 |
| Contact discovery | Phone lookup only | ⚠️ Not hashed | React sends raw phone numbers. CLAUDE.md specifies hashed. Deferred to Phase 2. |
| Profile encryption | NOT implemented | ❌ | Not in React. Flutter deferred to Phase 2. |
| Offline outbox | Implemented (IndexedDB) | ✅ | Match React's outbox pattern — persist before send, delete on ACK |
| Two-phase ratchet commit | Implemented | ✅ | Critical — must port this pattern to SQLCipher |
| Plaintext cache | Implemented | ✅ | Prevents double-decrypt. Port to SQLCipher. |
| SK recovery (P2P) | Implemented | ✅ | Use Supabase Realtime broadcast for recovery requests |
| Tombstone rotation | Implemented | ✅ | Check `space_tombstones` table for key freshness |

### 5.2 React Deviations the Flutter Agents Must Respect
1. **Custom HKDF info strings** — React uses `'XarkE2EE-x3dh'`, `'XarkE2EE-ratchet'`, `'XarkE2EE-header-secret'`, `'XarkE2EE-header-key'`. Flutter MUST use identical strings or sessions won't interoperate.
2. **Header encryption** — React encrypts ratchet headers (Signal spec sends them in cleartext). Flutter must do the same.
3. **XChaCha20-Poly1305** for messages (not AES-256-CBC like Signal). Flutter must use XChaCha20 for interop.
4. **AES-256-GCM** for file encryption (different cipher than messages). Two different ciphers in use.
5. **Chain KDF** uses `[0x01]` and `[0x02]` as HMAC inputs (matches Signal spec).
6. **Inline thumbnails** — base64 JPEG inside the E2EE payload, not separately uploaded.
7. **Messages routed via HTTP POST** to /api/message, NOT via WebSocket frames. Realtime only delivers notifications.
8. **User IDs are text** (format: `name_ram`), not UUIDs. RLS uses `auth.jwt()->>'sub'`.

### 5.3 React Features Not in the Spec
- **Link preview encryption** — OG metadata encrypted inside E2EE payload with separate AES keys
- **Plaintext cache** — decrypted messages cached in IndexedDB for instant re-display
- **Two-phase ratchet commit** — unacked state survives crashes
- **SK recovery via P2P broadcast** — peers re-distribute Sender Keys on request
- **Tombstone-based SK rotation** — lazy rotation after member leave
- **JWT gatekeeper** — SK distribution fails loudly without auth

### 5.4 Spec Features Not in React
- **Multi-device architecture** — React is single-device
- **SHA-256 media hash verification** — React doesn't verify
- **Separate thumbnail encryption/upload** — React uses inline base64
- **Hashed contact discovery** — React sends raw phone numbers
- **Profile metadata encryption** — not implemented
- **Push notification background decrypt** — not implemented
- **Device linking protocol** — not implemented

---

## 6. Flutter Agent Directives

### For Agent 02 (Domain Models)
- `Message.id` is a string UUID, client-generated
- `MessageType` enum: `e2ee`, `xark`, `system`, `legacy`, `sender_key_dist`
- `DecryptedMessage` fields must match React exactly: `text, replyTo, mediaUrl, type, aesKeyBase64, ivBase64, mimeType, inlineThumbnail, linkPreview`
- User IDs are text strings (e.g., `name_ram`), not UUIDs

### For Agent 03 (Crypto Layer)
- Use `cryptography` package's X25519 and Ed25519 (NOT Ecdh.p256)
- HKDF info strings MUST be: `'XarkE2EE-x3dh'`, `'XarkE2EE-ratchet'`, `'XarkE2EE-header-secret'`, `'XarkE2EE-header-key'`
- Chain KDF: HMAC-SHA256 with inputs `[0x01]` (message key) and `[0x02]` (next chain key)
- Cipher: XChaCha20-Poly1305 for messages, AES-256-GCM for files (two different ciphers)
- Header encryption: JSON header encrypted with XChaCha20, packed as `nonce(24)+headerCiphertext`
- Max skipped keys: 1000 with FIFO eviction
- Sender Key iteration is 1-indexed (post-increment)
- Ed25519→Curve25519 birational mapping required for identity keys

### For Agent 05 (Persistence)
- Port IndexedDB stores to SQLCipher tables: sessions, sender-keys, unacked-ratchet, decrypted-messages, processed-distributions
- Session key format: `"userId:deviceId"`
- Sender Key storage key: `"active_spaceId"` or `"spaceId:senderId"` for received keys
- Implement two-phase ratchet commit: save unacked state before send, persist on ACK
- Plaintext cache: store decrypted text keyed by messageId, encrypted at rest

### For Agent 06 (Transport)
- Messages sent via HTTP POST to `/api/message`, NOT WebSocket
- Supabase Realtime delivers new message notifications (Postgres LISTEN/NOTIFY)
- PreKey fetch uses Supabase RPC `fetch_key_bundle` (atomic OTK consume with `FOR UPDATE SKIP LOCKED`)
- Auth: JWT Bearer token in Authorization header
- No custom binary WebSocket frame format — use Supabase client protocol

### For Agent 08 (Messaging)
- 1:1 pack format: `nonce(24) + ciphertext` → base64
- Group pack format: `nonce(24) + signature(64) + iteration(4 bytes big-endian) + ciphertext` → base64
- Ratchet header is a JSON envelope containing encrypted header + optional X3DH metadata
- Always distribute Sender Key with every group message (catches late joins, rotations)
- Two-phase commit is mandatory — save unacked state before network call

### For Agent 09 (Media)
- Use AES-256-GCM (NOT XChaCha20-Poly1305) for file encryption — matches React
- Key: 256-bit random, IV: 12 bytes random
- Key transport: `aesKeyBase64` and `ivBase64` fields inside the E2EE message payload
- React uses inline base64 thumbnails. CLAUDE.md says separate upload. **Follow CLAUDE.md spec** (separate keys) but also support inline thumbnails for backwards compat with React messages
- Add SHA-256 hash verification (React doesn't have this — it's an improvement)

### For Agent 11 (Integration Tests)
- Mock server should mimic Supabase RPC responses (not custom WebSocket protocol)
- Message envelope: POST body matches section 2.5 exactly
- Key fetch returns: `{ identity_key, signed_pre_key, signed_pre_key_id, pre_key_sig, otk_public?, otk_id? }`
- Test the two-phase commit: crash between encrypt and ACK, verify recovery on restart

---

## 7. Do Not Replicate

1. **IndexedDB unencrypted fallback** — React has `"plain:"` prefix fallback for unencrypted storage. Flutter should NEVER store anything unencrypted. SQLCipher handles this at the DB level.
2. **Client-side OTK deletion after fetch** — React had a bug (P1 BUG 3) where client deleted peer's OTK locally. Server handles OTK consume atomically. Flutter should NOT touch peer key state locally.
3. **Global mutable skipped Sender Key cache** — React uses a global `Map` for skipped SK message keys. Flutter should scope this per-session or persist to DB to survive app restarts.
4. **WebCrypto non-extractable keys** — Browser-specific pattern. Flutter uses `cryptography` package — all keys are extractable byte arrays stored in secure storage.
5. **Supabase Realtime for SK recovery** — Works in React because both sender and receiver are online. Flutter should also handle the case where sender is offline (queue recovery request, retry on reconnect).

---

## 8. Open Questions

1. **Cross-platform interop:** Will the Flutter engine need to decrypt messages sent by the React web app? If yes, wire formats and HKDF strings MUST match exactly. If no, Flutter can optimize independently.
2. **Supabase vs custom server:** CLAUDE.md describes a generic "untrusted relay" but React uses Supabase directly. Will Flutter use the same Supabase project, or a new backend?
3. **Firebase Storage for media:** React uploads encrypted blobs to Firebase Storage. Will Flutter use the same bucket, or a different storage backend?
4. **Device ID assignment:** React uses a single integer device_id per user. CLAUDE.md describes multi-device with device registry. How are device IDs assigned and coordinated?
5. **Sender Key tombstones:** React checks `space_tombstones` table for key rotation. Is this table and RPC available in the Flutter backend?
