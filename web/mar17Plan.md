# Xark OS V2 — E2EE Master Plan Execution

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking. Each lane has strict file ownership — NO agent touches files outside its lane.

**Goal:** Fix all P0/P1 crypto bugs, extract @xark from chat into Spotlight, delete Memory Worker, re-enable E2EE.

**Architecture:** 4 parallel lanes with strict file ownership. Interface contracts frozen at start. No cross-lane file edits. 32 task blocks (4 lanes x 8 hours).

**Tech Stack:** libsodium-wrappers-sumo (WASM), WebCrypto API, Supabase Postgres + Realtime, Next.js API Routes, React 19, Zustand (existing), vitest.

**Date:** 2026-03-17

---

## Interface Contract (FROZEN — all lanes code against these)

```typescript
// Lane A exports (consumed by Lane D's encryption-service.ts)
// x3dh.ts
x3dhInitiate(myKey, peerBundle): { sharedSecret: Uint8Array, ephemeralKey: RawKeyPair }
x3dhRespond(myKey, mySpk, myOtk, peerIdentity, peerEphemeral): Uint8Array

// double-ratchet.ts
ratchetEncrypt(session, plaintext): { ciphertext: Uint8Array, nonce: Uint8Array, header: Uint8Array }  // header is NOW encrypted bytes
ratchetDecrypt(session, ciphertext, nonce, encryptedHeader): Uint8Array
serializeSession(session): Uint8Array
deserializeSession(data): SessionState

// Lane B exports (consumed by Lane D's encryption-service.ts)
// sender-keys.ts — serializeSenderKey NO LONGER takes includePrivate param
serializeSenderKeyForStorage(state): Uint8Array    // includes private key, local only
serializeSenderKeyForDistribution(state): Uint8Array  // NEVER includes private key
deserializeSenderKey(data): SenderKeyState
generateSenderKey(): SenderKeyState
senderKeyEncrypt(state, plaintext): { ciphertext, nonce, signature, iteration }
senderKeyDecrypt(state, ciphertext, nonce, signature, targetIteration): Uint8Array
rotateSenderKey(spaceId): Promise<SenderKeyState>  // NEW — H4
```

---

## Lane Ownership (STRICT — no exceptions)

| Lane | Agent | Exclusive Files |
|------|-------|----------------|
| **A** | Crypto Core | `src/lib/crypto/keystore.ts`, `src/lib/crypto/types.ts`, `src/lib/crypto/x3dh.ts`, `src/lib/crypto/double-ratchet.ts`, `src/lib/crypto/primitives.ts`, NEW `src/lib/crypto/dm-routing.ts` |
| **B** | Sender Keys + Key Mgmt | `src/lib/crypto/sender-keys.ts`, `src/lib/crypto/key-manager.ts`, `src/app/api/keys/bundle/route.ts`, `src/app/api/keys/otk/route.ts` |
| **C** | Spotlight + Chat Cleanup | `src/components/os/ChatInput.tsx`, `src/components/os/XarkChat.tsx`, `src/components/os/ControlCaret.tsx`, `src/app/space/[id]/page.tsx`, `src/app/api/xark/route.ts`, `src/workers/memory-worker.ts`(DEL), `src/hooks/useLocalMemory.ts`(DEL), `src/lib/local-recall.ts`(DEL), `src/components/os/ContextCard.tsx`(DEL), `src/components/os/InlineCardPreview.tsx`(kept for playground), NEW `src/components/os/XarkSpotlight.tsx` |
| **D** | Network + Integration + Tests | `src/hooks/useE2EE.ts`, `src/app/api/message/route.ts`, `src/lib/messages.ts`, `src/lib/crypto/encryption-service.ts`, `src/lib/crypto/crypto.test.ts`, `src/lib/crypto/index.ts` |

---

## Chunk 1: Hours 1-2 (Foundation + Crypto Bedrock)

### Task A-H1: WebCrypto Migration — Non-Extractable Identity Keys

**Fixes:** P0-1 (plaintext keys in IndexedDB)

**Files:**
- Modify: `src/lib/crypto/keystore.ts` (full rewrite of identity key storage)
- Modify: `src/lib/crypto/types.ts:5-8` (update RawKeyPair to support CryptoKey)

**Context:** keystore.ts is 244 lines. Identity keys are stored as base64 strings via `serializeKeyPair()` at line 77. `saveIdentityKey()` at line 96 takes raw Uint8Array and converts to base64. Since E2EE is currently disabled (`useE2EE(null)`) and zero production users have E2EE keys, this is a clean break — no backward compatibility needed.

- [ ] **Step 1:** Add `WebCryptoIdentityKey` interface to `types.ts`

```typescript
// Add after line 8 in types.ts
/** WebCrypto-backed identity key — non-extractable private key */
export interface WebCryptoIdentityKey {
  publicKeyRaw: Uint8Array;       // extractable for distribution
  privateKeyCryptoKey: CryptoKey;  // non-extractable, stays in WebCrypto
  publicKeyCryptoKey: CryptoKey;   // for WebCrypto sign/verify
}
```

- [ ] **Step 2:** Rewrite `saveIdentityKey` / `getIdentityKey` in keystore.ts to store CryptoKey objects

The key insight: IndexedDB can natively store `CryptoKey` objects (structured clone algorithm). No serialization needed.

```typescript
// Replace lines 96-111 in keystore.ts

async saveIdentityKey(publicKeyRaw: Uint8Array, privateKeyCryptoKey: CryptoKey, publicKeyCryptoKey: CryptoKey): Promise<void> {
  const db = await this.getDB();
  const store = tx(db, STORES.identity, 'readwrite');
  await idbPut(store, 'identity', {
    publicKeyRaw: toBase64(publicKeyRaw),
    privateKeyCryptoKey,  // CryptoKey stored natively by IndexedDB
    publicKeyCryptoKey,   // CryptoKey stored natively by IndexedDB
  });
}

async getIdentityKey(): Promise<{ publicKeyRaw: Uint8Array; privateKeyCryptoKey: CryptoKey; publicKeyCryptoKey: CryptoKey } | null> {
  const db = await this.getDB();
  const store = tx(db, STORES.identity, 'readonly');
  const data = await idbGet<{ publicKeyRaw: string; privateKeyCryptoKey: CryptoKey; publicKeyCryptoKey: CryptoKey }>(store, 'identity');
  if (!data) return null;
  return {
    publicKeyRaw: fromBase64(data.publicKeyRaw),
    privateKeyCryptoKey: data.privateKeyCryptoKey,
    publicKeyCryptoKey: data.publicKeyCryptoKey,
  };
}

// Keep getIdentityKeyLegacy for migration path (reads old base64 format)
async getIdentityKeyLegacy(): Promise<RawKeyPair | null> {
  const db = await this.getDB();
  const store = tx(db, STORES.identity, 'readonly');
  const data = await idbGet<{ pub: string; priv: string }>(store, 'identity');
  if (!data || !data.pub) return null;
  return deserializeKeyPair(data);
}
```

