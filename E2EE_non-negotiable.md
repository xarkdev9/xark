# E2EE Non-Negotiable — Fix Plan

**Status**: 20 bugs found. 2 fatal, 8 high, 6 medium, 4 low.
**Core finding**: The crypto primitives work (33 tests pass). Every bug is in the wiring/integration layer.
**Fatal blocker**: X3DH ephemeral key is discarded — every first-contact session produces mismatched shared secrets. No message between two users who've never talked will ever decrypt.

---

## The 20 Bugs

### FATAL (nothing works without fixing these)

**BUG 11 — X3DH Ephemeral Key Discarded**
- File: `src/lib/crypto/encryption-service.ts` lines 61-64
- `x3dhInitiate()` returns `{ sharedSecret, ephemeralKey }` but only `sharedSecret` is destructured. The ephemeral key is thrown away.
- The ratchet header uses `header.publicKey` (the Double Ratchet DH key) as a stand-in, but this is a DIFFERENT key pair.
- Responder runs `x3dhRespond()` with the ratchet key instead of the ephemeral key → DH2 produces wrong value → shared secrets don't match → every first-contact decrypt fails.
- **Fix**: Include `toBase64(ephemeralKey.publicKey)` in `headerJson.x3dh.ephemeralKey`. Responder reads from `headerObj.x3dh.ephemeralKey`, not `header.publicKey`.

**BUG 15 — Private Signing Key Transmitted in Sender Key Distribution**
- File: `src/lib/crypto/sender-keys.ts` line 88
- `serializeSenderKey()` includes `signingKey.privateKey` in the distribution payload.
- Every group member receives the sender's private signing key → any member can forge messages that pass signature verification.
- Signal's actual protocol only distributes the public key + chain key.
- **Fix**: Remove `priv` from serialization. Recipients only need `signingKey.publicKey` for verification.

### HIGH (decryption fails for most real scenarios)

**BUG 20 — No Broadcast of sender_key_dist to Live Recipients**
- File: `src/app/space/[id]/page.tsx` lines 564-577
- When `distributeSenderKey()` inserts SK distribution messages via `/api/message`, no Realtime broadcast is sent.
- Online recipients never receive the Sender Key until they refresh the page.
- They see "[decryption pending]" for all messages until refresh.
- **Fix**: After `/api/message` succeeds for distribution, broadcast a `sender_key_dist` event on the space channel.

**BUG 5 — Broadcast Fires Before DB Write**
- File: `src/app/space/[id]/page.tsx` lines 564-577 vs 581-618
- `broadcastMessage()` fires BEFORE the `/api/message` fetch completes.
- If recipient processes `sender_key_dist` and calls `fetchCiphertexts()`, the rows don't exist yet.
- **Fix**: Move broadcast to AFTER the `/api/message` response returns successfully.

**BUG 2 — Device ID Range Mismatch**
- File: `src/lib/crypto/keystore.ts` line 220 generates IDs up to 2147483647
- File: `src/app/api/keys/fetch/route.ts` line 24 validates device_id must be 0-255
- If local device ID > 255, peer key bundle fetches via the API route always fail 400.
- **Fix**: Change `getDeviceId()` to generate IDs in 0-999999 range (safe for int32, avoids API conflict). Remove the 0-255 restriction in `/api/keys/fetch`.

**BUG 1 — JWT Race Condition in Key Registration**
- File: `src/hooks/useE2EE.ts` line 50 + `src/lib/crypto/key-manager.ts` line 43
- `registerKeys()` writes to Supabase via the anon client. If `setSupabaseToken()` hasn't been called yet, RLS blocks the insert silently.
- `useE2EE` fires immediately when `userId` is set, but JWT might not be set yet.
- **Fix**: In `useE2EE.ts`, check `getSupabaseToken() !== null` before calling `registerKeys()`. Add a retry with delay if null.

