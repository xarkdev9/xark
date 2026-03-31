# E2EE Chat SDK — Validation Report

**Date:** 2026-03-30
**Total:** 100 tests | ✅ 64 passed | ❌ 36 failed

## Stress Tests (50)

| # | Test | Status | Time |
|---|------|--------|------|
| 1 | STRESS-01: Valid JWT accepted | ❌ Expected 200, got 400 | 180ms |
| 2 | STRESS-02: Expired JWT rejected | ✅ | 1120ms |
| 3 | STRESS-03: Invalid JWT rejected | ✅ | 16ms |
| 4 | STRESS-04: Missing auth header rejected | ✅ | 11ms |
| 5 | STRESS-05: Empty bearer rejected | ✅ | 6ms |
| 6 | STRESS-06: Upload key bundle | ✅ | 121ms |
| 7 | STRESS-07: Upload Bob key bundle | ✅ | 73ms |
| 8 | STRESS-08: Upload Charlie key bundle | ✅ | 69ms |
| 9 | STRESS-09: Upload key bundle with missing fields rejects | ✅ | 8ms |
| 10 | STRESS-10: Upload key bundle idempotent (upsert) | ✅ | 74ms |
| 11 | STRESS-11: Upload batch OTKs | ✅ | 159ms |
| 12 | STRESS-12: Upload 100 OTKs (max batch) | ✅ | 93ms |
| 13 | STRESS-13: Upload 201 OTKs rejected (over limit) | ✅ | 13ms |
| 14 | STRESS-14: Upload OTKs with empty array | ✅ | 14ms |
| 15 | STRESS-15: Upload OTKs for different device | ✅ | 83ms |
| 16 | STRESS-16: Contact check empty list | ❌ Expected 200, got 400 | 10ms |
| 17 | STRESS-17: Contact check with phones | ✅ | 84ms |
| 18 | STRESS-18: Contact check max 500 | ✅ | 90ms |
| 19 | STRESS-19: Contact check over 500 rejected | ✅ | 7ms |
| 20 | STRESS-20: Contact check finds registered user | ✅ | 208ms |
| 21 | STRESS-21: Send message to valid group | ❌ Expected 200, got 500: {"error":"internal error"} | 23ms |
| 22 | STRESS-22: Send message non-member rejected | ❌ Expected 403, got 500 | 15ms |
| 23 | STRESS-23: Send message idempotent (same UUID) | ❌ Expected deduplicated, got undefined | 23ms |
| 24 | STRESS-24: Send 10 messages sequentially — seq increases | ❌ Seq should increase: undefined > undefined | 37026ms |
| 25 | STRESS-25: Send 5 concurrent messages — all succeed | ❌ Expected 200, got 500 | 18973ms |
| 26 | STRESS-26: Send message with ciphertexts | ❌ Expected 200, got 500 | 24ms |
| 27 | STRESS-27: Send message missing fields rejected | ✅ | 6ms |
| 28 | STRESS-28: Send message invalid message_type rejected | ✅ | 4ms |
| 29 | STRESS-29: Send message from Bob | ❌ Expected 200, got 500 | 11088ms |
| 30 | STRESS-30: Send message from Charlie | ❌ Expected 200, got 500 | 29ms |
| 31 | STRESS-31: Create 1:1 chat | ✅ | 462ms |
| 32 | STRESS-32: Proxy scrape external URL | ✅ | 88ms |
| 33 | STRESS-33: Proxy scrape invalid URL rejected | ✅ | 14ms |
| 34 | STRESS-34: Proxy scrape SSRF blocked (localhost) | ✅ | 9ms |
| 35 | STRESS-35: Proxy scrape SSRF blocked (internal IP) | ✅ | 7ms |
| 36 | STRESS-36: GET on POST-only endpoint rejected | ✅ | 5ms |
| 37 | STRESS-37: Invalid JSON body handled | ✅ | 7ms |
| 38 | STRESS-38: Very large body handled | ✅ | 5100ms |
| 39 | STRESS-39: Nonexistent endpoint returns 404 | ✅ | 118ms |
| 40 | STRESS-40: OPTIONS request handled (CORS) | ✅ | 6ms |
| 41 | STRESS-41: group_sequences exists and increments | ❌ group_sequences should have entry | 101ms |
| 42 | STRESS-42: Messages have server_seq | ❌ Should have messages | 73ms |
| 43 | STRESS-43: Ciphertexts linked to messages | ✅ | 190ms |
| 44 | STRESS-44: read_watermarks table accessible | ❌ Should return array | 63ms |
| 45 | STRESS-45: sk_acknowledgments table accessible | ❌ Should return array | 65ms |
| 46 | STRESS-46: 20 concurrent message sends | ❌ Expected >=15 successes, got 0/20 | 57484ms |
| 47 | STRESS-47: 3 users send simultaneously | ❌ Expected 200, got 500 | 13912ms |
| 48 | STRESS-48: 10 concurrent key bundle uploads | ✅ | 467ms |
| 49 | STRESS-49: Sequential seq assignment under concurrency | ❌ Last seq undefined should be > start 0 | 18646ms |
| 50 | STRESS-50: Message send latency < 2000ms | ✅ | 116ms |