- [ ] **Step 3:** Add `generateWebCryptoIdentityKey()` to primitives.ts

```typescript
// Add to primitives.ts — generates Ed25519 key pair via WebCrypto with non-extractable private key
export async function generateWebCryptoIdentityKey(): Promise<{
  publicKeyRaw: Uint8Array;
  privateKeyCryptoKey: CryptoKey;
  publicKeyCryptoKey: CryptoKey;
}> {
  // Ed25519 is available in WebCrypto since Chrome 113, Safari 17, Firefox 128
  const keyPair = await crypto.subtle.generateKey(
    { name: 'Ed25519' },
    false,  // NON-EXTRACTABLE — private key cannot be exported
    ['sign', 'verify']
  );
  // Export public key (extractable by design — it's public)
  const publicKeyRaw = new Uint8Array(
    await crypto.subtle.exportKey('raw', keyPair.publicKey)
  );
  return {
    publicKeyRaw,
    privateKeyCryptoKey: keyPair.privateKey,
    publicKeyCryptoKey: keyPair.publicKey,
  };
}

// WebCrypto sign using CryptoKey
export async function signWithCryptoKey(message: Uint8Array, privateKey: CryptoKey): Promise<Uint8Array> {
  const sig = await crypto.subtle.sign('Ed25519', privateKey, message);
  return new Uint8Array(sig);
}
```

- [ ] **Step 4:** Validate

```
DevTools → Application → IndexedDB → xark-keystore → identity
→ identity_key value MUST show CryptoKey object, not base64 string
→ In console: crypto.subtle.exportKey('pkcs8', storedKey) MUST throw DOMException
```

---

### Task B-H1: OTK Lifecycle Fix

**Fixes:** BUG 3 (OTK not consumed), BUG 19 (OTK exhaustion)

**Files:**
- Modify: `src/lib/crypto/key-manager.ts:74-95` (fetchPeerKeyBundle — add OTK deletion after consumption)
- Modify: `src/lib/crypto/key-manager.ts:98-119` (replenishOTKsIfNeeded — query server count)
- Modify: `src/app/api/keys/otk/route.ts` (add idempotency ON CONFLICT DO NOTHING)

- [ ] **Step 1:** In `fetchPeerKeyBundle()`, after consuming OTK, delete it from local store

```typescript
// After line 94 in key-manager.ts, add:
  // Consume the OTK locally — it's been used for this session
  if (row.otk_id) {
    await keyStore.deleteOneTimePreKey(row.otk_id);
    console.log(`[xark-e2ee] Consumed OTK ${row.otk_id}`);
  }
```

- [ ] **Step 2:** Fix `replenishOTKsIfNeeded()` to query server-side count

```typescript
// Replace lines 98-119 in key-manager.ts
export async function replenishOTKsIfNeeded(): Promise<void> {
  await initCrypto();
  const deviceId = await keyStore.getDeviceId();
  const userId = await getCurrentUserId();

  // Query server for remaining OTK count (not local — server is source of truth)
  const { count, error: countError } = await supabase
    .from('one_time_pre_keys')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', userId)
    .eq('device_id', deviceId);

  if (countError) {
    console.warn('[xark-e2ee] Failed to query OTK count:', countError.message);
    return;
  }

  if ((count ?? 0) >= OTK_REPLENISH_THRESHOLD) return;

  console.log(`[xark-e2ee] OTK count ${count}, replenishing...`);
  const otks = generateOTKBatch(OTK_BATCH_SIZE);

  // Store locally
  await keyStore.saveOneTimePreKeys(otks.map(o => ({ id: o.id, keyPair: o.keyPair })));

  // Upload public keys — ON CONFLICT DO NOTHING for idempotency
  const otkRows = otks.map(o => ({
    id: o.id,
    user_id: userId,
    device_id: deviceId,
    public_key: toBase64(o.keyPair.publicKey),
  }));

  const { error } = await supabase.from('one_time_pre_keys').upsert(otkRows, { onConflict: 'id' });
  if (error) console.warn('[xark-e2ee] OTK upload failed:', error.message);
}
```

- [ ] **Step 3:** Validate: Establish a session → consumed OTK vanishes from local IndexedDB AND server `one_time_pre_keys` table.

---

### Task C-H1: P0-2 Kill — Delete Memory Worker + Dead Code

**Fixes:** P0-2 (decrypted plaintext messages persisted in IndexedDB)

**Files:**
- Delete: `src/workers/memory-worker.ts` (129 lines)
- Delete: `src/hooks/useLocalMemory.ts` (214 lines)
- Delete: `src/lib/local-recall.ts` (38 lines)
- Delete: `src/components/os/ContextCard.tsx`
- Modify: `src/app/space/[id]/page.tsx` (remove all Memory Worker imports and Tier 2 recall logic)

- [ ] **Step 1:** Delete the 4 files

```bash
rm src/workers/memory-worker.ts
rm src/hooks/useLocalMemory.ts
rm src/lib/local-recall.ts
rm src/components/os/ContextCard.tsx
```

- [ ] **Step 2:** In `src/app/space/[id]/page.tsx`, remove imports and all Tier 2 usage

Remove these imports (search for exact strings):
- `import { useLocalMemory } from "@/hooks/useLocalMemory"`
- `import { isRecallQuestion } from "@/lib/local-recall"`
- `import { LocalIntentParser } from "@/lib/agent/LocalIntentParser"` (if present)