**BUG 6 — Sender Key Lookup Fails on First Group Message**
- File: `src/lib/crypto/encryption-service.ts` line 436-439
- When user A sends first message to group, user B receives it but has no Sender Key at `spaceId:userA`.
- Returns placeholder `[encrypted message - sender key not available]`.
- This is expected ONLY if SK distribution hasn't been processed yet — but BUG 20 means distribution never arrives in real-time.
- **Fix**: Fixing BUG 20 resolves this. Also add retry: if Sender Key missing, wait 2s, check again.

**BUG 9 — sender_key_dist Outside 50-Message Window**
- File: `src/app/space/[id]/page.tsx` line 163
- `fetchMessages(spaceId, { limit: 50 })` might not include the `sender_key_dist` message if >50 messages exist.
- Result: Sender Key never found on page reload → all E2EE messages unreadable.
- **Fix**: Separate fetch for `sender_key_dist` messages: `WHERE message_type = 'sender_key_dist' AND space_id = ?` with no limit. Process these before regular messages.

**BUG 16 — Out-of-Order Group Messages Not Handled**
- File: `src/lib/crypto/sender-keys.ts` lines 72-76
- No skipped-key dictionary for Sender Keys (unlike Double Ratchet which has `skippedKeys` map).
- If message 5 arrives before message 3, message 3 can never be decrypted.
- **Fix**: Add a skipped-key cache (same pattern as Double Ratchet) or enforce sequential processing with a buffer.

**BUG 13 — SPK ID Hardcoded to 1**
- File: `src/lib/crypto/encryption-service.ts` line 231
- Responder always loads SPK with ID 1. If SPK rotation is ever implemented, this breaks.
- **Fix**: Include `signedPreKeyId` in the X3DH header metadata. Responder reads it from header.

### MEDIUM

**BUG 3 — OTK Private Keys Never Deleted Locally**
- File: `src/lib/crypto/key-manager.ts` — `keyStore.deleteOneTimePreKey()` never called
- Local OTK count is always inflated → `replenishOTKsIfNeeded()` never triggers.
- OTKs can run out on the server while the client thinks it has plenty.
- **Fix**: After `fetch_key_bundle` returns, call `keyStore.deleteOneTimePreKey(consumedOtkId)`.

**BUG 19 — OTK Replenishment Via Direct DB Write**
- File: `src/lib/crypto/key-manager.ts` line 118
- Writes directly to `supabase.from('one_time_pre_keys')` instead of using `/api/keys/otk`.
- Bypasses rate limiting and proper auth validation.
- **Fix**: Route through `/api/keys/otk` instead.

**BUG 14 — registerKeys() Bypasses API Routes**
- File: `src/lib/crypto/key-manager.ts` lines 43-65
- Direct DB writes instead of using `/api/keys/bundle` and `/api/keys/otk`.
- API routes are dead code with unused rate limiting.
- **Fix**: Route through API endpoints. Remove dead code or use it.

**BUG 7 — Device ID Ciphertext Matching Uses OR Instead of AND**
- File: `src/app/space/[id]/page.tsx` lines 190-193
- `recipient_id === resolvedUserId OR recipient_device_id === e2ee.deviceId`
- Should be AND logic to correctly match ciphertext to this specific device.
- **Fix**: Change to AND: `recipient_id === resolvedUserId && recipient_device_id === e2ee.deviceId`.

**BUG 12 — Distribution Fallback Never Executes**
- File: `src/lib/crypto/encryption-service.ts` line 166-192
- Dead code fallback path. If `/api/message` fails, distribution is silently lost.
- No retry mechanism exists.
- **Fix**: Add retry (3 attempts with exponential backoff) on `/api/message` failure.

**BUG 18 — No Sender Key Rotation on Member Leave**
- Missing entirely. Deferred to v2.
- Anyone who was ever a member retains their Sender Key and can decrypt future messages.
- **Fix (v2)**: On member leave, all remaining members generate new Sender Keys + distribute.

### LOW

