# End-to-End Encrypted Chat — Design Spec

> **For agentic workers:** This spec defines the E2EE architecture for Xark OS. It covers cryptographic protocol selection, key management, message encryption flows, @xark integration, on-device constraint detection, and scale considerations for 1 to 1 million users.

**Date:** 2026-03-15
**Status:** Draft
**Scope:** All chat messages (group spaces + 1:1 sanctuaries). Does NOT cover decision items, reactions, or space metadata (these remain unencrypted as Layer 3 structured data).

---

## 1. Threat Model

**Goal:** Full zero-knowledge E2EE. Server never sees message plaintext. Only sender and recipients can read messages.

**Protects against:**
- Server/database compromise (Supabase breach → ciphertext only)
- Network eavesdropping (application-layer encryption on top of TLS)
- Operator access (Xark OS developers/admins cannot read user messages)

**Does NOT protect against:**
- Compromised client device (attacker with device access can read decrypted messages)
- Legally compelled access to client devices
- Side-channel attacks on client-side JavaScript (WebCrypto limitations)
- **@xark invocation plaintext**: When a user sends an `@xark` command, the command portion is sent in plaintext to the server for AI processing. The encrypted copy is still stored for recipient-side decryption. This is an explicit, user-initiated disclosure — the user chose to invoke @xark. The server does not persist the plaintext command beyond the API call lifetime.

**Privacy promise (user-facing):**
> "Your conversations are end-to-end encrypted. Only people in the chat can read messages. @xark reads your votes, decisions, and preferences — never your conversations."

---

## 2. Three-Layer Architecture

```
Layer 1: KEY MANAGEMENT
  Identity keys, pre-keys, key backup/restore
  Runs once per user registration + device setup

Layer 2: MESSAGE ENCRYPTION
  Signal Protocol — Double Ratchet (1:1), Sender Keys (groups)
  Per-message forward secrecy. Client-side only.

Layer 3: STRUCTURED INTELLIGENCE (unencrypted)
  Decision items, reactions, user/space constraints, space metadata.
  @xark operates exclusively in this layer.
  On-device constraint detection bridges Layer 2 → Layer 3.
```

### What's encrypted (zero-knowledge):
- All chat messages (1:1 sanctuaries and group spaces)
- Media files shared in chat (photos, receipts)
- Message content in encrypted cloud backups
- Sender display name (inside encrypted payload — server only knows sender_id)

### What's NOT encrypted (Layer 3, @xark reads freely):
- Decision items (title, description, category, state, scores)
- Reactions (who voted what, agreement scores)
- User constraints (dietary, accessibility, alcohol — global profile)
- Space constraints (budget, date preferences — per-space)
- Space metadata (title, dates, member roster)
- Message metadata (sender_id, space_id, timestamp — needed for routing)
- @xark messages (server-generated, plaintext with TTL)

---

## 3. Protocol Selection

**Signal Protocol** — Double Ratchet for 1:1, Sender Keys for groups.

### Why Signal over MLS:
- Xark groups are 2-15 members (architecture blueprint). Signal + Sender Keys is purpose-built for this range.
- MLS (TreeKEM) optimizes for 50-100+ members — over-engineered for current scope.
- Signal has mature libraries: `libsignal` (Rust/WASM), TypeScript implementations available.
- WhatsApp proved Signal works at 2B users. Xark's 1M target is user count, not group size.
- If large groups are needed later (events, 50+ people), MLS can be swapped behind the same encryption interface.

### Cryptographic primitives:
- **Identity Key:** Ed25519 key pair (used for signing). Converted to Curve25519 via birational mapping for X3DH key agreement. This is the standard Signal approach — one key pair serves both purposes.
- **Key agreement:** X3DH (Extended Triple Diffie-Hellman) with Curve25519
- **Message encryption:** AES-256-GCM (authenticated encryption)
- **Key derivation:** HKDF-SHA-256 (with application-specific `info` field: `"XarkE2EE"` + identity key fingerprints for domain separation)
- **Backup key derivation:** Argon2id (3 iterations, 64MB memory)
- **Signing:** Ed25519

### Sender Key forward secrecy limitation:
Sender Keys provide forward secrecy within a sender's chain (each message advances the chain), but if a Sender Key is compromised, ALL past messages from that sender since the last key rotation are readable. This is weaker than Double Ratchet's per-message forward secrecy. Mitigation: Sender Keys rotate on every member leave event. This tradeoff is accepted for group encryption efficiency (O(1) encrypt vs O(N) with Double Ratchet).

