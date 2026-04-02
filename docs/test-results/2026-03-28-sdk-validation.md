# E2EE Chat SDK — Validation Report

**Date:** 2026-04-02
**Total:** 100 tests | ✅ 92 passed | ❌ 8 failed

## Stress Tests (50)

| # | Test | Status | Time |
|---|------|--------|------|
| 1 | STRESS-01: Valid JWT accepted | ❌ Expected 200, got 400 | 345ms |
| 2 | STRESS-02: Expired JWT rejected | ✅ | 1136ms |
| 3 | STRESS-03: Invalid JWT rejected | ✅ | 11ms |
| 4 | STRESS-04: Missing auth header rejected | ✅ | 5ms |
| 5 | STRESS-05: Empty bearer rejected | ✅ | 12ms |
| 6 | STRESS-06: Upload key bundle | ✅ | 210ms |
| 7 | STRESS-07: Upload Bob key bundle | ✅ | 161ms |
| 8 | STRESS-08: Upload Charlie key bundle | ✅ | 97ms |
| 9 | STRESS-09: Upload key bundle with missing fields rejects | ✅ | 9ms |
| 10 | STRESS-10: Upload key bundle idempotent (upsert) | ✅ | 86ms |
| 11 | STRESS-11: Upload batch OTKs | ✅ | 119ms |
| 12 | STRESS-12: Upload 100 OTKs (max batch) | ✅ | 188ms |
| 13 | STRESS-13: Upload 201 OTKs rejected (over limit) | ✅ | 17ms |
| 14 | STRESS-14: Upload OTKs with empty array | ✅ | 13ms |
| 15 | STRESS-15: Upload OTKs for different device | ✅ | 70ms |
| 16 | STRESS-16: Contact check empty list | ❌ Expected 200, got 400 | 9ms |
| 17 | STRESS-17: Contact check with phones | ✅ | 96ms |
| 18 | STRESS-18: Contact check max 500 | ✅ | 266ms |
| 19 | STRESS-19: Contact check over 500 rejected | ✅ | 7ms |
| 20 | STRESS-20: Contact check finds registered user | ✅ | 143ms |
| 21 | STRESS-21: Send message to valid group | ✅ | 140ms |
| 22 | STRESS-22: Send message non-member rejected | ✅ | 79ms |
| 23 | STRESS-23: Send message idempotent (same UUID) | ❌ Dedup should return same seq: 2 vs undefined | 221ms |
| 24 | STRESS-24: Send 10 messages sequentially — seq increases | ✅ | 710ms |
| 25 | STRESS-25: Send 5 concurrent messages — all succeed | ✅ | 272ms |
| 26 | STRESS-26: Send message with ciphertexts | ✅ | 90ms |
| 27 | STRESS-27: Send message missing fields rejected | ✅ | 9ms |
| 28 | STRESS-28: Send message invalid message_type rejected | ✅ | 4ms |
| 29 | STRESS-29: Send message from Bob | ✅ | 58ms |
| 30 | STRESS-30: Send message from Charlie | ✅ | 58ms |
| 31 | STRESS-31: Create 1:1 chat | ✅ | 84ms |
| 32 | STRESS-32: Proxy scrape external URL | ✅ | 87ms |
| 33 | STRESS-33: Proxy scrape invalid URL rejected | ✅ | 8ms |
| 34 | STRESS-34: Proxy scrape SSRF blocked (localhost) | ✅ | 5ms |
| 35 | STRESS-35: Proxy scrape SSRF blocked (internal IP) | ✅ | 5ms |
| 36 | STRESS-36: GET on POST-only endpoint rejected | ✅ | 4ms |
| 37 | STRESS-37: Invalid JSON body handled | ✅ | 9ms |
| 38 | STRESS-38: Very large body handled | ✅ | 293ms |
| 39 | STRESS-39: Nonexistent endpoint returns 404 | ✅ | 114ms |
| 40 | STRESS-40: OPTIONS request handled (CORS) | ✅ | 5ms |
| 41 | STRESS-41: group_sequences exists and increments | ✅ | 56ms |
| 42 | STRESS-42: Messages have server_seq | ✅ | 160ms |
| 43 | STRESS-43: Ciphertexts linked to messages | ✅ | 134ms |
| 44 | STRESS-44: read_watermarks table accessible | ✅ | 63ms |
| 45 | STRESS-45: sk_acknowledgments table accessible | ✅ | 51ms |
| 46 | STRESS-46: 20 concurrent message sends | ✅ | 394ms |
| 47 | STRESS-47: 3 users send simultaneously | ✅ | 70ms |
| 48 | STRESS-48: 10 concurrent key bundle uploads | ✅ | 179ms |
| 49 | STRESS-49: Sequential seq assignment under concurrency | ✅ | 210ms |
| 50 | STRESS-50: Message send latency < 2000ms | ✅ | 59ms |

## Crypto Tests (50)