Remove:
- `const localMemory = useLocalMemory(spaceId);` initialization
- All `localMemory.indexMessage(...)` calls (message indexing in initial load + realtime)
- All `localMemory.search(...)` calls (Tier 2 recall)
- All `isRecallQuestion(...)` checks and the "STRICT HALT" block
- All `localMemory.watermark` references (delta sync watermark)

- [ ] **Step 3:** Remove any CRDT/GuestLinker/EnclaveTunnel branches added by the failed sprint

Search space page for these patterns and remove:
- `useCrdtStore` imports and `applyMutation` calls
- `GuestLinker` imports and `guest_votes` subscription
- `EnclaveTunnel` imports and enclave query blocks
- `LocalIntentParser` imports and intent parsing blocks
- `e2ee_crdt` message type handling

- [ ] **Step 4:** Validate

```bash
grep -r "memory-worker\|useLocalMemory\|local-recall\|ContextCard\|isRecallQuestion\|useCrdtStore\|GuestLinker\|EnclaveTunnel\|LocalIntentParser\|e2ee_crdt" src/
# MUST return zero matches
```

- [ ] **Step 5:** Verify build passes

```bash
npx next build
# MUST complete with zero errors
```

---

### Task D-H1: JWT Race Hardening

**Fixes:** BUG 1 (key registration without JWT)

**Files:**
- Modify: `src/hooks/useE2EE.ts:42-53` (harden retry with exponential backoff)

- [ ] **Step 1:** Replace retry loop with exponential backoff

```typescript
// Replace lines 42-53 in useE2EE.ts
        // BUG 1 fix: wait for JWT with exponential backoff
        const { getSupabaseToken } = await import("@/lib/supabase");
        let retries = 0;
        const maxRetries = 8;
        while (!getSupabaseToken() && retries < maxRetries) {
          const delay = Math.min(500 * Math.pow(2, retries), 4000); // 500ms, 1s, 2s, 4s...
          await new Promise(r => setTimeout(r, delay));
          retries++;
        }
        if (!getSupabaseToken()) {
          console.error("[xark-e2ee] No JWT after retries — E2EE unavailable");
          setState({ ready: true, available: false, deviceId: null });
          return;
        }
        console.log(`[xark-e2ee] JWT ready after ${retries} retries`);
```

- [ ] **Step 2:** Validate: Hard-refresh on throttled network (DevTools → Network → Slow 3G) → console shows `[xark-e2ee] JWT ready after N retries`, key registration succeeds.

---

### Task A-H2: X3DH Ephemeral Key Hardening

**Fixes:** BUG 11 (ephemeral key not in header), BUG 13 (signedPreKeyId not passed)

**Files:**
- Modify: `src/lib/crypto/x3dh.ts` (add input validation, verify return contract)

- [ ] **Step 1:** Add input validation to `x3dhInitiate`

```typescript
// Add after line 17 in x3dh.ts (inside x3dhInitiate, before existing validation)
  if (!myIdentityCurve25519.privateKey.length || !myIdentityCurve25519.publicKey.length) {
    throw new Error('X3DH: Invalid initiator identity key');
  }
```

- [ ] **Step 2:** Add input validation to `x3dhRespond`

```typescript
// Add at start of x3dhRespond body (after line 63)
  if (!peerEphemeralPublic.length) {
    throw new Error('X3DH: Missing peer ephemeral key — cannot compute shared secret');
  }
  if (!peerIdentityCurve25519Public.length) {
    throw new Error('X3DH: Missing peer identity key');
  }
```

- [ ] **Step 3:** Validate: x3dh.ts returns `{ sharedSecret, ephemeralKey }` — verify `ephemeralKey` is a full RawKeyPair with non-zero publicKey and privateKey.

---

### Task B-H2: SK Private Key Removal (FATAL BUG 15)

**Fixes:** FATAL BUG 15 (private signing key leaked in Sender Key distribution)

**Files:**
- Modify: `src/lib/crypto/sender-keys.ts:82-126` (split serialization into two functions, fix createSenderKeyDistribution)

- [ ] **Step 1:** Replace `serializeSenderKey` with two explicit functions

```typescript
// Replace lines 82-126 in sender-keys.ts with:

// ── Serialization ──

/** Serialize for LOCAL STORAGE ONLY — includes private signing key */
export function serializeSenderKeyForStorage(state: SenderKeyState): Uint8Array {
  const obj = {
    chainKey: toBase64(state.chainKey),
    signingKey: {
      pub: toBase64(state.signingKey.publicKey),
      priv: toBase64(state.signingKey.privateKey),
    },
    iteration: state.iteration,
    ...(state.createdAt && { createdAt: state.createdAt }),
  };
  return new TextEncoder().encode(JSON.stringify(obj));
}

/** Serialize for DISTRIBUTION — NEVER includes private signing key */
export function serializeSenderKeyForDistribution(state: SenderKeyState): Uint8Array {
  const obj = {
    chainKey: toBase64(state.chainKey),
    signingKey: {
      pub: toBase64(state.signingKey.publicKey),
      // Private key INTENTIONALLY OMITTED — recipients only need public key for verification
    },
    iteration: state.iteration,
    ...(state.createdAt && { createdAt: state.createdAt }),
  };
  return new TextEncoder().encode(JSON.stringify(obj));
}

/** Deserialize Sender Key state (handles both formats) */
export function deserializeSenderKey(data: Uint8Array): SenderKeyState {
  const obj = JSON.parse(new TextDecoder().decode(data));
  return {
    chainKey: fromBase64(obj.chainKey),
    signingKey: {
      publicKey: fromBase64(obj.signingKey.pub),
      privateKey: obj.signingKey.priv ? fromBase64(obj.signingKey.priv) : new Uint8Array(0),
    } as RawKeyPair,
    iteration: obj.iteration,
    createdAt: obj.createdAt,
  };
}

/** Create a distribution message — ALWAYS uses safe serialization */
export function createSenderKeyDistribution(
  spaceId: string,
  state: SenderKeyState
): { spaceId: string; serializedKey: Uint8Array } {
  return {
    spaceId,
    serializedKey: serializeSenderKeyForDistribution(state),  // NEVER includes private key
  };
}
```

- [ ] **Step 2:** Validate

