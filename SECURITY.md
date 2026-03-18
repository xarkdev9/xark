# Xark OS — Security, Privacy & Encryption Architecture

> **Audience**: Law enforcement inquiries, competitor due diligence, investor technical review, security auditors, and internal engineering reference. This document describes the complete privacy and security posture of Xark OS v2.0.

**Last updated**: 2026-03-15
**Encryption status**: Production-ready, Signal Protocol implementation
**Compliance target**: GDPR, CCPA, ECPA-aligned

---

## 0. THE ABSOLUTE LAW

**E2EE is NEVER bypassed.** Not for solo spaces. Not for convenience. Not for debugging. Not for "temporary" workarounds. Not for performance. Not for any reason that has ever existed or will ever exist.

- If encryption fails → the message does not send. The user sees an error.
- If a solo space has 1 member → encrypt to self (user's own device key is the recipient).
- If a feature cannot work with E2EE → the feature does not ship.
- If an AI agent suggests bypassing E2EE → reject the suggestion immediately. This is a constitutional crisis.
- Plaintext fallback paths are forbidden in code. Legacy message types exist only for reading pre-E2EE history, never for writing new messages.
- This rule has no exceptions. No "graceful degradation." No "just for testing." No "only in dev mode."

---

## 1. Executive Summary

Xark OS is a group decision-making platform with **end-to-end encrypted (E2EE) messaging** and **Zero-Knowledge Architecture**. The server is architecturally incapable of reading user chat messages, local E2EE intents, or cloud AI interactions. We use the same cryptographic protocol as WhatsApp and Signal — the Signal Protocol — adapted for small group collaboration via Conflict-Free Replicated Data Types (CRDTs).

**What we CAN provide** (to law enforcement, regulators, or any requesting party):
- Message metadata: who sent a message, to which space, at what time
- Space membership: who is in which group
- Decision data: what items were proposed, how people voted, what was locked
- @xark AI responses: server-generated plaintext (subject to TTL auto-purge)
- Account information: phone number, display name, registration date
- Device information: device IDs, key registration timestamps

**What we CANNOT provide** (by mathematical design — not policy choice):
- Message content (chat text, shared media)
- We do not possess decryption keys. They exist only on user devices.
- A server breach, insider threat, or legal order cannot produce plaintext messages.
- This is not a policy — it is a cryptographic fact.

---

## 2. Threat Model

### What E2EE protects against:

| Threat | Protection |
|--------|-----------|
| **Server/database breach** | Attacker gets ciphertext only. Decryption keys exist only on client devices. |
| **Network eavesdropping** | Application-layer encryption on top of TLS. Even if TLS is compromised (MITM proxy, rogue CA), message content remains encrypted. |
| **Operator access** | Xark OS developers and server administrators cannot read user messages. There is no admin backdoor, master key, or key escrow. |
| **Rogue employee** | Even with full database access, no employee can read messages. |
| **Compelled server-side access** | A warrant served to Xark OS for message content will return only ciphertext. We physically cannot decrypt it. |

### What E2EE does NOT protect against:

| Threat | Explanation |
|--------|------------|
| **Compromised client device** | If an attacker has physical or remote access to a user's unlocked device, they can read decrypted messages displayed in the app. E2EE protects data in transit and at rest on the server — not on the endpoint. |
| **Legally compelled device access** | A warrant served to a *user* (not Xark OS) for their device can yield decrypted messages stored locally. This is no different from reading messages on any messaging app with an unlocked phone. |
| **User screenshots or sharing** | A recipient can always screenshot or copy message text. E2EE prevents unauthorized third-party access, not authorized recipient sharing. |
| **Side-channel attacks on JavaScript** | WebCrypto and WASM-based crypto in a browser context are subject to side-channel risks (timing, speculative execution). We mitigate with constant-time comparison functions but acknowledge browser-based crypto is inherently less hardened than native implementations. |
| **@xark invocation plaintext** | When a user explicitly types `@xark`, the command text is sent to the server for AI processing. This is a deliberate, user-initiated disclosure. The server does not persist the plaintext command beyond the API request lifetime. See Section 6. |

---

## 3. Cryptographic Architecture

### Protocol: Signal Protocol

The same protocol used by WhatsApp (2B+ users), Signal Messenger, and Facebook Messenger's encrypted mode. Proven at scale, peer-reviewed, open specification.

### Three-Layer Architecture

```
LAYER 1: KEY MANAGEMENT (Hybrid Native)
  Identity keys (stored in iOS Secure Enclave / Android Keystore)
  Server stores PUBLIC keys only — never private keys
  PWAs authenticate via cryptographic Device Linking

LAYER 2: MESSAGE ENCRYPTION (zero-knowledge)
  Signal Protocol: Double Ratchet (1:1), Sender Keys (groups)
  Lazy Rotator middleware with Cryptographic Tombstones (prevents offline ejection races)
  Server stores ciphertext only — mathematically cannot decrypt

LAYER 3: ZERO KNOWLEDGE INTELLIGENCE (CRDTs & Enclaves)
  Decision items, expenses, and states are broadcast as encrypted CRDT mutations
  @xark AI operates inside AWS Nitro TEE Enclaves
  Vercel/Supabase cannot read AI prompts or responses
```

### Cryptographic Primitives

| Primitive | Algorithm | Purpose | Library |
|-----------|-----------|---------|---------|
| Identity keys | Ed25519 | Signing, identity verification | libsodium-wrappers-sumo (WASM) |
| Key agreement | X3DH with Curve25519 | Initial session establishment | libsodium (X25519 scalar mult) |
| Session encryption | Double Ratchet | 1:1 sanctuary messages (per-message forward secrecy) | Custom implementation on libsodium |
| Group encryption | Sender Keys | Group space messages (per-sender chain forward secrecy) | Custom implementation on libsodium |
| Message encryption | XChaCha20-Poly1305 | Authenticated encryption (24-byte nonce, hardware-independent) | libsodium AEAD |
| Key derivation | HKDF-SHA-256 | Deriving encryption keys from DH outputs | libsodium HMAC-SHA-256 |
| Backup encryption | Argon2id (3 iter, 64MB) | Password-based key derivation for cloud backups | libsodium pwhash |
| Signature verification | Ed25519 | Pre-key signature verification, Sender Key message signing | libsodium crypto_sign |

### Why XChaCha20-Poly1305 over AES-256-GCM

- **Hardware-independent**: AES-GCM requires AES-NI hardware instructions for constant-time operation. Without AES-NI (common on low-end Android devices), software AES-GCM is vulnerable to cache-timing attacks. XChaCha20 is constant-time in software on all platforms.
- **192-bit nonce**: Safe for random nonce generation with no collision risk. AES-GCM's 96-bit nonce has birthday-bound collision risk at ~2^32 messages per key.
- **Equally secure**: Both provide 256-bit key security with authenticated encryption. XChaCha20-Poly1305 is the recommended AEAD cipher for new implementations (IETF RFC 8439 extension).

---

## 4. Key Management

### Per-User Key Hierarchy

```
Identity Key (Ed25519 → Curve25519 birational pair)
  ├── Long-lived, generated once at registration
  ├── Ed25519: signs pre-keys, proves identity trust chain
  ├── Curve25519: used in X3DH Diffie-Hellman key agreement
  └── Stored on device (IndexedDB) + encrypted cloud backup (Firebase Storage)

Signed Pre-Key (Curve25519, with numeric ID)
  ├── Rotated every 30 days
  ├── Signed by Identity Key (proves authenticity to peers)
  └── Uploaded to Supabase key_bundles table (public half only)

One-Time Pre-Keys (Curve25519 × 100)
  ├── Batch of 100 generated on registration
  ├── Each consumed exactly once (atomic DELETE via fetch_key_bundle RPC)
  ├── Client replenishes when count < 20
  └── Prevents replay attacks on initial key exchange
```

### Key Distribution Server (Supabase Postgres)

The server stores **only public keys**. Private keys never leave the client device.

```
key_bundles table:
  (user_id, device_id) → identity_key, signed_pre_key, pre_key_sig
  RLS: Anyone can read (public keys). Only owner can write.

one_time_pre_keys table:
  id → user_id, device_id, public_key
  Consumed atomically via fetch_key_bundle RPC (FOR UPDATE SKIP LOCKED)
  RLS: Anyone can read. Only owner can insert.
```

### Race Condition Prevention

One-time pre-keys are consumed via a Postgres RPC that uses `FOR UPDATE SKIP LOCKED`:

```sql
DELETE FROM one_time_pre_keys
WHERE id = (
  SELECT id FROM one_time_pre_keys
  WHERE user_id = p_user_id AND device_id = p_device_id
  LIMIT 1 FOR UPDATE SKIP LOCKED
) RETURNING public_key INTO v_otk_key;
```

This prevents two concurrent session initiators from consuming the same OTK — a race condition that would cause one session to fail silently.

### Device Revocation

```sql
-- SECURITY DEFINER — only callable via authenticated API route
CREATE FUNCTION revoke_device(p_user_id text, p_device_id integer)
  → Deletes key_bundles + one_time_pre_keys for device
  → Broadcasts pg_notify('device_revoked') to all clients
  → Clients drop sessions with revoked device, rotate Sender Keys
```

### Key Backup & Recovery

- **Backup**: Identity key + Sender Keys encrypted with Argon2id-derived key (3 iterations, 64MB memory — resistant to GPU brute-force). Uploaded to Firebase Storage (`backups/{userId}/keys`).
- **Recovery**: New device authenticates via Firebase Auth (same phone number) → downloads encrypted blob → user enters backup password → Argon2id derives key → AES-256-GCM decrypts → private keys restored.
- **Fresh OTKs**: After restore, 100 new one-time pre-keys are generated (old ones are consumed/destroyed).

---

## 5. Message Encryption Flows

### 1:1 Sanctuary (Double Ratchet — full forward secrecy)

```
First message (X3DH key agreement):
  1. Alice fetches Bob's key bundle (identity + signed pre-key + OTK)
  2. X3DH computes shared secret from 4 DH operations
  3. Double Ratchet session initialized from shared secret
  4. Message encrypted with first ratchet key (XChaCha20-Poly1305)
  5. OTK atomically consumed (cannot be reused)

Every subsequent message:
  → Ratchet advances → new key → forward secrecy per message
  → Compromise of one key reveals ONLY that one message
  → Old keys deleted immediately after decryption
```

### Group Space (Sender Keys — O(1) encrypt)

```
When a user joins a group:
  1. Generate Sender Key (symmetric chain key + Ed25519 signing key)
  2. Distribute to each member via pairwise E2EE sessions
  3. Server never sees Sender Keys (distributed client-to-client)

Sending a group message:
  1. Encrypt ONCE with sender's chain key (XChaCha20-Poly1305)
  2. Sign with sender's Ed25519 key (authenticity proof)
  3. Advance chain (forward secrecy within sender's chain)
  4. Store: 1 messages row + 1 ciphertext row (not N rows)

Member leave:
  → ALL remaining members rotate Sender Keys
  → Departed member's old keys cannot decrypt future messages
  → Cost: O(N²) for N≤15 — acceptable and rare
```

### Forward Secrecy Properties

| Protocol | Forward Secrecy | Scope |
|----------|----------------|-------|
| Double Ratchet (1:1) | Per-message | Compromise of one key → only that message readable |
| Sender Keys (group) | Per-sender-chain | Compromise of sender key → messages from that sender since last rotation. Mitigated by rotation on member leave. |

---

## 6. @xark AI Integration — Privacy Boundary

### The E2EE Tunnel 

@xark operates inside an isolated AWS Nitro Trusted Execution Environment (TEE). It **never** processes requests on Vercel or Supabase.

### What @xark reads (Inside the Enclave):

- Encrypted Spotlight queries specifically targeting the Enclave Identity Public Key
- Decrypted context processed purely in RAM

### What @xark NEVER reads:

- Vercel and Supabase **never see the plaintext query**
- Chat messages are not scraped or exposed to the LLM
- The TEE issues cryptographic attestations proving responses were generated securely

### @xark command disclosure

When a user types `@xark find hotels in coronado`, the command is:
- Parsed locally for basic intent (Tier 1 Router)
- If complex, encrypted natively for the Enclave's public key (Tier 2/3)
- Sent as opaque base64 ciphertext over the network
- Supabase merely persists the ciphertext log. It does not know what you asked or what the AI answered.

### @xark response TTL

Server-generated @xark responses are plaintext (the server created them). They are subject to automatic purging:
- Spaces with trip dates: purged 30 days after trip end date
- Open-ended spaces: purged after 90 days
- Purge runs daily at 3am UTC via `purge_expired_xark_messages()` Postgres cron

### PII Sanitization

Before any text is sent to the AI (Gemini 2.5 Flash), it passes through `sanitize.ts`:
- Credit card numbers (validated with Luhn algorithm) → redacted
- Social Security numbers → redacted
- CVV codes → redacted
- Bank account numbers → redacted

This is defense-in-depth: the AI should never see PII, even in the @xark command text that the user voluntarily sends.

---

## 7. On-Device Constraint Detection

This feature bridges encrypted messages (Layer 2) and structured intelligence data (Layer 3) with **explicit user consent**.

### How it works:

1. User sends a message: "I'm allergic to shellfish"
2. Message is encrypted and sent (Layer 2 — server can't read it)
3. **On the sender's device only**, the plaintext is checked against conservative allowlists
4. Match found → inline whisper appears: `"detected: no shellfish allergy. save to your profile?"`
5. User taps **save** → structured constraint written to Layer 3 (`user_constraints` table)
6. User taps **dismiss** → nothing happens, dismissal synced across sender's devices

### Privacy guarantees:

- Detection happens **only on the sender's device** — not on recipients' devices, not on the server
- **Conservative allowlists** — exact phrase matching, not open regex or NLP
- **User consent required** — detected constraints are never automatically saved
- **One prompt per message** — no alert fatigue
- The server never sees the message text that triggered the detection

### What gets detected (v1):

- Dietary: vegan, vegetarian, halal, kosher, shellfish/peanut/dairy/gluten allergies
- Budget: "budget is around $200" pattern
- Accessibility: wheelchair, mobility aid
- Alcohol: "I don't drink", "I am sober"

---

## 8. Data Architecture — What's Stored Where

### On client device (OS Enclave & IndexedDB):

| Data | Encrypted at rest | Purpose |
|------|------------------|---------|
| Identity key pair | Native Secure Enclave | Signing, key agreement |
| Signed pre-key pair | Native Secure Enclave | Session establishment |
| One-time pre-keys | Browser sandboxed | Anti-replay on key exchange |
| Double Ratchet sessions | Browser sandboxed | Per-peer encryption state |
| Sender Keys (active) | Browser sandboxed | Group encryption state |
| Memory Engine Block | XChaCha20-Poly1305 | Semantic recall (Tier 2 AI) |

### On server (Supabase Postgres):

| Data | Encrypted | Readable by server |
|------|-----------|-------------------|
| Message ciphertext | E2EE | No — only ciphertext stored |
| Message metadata (sender_id, space_id, timestamp) | No | Yes |
| Key bundles (public keys only) | No | Yes — but these are public keys by design |
| One-time pre-keys (public keys) | No | Yes — public keys, consumed on use |
| Decision items, reactions, constraints | No | Yes — Layer 3, @xark reads these |
| Space metadata (title, members, dates) | No | Yes |
| @xark responses | No | Yes — server-generated, TTL auto-purge |

### On Firebase Storage:

| Data | Encrypted | Readable by server |
|------|-----------|-------------------|
| Encrypted key backup blob | Argon2id + AES-256-GCM | No — encrypted with user's backup password |
| Profile photos | No | Yes |
| Hero images | No | Yes |

---

## 9. Law Enforcement Response Framework

### When served with a legal order:

**We will provide** (to the extent required by applicable law):
1. Account registration information (phone number, display name, registration date)
2. Space membership (which groups a user belongs to)
3. Message metadata (timestamps, sender IDs, space IDs)
4. Decision data (items proposed, votes cast, items locked/purchased)
5. @xark AI responses (if not yet purged by TTL)
6. IP address logs (standard web server logs, retention per infrastructure provider)
7. Device registration records (device IDs, key bundle upload timestamps)

**We cannot provide** (mathematically impossible):
1. Message content — we store only ciphertext. We do not possess decryption keys.
2. Media shared in encrypted chats — same as above.
3. Sender Key material — distributed client-to-client, never touches our servers.
4. Double Ratchet session state — exists only on user devices.
5. Backup password — never transmitted to or stored on our servers.
6. Decrypted backup blobs — encrypted with user's password via Argon2id.

### Technical proof of inability:

The encryption architecture makes it **technically impossible** for Xark OS to decrypt user messages, even if compelled by any legal authority worldwide. This is by design, not by policy:

1. **No master key exists.** There is no key escrow, no recovery key held by Xark OS, no "admin backdoor."
2. **No key escrow.** Backup encryption uses a password known only to the user. We never see this password.
3. **Forward secrecy.** Even if somehow a single session key were obtained, it would decrypt only one message — past and future messages use different keys.
4. **Open protocol.** The Signal Protocol is publicly documented and peer-reviewed. Our implementation can be audited to verify these claims.

### Canary statement:

As of 2026-03-15, Xark OS has not:
- Received a National Security Letter
- Been subject to a FISA order
- Provided message content to any government or law enforcement agency
- Been compelled to build a backdoor or weaken encryption
- Received a gag order preventing disclosure of any of the above

This statement will be updated quarterly. Its removal or non-update should be treated as significant.

---

## 10. Competitive Position

### vs. WhatsApp (Meta)

| Dimension | WhatsApp | Xark OS |
|-----------|----------|---------|
| Encryption protocol | Signal Protocol | Signal Protocol (same) |
| Server access to messages | No (E2EE) | No (E2EE) |
| Server access to metadata | Yes (extensive) | Yes (minimal — space membership, timestamps) |
| AI access to messages | Yes — Meta AI can read messages for "suggestions" | No — @xark reads only Layer 3 structured data |
| Key backup | Google Drive/iCloud (optional E2EE) | Firebase Storage (always E2EE with Argon2id) |
| Group encryption | Sender Keys | Sender Keys (same) |
| Code open-source | Client libraries only | Full implementation auditable |
| Business model | Ads + data mining | Subscription (no ads, no data mining) |

**Key differentiator**: WhatsApp's "AI features" can access message content. Xark's @xark AI operates in a separate, unencrypted data layer and is architecturally prevented from reading chat messages.

### vs. Signal Messenger

| Dimension | Signal | Xark OS |
|-----------|--------|---------|
| Encryption protocol | Signal Protocol | Signal Protocol (same) |
| Server metadata | Minimal (sealed sender) | Standard (sender_id visible to server) |
| Group protocol | Signal Protocol + Sender Keys | Sender Keys (same) |
| AI features | None | @xark (Layer 3 only, never reads messages) |
| Key backup | PIN-based SVR (secure value recovery) | Argon2id + Firebase Storage |
| Focus | Private messaging | Group decision-making with E2EE messaging |

**Key differentiator**: Signal has superior metadata protection (sealed sender). Xark has structured group decision-making (reactions, consensus, commitment protocol) with AI assistance — all without compromising message encryption.

### vs. Telegram

| Dimension | Telegram | Xark OS |
|-----------|----------|---------|
| Default encryption | Server-side only (NOT E2EE) | E2EE for all messages |
| E2EE available? | Only in "Secret Chats" (1:1, opt-in) | All chats (1:1 and groups) |
| Group encryption | None — all groups are server-readable | Sender Keys E2EE |
| Server stores plaintext | Yes (for non-secret chats) | Never |
| AI features | Bots (access all messages) | @xark (Layer 3 only) |
| Key backup | N/A (server has keys) | Argon2id + Firebase Storage |

**Key differentiator**: Telegram's default mode is NOT end-to-end encrypted. Groups are never E2EE. Xark encrypts everything by default.

### vs. iMessage (Apple)

| Dimension | iMessage | Xark OS |
|-----------|----------|---------|
| Encryption | E2EE (proprietary protocol) | E2EE (Signal Protocol) |
| iCloud backup | Includes message keys (Apple can decrypt) | Backup encrypted with user password (we cannot decrypt) |
| Protocol transparency | Proprietary, not publicly auditable | Signal Protocol — open, peer-reviewed |
| Group protocol | Proprietary | Sender Keys (Signal approach) |
| Cross-platform | Apple devices only | PWA (any device with a browser) |

**Key differentiator**: iMessage backup to iCloud (when Advanced Data Protection is off, which is the default) gives Apple access to decryption keys. Xark backups are always E2EE with a user-held password.

---

## 11. Security Hardening

### Row-Level Security (RLS)

All Supabase tables enforce RLS:
- **key_bundles**: Anyone can read (public keys). Only the key owner can write/update/delete.
- **one_time_pre_keys**: Anyone can read. Only the key owner can insert.
- **message_ciphertexts**: Recipients can read their own. Group ciphertexts (`_group_`) readable by space members. Inserts via service role (API route).
- **user_constraints**: Owner-only CRUD.
- **space_constraints**: Space members can read. Owner can write.

All policies use `auth.jwt()->>'sub'` (not `auth.uid()`) because user IDs are text format (`name_ram`), not UUID.

### Anti-Injection Defense

Client-side message type guard prevents a compromised server from injecting fake plaintext:

```typescript
if (messageType === 'e2ee' || messageType === 'e2ee_xark') {
  // NEVER read msg.content — always decrypt from ciphertext
  return decryptedContent ?? '[decryption pending]';
}
```

Even if the server sets `content` on an E2EE message, the client ignores it and decrypts from `message_ciphertexts` only.

### Skipped Message Key Bounds

Out-of-order messages (common on mobile) require retaining skipped decryption keys. Bounded at 1000 keys maximum to prevent memory exhaustion attacks. Oldest keys evicted first.

### Constant-Time Operations

All key comparison operations use `sodium.memcmp()` (constant-time) to prevent timing side-channel attacks.

### SECURITY DEFINER Functions

Database RPCs (`fetch_key_bundle`, `revoke_device`, `purge_expired_xark_messages`) use `SECURITY DEFINER` with `SET search_path = public` to prevent search path injection.

---

## 12. Privacy Policy Summary

### Data we collect:

- Phone number (Firebase Auth — for login only)
- Display name (user-provided)
- Space membership and metadata
- Decision items, reactions, constraints (Layer 3 — functional data for group decisions)
- Message metadata (sender, space, timestamp — for message routing)
- Message ciphertext (encrypted — we cannot read it)

### Data we DO NOT collect:

- Message content (encrypted, we have no keys)
- Location data (no GPS, no IP-based location tracking)
- Contact lists (no address book access)
- Usage analytics or behavioral profiling
- Advertising identifiers

### Data we DO NOT sell:

All data. Period. We do not sell, share, license, or transfer any user data to any third party for advertising, marketing, or profiling purposes.

### Data retention:

- Message ciphertext: Hot storage (6 months, Postgres) → cold archive (Firebase Storage, indefinite)
- @xark responses: Auto-purged (30 days post-trip or 90 days for open spaces)
- Key bundles: Retained while device is active. Deleted on device revocation.
- One-time pre-keys: Deleted immediately on consumption.
- Account data: Retained while account is active. Deleted on account deletion request.

### User rights:

- **Access**: Users can view all their data through the app
- **Deletion**: Account deletion removes all server-side data. Ciphertexts in cold storage are purged on next archive cycle.
- **Portability**: Message data is encrypted — users possess their own decryption keys and can export locally decrypted messages.
- **Correction**: Users can update display name and profile photo at any time.

---

## 13. Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT DEVICE                         │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐   │
│  │ KeyStore │  │  Double   │  │    Sender Keys     │   │
│  │(IndexedDB)│  │ Ratchet  │  │  (group encrypt)   │   │
│  └─────┬────┘  └─────┬────┘  └────────┬───────────┘   │
│        │             │                 │                │
│        └─────────────┼─────────────────┘                │
│                      │                                  │
│              ┌───────┴───────┐                          │
│              │  Encryption   │                          │
│              │   Service     │                          │
│              └───────┬───────┘                          │
│                      │                                  │
│         ┌────────────┼────────────┐                     │
│         │ plaintext   │ ciphertext │                    │
│         ▼             ▼            ▼                    │
│  ┌─────────────┐  ┌──────────────────┐                 │
│  │  Constraint  │  │  POST /api/message│                │
│  │  Detection   │  │  (ciphertext only)│                │
│  │(sender only) │  └────────┬─────────┘                │
│  └──────┬──────┘           │                           │
│         │ consent           │                           │
│         ▼                   │                           │
│  ┌─────────────┐           │                           │
│  │ Layer 3 save│           │                           │
│  │(constraints)│           │                           │
│  └─────────────┘           │                           │
└────────────────────────────┼───────────────────────────┘
                             │
                    ═════════╪═════════  NETWORK (TLS)
                             │
┌────────────────────────────┼───────────────────────────┐
│                    SERVER                               │
│                                                         │
│  ┌─────────────────────────┴──────────────────────┐    │
│  │              Supabase Postgres                   │    │
│  │                                                  │    │
│  │  messages:          ciphertext only (content=NULL)│   │
│  │  message_ciphertexts: encrypted blobs             │   │
│  │  key_bundles:       PUBLIC keys only              │   │
│  │  decision_items:    Layer 3 (unencrypted)         │   │
│  │  reactions:         Layer 3 (unencrypted)         │   │
│  │  constraints:       Layer 3 (unencrypted)         │   │
│  │                                                  │    │
│  │  ┌────────────────────────────────────────────┐  │   │
│  │  │  RLS: auth.jwt()->>'sub' on all tables     │  │   │
│  │  │  SECURITY DEFINER: fetch_key_bundle,       │  │   │
│  │  │    revoke_device, purge_expired_xark       │  │   │
│  │  └────────────────────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  ┌──────────────────┐  ┌────────────────────────┐      │
│  │  @xark / Gemini  │  │  Firebase Storage      │      │
│  │  (Layer 3 ONLY)  │  │  (encrypted backups)   │      │
│  │  Never sees chat │  │  (cold ciphertext)     │      │
│  └──────────────────┘  └────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
```

---

## 14. Database Migration Reference

E2EE tables are defined in `supabase/migrations/014_e2ee.sql`:

**Tables**: `key_bundles`, `one_time_pre_keys`, `message_ciphertexts`, `user_constraints`, `space_constraints`, `constraint_prompts`

**RPCs**: `fetch_key_bundle` (atomic OTK consumption), `revoke_device` (device removal + broadcast), `purge_expired_xark_messages` (TTL enforcement)

**Indexes**: `idx_otk_user_device`, `idx_mc_msg_recipient` (unique), `idx_mc_message_id`, `idx_messages_type`, `idx_uc_user`, `idx_sc_space`

**Realtime**: `message_ciphertexts`, `key_bundles`, `constraint_prompts` published via Supabase Realtime.

---

## 15. Code Reference

| Module | Path | Purpose |
|--------|------|---------|
| Type definitions | `src/lib/crypto/types.ts` | All E2EE types (key pairs, sessions, payloads) |
| Primitives | `src/lib/crypto/primitives.ts` | libsodium wrapper (XChaCha20, Ed25519, Curve25519, HKDF, Argon2id) |
| KeyStore | `src/lib/crypto/keystore.ts` | IndexedDB-backed persistent key storage |
| X3DH | `src/lib/crypto/x3dh.ts` | Extended Triple Diffie-Hellman key agreement |
| Double Ratchet | `src/lib/crypto/double-ratchet.ts` | Per-message forward secrecy (1:1 sanctuaries) |
| Sender Keys | `src/lib/crypto/sender-keys.ts` | Group encryption with chain advancement |
| Key Manager | `src/lib/crypto/key-manager.ts` | Registration, key fetch, OTK replenishment, backup/restore |
| Encryption Service | `src/lib/crypto/encryption-service.ts` | High-level encrypt/decrypt API + message type guard |
| Constraint Detection | `src/lib/constraints.ts` | On-device pattern matching (sender-only, user-consented) |
| E2EE Hook | `src/hooks/useE2EE.ts` | React lifecycle hook (init, encrypt, decrypt, graceful fallback) |
| Unified Endpoint | `src/app/api/message/route.ts` | Atomic encrypted message + optional @xark trigger |
| Key APIs | `src/app/api/keys/` | Key bundle upload, OTK upload, atomic key fetch |
| PII Sanitizer | `src/lib/intelligence/sanitize.ts` | Redacts credit cards (Luhn), SSN, CVV before AI calls |
| Migration | `supabase/migrations/014_e2ee.sql` | All E2EE tables, RPCs, RLS, indexes |

---

## 16. Audit Readiness

### For security auditors:

1. **All crypto is client-side** — `src/lib/crypto/` is the complete crypto module. No server-side encryption/decryption.
2. **33 unit tests** — `src/lib/crypto/crypto.test.ts` covers primitives, X3DH, Double Ratchet, Sender Keys, and constraint detection.
3. **Build verification** — `npx next build` passes clean. 79/79 tests passing.
4. **Protocol conformance** — Implementation follows Signal Protocol specification (X3DH, Double Ratchet, Sender Keys). Custom implementation on libsodium-wrappers-sumo for auditability.
5. **No backdoors** — No master key, no key escrow, no recovery mechanism that bypasses user password.
6. **Open primitives** — All crypto operations use libsodium (NaCl), a well-audited cryptographic library.

### Known limitations (Resolved in v2):

- ~~IndexedDB key storage is vulnerable~~ → Resolved: Identity keys generated in OS Secure Enclaves via Capacitor `NativeCryptoProvider`.
- ~~Server can read metadata for AI~~ → Resolved: Local Intent Parsers handle simple tasks; Enclave Tunnels handle complex AI without server exposure.
- ~~Synchronous Sender Key rotation offline ejection vulnerability~~ → Resolved: Decentralized Tombstone mechanism blocks sends to offline compromised devices.

---

## 17. Frequently Asked Questions

**Q: Can Xark OS read my messages?**
A: No. Messages are encrypted on your device before they leave it. We store only the encrypted version. We do not have the keys to decrypt them.

**Q: What if Xark OS is hacked?**
A: An attacker who breaches our servers would obtain only encrypted data (ciphertext). Without the decryption keys, which exist only on user devices, the data is unreadable.

**Q: Can law enforcement read my messages?**
A: Not through us. We can provide message metadata (who messaged whom, when) but not message content. A warrant served to us for message content would yield only ciphertext. Law enforcement would need access to the user's physical device to read decrypted messages.

**Q: Does @xark read my messages?**
A: No. @xark reads your votes, decisions, and preferences (Layer 3 structured data) — never your conversations (Layer 2 encrypted messages). When you type @xark, only the command text you typed is sent to the AI.

**Q: What happens if I lose my phone?**
A: If you set a backup password, you can restore your encryption keys on a new device. Without the backup password, you start fresh — old messages on the lost device are inaccessible to anyone without the device passcode, and new messages will work normally.

**Q: Can a departed group member read future messages?**
A: No. When a member leaves a group, all remaining members rotate their Sender Keys. The departed member's old keys cannot decrypt messages sent after their departure.

**Q: Can a new group member read old messages?**
A: No (v1). New members receive current Sender Keys and can only decrypt messages sent after they joined. History sync is planned for v2.

**Q: Is the encryption code auditable?**
A: Yes. The complete crypto module is in `src/lib/crypto/`. We use libsodium (NaCl) for all primitives — a widely audited, open-source cryptographic library. The Signal Protocol specification is publicly documented.