| # | Test | Status | Time |
|---|------|--------|------|
| 1 | CRYPTO-01: UUIDv7 format valid | ✅ | 1ms |
| 2 | CRYPTO-02: UUIDv7 time-ordered | ✅ | 2ms |
| 3 | CRYPTO-03: UUIDv7 unique (100 generated) | ✅ | 1ms |
| 4 | CRYPTO-04: UUIDv7 embeds current timestamp | ✅ | 0ms |
| 5 | CRYPTO-05: UUIDv7 version nibble is 7 | ✅ | 0ms |
| 6 | CRYPTO-06: Key bundle stored correctly | ✅ | 56ms |
| 7 | CRYPTO-07: OTKs stored and retrievable | ✅ | 59ms |
| 8 | CRYPTO-08: Key bundle per-device isolation | ✅ | 146ms |
| 9 | CRYPTO-09: PQXDH columns exist on key_bundles | ✅ | 143ms |
| 10 | CRYPTO-10: PQXDH columns exist on one_time_pre_keys | ✅ | 56ms |
| 11 | CRYPTO-11: Ciphertext stored with recipient info | ✅ | 138ms |
| 12 | CRYPTO-12: Multiple ciphertexts per message (fan-out) | ✅ | 136ms |
| 13 | CRYPTO-13: Ciphertext has created_at (partition-ready) | ✅ | 191ms |
| 14 | CRYPTO-14: Server never stores plaintext | ✅ | 53ms |
| 15 | CRYPTO-15: Ciphertext is base64 encoded | ✅ | 57ms |
| 16 | CRYPTO-16: Same UUID -> same server_seq (idempotent) | ❌ Message IDs should match | 141ms |
| 17 | CRYPTO-17: Dedup returns created_at | ❌ Dedup response should include created_at | 129ms |
| 18 | CRYPTO-18: Different UUIDs -> different server_seqs | ✅ | 208ms |
| 19 | CRYPTO-19: Clock skew > 5min rejected | ✅ | 54ms |
| 20 | CRYPTO-20: Clock skew < 5min accepted | ✅ | 59ms |
| 21 | CRYPTO-21: JWT with wrong secret rejected | ✅ | 6ms |
| 22 | CRYPTO-22: JWT without sub claim rejected | ✅ | 4ms |
| 23 | CRYPTO-23: JWT with HS384 algorithm rejected | ✅ | 5ms |
| 24 | CRYPTO-24: JWT sub maps to correct user | ✅ | 110ms |
| 25 | CRYPTO-25: Different users isolated | ✅ | 112ms |
| 26 | CRYPTO-26: Membership check prevents cross-group injection | ✅ | 113ms |
| 27 | CRYPTO-27: E2EE messages have no server_content | ✅ | 115ms |
| 28 | CRYPTO-28: Sender key distribution type accepted | ✅ | 61ms |
| 29 | CRYPTO-29: Group-scoped sequence isolation | ✅ | 176ms |
| 30 | CRYPTO-30: RLS prevents cross-user key bundle access | ✅ | 50ms |
| 31 | CRYPTO-31: No duplicate messages after concurrent sends | ✅ | 178ms |
| 32 | CRYPTO-32: No duplicate ciphertexts after concurrent sends | ✅ | 172ms |
| 33 | CRYPTO-33: Monotonic seq even under concurrency | ✅ | 114ms |
| 34 | CRYPTO-34: Key bundle upsert preserves latest | ✅ | 239ms |
| 35 | CRYPTO-35: User devices table has 5-device limit trigger | ❌ Should return array | 62ms |
| 36 | CRYPTO-36: SK acknowledgments writable | ✅ | 107ms |
| 37 | CRYPTO-37: Read watermarks writable | ✅ | 148ms |
| 38 | CRYPTO-38: Server_seq scoped per group | ✅ | 199ms |
| 39 | CRYPTO-39: Tombstone function exists | ❌ tombstone_message should exist: {"code":"42883","d | 56ms |
| 40 | CRYPTO-40: uuidv7_to_timestamptz function exists | ✅ | 55ms |
| 41 | CRYPTO-41: XarkE2EE HKDF info strings referenced in codebase | ✅ | 1ms |
| 42 | CRYPTO-42: X3DH HKDF info string present | ✅ | 1ms |
| 43 | CRYPTO-43: PQXDH HKDF info string present | ✅ | 1ms |
| 44 | CRYPTO-44: Double Ratchet skipped key limit = 1000 | ✅ | 1ms |
| 45 | CRYPTO-45: Streaming AEAD chunk size = 64KB | ✅ | 1ms |
| 46 | CRYPTO-46: Hardware key store interface exists | ✅ | 0ms |
| 47 | CRYPTO-47: Crypto isolate with TransferableTypedData | ✅ | 1ms |
| 48 | CRYPTO-48: No plaintext logging in encryption service | ✅ | 3ms |
| 49 | CRYPTO-49: Web Locks mutex with AbortController | ✅ | 2ms |
| 50 | CRYPTO-50: Push fallback says "You may have new messages" | ❌ Should NOT mention encryption in user-facing text | 0ms |

## Failed Tests Detail

### STRESS-01: Valid JWT accepted
**Error:** Expected 200, got 400

### STRESS-16: Contact check empty list
**Error:** Expected 200, got 400

### STRESS-23: Send message idempotent (same UUID)
**Error:** Dedup should return same seq: 2 vs undefined

### CRYPTO-16: Same UUID -> same server_seq (idempotent)
**Error:** Message IDs should match

### CRYPTO-17: Dedup returns created_at
**Error:** Dedup response should include created_at

### CRYPTO-35: User devices table has 5-device limit trigger
**Error:** Should return array

### CRYPTO-39: Tombstone function exists
**Error:** tombstone_message should exist: {"code":"42883","details":null,"hint":"No operator matches the given name and argument types. You mi

### CRYPTO-50: Push fallback says "You may have new messages"
**Error:** Should NOT mention encryption in user-facing text