---

## 4. Key Management

### 4a. Per-User Key Hierarchy

```
Identity Key (Ed25519 → Curve25519 birational pair)
  Long-lived, generated once at registration
  Ed25519 half: signs pre-keys and proves trust
  Curve25519 half: used in X3DH key agreement
  Stored on device + encrypted cloud backup

Signed Pre-Key (Curve25519, with numeric ID)
  Rotated every 30 days, old keys retained briefly for in-flight sessions
  Signed by Identity Key Ed25519 half (proves authenticity)
  Uploaded to Key Distribution Server with signed_pre_key_id

One-Time Pre-Keys (Curve25519 x 100)
  Batch of 100 generated on registration
  Each used exactly once then discarded (DELETE on fetch)
  Client uploads fresh batch when supply < 20
```

### 4b. Key Distribution Server (Supabase tables)

```sql
-- Public keys only. Server NEVER sees private keys.
-- Composite PK: (user_id, device_id) — one bundle per device
key_bundles:
  user_id            text
  device_id          integer
  identity_key       text          -- base64 Ed25519 public key (converts to Curve25519 for DH)
  signed_pre_key     text          -- base64 Curve25519, rotated monthly
  signed_pre_key_id  integer       -- numeric ID for session reference during key rotation
  pre_key_sig        text          -- Ed25519 signature by identity key
  updated_at         timestamptz
  PRIMARY KEY (user_id, device_id)

-- Single-use pre-keys, consumed atomically
one_time_pre_keys:
  id               text PK
  user_id          text
  device_id        integer
  public_key       text          -- base64 Curve25519
```

### 4c. Atomic OTK Fetching (prevents race conditions at scale)

```sql
CREATE FUNCTION fetch_key_bundle(p_user_id text, p_device_id integer)
RETURNS TABLE(identity_key text, signed_pre_key text, pre_key_sig text, otk_public text)
LANGUAGE plpgsql AS $$
DECLARE v_otk_key text;
BEGIN
  -- Atomic: grab one OTK, lock it, delete it
  DELETE FROM one_time_pre_keys
  WHERE id = (
    SELECT id FROM one_time_pre_keys
    WHERE user_id = p_user_id AND device_id = p_device_id
    LIMIT 1 FOR UPDATE SKIP LOCKED
  ) RETURNING public_key INTO v_otk_key;

  RETURN QUERY
  SELECT kb.identity_key, kb.signed_pre_key, kb.pre_key_sig, v_otk_key
  FROM key_bundles kb
  WHERE kb.user_id = p_user_id AND kb.device_id = p_device_id;
END; $$;
```

### 4d. Registration Flow

1. User completes Firebase Auth (phone OTP)
2. Client generates Identity Key pair (Curve25519)
3. Client generates Signed Pre-Key + signs with Identity Key
4. Client generates 100 One-Time Pre-Keys
5. Client uploads PUBLIC halves to `key_bundles` + `one_time_pre_keys`
6. Client stores PRIVATE halves in IndexedDB (encrypted with device key)
7. Client prompts: "set a backup password"
8. Client derives backup key from password (Argon2id, 3 iterations, 64MB)
9. Client encrypts Identity Key + Signed Pre-Key + active Group Sender Keys with backup key (AES-256-GCM). **NOT OTK private keys** — fresh OTKs generated on restore.
10. Client uploads encrypted blob to Firebase Storage (`backups/{userId}/keys`)

### 4e. Backup & Restore Flow

```
Lost phone → new device → Firebase Auth (same phone number)
  → Download encrypted key blob from Firebase Storage
  → "Enter your backup password"
  → Argon2id derive key → AES-256-GCM decrypt → private keys restored
  → Generate fresh batch of 100 OTKs, upload to server
  → Re-establish sessions with existing contacts
```

### 4f. Multi-Device Support

- Each device gets its own Device Key pair + Signed Pre-Key + OTKs
- Identity Key is shared across devices
- Messages encrypted to ALL of a user's active devices
- Device registry: extend existing `user_devices` table with `device_id` integer
- Sender must fetch key bundles for each recipient device

**Adding a second device (device linking):**
- Open new device → Firebase Auth (same phone number)
- On existing device: "New device detected. Approve?" → QR code displayed
- New device scans QR code → establishes encrypted channel to existing device
- Existing device transfers Identity Key over encrypted channel (no cloud backup password needed)
- New device generates its own Signed Pre-Key + OTKs, uploads to server
- This is distinct from backup/restore (which requires the backup password and is for lost-device recovery)