**BUG 4 — Sender Key Iteration Off-by-One**
- File: `src/lib/crypto/sender-keys.ts` line 30
- `iteration++` happens before encrypt returns. Functionally consistent within a session but confusing.
- Not a runtime failure — just a code clarity issue.

**BUG 8 — fetchCiphertexts Returns All Rows (No Recipient Filter)**
- File: `src/lib/messages.ts` line 104
- Fetches all ciphertext rows per message ID, including rows for other recipients.
- Wastes decrypt calls (silently caught) but doesn't break correctness.
- **Fix**: Add `.eq('recipient_id', userId)` or `.in('recipient_id', [userId, '_group_'])` filter.

**BUG 17 — Dummy __sender_key_dist__ Row Confuses Batch Decrypt**
- File: `/api/message/route.ts` line 111-125
- The placeholder ciphertext `__sender_key_dist__` gets returned by `fetchCiphertexts()`.
- Decrypt fails silently on this row. Wasteful but not broken.

**BUG 10 — Direct RPC vs API Route Inconsistency**
- `distributeSenderKey()` calls `supabase.rpc('fetch_key_bundle')` directly.
- `/api/keys/fetch` exists but is only used externally.
- Not a bug — just inconsistent patterns.

---

## Task Execution Order

### Phase 1: Fix Fatal Bugs (must do first — nothing works without these)

- [ ] **Task 1**: Fix BUG 11 — X3DH ephemeral key
  - `encryption-service.ts`: Save ephemeral key from `x3dhInitiate()`, include in header as `x3dh.ephemeralKey`
  - `processSenderKeyDistribution()`: Read `x3dh.ephemeralKey` from header, use for `x3dhRespond()`
  - `decryptMessage()` responder path: Same fix
  - Update `crypto.test.ts` with integration test

- [ ] **Task 2**: Fix BUG 15 — Remove private signing key from distribution
  - `sender-keys.ts`: `serializeSenderKey()` — exclude `signingKey.privateKey`
  - `sender-keys.ts`: `deserializeSenderKey()` — handle missing `priv` field
  - `senderKeyDecrypt()` — use only the public key for `verify()`
  - Verify existing tests still pass

### Phase 2: Fix High Bugs (decrypt will fail without these)

- [ ] **Task 3**: Fix BUG 1 — JWT race condition
  - `useE2EE.ts`: Check `getSupabaseToken()` before `registerKeys()`. Retry with 1s delay up to 3 times.

- [ ] **Task 4**: Fix BUG 2 — Device ID range
  - `keystore.ts`: Change `getDeviceId()` range to 0-999999
  - `/api/keys/fetch/route.ts`: Remove 0-255 restriction, allow full int32

- [ ] **Task 5**: Fix BUG 5 — Broadcast after DB write
  - `space/[id]/page.tsx`: Move `broadcastMessage()` to AFTER `/api/message` response resolves

- [ ] **Task 6**: Fix BUG 20 — Broadcast sender_key_dist
  - `encryption-service.ts` `distributeSenderKey()`: After `/api/message` succeeds, broadcast a `sender_key_dist` event on the space channel with the message ID
  - `space/[id]/page.tsx`: Handle the broadcast event to trigger `processSenderKeyDistribution()`

- [ ] **Task 7**: Fix BUG 9 — sender_key_dist outside message window
  - `space/[id]/page.tsx`: Add a separate `fetchMessages` query for ALL `sender_key_dist` messages (no limit) before the regular batch decrypt
  - Or: Add a dedicated `fetchSenderKeyDistributions(spaceId)` function in `messages.ts`

- [ ] **Task 8**: Fix BUG 6 — Sender Key retry on first message
  - `encryption-service.ts` `decryptMessage()`: If Sender Key missing, wait 2s, check IndexedDB again (SK distribution may be processing concurrently)