## Crypto Tests (50)

| # | Test | Status | Time |
|---|------|--------|------|
| 1 | CRYPTO-01: UUIDv7 format valid | ✅ | 1ms |
| 2 | CRYPTO-02: UUIDv7 time-ordered | ✅ | 3ms |
| 3 | CRYPTO-03: UUIDv7 unique (100 generated) | ✅ | 2ms |
| 4 | CRYPTO-04: UUIDv7 embeds current timestamp | ✅ | 0ms |
| 5 | CRYPTO-05: UUIDv7 version nibble is 7 | ✅ | 0ms |
| 6 | CRYPTO-06: Key bundle stored correctly | ✅ | 116ms |
| 7 | CRYPTO-07: OTKs stored and retrievable | ✅ | 58ms |
| 8 | CRYPTO-08: Key bundle per-device isolation | ✅ | 219ms |
| 9 | CRYPTO-09: PQXDH columns exist on key_bundles | ❌ Should return array (columns exist even if null) | 59ms |
| 10 | CRYPTO-10: PQXDH columns exist on one_time_pre_keys | ❌ Should return array (column exists even if null) | 61ms |
| 11 | CRYPTO-11: Ciphertext stored with recipient info | ❌ Expected 1 ciphertext, got 0 | 89ms |
| 12 | CRYPTO-12: Multiple ciphertexts per message (fan-out) | ❌ Expected 2 ciphertexts (fan-out), got 0 | 83ms |
| 13 | CRYPTO-13: Ciphertext has created_at (partition-ready) | ✅ | 65ms |
| 14 | CRYPTO-14: Server never stores plaintext | ❌ msgs is not iterable | 61ms |
| 15 | CRYPTO-15: Ciphertext is base64 encoded | ✅ | 110ms |
| 16 | CRYPTO-16: Same UUID -> same server_seq (idempotent) | ✅ | 13366ms |
| 17 | CRYPTO-17: Dedup returns created_at | ❌ Dedup response should include created_at | 1979ms |
| 18 | CRYPTO-18: Different UUIDs -> different server_seqs | ❌ Different UUIDs should get different seqs | 376ms |
| 19 | CRYPTO-19: Clock skew > 5min rejected | ❌ Expected 400 for clock skew, got 500 | 13407ms |
| 20 | CRYPTO-20: Clock skew < 5min accepted | ❌ Expected 200 for small clock skew, got 500 | 45ms |
| 21 | CRYPTO-21: JWT with wrong secret rejected | ✅ | 9ms |
| 22 | CRYPTO-22: JWT without sub claim rejected | ✅ | 10ms |
| 23 | CRYPTO-23: JWT with HS384 algorithm rejected | ✅ | 5ms |
| 24 | CRYPTO-24: JWT sub maps to correct user | ✅ | 316ms |
| 25 | CRYPTO-25: Different users isolated | ✅ | 143ms |
| 26 | CRYPTO-26: Membership check prevents cross-group injection | ❌ Non-member should get 403, got 500 | 22ms |
| 27 | CRYPTO-27: E2EE messages have no server_content | ❌ Cannot read properties of undefined (reading 'serv | 3667ms |
| 28 | CRYPTO-28: Sender key distribution type accepted | ❌ Expected 200 for SK dist, got 500 | 49ms |
| 29 | CRYPTO-29: Group-scoped sequence isolation | ❌ Isolated group first message should have seq=1, go | 11168ms |
| 30 | CRYPTO-30: RLS prevents cross-user key bundle access | ✅ | 106ms |
| 31 | CRYPTO-31: No duplicate messages after concurrent sends | ❌ Expected exactly 1 message, got 0 (dedup failure) | 10185ms |
| 32 | CRYPTO-32: No duplicate ciphertexts after concurrent sends | ❌ Expected 1 ciphertext, got 0 (dedup failure) | 11357ms |
| 33 | CRYPTO-33: Monotonic seq even under concurrency | ✅ | 27024ms |
| 34 | CRYPTO-34: Key bundle upsert preserves latest | ✅ | 403ms |
| 35 | CRYPTO-35: User devices table has 5-device limit trigger | ❌ Should return array | 108ms |
| 36 | CRYPTO-36: SK acknowledgments writable | ❌ ACK should be stored | 219ms |
| 37 | CRYPTO-37: Read watermarks writable | ❌ Cannot read properties of undefined (reading 'last | 128ms |
| 38 | CRYPTO-38: Server_seq scoped per group | ✅ | 138ms |
| 39 | CRYPTO-39: Tombstone function exists | ✅ | 130ms |
| 40 | CRYPTO-40: uuidv7_to_timestamptz function exists | ✅ | 58ms |
| 41 | CRYPTO-41: XarkE2EE HKDF info strings referenced in codebase | ✅ | 2ms |
| 42 | CRYPTO-42: X3DH HKDF info string present | ✅ | 0ms |
| 43 | CRYPTO-43: PQXDH HKDF info string present | ✅ | 0ms |
| 44 | CRYPTO-44: Double Ratchet skipped key limit = 1000 | ✅ | 0ms |
| 45 | CRYPTO-45: Streaming AEAD chunk size = 64KB | ✅ | 0ms |
| 46 | CRYPTO-46: Hardware key store interface exists | ✅ | 0ms |
| 47 | CRYPTO-47: Crypto isolate with TransferableTypedData | ✅ | 1ms |
| 48 | CRYPTO-48: No plaintext logging in encryption service | ✅ | 1ms |
| 49 | CRYPTO-49: Web Locks mutex with AbortController | ✅ | 0ms |
| 50 | CRYPTO-50: Push fallback says "You may have new messages" | ❌ Should NOT mention encryption in user-facing text | 1ms |

## Failed Tests Detail

### STRESS-01: Valid JWT accepted
**Error:** Expected 200, got 400

### STRESS-16: Contact check empty list
**Error:** Expected 200, got 400

### STRESS-21: Send message to valid group
**Error:** Expected 200, got 500: {"error":"internal error"}

### STRESS-22: Send message non-member rejected
**Error:** Expected 403, got 500

### STRESS-23: Send message idempotent (same UUID)
**Error:** Expected deduplicated, got undefined

### STRESS-24: Send 10 messages sequentially — seq increases
**Error:** Seq should increase: undefined > undefined

### STRESS-25: Send 5 concurrent messages — all succeed
**Error:** Expected 200, got 500

### STRESS-26: Send message with ciphertexts
**Error:** Expected 200, got 500

### STRESS-29: Send message from Bob
**Error:** Expected 200, got 500

### STRESS-30: Send message from Charlie
**Error:** Expected 200, got 500

### STRESS-41: group_sequences exists and increments
**Error:** group_sequences should have entry

### STRESS-42: Messages have server_seq
**Error:** Should have messages

### STRESS-44: read_watermarks table accessible
**Error:** Should return array

### STRESS-45: sk_acknowledgments table accessible
**Error:** Should return array

### STRESS-46: 20 concurrent message sends
**Error:** Expected >=15 successes, got 0/20

### STRESS-47: 3 users send simultaneously
**Error:** Expected 200, got 500

### STRESS-49: Sequential seq assignment under concurrency
**Error:** Last seq undefined should be > start 0

### CRYPTO-09: PQXDH columns exist on key_bundles
**Error:** Should return array (columns exist even if null)

### CRYPTO-10: PQXDH columns exist on one_time_pre_keys
**Error:** Should return array (column exists even if null)

### CRYPTO-11: Ciphertext stored with recipient info
**Error:** Expected 1 ciphertext, got 0

### CRYPTO-12: Multiple ciphertexts per message (fan-out)
**Error:** Expected 2 ciphertexts (fan-out), got 0

### CRYPTO-14: Server never stores plaintext
**Error:** msgs is not iterable

### CRYPTO-17: Dedup returns created_at
**Error:** Dedup response should include created_at

### CRYPTO-18: Different UUIDs -> different server_seqs
**Error:** Different UUIDs should get different seqs

### CRYPTO-19: Clock skew > 5min rejected
**Error:** Expected 400 for clock skew, got 500

### CRYPTO-20: Clock skew < 5min accepted
**Error:** Expected 200 for small clock skew, got 500

### CRYPTO-26: Membership check prevents cross-group injection
**Error:** Non-member should get 403, got 500

### CRYPTO-27: E2EE messages have no server_content
**Error:** Cannot read properties of undefined (reading 'server_content')

### CRYPTO-28: Sender key distribution type accepted
**Error:** Expected 200 for SK dist, got 500

### CRYPTO-29: Group-scoped sequence isolation
**Error:** Isolated group first message should have seq=1, got undefined

### CRYPTO-31: No duplicate messages after concurrent sends
**Error:** Expected exactly 1 message, got 0 (dedup failure)

### CRYPTO-32: No duplicate ciphertexts after concurrent sends
**Error:** Expected 1 ciphertext, got 0 (dedup failure)

### CRYPTO-35: User devices table has 5-device limit trigger
**Error:** Should return array

### CRYPTO-36: SK acknowledgments writable
**Error:** ACK should be stored

### CRYPTO-37: Read watermarks writable
**Error:** Cannot read properties of undefined (reading 'last_read_seq')

### CRYPTO-50: Push fallback says "You may have new messages"
**Error:** Should NOT mention encryption in user-facing text