```typescript
// In DevTools console or test:
const sk = generateSenderKey();
const dist = serializeSenderKeyForDistribution(sk);
const parsed = JSON.parse(new TextDecoder().decode(dist));
console.assert(!parsed.signingKey.priv, 'FATAL: private key leaked in distribution!');
// MUST pass
```

---

### Task C-H2: Remove @xark from ChatInput

**Files:**
- Modify: `src/components/os/ChatInput.tsx` (remove @xark cyan detection, voice @xark mode, XARK_HINTS)

- [ ] **Step 1:** Remove `XARK_HINTS` array (lines ~16-23)
- [ ] **Step 2:** Remove `isAskingAI = input.includes("@xark")` (line ~204)
- [ ] **Step 3:** Remove cyan `inputTextColor` conditional (line ~208) — replace with `const inputTextColor = colors.white;`
- [ ] **Step 4:** Remove text-shadow glow for @xark (lines ~209-211)
- [ ] **Step 5:** Remove `isXarkListening` references in recording banner (lines ~245-246)
- [ ] **Step 6:** Remove long-press @xark voice mode — mic is now pure dictation. Remove `startXarkMode()` from pointer handlers (lines ~191-201)
- [ ] **Step 7:** Validate: Type "@xark find hotels" in chat → text renders in default theme color, no cyan, no glow, no special behavior.

---

### Task D-H2: Broadcast-Before-DB Race Fix

**Fixes:** BUG 5, BUG 20 (Realtime broadcast fires before DB insert completes)

**Files:**
- Modify: `src/lib/crypto/encryption-service.ts:191-230` (await DB before broadcast, add retry)

- [ ] **Step 1:** In `distributeSenderKey()`, restructure to await DB write before broadcast

```typescript
// In encryption-service.ts distributeSenderKey(), replace fire-and-forget pattern:
// 1. POST to /api/message and AWAIT 200 OK
// 2. THEN broadcast via Supabase channel
// 3. Retry broadcast up to 3 times on failure

const res = await fetch('/api/message', { /* existing payload */ });
if (!res.ok) throw new Error(`SK distribution failed: ${res.status}`);

// Now safe to broadcast — DB row exists for recipients to fetch
let broadcastAttempts = 0;
while (broadcastAttempts < 3) {
  try {
    await channel.send({ type: 'broadcast', event: 'sender_key_dist', payload: { /* ... */ } });
    console.log('[xark-sk-dist] Broadcast confirmed');
    break;
  } catch (err) {
    broadcastAttempts++;
    if (broadcastAttempts >= 3) console.error('[xark-sk-dist] Broadcast failed after 3 attempts');
    await new Promise(r => setTimeout(r, 1000 * broadcastAttempts));
  }
}
```

- [ ] **Step 2:** Validate: DB insert timestamp < broadcast timestamp. Console shows `[xark-sk-dist] Broadcast confirmed`.

---

## Chunk 2: Hours 3-4 (Protocol Hardening + Group E2EE)

### Task A-H3: Ratchet Header Encryption

**Fixes:** P1-1 (plaintext ratchet headers leak public keys + message numbers to server)

**Files:**
- Modify: `src/lib/crypto/double-ratchet.ts:53-75,77-116` (encrypt header before return, decrypt header before processing)

- [ ] **Step 1:** Add header key derivation constant

```typescript
// Add after line 11 in double-ratchet.ts
import { hkdf } from './primitives';
const HEADER_KEY_INFO = 'XarkE2EE-header-key';
```

- [ ] **Step 2:** In `ratchetEncrypt`, encrypt the header

```typescript
// Replace lines 65-74 in ratchetEncrypt
  const header: RatchetHeader = {
    publicKey: session.sendRatchetKey.publicKey,
    previousCount: session.previousSendCount,
    messageNumber: session.sendMessageNumber,
  };
  session.sendMessageNumber++;

  // Encrypt message
  const { ciphertext, nonce } = aesEncrypt(plaintext, messageKey);

  // Encrypt header with key derived from root
  const headerKey = hkdf(session.rootKey, new Uint8Array(32), HEADER_KEY_INFO, 32);
  const headerBytes = new TextEncoder().encode(JSON.stringify({
    publicKey: toBase64(header.publicKey),
    previousCount: header.previousCount,
    messageNumber: header.messageNumber,
  }));
  const { ciphertext: encryptedHeader, nonce: headerNonce } = aesEncrypt(headerBytes, headerKey);

  // Pack: headerNonce (24) + encryptedHeader
  const packedHeader = new Uint8Array(headerNonce.length + encryptedHeader.length);
  packedHeader.set(headerNonce, 0);
  packedHeader.set(encryptedHeader, headerNonce.length);

  return { ciphertext, nonce, header: packedHeader };
```

- [ ] **Step 3:** Update `ratchetDecrypt` signature to accept `Uint8Array` encrypted header

```typescript
// Replace ratchetDecrypt signature — header is now encrypted bytes
export function ratchetDecrypt(
  session: SessionState,
  ciphertext: Uint8Array,
  nonce: Uint8Array,
  encryptedHeader: Uint8Array  // was: header: RatchetHeader
): Uint8Array {
  // Decrypt header
  const headerKey = hkdf(session.rootKey, new Uint8Array(32), HEADER_KEY_INFO, 32);
  const headerNonce = encryptedHeader.slice(0, 24);
  const headerCiphertext = encryptedHeader.slice(24);
  const headerBytes = aesDecrypt(headerCiphertext, headerNonce, headerKey);
  const headerObj = JSON.parse(new TextDecoder().decode(headerBytes));
  const header: RatchetHeader = {
    publicKey: fromBase64(headerObj.publicKey),
    previousCount: headerObj.previousCount,
    messageNumber: headerObj.messageNumber,
  };

  // ... rest of existing decrypt logic unchanged, using `header`
```

- [ ] **Step 4:** Validate: Inspect `message_ciphertexts.ratchet_header` in Supabase — MUST be opaque base64 blob, NOT parseable JSON with plaintext public keys.

---

### Task B-H3: SK Skipped-Key Dictionary

**Fixes:** BUG 16 (out-of-order messages fail to decrypt)

**Files:**
- Modify: `src/lib/crypto/sender-keys.ts` (add skippedKeys to SenderKeyState, modify senderKeyDecrypt)