### 4g. Device Revocation

```sql
-- SECURITY: Restricted to service-role only. Client calls /api/device/revoke
-- which verifies auth.jwt()->>'sub' = p_user_id before invoking.
CREATE FUNCTION revoke_device(p_user_id text, p_device_id integer)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  DELETE FROM key_bundles
    WHERE user_id = p_user_id AND device_id = p_device_id;
  DELETE FROM one_time_pre_keys
    WHERE user_id = p_user_id AND device_id = p_device_id;
  PERFORM pg_notify('device_revoked',
    json_build_object('user_id', p_user_id, 'device_id', p_device_id)::text);
END; $$;
```

All clients subscribe to `device_revoked` Realtime events. On receipt: drop device session from local state, exclude from future encryptions, rotate Sender Keys for all shared groups.

### 4h. Local Key Storage

```typescript
// Abstract interface — swap implementation for native platforms
interface KeyStore {
  // Identity
  saveIdentityKey(key: CryptoKeyPair): Promise<void>
  getIdentityKey(): Promise<CryptoKeyPair | null>
  // Signed Pre-Key
  saveSignedPreKey(id: number, key: CryptoKeyPair): Promise<void>
  getSignedPreKey(id: number): Promise<CryptoKeyPair | null>
  // One-Time Pre-Keys
  saveOneTimePreKeys(keys: Array<{ id: string; key: CryptoKeyPair }>): Promise<void>
  getOneTimePreKey(id: string): Promise<CryptoKeyPair | null>
  deleteOneTimePreKey(id: string): Promise<void>
  getOneTimePreKeyCount(): Promise<number>
  // Sender Keys (group encryption)
  saveSenderKey(spaceId: string, key: Uint8Array): Promise<void>
  getSenderKey(spaceId: string): Promise<Uint8Array | null>
  deleteSenderKey(spaceId: string): Promise<void>
  // Sessions (Double Ratchet state per peer device)
  saveSession(userId: string, deviceId: number, state: Uint8Array): Promise<void>
  getSession(userId: string, deviceId: number): Promise<Uint8Array | null>
  deleteSession(userId: string, deviceId: number): Promise<void>
  // Device
  getDeviceId(): Promise<number>
  // Lifecycle
  clear(): Promise<void>
}
// PWA: IndexedDB implementation
// Native (roadmap): iOS Secure Enclave / Android Keystore
```

---

## 5. Message Encryption Flow

### 5a. Database Schema

```sql
-- Envelope: routing metadata (one per message)
-- MIGRATION NOTE: existing messages table retains `content` and `sender_name` columns
-- for backward compatibility (pre-E2EE messages) and @xark plaintext responses.
-- New E2EE messages set content=NULL and sender_name=NULL.
messages:
  id                text PK
  space_id          text FK
  sender_id         text
  sender_device_id  integer       -- NULL for pre-E2EE and @xark messages
  message_type      text          -- 'e2ee' | 'e2ee_xark' | 'xark' | 'system' | 'legacy'
  content           text          -- NULL for E2EE messages. Used by: pre-E2EE legacy, @xark plaintext
  sender_name       text          -- NULL for E2EE messages. Used by: pre-E2EE legacy, @xark
  created_at        timestamptz

-- Ciphertexts: per-device for 1:1, single row for groups
message_ciphertexts:
  id                  text PK     -- surrogate PK (msg_crypt_{uuid})
  message_id          text FK     -- references messages(id)
  recipient_id        text        -- user_id for 1:1, '_group_' sentinel for Sender Key messages
  recipient_device_id integer     -- device_id for 1:1, 0 sentinel for Sender Key messages
  ciphertext          text        -- base64 AES-256-GCM ciphertext
  ratchet_header      text        -- base64 Double Ratchet header (NULL for Sender Key messages)

CREATE UNIQUE INDEX idx_mc_msg_recipient
  ON message_ciphertexts(message_id, recipient_id, recipient_device_id);
CREATE INDEX idx_mc_message_id ON message_ciphertexts(message_id);
```

### 5b. Encrypted Payload (inside ciphertext)

```json
{
  "text": "hey guys I'm allergic to shellfish",
  "reply_to": null,
  "media_url": null,
  "type": "message"
}
```

No `sender_name` in payload. Client resolves `sender_id` → display name from local `space_members` cache (fetched on space entry, updated via Realtime subscription on `space_members` table). Name changes apply retroactively. If cache is stale (e.g., new member not yet synced), client falls back to `sender_id` display until cache refreshes.

