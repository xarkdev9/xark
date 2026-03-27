# E2EE Chat Engine — Decision & Change Log

**Purpose:** Every architectural decision, deviation from spec, assumption, and bug fix made during the overnight build is logged here. Review this file in the morning before reviewing code.

**Updated by:** Each agent appends to this file after completing its step.

---

## How to Read This File

- **DECISION**: A choice was made between two or more valid approaches
- **DEVIATION**: The agent could not follow the spec exactly and chose an alternative
- **ASSUMPTION**: The spec was ambiguous — the agent assumed an interpretation
- **BUG_FIX**: A bug was found in a previous agent's output and fixed
- **SKIPPED**: A feature or requirement was intentionally skipped (with reason)

---

## Log

### Step 00 — Discovery Agent (complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | Use React's custom HKDF info strings | React uses `'XarkE2EE-x3dh'`, `'XarkE2EE-ratchet'`, `'XarkE2EE-header-secret'`, `'XarkE2EE-header-key'` instead of Signal's standard strings. Flutter must match for interop. | Agent 03 crypto |
| 2 | DECISION | XChaCha20-Poly1305 for messages, AES-256-GCM for files | React uses two different ciphers. Messages use libsodium XChaCha20, files use Web Crypto AES-GCM. Flutter must implement both. | Agent 03, Agent 09 |
| 3 | DECISION | Header encryption (non-standard) | React encrypts ratchet headers — Signal spec sends them in cleartext. Flutter must do the same or sessions won't interop. | Agent 03 |
| 4 | DECISION | Messages via HTTP POST, not WebSocket | React POSTs to /api/message. Supabase Realtime only delivers notifications. Flutter transport layer should match. | Agent 06 |
| 5 | ASSUMPTION | Cross-platform interop required | Assumed Flutter engine must decrypt messages sent by React web app. All wire formats and HKDF strings must match exactly. Flagged as open question. | All agents |
| 6 | DEVIATION | Thumbnails: inline in React, separate upload in spec | React embeds base64 thumbnails inline. CLAUDE.md says separate encrypted upload. Recommended: follow CLAUDE.md spec but support inline for backwards compat. | Agent 09 |
| 7 | SKIPPED | Multi-device, contact discovery, profile encryption | Not implemented in React. Deferred to Phase 2 in CLAUDE.md. Agents should not depend on these. | Phase 2 |

**Duration:** — | **Tests:** N/A | **Warnings:** 5 open questions in CODEBASE_CONTEXT.md §8

<!-- AGENTS: Append entries below this line. Do NOT modify existing entries. -->
<!-- Format:
### Step {NN} — {Agent Name} ({STATUS})

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | ... | ... | ... |

**Duration:** X min | **Tests:** N/N passed | **Warnings:** ...
-->

### Step 01 — Scaffold (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DEVIATION | drift_sqflite version adjusted | `drift_sqflite: ^2.2.0` does not exist on pub.dev; adjusted to `^2.0.1` which resolved successfully | pubspec.yaml |
| 2 | DECISION | No firebase_storage dependency | Media upload will use Supabase Storage or generic HTTP, not Firebase Storage SDK | pubspec.yaml |
| 3 | DECISION | No ios/android native stubs | NSE and MessagingService are Phase 2; not scaffolded | — |

**Duration:** ~2.5 min | **Tests:** 0/0 | **Warnings:** drift_sqflite version deviation

### Step 02 — Domain Models (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | MediaPayload no JSON serialization | Uint8List doesn't work with json_serializable; model is in-memory only | media_payload.dart |
| 2 | DECISION | KeyFingerprint plain class, not freezed | Uint8List equality doesn't work with freezed; used plain class with const constructor | key_fingerprint.dart |
| 3 | DECISION | Added build.yaml with explicit_to_json | Required for nested freezed object serialization (Message→MediaMetadata, DecryptedMessage→LinkPreview) | build.yaml |
| 4 | DECISION | EngineConnectionState enum naming | Avoids dart:io ConnectionState conflict as spec requires | connection_state.dart |

**Duration:** ~6.5 min | **Tests:** 25/25 passed | **Warnings:** none