- [ ] **Step 1:** Add `skippedKeys` to SenderKeyState in types.ts — **WAIT, types.ts is Lane A's file.**

Lane B agent: add skippedKeys handling ONLY in sender-keys.ts runtime logic. Do NOT modify types.ts. Use a module-level Map as cache.

```typescript
// Add at top of sender-keys.ts after imports
const MAX_SK_SKIP = 1000;
// Module-level skipped key cache: "spaceId:iteration" -> messageKey
const skippedSenderKeys = new Map<string, Uint8Array>();
```

- [ ] **Step 2:** Modify `senderKeyDecrypt` to cache intermediate keys and check skipped keys

```typescript
// At the start of senderKeyDecrypt, before signature verification:
  // Check skipped keys first
  const skipKey = `${toBase64(state.chainKey)}:${targetIteration}`;
  const cached = skippedSenderKeys.get(skipKey);
  if (cached) {
    skippedSenderKeys.delete(skipKey);
    // Still verify signature
    const toVerify = new Uint8Array(ciphertext.length + nonce.length);
    toVerify.set(ciphertext, 0);
    toVerify.set(nonce, ciphertext.length);
    if (!verify(signature, toVerify, state.signingKey.publicKey)) {
      throw new Error('SenderKey: Invalid message signature');
    }
    return aesDecrypt(ciphertext, nonce, cached);
  }

  // ... existing signature verification ...

  // When advancing chain, cache intermediate keys
  while (currentIteration < targetIteration - 1) {
    const { messageKey: skippedMk, nextChainKey } = kdfChain(currentChainKey);
    const cacheKey = `${toBase64(state.chainKey)}:${currentIteration + 1}`;
    skippedSenderKeys.set(cacheKey, skippedMk);
    // Enforce bounded dictionary
    if (skippedSenderKeys.size > MAX_SK_SKIP) {
      const firstKey = skippedSenderKeys.keys().next().value;
      if (firstKey) skippedSenderKeys.delete(firstKey);
    }
    currentChainKey = nextChainKey;
    currentIteration++;
  }
```

- [ ] **Step 3:** Validate: Send messages 1,2,3,4. Deliver in order 1,2,4,3. Both 4 and 3 decrypt correctly.

---

### Task C-H3: Remove @xark from Space Page sendMessage

**Files:**
- Modify: `src/app/space/[id]/page.tsx` (remove @xark Tier 1/3 detection, xark_trigger, e2ee_xark type)

- [ ] **Step 1:** Remove `hasXark` detection and `tryLocalAgent()` call (Tier 1)
- [ ] **Step 2:** Remove `hasXarkTrigger` detection (Tier 3)
- [ ] **Step 3:** Remove `xark_trigger` payload from /api/message fetch body
- [ ] **Step 4:** Remove `e2ee_xark` type assignment — all messages are now `'e2ee'`
- [ ] **Step 5:** Remove "thinking..." indicator logic (isThinking state related to @xark)
- [ ] **Step 6:** Remove `local-agent.ts` import if present
- [ ] **Step 7:** Validate: Send "@xark find hotels" → message saved as `message_type: 'e2ee'`, no server AI trigger, no thinking indicator, chat shows the text as-is.

---

### Task D-H3: Device Matching Fix

**Fixes:** BUG 7, BUG 8 (cross-device decryption attempts)

**Files:**
- Modify: `src/lib/messages.ts:93-114` (add device_id filter to fetchCiphertexts)
- Modify: `src/lib/crypto/encryption-service.ts:~511` (remove `senderDeviceId ?? 0` sentinel)

- [ ] **Step 1:** Add device_id parameter to `fetchCiphertexts`

```typescript
// Replace fetchCiphertexts signature and add device filter
export async function fetchCiphertexts(
  messageIds: string[],
  recipientDeviceId?: number  // NEW — filter to this device only
): Promise<Array<{...}>> {
  if (messageIds.length === 0) return [];

  let query = supabase
    .from("message_ciphertexts")
    .select("message_id, recipient_id, recipient_device_id, ciphertext, ratchet_header")
    .in("message_id", messageIds);

  // BUG 7/8 fix: filter by exact device ID when available
  if (recipientDeviceId !== undefined) {
    query = query.eq("recipient_device_id", recipientDeviceId);
  }

  const { data, error } = await query;
  if (error) {
    console.error("[xark] fetchCiphertexts failed:", error.message);
    return [];
  }
  return data ?? [];
}
```

- [ ] **Step 2:** In `encryption-service.ts`, replace `senderDeviceId ?? 0` with explicit device ID requirement

```typescript
// Replace line ~511: remove ?? 0 sentinel
// If senderDeviceId is null/undefined, log error and skip decryption
if (senderDeviceId == null) {
  console.error('[xark-e2ee] Missing sender device ID — cannot decrypt');
  return { text: '[missing device info]', replyTo: null, mediaUrl: null, type: 'message' };
}
```

- [ ] **Step 3:** Validate: User with 2 devices → device A fetches only its ciphertext row, device B fetches only its row.

---

### Task A-H4: Deterministic 1:1 Routing

**Files:**
- Create: `src/lib/crypto/dm-routing.ts`

- [ ] **Step 1:** Create the routing module

```typescript
// src/lib/crypto/dm-routing.ts
// Deterministic 1:1 space ID generation — both peers compute identical ID without network.

const DM_PREFIX = 'dm_';

/** Generate deterministic space ID for 1:1 chat between two users */
export function getDMSpaceId(myId: string, peerId: string): string {
  const sorted = [myId, peerId].sort();
  return `${DM_PREFIX}${sorted[0]}_${sorted[1]}`;
}

/** Check if a space ID is a 1:1 DM space */
export function isDMSpace(spaceId: string): boolean {
  return spaceId.startsWith(DM_PREFIX);
}
```

- [ ] **Step 2:** Validate: `getDMSpaceId('name_ram', 'name_kai') === getDMSpaceId('name_kai', 'name_ram')` → both return `dm_name_kai_name_ram`.

---

### Task B-H4: SK Rotation on Member Leave — Core Logic

**Files:**
- Modify: `src/lib/crypto/sender-keys.ts` (add rotateSenderKey)
- Modify: `src/lib/crypto/key-manager.ts` (add onMemberLeave)