**Pre-E2EE messages** (migration): Old messages retain `content` and `sender_name` in the `messages` table. Client checks `message_type`: if `'legacy'`, read from `messages.content`; if `'e2ee'`, decrypt from `message_ciphertexts`. Displayed with a subtle "sent before encryption" indicator.

### 5c. 1:1 Sanctuary Flow (Double Ratchet)

```
First message (X3DH key agreement):
  1. Ram's client calls fetch_key_bundle('nina', device_id)
     for EACH of Nina's active devices
  2. X3DH per device:
     DH1: Ram's Identity Key x Nina's Signed Pre-Key
     DH2: Ram's Ephemeral Key x Nina's Identity Key
     DH3: Ram's Ephemeral Key x Nina's Signed Pre-Key
     DH4: Ram's Ephemeral Key x Nina's OTK (if available)
     Shared secret = HKDF(DH1 || DH2 || DH3 || DH4)
  3. Double Ratchet initialized per device
  4. Message encrypted with first ratchet key (AES-256-GCM)
  5. One messages row, N message_ciphertexts rows (one per device)

Subsequent messages:
  Each message advances the ratchet → new key per message
  Forward secrecy: compromise one key = only one message exposed
  Keys deleted after decryption
```

### 5d. Group Space Flow (Sender Keys)

```
When Ram joins "San Diego Trip" (5 members):
  1. Ram generates a Sender Key (symmetric chain key + signing key)
  2. Ram distributes Sender Key to each member's devices
     via pairwise Signal sessions (encrypted 1:1)
  3. Server stores nothing — distribution is E2EE

When Ram sends a group message:
  1. Encrypt once with Ram's Sender Key chain (AES-256-GCM)
  2. Advance chain (forward secrecy within sender's chain)
  3. One messages row, one message_ciphertexts row
     (recipient_id NULL — everyone decrypts with Ram's Sender Key)

When a member leaves:
  ALL remaining members generate new Sender Keys
  Distribute via pairwise sessions
  Old keys deleted — departed member can't read future messages
  Cost: O(N^2) for N<=15, acceptable and rare

When a member joins:
  New member receives current Sender Keys from all members
  New member generates own Sender Key, distributes it
  New member CANNOT read pre-join history (no old keys)
  History Sync: v2 roadmap (admin bundles recent history via pairwise session)
```

### 5e. @xark Messages (exception — server-generated plaintext)

- @xark responses stored with `message_type: 'xark'` and plaintext content
- Rendered inline in chat but visually distinct (cyan label)
- NOT E2EE — the server created them, this is transparent to users
- Subject to 30-day TTL auto-purge (see Section 9)

---

## 6. Unified API Endpoint

**`/api/message` — unified endpoint for encrypted messages + @xark triggers.**

Single atomic request from client. No ghost messages, no orphaned @xark responses. Rate limiting on @xark invocations inherited from existing `/api/xark` (10 calls/user/minute).

**All existing `/api/xark` logic is preserved** inside `orchestrateAndUpdate()`: parallelized pre-Gemini fetches via `Promise.all` (space title + grounding context), PII sanitization before Gemini calls, search results auto-upserted as `decision_items` with `search_batch` + `search_label` metadata, `isGarbageResponse()` check. The existing `/api/xark` route file becomes an internal function, not a public endpoint.

### Client-side:

```typescript
async function sendMessage(text: string, spaceId: string) {
  const encrypted = await encryptForSpace(text, spaceId);

  const payload: MessagePayload = {
    space_id: spaceId,
    sender_id: currentUserId,
    sender_device_id: currentDeviceId,
    ciphertext: encrypted.ciphertext,
    ratchet_header: encrypted.header,
  };

  if (text.toLowerCase().includes('@xark')) {
    const pending = localStorage.get(`xark_question_${spaceId}`);
    payload.xark_trigger = {
      plaintext_command: text.replace(/@xark\s*/i, '').trim(),
      bundled_context: pending?.question
        ? `[Answering: "${pending.question}"]`
        : undefined,
    };
    localStorage.remove(`xark_question_${spaceId}`);
  }

  return fetch('/api/message', { body: JSON.stringify(payload) });
}
```

### Server-side:

```typescript
// POST /api/message — atomic message + optional @xark trigger
export async function POST(req: NextRequest) {
  const { space_id, sender_id, sender_device_id,
          ciphertext, ratchet_header, xark_trigger } = await req.json();

  // Step 1: Insert encrypted message (always)
  const msgId = `msg_${crypto.randomUUID()}`;
  await supabaseAdmin.from('messages').insert({
    id: msgId, space_id, sender_id, sender_device_id,
    message_type: xark_trigger ? 'e2ee_xark' : 'e2ee',
    created_at: new Date().toISOString(),
  });
  await supabaseAdmin.from('message_ciphertexts').insert({
    message_id: msgId,
    recipient_id: null,
    recipient_device_id: null,
    ciphertext, ratchet_header,
  });

  // Step 2: If @xark, process (only if Step 1 succeeded)
  if (xark_trigger) {
    const xarkMsgId = `msg_${crypto.randomUUID()}`;
    await supabaseAdmin.from('messages').insert({
      id: xarkMsgId, space_id, sender_id: null,
      message_type: 'xark',
      created_at: new Date().toISOString(),
    });
    orchestrateAndUpdate(xarkMsgId, space_id, xark_trigger);
  }

  return NextResponse.json({ messageId: msgId });
}
```

### Orchestrator failure handling:

```typescript
async function orchestrateAndUpdate(xarkMsgId, spaceId, trigger) {
  try {
    const result = await orchestrate({ /* Layer 3 context */ });
    if (isGarbageResponse(result.response)) {
      await supabaseAdmin.from('messages').delete().eq('id', xarkMsgId);
      return;
    }
    await supabaseAdmin.from('messages')
      .update({ content: result.response }).eq('id', xarkMsgId);
  } catch (err) {
    const isTimeout = err instanceof Error && err.message.includes('timeout');
    await supabaseAdmin.from('messages').update({
      content: isTimeout ? "took too long. try again." : "something glitched. try that again?"
    }).eq('id', xarkMsgId);
  }
}
```

No infinite "thinking..." state. Every code path resolves.

---

## 7. @xark in the Encrypted World

### Group spaces — @xark enabled:

@xark builds context exclusively from Layer 3:
- Space title and dates
- Grounding state map (decision items grouped by state)
- Reaction data with user attribution
- User constraints (dietary, accessibility, alcohol) for all members
- Space constraints (budget, location preferences)
- The explicit @xark message text

@xark **never** sees: message history, chat content, media shared in chat.

### Sanctuaries — @xark disabled for privacy:

This is a **new constraint** introduced by E2EE. The existing GROUNDING_PROTOCOL.md says @xark operates in sanctuaries ("more intimate, more direct"). With E2EE, sanctuaries become pure encrypted pipes — @xark cannot read 1:1 messages, and there is no Layer 3 decision data in sanctuaries to work with. GROUNDING_PROTOCOL.md must be updated to reflect this change.

```typescript
// Client-side guard:
if (space.atmosphere === 'sanctuary' && message.includes('@xark')) {
  showWhisper("@xark isn't available in private chats");
  return;
}

// Server-side guard (defense in depth):
if (spaceAtmosphere === 'sanctuary') {
  return NextResponse.json({ response: null });
}
```

### Smart follow-up (client-side, space-wide):

Any client in the space that receives an @xark message containing `?` stores the question locally:

```typescript
// On receiving @xark message via Realtime:
if (payload.message_type === 'xark' && payload.content?.includes('?')) {
  localStorage.set(`xark_question_${spaceId}`, {
    question: payload.content,
    timestamp: Date.now()
  });
}
// Any member can answer within 3 minutes
```

### Feature comparison:

| Feature | Group Space | Sanctuary |
|---------|------------|-----------|
| E2EE | Signal + Sender Keys | Signal Double Ratchet |
| @xark | Available (Layer 3 context) | Disabled completely |
| Constraint detection | Active (sender device) | Disabled |
| Decision items | Active | None |
| Reactions | Active | None |
| Media | E2EE | E2EE |
| Smart follow-up | Client-side, space-wide | N/A |

---

## 8. On-Device Constraint Detection

Bridges Layer 2 (encrypted messages) → Layer 3 (structured data) with explicit user consent.

### Flow:
1. Message decrypted on **sender's device only** (`sender_id === currentUserId`)
2. Conservative allowlist matching (no open regex)
3. Match found → inline whisper below the message
4. User taps [yes] → structured constraint written to Layer 3
5. User taps [dismiss] → dismissal synced across sender's devices via `constraint_prompts`

### Allowlists (hardcoded, conservative):