### Step 03 — Crypto Layer (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | XChaCha20-Poly1305 via cryptography package | Xchacha20.poly1305Aead() available in cryptography 2.9.0 — no fallback needed | double_ratchet.dart, group_cipher.dart |
| 2 | DECISION | Pure Dart Ed25519→Curve25519 conversion | GF(2^255-19) field arithmetic implemented in pure Dart (10-limb ref10/TweetNaCl style). No pinenacl dependency added. | ed25519_to_curve25519.dart |
| 3 | DECISION | Renamed KeyPairData→RatchetKeyPair | Avoids collision with cryptography package's KeyPairData type | key_types.dart |
| 4 | DECISION | All HKDF info strings match interop spec | XarkE2EE-x3dh, XarkE2EE-ratchet, XarkE2EE-header-secret, XarkE2EE-header-key | x3dh.dart, double_ratchet.dart |
| 5 | DECISION | Chain KDF uses [0x01] and [0x02] HMAC inputs | Matches Signal spec and React implementation | double_ratchet.dart, group_cipher.dart |

**Duration:** ~14 min | **Tests:** 25/25 (existing pass) | **Warnings:** none

### Step 04 — Crypto Tests (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | BUG_FIX | Ed25519→Curve25519 carry loop off-by-one | `_Fe.fromBytes` carry loop iterated i=1..9 step 2, causing h[10] RangeError on i=9. Fixed to i=1..7. Without this fix, ALL X3DH/ratchet operations were broken. | ed25519_to_curve25519.dart |
| 2 | DECISION | FakeKeyStore and FakeSenderKeyStore | Used real in-memory implementations instead of mocktail mocks for crypto tests — exercises full crypto logic end-to-end | test/helpers/test_helpers.dart |
| 3 | DECISION | 63 tests covering all crypto modules | X3DH (9), Ratchet (18), GroupCipher (9), MediaCrypto (12), ProfileCrypto (8), Ed25519Curve25519 (7) | test/crypto/*.dart |

**Duration:** ~6 min | **Tests:** 63/63 crypto + 25/25 domain | **Warnings:** none

### Step 05 — Persistence Layer (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | Two-table message schema | Messages (metadata) + MessageCiphertexts (per-device E2EE payload) matches backend exactly | tables.dart, message_repository_impl.dart |
| 2 | DECISION | Search via plaintext cache join | No FTS5 on encrypted blob — searches cached decrypted text client-side, capped at 500 results | message_repository_impl.dart |
| 3 | DECISION | SqfliteQueryExecutor for runtime | drift_sqflite's SqfliteQueryExecutor for Flutter runtime; NativeDatabase.memory() for tests | database_factory.dart, tests |
| 4 | DECISION | Participant IDs as JSON array string | ConversationRow stores participantIdsJson as text column, parsed in repository | conversation_repository_impl.dart |

**Duration:** ~12 min | **Tests:** 40/40 persistence + 88 existing = 128/128 | **Warnings:** none

### Step 06 — Transport Layer (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | HTTP package for API routes | Used `http` package for /api/* endpoints since they are Next.js API routes, not Supabase Edge Functions | supabase_client.dart, pubspec.yaml |
| 2 | DECISION | Supabase Storage instead of Firebase Storage | firebase_storage not in pubspec; used Supabase Storage for encrypted media blobs | media_upload_client.dart |
| 3 | DECISION | Snake_case JSON via @JsonKey | MessageEnvelope and DistributionCiphertext use @JsonKey(name:) for wire-compatible snake_case | message_envelope.dart |
| 4 | DECISION | ApiException typed error class | Custom exception wrapping HTTP status + body for error mapping to ChatEngineError | supabase_client.dart |

**Duration:** ~10 min | **Tests:** 21/21 transport + 128 existing = 149/149 | **Warnings:** none

### Step 07 — Sync Engine (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | Decrypt in caller, not MessageProcessor | MessageProcessor returns raw ciphertext; caller (MessagingService) handles decrypt since it has crypto layer access | message_processor.dart |
| 2 | DECISION | Per-conversation DeduplicationSet | Each subscribed space gets its own 1000-entry LRU dedup set, not one global set | message_processor.dart, deduplication_set.dart |
| 3 | DECISION | Batch size 5 for outbox drain | Processes 5 outbox items in parallel per batch, balancing throughput with resource use | outbox_processor.dart |
| 4 | DECISION | Exponential backoff clamped at 60s | Retry intervals: 1, 2, 4, 8, 16, 32, 60, 60... Max 10 retries before permanent delete | outbox_processor.dart |

**Duration:** ~13 min | **Tests:** 31/31 sync + 149 existing = 180/180 | **Warnings:** none

### Step 08 — 1:1 Messaging (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | Outbox guard at 500 pending | sendText rejects new messages with OutboxFull error if outbox has >500 items | send_message_use_case.dart |
| 2 | DECISION | Two-phase commit in send pipeline | Unacked ratchet state saved before network call; committed on server ACK; preserved for crash recovery on failure | send_message_use_case.dart |
| 3 | DECISION | Delete-for-everyone window 1h8m | Matches WhatsApp's default; enforced client-side | delete_message_use_case.dart |
| 4 | DECISION | ChatEngineConfig with int deviceId | deviceId is integer matching backend schema (not string UUID as in CLAUDE.md) | chat_engine_impl.dart |

**Duration:** ~16 min | **Tests:** 23/23 new + 180 existing = 203/203 | **Warnings:** none

### Step 09 — Media Pipeline (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | Separate thumbnail key per CLAUDE.md spec | Main asset and thumbnail each get independent AES-256-GCM keys | upload_manager.dart |
| 2 | DECISION | Inline thumbnail for React backwards compat | Also generates base64 inline thumbnail alongside separate encrypted upload | upload_manager.dart |
| 3 | DECISION | ChatEngineError now implements Exception | Changed sealed class to allow error types to be thrown in media pipeline | chat_engine_error.dart |
| 4 | DECISION | In-memory LRU cache for decrypted media | 20 items max, no disk cache for decrypted bytes (security requirement) | media_cache.dart |

**Duration:** ~7 min | **Tests:** 15/15 media + 203 existing = 218/218 | **Warnings:** none

### Step 10 — Public API (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | ChatEngineConfig extracted to standalone file | Moved from chat_engine_impl.dart to public_api/chat_engine_config.dart for clean export | chat_engine_config.dart, chat_engine_impl.dart |
| 2 | DECISION | Abstract interfaces for ChatEngine + ChatSession | Impls implement abstract interfaces; public API only exposes abstractions | chat_engine.dart, chat_session.dart |
| 3 | DECISION | Barrel exports only public types | No RatchetState, AppDatabase, drift types, repository impls, use cases exported | lib/chat_engine.dart |

**Duration:** ~9 min | **Tests:** 10/10 new + 218 existing = 228/228 | **Warnings:** none

### Step 11 — Integration Tests (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | Mock-based integration tests | Used mocked transport (no platform channels) with real crypto + real persistence (in-memory drift) for true end-to-end testing | messaging_integration_test.dart |
| 2 | DECISION | 19 tests across 6 groups | 1:1 ratchet (7), group SK (2), media (2), cache (1), outbox (2), two-phase commit (1), e2e (4) | messaging_integration_test.dart |

**Duration:** ~8 min | **Tests:** 19/19 integration + 228 existing = 247/247 | **Warnings:** none

### Step 12 — Validation (✅ complete)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | — | No issues found | All analysis, tests, architecture, and crypto checks passed | — |

### Step 13 — Live Interop Test (✅ partial)

| # | Type | Summary | Details | Files Affected |
|---|------|---------|---------|----------------|
| 1 | DECISION | Split into offline + live tests | Offline crypto tests verify all parameters without network. Live tests need dev server + real JWT. | test/interop/ |
| 2 | BUG_FIX | GroupCipher interop test needed sender/receiver separation | Same SenderKeyStore used for encrypt+decrypt caused iteration mismatch. Fixed by using separate stores (sender creates, distributes public half to receiver) — matches real distribution flow. | test/interop/crypto_interop_test.dart |
| 3 | DECISION | Live tests gated by env var | `INTEROP_SUPABASE_URL` must be set. Prevents accidental writes to production DB during CI. | test/interop/live_interop_test.dart |

**Duration:** — | **Tests:** 11/11 offline, 5 skipped live | **Warnings:** Live tests require `cd ~/xark9 && npm run dev`

**Duration:** ~2 min | **Tests:** 247/247 | **Warnings:** none

---

## Morning Review Checklist

- [ ] Read every DECISION — do you agree with the tradeoff?
- [ ] Read every DEVIATION — is the alternative acceptable or does it need a redo?
- [ ] Read every ASSUMPTION — was the assumption correct?
- [ ] Read every BUG_FIX — is the root cause understood?
- [ ] Read every SKIPPED — is it OK to ship Phase 1 without this?
- [ ] Check TRACKER.md for any FAILED steps
- [ ] Run `flutter test` to confirm all tests still pass
- [ ] Run `dart analyze --fatal-warnings` to confirm no new warnings
