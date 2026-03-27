# Xark E2EE Architecture Audit — Adversarial Assessment

**Auditor Persona:** Principal Cryptography Engineer, 10 years Signal/WhatsApp infrastructure
**Date:** 2026-03-16
**Codebase:** /Users/ramchitturi/xark9
**Reference:** E2EE_non-negotiable.md, SECURITY.md, mar15E2EE.md

---

## 1. EXECUTIVE SUMMARY

Xark has built a legitimate Signal Protocol implementation at the cryptographic layer. The primitives are correct — XChaCha20-Poly1305, Ed25519, X3DH, Double Ratchet, Sender Keys — and 33 unit tests verify them. This is better than 95% of startups who claim "E2EE" while shipping AES-CBC with a hardcoded IV.

**But the system is not end-to-end encrypted in any meaningful production sense.** The crypto works in isolation. The integration layer has 20 catalogued bugs (2 fatal), and more critically, the architecture makes three design choices that fundamentally undermine the E2EE guarantee:

1. **@xark intelligence receives plaintext commands.** Every `@xark find hotels` message is sent as `plaintext_command` in the `xark_trigger` payload to the server. The server reads it, calls Gemini, and processes it. This is not E2EE — this is "encrypted except when using the product's core feature."

2. **Metadata leaks reconstruct conversation content.** Space IDs are topic slugs (`space_goa-beach-trip`), user IDs contain phone digits (`phone_9642866999`), sender names are plaintext in every message row, and the `space_ledger` stores trip dates and destinations unencrypted. A compromised server doesn't need to break the crypto — the metadata tells the full story.

3. **No multi-device, no key recovery, no key transparency.** One browser = one identity. Clear your cookies and your keys are gone forever. No backup UI exists. No device linking. No way to verify you're talking to the right person. Signal solved all of these by 2019.

**Viability assessment:** The crypto primitives are a solid foundation. The integration is broken but fixable (E2EE_non-negotiable.md covers this). The metadata architecture requires a fundamental redesign to match Signal/WhatsApp's privacy guarantees. The @xark plaintext leak is an architectural contradiction that needs a design decision, not a bug fix.

---

## 2. CRITICAL VULNERABILITIES (P0/P1)

### P0-1: @xark Plaintext Command Leak

**The exploit:** User types `@xark find hotels in goa for my anniversary with priya, budget 50k`. The client sends this as `xark_trigger.plaintext_command` to `/api/message`. The server reads it, passes it to Gemini, processes it. The "encrypted" message has `content: null` on the server, but the plaintext query sits right next to it in the request body.

**Impact:** Every @xark interaction leaks the user's intent, destination, budget, dietary restrictions, and companion names to the server. This is approximately 40-60% of all meaningful user messages in a trip planning app.

**Signal/WhatsApp standard:** Neither has server-side AI processing of user messages. If they did, it would use on-device models (Apple Intelligence approach) or a secure enclave with attestation. The @xark three-tier architecture already has Tier 1 (local regex) and Tier 2 (local Web Worker search). Tier 3 (Gemini) is the only one that breaks E2EE.

**Fix options:**
- (a) Move Gemini to on-device (transformers.js with a small model — feasible for intent parsing, not for search)
- (b) Use a Trusted Execution Environment with remote attestation
- (c) Explicitly document that @xark queries are NOT encrypted and let users choose. Option (c) is the honest path for v1.

### P0-2: X3DH Ephemeral Key Discarded (BUG 11)

**The exploit:** The initiator's `x3dhInitiate()` returns `{ sharedSecret, ephemeralKey }`. The ephemeral key was being discarded. The responder used the ratchet DH key instead, producing a different shared secret. Every first-contact session produced mismatched keys. All messages between new contacts failed to decrypt.

**Status:** Fix committed (Mar 16 session). Ephemeral key now included in ratchet header's `x3dh.ephemeralKey` field. Both responder paths updated. **Untested in browser.**

**Signal standard:** The X3DH "prekey message" is a distinct message type that carries `(identityKey, ephemeralKey, usedPreKeyId, registrationId)`. Xark collapses this into the ratchet header JSON, which is fragile but functional if implemented correctly.

### P0-3: Identity Keys Stored Extractable in IndexedDB

**The exploit:** `keystore.ts` stores the Ed25519 identity private key as `toBase64(privateKey)` in IndexedDB. Any JavaScript running on the same origin (XSS, browser extension, injected script) can read it. With the identity key, an attacker can:
- Impersonate the user in X3DH negotiations
- Derive the HKDF key used for memory index blob encryption
- Decrypt all Sender Keys distributed to this user