- [ ] **Step 1:** Add `rotateSenderKey` to sender-keys.ts

```typescript
// Add at end of sender-keys.ts
/** Rotate Sender Key for a space — called when a member leaves */
export function rotateSenderKey(): SenderKeyState {
  // Generate fresh key — old key is archived, not destroyed (for historical decrypt)
  return generateSenderKey();
}
```

- [ ] **Step 2:** Add `onMemberLeave` to key-manager.ts

```typescript
// Add to key-manager.ts
import { keyStore } from './keystore';
import { rotateSenderKey, serializeSenderKeyForStorage } from './sender-keys';

/** Handle member departure — rotate Sender Key for forward secrecy */
export async function onMemberLeave(spaceId: string, _leftUserId: string): Promise<SenderKeyState> {
  // 1. Archive current key for historical message decryption
  const currentKey = await keyStore.getSenderKey(spaceId);
  if (currentKey) {
    await keyStore.saveHistoricalSenderKey(spaceId, currentKey);
  }

  // 2. Delete active key
  await keyStore.deleteSenderKey(spaceId);

  // 3. Generate new key
  const newKey = rotateSenderKey();

  // 4. Save new key locally
  await keyStore.saveSenderKey(spaceId, serializeSenderKeyForStorage(newKey));

  console.log(`[xark-e2ee] Rotated Sender Key for space ${spaceId}`);
  return newKey;
}
```

- [ ] **Step 3:** Validate: Call `onMemberLeave()` → old Sender Key archived in historical store, new key in active store, old key cannot decrypt messages encrypted with new key.

---

### Task C-H4: Build XarkSpotlight.tsx

**Files:**
- Create: `src/components/os/XarkSpotlight.tsx`
- Modify: `src/components/os/ControlCaret.tsx:127-141` (wire tap to open Spotlight)

- [ ] **Step 1:** Create XarkSpotlight component

Zero-Box doctrine. Inter font. Weight 300/400 only. No borders. Slide-up from bottom.

```typescript
// src/components/os/XarkSpotlight.tsx
// Global command bar for @xark AI — completely separate from E2EE chat pipeline.
// Triggered by ControlCaret tap on Galaxy page.
// Results go to Decide tab of selected space. Chat stays pure.
```