- [ ] **Task 9**: Fix BUG 13 — SPK ID in header
  - `encryption-service.ts`: Include `signedPreKeyId` in `x3dh` header metadata
  - `processSenderKeyDistribution()`: Read SPK ID from header instead of hardcoding 1

### Phase 3: Fix Medium Bugs (correctness + security)

- [ ] **Task 10**: Fix BUG 3 + 19 — OTK lifecycle
  - After `fetch_key_bundle` returns, delete consumed OTK locally
  - Fix `replenishOTKsIfNeeded()` to query server count instead of local count

- [ ] **Task 11**: Fix BUG 7 — Ciphertext matching AND logic
  - `space/[id]/page.tsx`: Change OR to AND in recipient/device matching

- [ ] **Task 12**: Fix BUG 8 — fetchCiphertexts recipient filter
  - `messages.ts`: Add recipient filter to ciphertext query

- [ ] **Task 13**: Fix BUG 16 — Out-of-order Sender Key messages
  - `sender-keys.ts`: Add skipped-key dictionary (same pattern as Double Ratchet)

### Phase 4: Integration Testing

- [ ] **Task 14**: Two-tab browser test
  - Tab 1: Ram (phone auth) — create space, send message
  - Tab 2: Myna (phone auth) — join space, verify message decrypts
  - Verify: key registration, SK distribution, encrypt, decrypt, page refresh

- [ ] **Task 15**: Multi-user group test
  - 3 users in one space
  - Each sends messages
  - All can read all messages
  - Verify scores/reactions still work alongside E2EE

- [ ] **Task 16**: Edge cases
  - User joins after messages were sent (should see "[encrypted message]" for pre-join messages — same as WhatsApp)
  - Page refresh with >50 messages
  - Rapid-fire messages (does chain advance correctly?)
  - User opens second tab (same keys from IndexedDB)

### Phase 5: Defer to v2

- BUG 18: Sender Key rotation on member leave
- BUG 14: Route key registration through API endpoints
- Key backup UI (password-protected Argon2id backup)
- Device linking (QR code)

---

## Files to Modify

| File | Changes |
|---|---|
| `src/lib/crypto/encryption-service.ts` | BUG 11 (ephemeral key), BUG 6 (retry), BUG 13 (SPK ID), BUG 12 (retry) |
| `src/lib/crypto/sender-keys.ts` | BUG 15 (no private key), BUG 16 (skipped keys), BUG 4 (iteration) |
| `src/lib/crypto/key-manager.ts` | BUG 3 (OTK delete), BUG 19 (replenish fix) |
| `src/lib/crypto/keystore.ts` | BUG 2 (device ID range) |
| `src/hooks/useE2EE.ts` | BUG 1 (JWT check before registration) |
| `src/app/space/[id]/page.tsx` | BUG 5 (broadcast after write), BUG 7 (AND logic), BUG 9 (SK dist fetch), BUG 20 (broadcast dist) |
| `src/app/api/keys/fetch/route.ts` | BUG 2 (remove 0-255 restriction) |
| `src/lib/messages.ts` | BUG 8 (recipient filter in fetchCiphertexts) |
| `src/lib/crypto/crypto.test.ts` | Integration tests for fixed flows |

---

## Time Estimate

| Phase | Tasks | Estimate |
|---|---|---|
| Phase 1: Fatal | 2 tasks | 2-3 hours |
| Phase 2: High | 7 tasks | 4-5 hours |
| Phase 3: Medium | 4 tasks | 2-3 hours |
| Phase 4: Testing | 3 tasks | 2-3 hours |
| **Total** | **16 tasks** | **10-14 hours (2 focused days)** |

---

## Success Criteria

E2EE is ready for production when:
1. Two phone-authenticated users can exchange encrypted messages in a group space
2. Messages decrypt correctly on page refresh
3. A third user joining the space gets Sender Keys on next message
4. The server (Supabase) never sees plaintext content
5. All 33 existing crypto tests pass + new integration tests pass
6. Console shows zero `[e2ee]` errors during a normal chat session