**Signal standard:** Signal uses platform keystores (Android Keystore, iOS Keychain) with hardware-backed non-extractable keys. The WebCrypto API offers `generateKey({ extractable: false })` which binds keys to the origin's opaque storage — JavaScript cannot read the raw bytes. Xark uses libsodium's raw `Uint8Array` keys because it needs the bytes for custom protocol operations (X3DH, Double Ratchet). This is the fundamental tension of doing Signal Protocol in a browser without WebCrypto integration.

**Fix:** No easy fix within the current libsodium architecture. Mitigation: encrypt the IndexedDB keystore with a user-provided password (Argon2id key derivation). The `createKeyBackup`/`restoreKeyBackup` functions exist but have no UI. Ship the backup password prompt.

### P1-1: Private Signing Key in Sender Key Distribution (BUG 15)

**The exploit:** `serializeSenderKey()` was including `signingKey.privateKey` in the distribution payload. Every group member received the sender's private signing key. Any member could forge messages that pass signature verification, impersonating the sender to all other members.

**Status:** Fix committed (Mar 16 session). `serializeSenderKey(state, false)` now excludes the private key for distribution. Recipients get only the public key for verification.

**Signal standard:** Signal never distributes private signing keys. The sender signs; recipients verify with the public key. Correct.

### P1-2: Sender Key Never Rotated on Member Leave (BUG 18)

**The exploit:** When a member leaves (or is removed from) a group, their copy of the Sender Key is not invalidated. They retain the chain key and can derive all future message keys, decrypting every message sent after their departure.

**Signal standard:** Signal rotates Sender Keys on every membership change. The remaining members generate new Sender Keys and redistribute via pairwise sessions. This is computationally expensive (O(N) pairwise encryptions) but necessary for forward secrecy on member departure.

**Status:** Not implemented. Deferred to v2. This is a shipping blocker for any group with more than 2 people if privacy is a genuine concern.

---

## 3. SCALING & STATE BOTTLENECKS

### OTK Exhaustion

The system generates 100 OTKs on registration. `replenishOTKsIfNeeded()` checks the **local** IndexedDB count, which is never decremented (BUG 3 — consumed OTKs are not deleted locally). Result: the server runs out of OTKs while the client thinks it has plenty. Replenishment never triggers.

**At 1M users:** If each user contacts 50 new people per month, that's 50M OTK consumptions. With 100 OTKs per user and no replenishment, OTKs are exhausted within 2 months for active users. X3DH falls back to 3-DH (no OTK), which is functional but loses one layer of forward secrecy on the first message.

**Fix:** After `fetch_key_bundle` returns, delete the consumed OTK locally. Query server count for replenishment decisions, not local count.

### fetch_key_bundle Race Condition

The RPC uses `FOR UPDATE SKIP LOCKED`, which is the correct PostgreSQL primitive for atomic OTK consumption. Two simultaneous requests will get different OTKs (or one gets null if only one remains). **No race condition.** This is well-designed.

### In-Memory Rate Limiter

The rate limiter uses a `Map<string, number[]>()` in process memory. On Vercel (serverless), each invocation may run in a separate cold-started process. The Map is not shared. Rate limiting provides zero protection in production.

**At 1M users:** An attacker can trivially exhaust API quotas (Gemini, Apify) by spamming @xark from multiple IPs, each hitting a fresh serverless instance with an empty rate limit Map.

**Fix:** Upstash Redis (`@upstash/ratelimit`) — free tier covers 10K requests/day, $0.25/100K after that.

### Realtime Channel Proliferation

Each space creates multiple Supabase Realtime channels (`chat:${spaceId}`, `horizon:${spaceId}`, `ledger:${spaceId}`). Each user subscribes to channels for every space they're in.

**At 1M users with 5 spaces each:** 5M channel subscriptions × 3 channels = 15M concurrent subscriptions. Supabase Pro supports 500 concurrent connections. This architecture melts at ~150 concurrent users.

**Fix:** Multiplex channels (one channel per user, not per space). Or use a dedicated WebSocket gateway (Ably, Pusher) instead of Supabase Realtime for message delivery.

---

## 4. METADATA & LAYER 3 LEAKS

### Space ID = Topic Slug

`space_goa-beach-trip`, `space_ravis-birthday`, `space_friday-dinner`. These appear in:
- URL bar (visible to browser history, ISP, network proxy)
- Supabase Realtime channel names (visible to Supabase infrastructure)
- Every `messages` row, `decision_items` row, `space_members` row
- API request/response payloads