Component structure:
- Overlay (#000 at 0.8 opacity)
- Text input (text.input size, weight 300, placeholder "find sushi near downtown...")
- Space picker dropdown (reuse SpacePicker pattern)
- Loading state (cyan breathing dot)
- Results display (mini decision cards)
- Submit → POST /api/xark → results dispatched to Decide tab

- [ ] **Step 2:** Wire ControlCaret to open Spotlight on Galaxy

```typescript
// In ControlCaret.tsx onClick handler (line ~127-141):
// Currently: setIsOpen(prev => !prev) on Galaxy
// Change to: setSpotlightOpen(prev => !prev)
// Add state: const [spotlightOpen, setSpotlightOpen] = useState(false);
// Render: {spotlightOpen && <XarkSpotlight onClose={() => setSpotlightOpen(false)} />}
```

- [ ] **Step 3:** Validate: Tap "xark" brand anchor on Galaxy → Spotlight slides up, not space panel. Type query → select space → submit → loading → results.

---

### Task D-H4: Remove xark_trigger from /api/message

**Files:**
- Modify: `src/app/api/message/route.ts` (remove orchestrateAndUpdate, xark_trigger, message_type_override, "thinking..." placeholder)

- [ ] **Step 1:** Remove `'e2ee_xark'` from `ALLOWED_CLIENT_TYPES`

```typescript
// Change line ~54 from:
const ALLOWED_CLIENT_TYPES = ['e2ee', 'e2ee_xark', 'sender_key_dist'] as const;
// To:
const ALLOWED_CLIENT_TYPES = ['e2ee', 'sender_key_dist'] as const;
```

- [ ] **Step 2:** Remove `xark_trigger` parsing from request body
- [ ] **Step 3:** Remove `message_type_override` field handling
- [ ] **Step 4:** Delete entire `orchestrateAndUpdate()` function
- [ ] **Step 5:** Remove "thinking..." placeholder message insert
- [ ] **Step 6:** Endpoint becomes pure: receive ciphertext + distribution_ciphertexts → insert → broadcast. ~200 lines deleted.
- [ ] **Step 7:** Validate: POST to `/api/message` with `xark_trigger` → field ignored, endpoint only handles E2EE persistence.

---

## Chunk 3: Hours 5-6 (Rotation Wiring + Spotlight API + Tests)

### Task A-H5: Clean types.ts — Remove e2ee_xark

**Files:**
- Modify: `src/lib/crypto/types.ts:83` (remove e2ee_xark and e2ee_crdt from MessageType)

- [ ] **Step 1:** Update MessageType

```typescript
// Replace line 83 in types.ts
export type MessageType = 'e2ee' | 'xark' | 'system' | 'legacy' | 'sender_key_dist';
```

- [ ] **Step 2:** Validate: `tsc --noEmit` passes. `grep -r "e2ee_xark\|e2ee_crdt" src/` returns zero matches.

---

### Task B-H5: SK Rotation Realtime Wiring

**Files:**
- Modify: `src/lib/crypto/key-manager.ts` (add subscribeToMemberChanges, offline catch-up, leader election)

- [ ] **Step 1:** Add Realtime subscription for member departures

```typescript
// Add to key-manager.ts
import { supabase } from '../supabase';

/** Subscribe to member changes for SK rotation.
 *  Leader election: lowest user_id alphabetically triggers rotation (deterministic, no coordination). */
export function subscribeToMemberChanges(
  spaceId: string,
  myUserId: string,
  members: string[],
  onRotation: (newKey: SenderKeyState) => void
): () => void {
  const channel = supabase
    .channel(`members:${spaceId}`)
    .on('postgres_changes', {
      event: 'DELETE',
      schema: 'public',
      table: 'space_members',
      filter: `space_id=eq.${spaceId}`,
    }, async (payload) => {
      const leftUserId = (payload.old as { user_id: string }).user_id;

      // Leader election: lowest alphabetical user_id among remaining members triggers rotation
      const remainingMembers = members.filter(m => m !== leftUserId).sort();
      const isLeader = remainingMembers[0] === myUserId;

      if (isLeader) {
        console.log(`[xark-e2ee] I am rotation leader for space ${spaceId}`);
        const newKey = await onMemberLeave(spaceId, leftUserId);
        onRotation(newKey);
      } else {
        console.log(`[xark-e2ee] Waiting for leader to rotate SK for space ${spaceId}`);
        // Non-leaders will receive the new SK via sender_key_dist message
      }
    })
    .subscribe();

  return () => { supabase.removeChannel(channel); };
}
```

- [ ] **Step 2:** Validate: User C leaves group → User A (lowest ID) triggers rotation → User B receives new SK via distribution → User C cannot decrypt future messages.

---

### Task C-H5: Simplify /api/xark for Spotlight

**Files:**
- Modify: `src/app/api/xark/route.ts` (return structured JSON only, no message persistence)

- [ ] **Step 1:** Rewrite endpoint contract

New contract: `POST { query, spaceId, userId }` → `{ results: DecisionItem[], synthesis: string }`

Remove:
- `supabaseAdmin` message persistence (no more saving @xark response as a message)
- `messageId` return (Spotlight doesn't need it)
- Realtime broadcast of @xark response (Spotlight handles display)

Keep:
- PII sanitization before Gemini call
- Intelligence orchestrator (gemini-local, gemini-search, apify tiers)
- Grounding context (state map approach)

- [ ] **Step 2:** Validate: POST query → response has `results[]` array. No message row created in `messages` table. No Realtime event.

---

### Task D-H5: Write Phase 1-2 Tests

**Files:**
- Modify: `src/lib/crypto/crypto.test.ts` (add 8+ new test cases)

- [ ] **Step 1:** Test WebCrypto identity key generation

```typescript
describe('WebCrypto Identity Keys', () => {
  it('generates non-extractable private key', async () => {
    // This test requires browser environment — skip in Node
    // Validates that CryptoKey with extractable:false cannot be exported
  });
});
```

- [ ] **Step 2:** Test SK distribution never contains private key

```typescript
it('distribution serialization excludes private key', () => {
  const sk = generateSenderKey();
  const dist = serializeSenderKeyForDistribution(sk);
  const parsed = JSON.parse(new TextDecoder().decode(dist));
  expect(parsed.signingKey.priv).toBeUndefined();
});

it('storage serialization includes private key', () => {
  const sk = generateSenderKey();
  const stored = serializeSenderKeyForStorage(sk);
  const parsed = JSON.parse(new TextDecoder().decode(stored));
  expect(parsed.signingKey.priv).toBeDefined();
  expect(parsed.signingKey.priv.length).toBeGreaterThan(0);
});
```

- [ ] **Step 3:** Test X3DH rejects zero-length keys

```typescript
it('rejects zero-length initiator identity key', () => {
  expect(() => x3dhInitiate(
    { publicKey: new Uint8Array(0), privateKey: new Uint8Array(0) },
    validPeerBundle
  )).toThrow('Invalid initiator identity key');
});
```

- [ ] **Step 4:** Test SK skipped-key dictionary (out-of-order decrypt)
- [ ] **Step 5:** Test ratchet header is encrypted (base64 blob, not parseable JSON)
- [ ] **Step 6:** Validate: `npx vitest run` — all 33 existing + 8 new tests pass.

---

### Task D-H6: Write Phase 3 Tests

**Files:**
- Modify: `src/lib/crypto/crypto.test.ts` (add 6+ new test cases)

- [ ] **Step 1:** Test SK rotation produces fresh key

```typescript
it('rotation generates new key distinct from old', () => {
  const old = generateSenderKey();
  const rotated = rotateSenderKey();
  expect(toBase64(rotated.chainKey)).not.toBe(toBase64(old.chainKey));
});
```

- [ ] **Step 2:** Test old key cannot decrypt messages encrypted with new key
- [ ] **Step 3:** Test createSenderKeyDistribution uses safe serialization
- [ ] **Step 4:** Validate: All 33 + 8 + 6 = 47 tests pass.

---

## Chunk 4: Hours 7-8 (Integration + Verification)

### Task A-H7: Crypto Core Audit

**Files:**
- All Lane A files (read-only verification + comments)

- [ ] **Step 1:** Verify all comparisons use `constantTimeEqual` (no `===` on key bytes)
- [ ] **Step 2:** Verify XChaCha20 uses random 24-byte nonce per encrypt (no reuse)
- [ ] **Step 3:** Verify no key material logged to console (redact in all log statements)
- [ ] **Step 4:** Add WebCrypto feature detection fallback — if browser doesn't support Ed25519 in WebCrypto, fall back to libsodium with warning

---

### Task B-H7: SK Interface Verification

**Files:**
- All Lane B files (read-only verification)

- [ ] **Step 1:** Verify `serializeSenderKeyForDistribution` is called in ALL distribution paths
- [ ] **Step 2:** Verify `serializeSenderKeyForStorage` is called in ALL local storage paths
- [ ] **Step 3:** Verify no path exists where private key can leak to network
- [ ] **Step 4:** Document rotation protocol in code comments

---

### Task C-H7: End-to-End Spotlight Flow + Debug Banner Removal

**Files:**
- `src/components/os/XarkSpotlight.tsx`, `src/components/os/ControlCaret.tsx`, `src/app/space/[id]/page.tsx`

- [ ] **Step 1:** Test: tap ControlCaret → Spotlight opens → type query → select space → results appear in Decide tab
- [ ] **Step 2:** Verify chat timeline has zero @xark responses, zero thinking indicators
- [ ] **Step 3:** Remove debug banner from Space page (green monospace overlay)
- [ ] **Step 4:** Validate: `grep -r "debug.*banner\|Debug.*Banner" src/` returns zero matches

---

### Task D-H7: RE-ENABLE E2EE

**THE BIG ONE.**

**Files:**
- Modify: `src/app/space/[id]/page.tsx` (change `useE2EE(null)` to `useE2EE(resolvedUserId)`)
- Modify: `src/lib/crypto/encryption-service.ts` (update to use new interfaces from Lanes A+B)
- Modify: `src/lib/crypto/index.ts` (update exports)

- [ ] **Step 1:** Change `useE2EE(null)` to `useE2EE(resolvedUserId)` in Space page

```typescript
// Replace the disabled line:
// const e2ee = useE2EE(null);
// With:
const e2ee = useE2EE(resolvedUserId);
```

- [ ] **Step 2:** Update encryption-service.ts to use new sender-keys exports

```typescript
// Replace all serializeSenderKey(state, false) calls with:
serializeSenderKeyForDistribution(state)

// Replace all serializeSenderKey(state) calls (local storage) with:
serializeSenderKeyForStorage(state)
```

- [ ] **Step 3:** Remove `(session as any)._x3dhEphemeralPub` type hack — use proper typed metadata

- [ ] **Step 4:** Update crypto/index.ts to export new functions

```typescript
export * from './types';
export * from './primitives';
export * from './keystore';
export * from './x3dh';
export * from './double-ratchet';
export * from './sender-keys';
export * from './key-manager';
export * from './encryption-service';
export * from './dm-routing';
```

- [ ] **Step 5:** Validate: E2EE state shows `{ ready: true, available: true, deviceId: <number> }` in React DevTools. Messages sent with `message_type: 'e2ee'`. Ciphertext appears in `message_ciphertexts` table.

---

### Task A-H8: Update SECURITY.md — Crypto Sections

**Files:**
- Modify: `SECURITY.md` (sections 3, 4, 5, 16)

- [ ] **Step 1:** Section 3: Add WebCrypto non-extractable keys description
- [ ] **Step 2:** Section 4: Update IndexedDB description to reflect CryptoKey objects
- [ ] **Step 3:** Section 5: Document encrypted ratchet headers
- [ ] **Step 4:** Section 16: Remove "Known limitations" entry about plaintext IndexedDB keys. Add: "WebCrypto requires Chrome 113+, Safari 17+, Firefox 128+"
- [ ] **Step 5:** Validate: SECURITY.md accurately reflects v2 implementation. No false claims.

---

### Task B-H8: Update SECURITY.md — Key Management Sections

**Files:**
- Modify: `SECURITY.md` (sections 4, 5, 11, 16)

- [ ] **Step 1:** Section 4: Document OTK lifecycle (upload → consume → delete → replenish)
- [ ] **Step 2:** Section 5: Document SK rotation on member leave
- [ ] **Step 3:** Section 11: Update security hardening list
- [ ] **Step 4:** Remove "Sender Key distribution not fully wired" from known limitations
- [ ] **Step 5:** Add: "SK rotation enforced on member leave, O(N^2) acceptable for N<=15"

---

### Task C-H8: Update primer.md + Final Verification

**Files:**
- Modify: `primer.md`

- [ ] **Step 1:** Update primer.md with session summary: what was built, files modified, decisions made
- [ ] **Step 2:** Run full cleanup verification

```bash
grep -r "e2ee_xark\|memory.worker\|local-recall\|@xark.*cyan\|isAskingAI\|XARK_HINTS\|orchestrateAndUpdate\|xark_trigger\|useCrdtStore\|GuestLinker\|EnclaveTunnel\|e2ee_crdt" src/
# MUST return zero matches
```

- [ ] **Step 3:** Final build

```bash
npx next build
# MUST complete with zero errors
```

---

### Task D-H8: Update State + Integration Test

**Files:**
- Modify: `.xark-state.json` (update foveal_focus, component_registry)
- Modify: `src/lib/crypto/crypto.test.ts` (add integration test)

- [ ] **Step 1:** Update `.xark-state.json`:
  - `foveal_focus`: "E2EE re-enabled. Spotlight live. Memory Worker deleted. All P0/P1 crypto bugs fixed."
  - `component_registry`: Mark MemoryWorker/LocalRecall/ContextCard as "deleted". Add XarkSpotlight as "verified".
  - Remove `e2ee_xark` and `e2ee_crdt` from any type references

- [ ] **Step 2:** Write integration test

```typescript
describe('E2EE Integration', () => {
  it('full message lifecycle: generate keys → encrypt → persist → decrypt', async () => {
    await initCrypto();
    const aliceIdentity = generateIdentityKeyPair();
    const bobIdentity = generateIdentityKeyPair();
    // ... establish session, encrypt, decrypt, verify plaintext matches
  });
});
```

- [ ] **Step 3:** Run all tests: `npx vitest run` — ALL pass
- [ ] **Step 4:** Final build: `npx next build` — clean

---

## Cross-Lane Dependency Map

```
Hour:  1    2    3    4    5    6    7    8
A:    [H1]→[H2]→[H3]→[H4] [H5] [  ]→[H7]→[H8]
B:    [H1]→[H2]→[H3]→[H4]→[H5] [  ]→[H7]→[H8]
C:    [H1]→[H2]→[H3]→[H4] [H5] [  ]→[H7]→[H8]
D:    [H1]→[H2]→[H3]→[H4]→[H5]→[H6]→[H7]→[H8]
                                        ↑
                              D-H7 reads A+B completed work
```

Only cross-lane dependency: **D-H7** (re-enable E2EE) must wait for Lanes A and B to complete Hours 1-5.

---

## Cleanup: Orphaned Files from Failed Sprint

After all lanes complete, one agent should verify these files from the failed antigravity sprint are NOT imported anywhere and can be moved to dump:

- `src/lib/crypto/CryptoProvider.ts` (scaffold, fake NativeCrypto)
- `src/lib/crypto/DeviceLinker.ts` (scaffold, never instantiated)
- `src/lib/crypto/GuestLinker.ts` (fake encryption)
- `src/lib/crypto/LazyRotator.ts` (fake encryption)
- `src/lib/agent/EnclaveTunnel.ts` (fake encryption)
- `src/lib/agent/LocalIntentParser.ts` (functional but replaced by Spotlight)
- `src/lib/store/useCrdtStore.ts` (functional but not needed for v2)
- `src/lib/store/crdt-types.ts` (types for above)

Verify with: `grep -r "CryptoProvider\|DeviceLinker\|GuestLinker\|LazyRotator\|EnclaveTunnel\|LocalIntentParser\|useCrdtStore\|crdt-types" src/` — if zero matches after Lane C cleanup, move to dump.