```typescript
const DIETARY_TRIGGERS: Record<string, string[]> = {
  'vegan':         ['i\'m vegan', 'i am vegan', 'i eat vegan'],
  'vegetarian':    ['i\'m vegetarian', 'i am vegetarian'],
  'halal':         ['i eat halal', 'halal only', 'i need halal'],
  'kosher':        ['i keep kosher', 'kosher only'],
  'no_shellfish':  ['allergic to shellfish', 'shellfish allergy'],
  'no_peanuts':    ['allergic to peanuts', 'peanut allergy', 'nut allergy'],
  'no_dairy':      ['allergic to dairy', 'dairy free', 'lactose intolerant'],
  'no_gluten':     ['gluten free', 'celiac', 'allergic to gluten'],
};

const BUDGET_PATTERN = /budget\s+(?:is|around|under|max|of)\s+(?:\$)?(\d+)/i;
const ACCESSIBILITY = ['wheelchair', 'accessible', 'mobility aid'];
const ALCOHOL = ['i don\'t drink', 'i am sober', 'no alcohol'];
```

### Rules:
- Sender's device only (no multi-device echo)
- Lowercase comparison, exact phrase match
- One prompt per message max (first match wins)
- Conservative: better to miss than false-positive (alert fatigue)
- **Known v1 limitation**: Third-person references may false-match (e.g., "my friend is allergic to shellfish" → attributes to sender). Accepted for v1 — the user can dismiss the prompt, and the constraint management UI allows deletion. Future refinement: require first-person pronoun prefix (I/I'm/I am) before trigger phrases.

### Constraint storage:

```sql
-- Global: travels with user across all spaces
user_constraints:
  id           text PK
  user_id      text FK
  type         text         -- 'dietary' | 'accessibility' | 'alcohol'
  value        text         -- 'vegan' | 'no_shellfish' | 'wheelchair'
  created_at   timestamptz

-- Space-specific
space_constraints:
  id           text PK
  space_id     text FK
  user_id      text
  type         text         -- 'budget' | 'date' | 'location_pref'
  value        text         -- '$150' | 'near beach'
  created_at   timestamptz

-- Prompt dismissal state (cross-device sync)
constraint_prompts:
  message_id   text
  user_id      text
  action       text         -- 'accepted' | 'dismissed'
  created_at   timestamptz
  PRIMARY KEY (message_id, user_id)  -- same message could prompt different users
```

Dietary/accessibility/alcohol prompts → `user_constraints` (global profile).
Budget/location prompts → `space_constraints` (per-space).

### Constraint management UI:
- Profile section in UserMenu: view/edit/delete global constraints
- Space settings: view/edit/delete space constraints
- Floating text actions, consistent with Zero-Box doctrine

---

## 9. Production Hardening

### 9a. @xark Plaintext TTL

Server-generated @xark messages are plaintext — a breach target. Auto-purge after trip ends:

```sql
CREATE FUNCTION purge_expired_xark_messages()
RETURNS integer LANGUAGE plpgsql AS $$
DECLARE deleted_count integer;
BEGIN
  DELETE FROM messages
  WHERE message_type = 'xark'  -- only purge plaintext @xark responses (not e2ee_xark which is ciphertext)
    AND (
      -- Spaces with trip dates: purge 30 days after trip ends
      (space_id IN (
        SELECT space_id FROM space_dates
        WHERE end_date < CURRENT_DATE - INTERVAL '30 days'
      ))
      OR
      -- Open-ended spaces (no trip dates): purge after 90 days
      (space_id NOT IN (SELECT space_id FROM space_dates)
       AND created_at < NOW() - INTERVAL '90 days')
    );
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END; $$;

-- Daily at 3am UTC
SELECT cron.schedule('purge-xark', '0 3 * * *', 'SELECT purge_expired_xark_messages()');
```

### 9b. Cold Storage Pipeline

Hot Postgres holds 6 months of `message_ciphertexts`. Older partitions archived to cold storage.

```
Monthly partitions:
  message_ciphertexts_2026_03
  message_ciphertexts_2026_04
  ...

Monthly cron (detach + archive):
  1. COPY partition older than 6 months → JSONL file
  2. Compress (gzip)
  3. Upload to Firebase Storage: cold/{year}/{month}/ciphertexts.jsonl.gz
  4. DETACH PARTITION
  5. DROP detached partition

On-demand retrieval:
  Client scrolls past 6-month boundary
  → GET /api/messages/cold?space_id=X&month=2026-03
  → Server returns signed Firebase Storage URL
  → Client downloads, decrypts locally

CRITICAL: Server NEVER touches Sender Keys.
  The server archives only ciphertexts — it has no access to Sender
  Keys (they are distributed client-to-client via pairwise E2EE).
  Clients are responsible for retaining historical Sender Keys in
  their local KeyStore and inside their encrypted cloud backup blob.
  When a client fetches cold-archived ciphertexts, it decrypts using
  its locally-retained historical Sender Keys. If a user has deleted
  a historical Sender Key (or never received it), that chunk of
  group history is unreadable to them — this is by design, consistent
  with forward secrecy goals. The server remains completely blind
  to all Sender Keys at all times.
```

### 9c. OTK Replenishment

```
Client monitors local OTK count after each session establishment.
When local count < 20:
  Generate 100 fresh OTKs
  Upload public halves to one_time_pre_keys
Server can also push FCM notification: "replenish_keys" when server-side count < 20.
```

---

## 10. Scale Characteristics

### Storage:
- 1M users x 100 OTKs = 100M rows (~12GB) — fits in Postgres
- 50M messages/day x 600 bytes = ~30GB/day
- Hot window (6 months): ~5.4TB → partitioned monthly
- Cold archive: Firebase Storage (~$0.02/GB/month)

### Realtime:
- Channels are per-space, not per-user
- 1M users across ~100K spaces = 100K channels
- 2-15 subscribers per channel — within Supabase limits

### Key distribution:
- `fetch_key_bundle` RPC: called on first contact + key rotation only
- ~10K new sessions/hour comfortable for Postgres
- `FOR UPDATE SKIP LOCKED` prevents OTK contention

### Sender Key operations:
- Member leave: N x (N-1) pairwise deliveries
- Max group (N=15): 210 messages (one-time, small payloads, rare event)

### What needs attention at 500K+ users:
- OTK table vacuuming (consumed keys deleted, index bloat)
- `message_ciphertexts` monthly partitioning
- Connection pooling (Supabase pgBouncer)
- Read replicas for `key_bundles` (write-rarely, read-often)

---

## 11. Migration Strategy

### Phase 1 (v1 launch — new messages only):
- All new messages encrypted. No migration of old plaintext messages.
- Old messages remain readable but marked with "sent before encryption was enabled"
- `messages.content` column retained for old messages + @xark messages
- New encrypted messages use `message_ciphertexts` table

### Phase 2 (v2 — full feature set):
- History Sync for late group joiners (admin bundles recent history via pairwise session)
- "Share with @xark" button on encrypted media (decrypt locally, send as Layer 3 task)
- Native key storage (iOS Secure Enclave / Android Keystore) when wrapping in native shell

### Phase 3 (v3 — hardening):
- Key transparency log (public verifiability of identity keys)
- Safety number verification UI (QR code scan between users)
- MLS evaluation for large group support (50+ members)

---

## 12. New Database Tables Summary

```sql
-- Key management
key_bundles (user_id, device_id, identity_key, signed_pre_key, signed_pre_key_id, pre_key_sig, updated_at)
  PK: (user_id, device_id)
one_time_pre_keys (id PK, user_id, device_id, public_key)

-- Messages (modified — retains content + sender_name for backward compat + @xark)
messages (id PK, space_id, sender_id, sender_device_id, message_type, content, sender_name, created_at)
  message_type: 'e2ee' | 'e2ee_xark' | 'xark' | 'system' | 'legacy'
  content/sender_name: NULL for E2EE messages, populated for legacy + @xark
message_ciphertexts (id PK, message_id FK, recipient_id, recipient_device_id, ciphertext, ratchet_header)
  UNIQUE INDEX: (message_id, recipient_id, recipient_device_id)
  INDEX: (message_id)

-- Constraints
user_constraints (id PK, user_id, type, value, created_at)
space_constraints (id PK, space_id, user_id, type, value, created_at)
constraint_prompts (message_id, user_id, action, created_at)
  PK: (message_id, user_id)

-- RPCs
fetch_key_bundle(user_id, device_id) — atomic OTK consumption (FOR UPDATE SKIP LOCKED)
revoke_device(user_id, device_id) — device revocation + broadcast (SECURITY DEFINER, service-role only)
purge_expired_xark_messages() — 30/90-day TTL cron
```

---

## 13. Dependencies

### New libraries required:
- **`libsodium-wrappers-sumo`** (maintained, 75KB gzipped) — Provides all required primitives: Curve25519, Ed25519, X25519, AES-256-GCM, Argon2id, HKDF. Well-maintained with npm downloads >1M/week. The `-sumo` variant includes Argon2id (standard `libsodium-wrappers` does not).
- **Custom Double Ratchet + Sender Keys implementation** built on top of libsodium primitives. Community `libsignal-protocol-typescript` forks have inconsistent maintenance. Building on libsodium gives full control over the protocol implementation while using battle-tested cryptographic primitives. The Double Ratchet algorithm is well-documented (Signal's technical docs) and implementable in ~500 lines of TypeScript.
- No new server-side dependencies (all crypto is client-side)

### Client-side performance note:
For low-end devices (detected via `useDeviceTier.ts`), encryption operations (especially group messages to 15 members with multiple devices each) should be offloaded to a Web Worker to avoid blocking the UI thread. Estimated overhead: <50ms per message on modern devices, up to 200ms on low-end — acceptable but should not block render.

### Existing infrastructure used:
- Firebase Auth — identity (unchanged)
- Supabase Postgres — key distribution + encrypted message storage
- Supabase Realtime — encrypted message delivery + device revocation events
- Firebase Storage — encrypted cloud backups + cold archive
- FCM — OTK replenishment push notifications

---

## 14. Implementation Safety Nuances

### 14a. Skipped Message Keys (Double Ratchet)

Out-of-order message delivery is common on mobile networks. The Double Ratchet must maintain a dictionary of skipped message keys for messages that arrive out of sequence. Critical rules:

- **Bounded dictionary**: Cap at 1000 skipped keys. If exceeded, oldest keys are evicted (those messages become unreadable — acceptable tradeoff vs unbounded memory).
- **Delete after use**: Once a skipped key is used to decrypt an out-of-order message, it MUST be immediately deleted. Retaining it violates forward secrecy.
- **Persist to KeyStore**: Skipped keys must survive app restarts (stored in IndexedDB via KeyStore interface). A crashed app that loses skipped keys = unreadable messages.
- **Test rigorously**: Simulate message reordering, duplication, and gaps in integration tests.

### 14b. Ed25519 → Curve25519 Birational Mapping

Use libsodium's specific conversion functions. Do NOT implement the birational mapping manually.

```typescript
import sodium from 'libsodium-wrappers-sumo';

// Ed25519 signing key → Curve25519 DH key
const curve25519PK = sodium.crypto_sign_ed25519_pk_to_curve25519(ed25519PublicKey);
const curve25519SK = sodium.crypto_sign_ed25519_sk_to_curve25519(ed25519SecretKey);
```

These functions handle the clamping and field mapping correctly. Manual conversion is a common source of cryptographic errors.

### 14c. Client-Side Message Type Guard (Anti-Injection)

A compromised server could inject plaintext into the `content` field of a message with `message_type: 'e2ee'`. The client MUST enforce this rule:

```typescript
function renderMessage(msg: Message) {
  if (msg.message_type === 'e2ee' || msg.message_type === 'e2ee_xark') {
    // MUST decrypt from message_ciphertexts. NEVER read msg.content.
    // Even if msg.content is populated, ignore it entirely.
    const plaintext = await decryptCiphertext(msg.id);
    return plaintext;
  }
  if (msg.message_type === 'xark' || msg.message_type === 'legacy') {
    // Plaintext is expected for these types
    return msg.content;
  }
}
```

This is defense-in-depth: even if the server is compromised and inserts fake plaintext, E2EE messages are only ever rendered from decrypted ciphertext.

### 14d. Sender Key Retention in Backup

The encrypted cloud backup blob must include ALL historical Sender Keys, not just the currently active ones. When a Sender Key rotates (due to member leave), the old key moves from "active" to "historical" in the KeyStore. Both are included in the backup. This ensures cold-archived messages remain decryptable after device restore.

Backup blob structure:
```
{
  identity_key: Ed25519KeyPair,
  signed_pre_key: { id: number, key: Curve25519KeyPair },
  sender_keys: {
    active: { [spaceId]: SenderKey },
    historical: { [spaceId]: SenderKey[] }  // ordered by rotation date
  }
}
```

---

## 15. What This Design Does NOT Cover (Explicit Non-Goals for v1)

- Message search (cannot full-text search encrypted messages)
- History Sync for late group joiners (v2)
- Encrypted media sharing with @xark (v2 — "Share with @xark" button)
- Native platform key storage (v2 — iOS Secure Enclave / Android Keystore)
- Key transparency / safety number verification (v3)
- MLS for large groups (v3)
- Disappearing messages / ephemeral mode
- Screenshot detection or prevention