**Fix:** Use opaque UUIDs (`space_a7f3e2...`) for space IDs. Store the human-readable title only in the `spaces.title` column (which is already server-side). The `getOptimisticSpaceId()` function that generates slugs from titles must be replaced with `crypto.randomUUID()`.

### User ID = Phone Number

`phone_9642866999` contains the last 10 digits of the user's phone number. This appears in every message row (`user_id`), every membership row, every API request, and every Realtime broadcast. Anyone with read access to any table knows every user's phone number.

**Signal standard:** Signal uses opaque UUIDs for user identity. Phone numbers are only used for initial registration and discovery, never stored in message metadata.

**Fix:** Use opaque UUIDs for `user_id`. Map phone → UUID only in a separate `phone_lookup` table with restricted access.

### sender_name in Plaintext

Every message row stores `sender_name` in plaintext alongside the encrypted content. The server knows who sent every message in every space, with timestamps. Combined with space_id slugs, the server can reconstruct: "venky sent a message to the goa-beach-trip group at 3:47 PM."

**Signal standard:** Signal stores only (sender_uuid, timestamp, encrypted_payload). The sender's display name is inside the encrypted payload, not in the message envelope.

**Fix:** Remove `sender_name` from the `messages` table. Include it inside the encrypted payload (Layer 2). Recipients decrypt it along with the message content.

### space_ledger is a Conversation Transcript

The `space_ledger` stores `{ actor_name, action: "update_dates", payload: { start_date: "2026-06-01", end_date: "2026-06-05" } }` in plaintext. A compromised server (or a Supabase employee, or a law enforcement subpoena) can read:
- Who is traveling where and when
- Who changed plans and why
- The complete administrative history of every trip

Combined with `decision_items` (also unencrypted Layer 3: restaurant names, hotel names, prices, vote scores), the server has a more detailed picture of the user's plans than the encrypted chat would reveal.

**This is by design** — Layer 3 is explicitly unencrypted for @xark intelligence. But it means Xark's E2EE claim is: "We encrypt your chat messages, but we can see your entire trip itinerary, budget, food preferences, and travel dates in plaintext." This should be clearly disclosed.

---

## 5. ACTIONABLE REMEDIATION PLAN

### Tier 1 — Ship Blockers (must fix before claiming "E2EE")

- [ ] Verify BUG 11 fix in browser — two-device test with real phone auth
- [ ] Ship backup password UI — without it, users lose all keys on browser clear
- [ ] Fix OTK replenishment (BUG 3) — delete consumed OTKs locally
- [ ] Disclose @xark plaintext — add visible indicator when @xark query is sent to server: "this message is processed by our AI and is not end-to-end encrypted"
- [ ] Replace slug-based space IDs with opaque UUIDs
- [ ] Replace `phone_XXXXXXXXXX` user IDs with opaque UUIDs
- [ ] Move `sender_name` inside encrypted payload
- [ ] Implement Sender Key rotation on member leave (BUG 18)

### Tier 2 — Production Hardening

- [ ] Replace in-memory rate limiter with Upstash Redis
- [ ] Add key transparency log (public append-only record of key changes)
- [ ] Ship device management UI (list devices, revoke old ones)
- [ ] Implement device linking (QR code for multi-device)
- [ ] Add skipped-key dictionary to Sender Keys (BUG 16, out-of-order messages)
- [ ] Encrypt the IndexedDB keystore with user password (Argon2id)

### Tier 3 — Signal Parity

- [ ] Move @xark intent parsing on-device (small local model)
- [ ] Implement Sealed Sender (hide sender identity from server)
- [ ] Add message padding (fixed-size payloads to prevent length analysis)
- [ ] Implement private contact discovery (PSI protocol)
- [ ] Regular third-party security audit

---

## THE BOTTOM LINE

Xark's crypto primitives are sound. The integration bugs are fixable in 2 focused days (E2EE_non-negotiable.md is the roadmap). The metadata leaks require architectural changes that touch every table and every API — that's a 2-week refactor.

The fundamental question Xark must answer: **Is @xark (the AI) part of the encrypted system or outside it?** Right now it's outside — and that's fine if disclosed. Signal doesn't have server-side AI. WhatsApp doesn't either. If Xark wants AI + E2EE, the AI must run on-device. There is no middle ground that is both honest and encrypted.

Ship the disclosure. Fix the integration bugs. Refactor the identifiers. Then you have a legitimate E2EE system with a clearly scoped AI carve-out. That's a defensible product.
