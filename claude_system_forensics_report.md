# System Forensics Report — hello Monorepo

**Date:** 2026-04-10
**Auditor:** Claude Opus 4.6 (Forensic Systems Architect)
**Scope:** 297 source files across 5 domains (engine/, app/, web/, algo/, xpensly/)
**Method:** Line-by-line read of every source file via 6 parallel forensic agents

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Monorepo Structure](#2-monorepo-structure)
3. [Master Feature Matrix](#3-master-feature-matrix)
4. [Critical Security Findings](#4-critical-security-findings)
5. [Phantom Limbs & Dead Code](#5-phantom-limbs--dead-code)
6. [Broken UI Trails](#6-broken-ui-trails)
7. [1,000-User Readiness Verdict](#7-1000-user-readiness-verdict)

---

## 1. Executive Summary

| Domain | Files Audited | Production | Stub/Mock | Dead/Broken | Score |
|--------|--------------|------------|-----------|-------------|-------|
| **engine/** (E2EE SDK) | 91 | 62 | 19 | 10 | 68% |
| **web/** (Next.js) | 103 | 74 | 18 | 11 | 72% |
| **app/** (Flutter) | 58 | 18 | 28 | 12 | 31% |
| **algo/** (Decision Engine) | 23 | 22 | 0 | 1 | 96% |
| **xpensly/** (Expense SDK) | 32 | 28 | 4 | 0 | 88% |
| **TOTAL** | **297** | **204** | **69** | **34** | **69%** |

**Verdict: NOT ready for 1,000 live users.** The web app is closest to production. The Flutter app is heavily mocked. There are 7 critical security findings that must be resolved first.

---

## 2. Monorepo Structure

```
/hello
├── engine/    E2EE Chat SDK (Dart/Flutter, 91 files)
│   ├── crypto/     Signal Protocol: X3DH, Double Ratchet, Sender Keys, PQXDH
│   ├── persistence/ Drift ORM + SQLCipher
│   ├── transport/   Supabase REST + Realtime
│   ├── sync/        Outbox, gap fill, dedup, conflict resolution
│   ├── media/       AES-256-GCM encrypt/upload/download
│   └── domain/      Freezed models, use cases, repositories
│
├── app/       Flutter App Shell (58 files)
│   ├── views/       14 screens (auth, chat, settings, discover, invite)
│   ├── demov2/      Decide-First UX variant (11 files)
│   ├── providers/   Riverpod state (7 providers)
│   └── widgets/     10 reusable components
│
├── web/       Next.js Web App (103 files)
│   ├── api/         53 API routes (auth, keys, message, hello, xpensly, discovery)
│   ├── components/  49 React components
│   ├── hooks/       11 React hooks
│   ├── lib/crypto/  26 crypto modules (libsodium-wrappers-sumo)
│   └── lib/intelligence/  11 AI orchestration modules
│
├── algo/      Decision Engine (23 files, TypeScript)
│   ├── engine/      HeartSort, GreenLock, StateMachine, Consensus, AI Grounding
│   ├── ports/       5 hexagonal interfaces
│   ├── adapters/    6 implementations (memory, postgres)
│   └── service/     DecisionService + RequestHandler
│
├── xpensly/   Expense Splitting SDK (32 files)
│   ├── xpensly_core/  Pure Dart (6 engines, 12 models, 8 adapters)
│   └── xpensly_ui/    Flutter widgets (9 widgets, 3 themes)
│
└── web/supabase/migrations/  45 SQL migrations
```

---

## 3. Master Feature Matrix

### 3.1 Engine — Cryptography Domain

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `engine/lib/src/crypto/x3dh/x3dh.dart` | X3DH key agreement (1:1 session) | KeyStore, cryptography pkg | Ed25519 sig verify, HKDF-SHA256, X25519 DH | **Production** |
| `engine/lib/src/crypto/ratchet/double_ratchet.dart` | Double Ratchet forward secrecy | KeyStore, crypto_isolate | XChaCha20-Poly1305, HKDF-SHA256, header encryption, 1000-key skip | **Production** |
| `engine/lib/src/crypto/sender_keys/group_cipher.dart` | Sender Keys group encryption | SenderKeyStore, crypto_isolate | XChaCha20-Poly1305, Ed25519 signing, HMAC-SHA256 chain | **Production** |
| `engine/lib/src/crypto/sender_keys/sk_recovery_handler.dart` | NACK-based Sender Key re-distribution | SenderKeyStore | SK payload encrypted via 1:1 ratchet by caller | **Production** |
| `engine/lib/src/crypto/sender_keys/persistent_sender_key_store.dart` | SK persistence via platform keychain | FlutterSecureStorage | Encrypted at rest (iOS Keychain / Android Keystore) | **Production** |
| `engine/lib/src/crypto/sender_keys/sqlite_sender_key_store.dart` | SK persistence via SQLCipher | DatabaseKeyManager, sqflite_sqlcipher | SQLCipher AES-256; **FALLS BACK TO UNENCRYPTED ON WEB** | **Production (native) / Gap (web)** |
| `engine/lib/src/crypto/keys/key_store_impl.dart` | Identity/SPK/OTK/session persistence | HardwareKeyStore, FlutterSecureStorage | Platform keychain; optional hardware wrapping | **Production** |
| `engine/lib/src/crypto/keys/hardware_key_store.dart` | Hardware-backed key wrapping | Abstract interface only | SoftwareKeyStore: in-memory random key (NOT hardware) | **Stub** |
| `engine/lib/src/crypto/keys/escrow_manager.dart` | BIP39 12-word mnemonic key backup | bip39 pkg, Supabase `user_key_backups` | PBKDF2-HMAC-SHA256 (200k iter), AES-256-GCM | **Production (compile error: field name mismatch)** |
| `engine/lib/src/crypto/keys/database_key_manager.dart` | SQLCipher master key management | FlutterSecureStorage | Platform keychain; returns null on web | **Production** |
| `engine/lib/src/crypto/keys/ed25519_to_curve25519.dart` | Ed25519 → X25519 key conversion | cryptography pkg | Hand-rolled GF(2^255-19) field arithmetic | **Production (high correctness risk)** |
| `engine/lib/src/crypto/media/media_crypto.dart` | AES-256-GCM media file encryption | StreamingAead, cryptography | One-time AES key per file; SHA-256 verification | **Production** |
| `engine/lib/src/crypto/media/streaming_aead.dart` | 64KB chunked AES-GCM for large files | Standalone | Per-chunk nonce derived by XOR; wire format self-describing | **Production** |
| `engine/lib/src/crypto/pqxdh/pqxdh.dart` | PQXDH hybrid X25519 + Kyber-1024 | cryptography, StubKyber | HKDF combining layer is real; **KEM is random bytes (no real Kyber)** | **Protocol: Production / KEM: Stub** |
| `engine/lib/src/crypto/profile/profile_crypto.dart` | Profile metadata encryption | cryptography | AES-256-GCM with prepended IV | **Production** |
| `engine/lib/src/crypto/franking/message_franking.dart` | E2EE message franking for moderation | Abstract interface only | No concrete implementation anywhere | **Dead Interface** |
| `engine/lib/src/crypto/crypto_isolate.dart` | Background isolate for all crypto ops | dart:isolate, all crypto modules | 10s watchdog, 3 max respawns, TransferableTypedData | **CRITICAL: Echoes bytes unchanged — no ratchet/SK ops execute** |

### 3.2 Engine — Persistence & Sync

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `engine/lib/src/persistence/database/tables.dart` | 12 Drift table schemas | AppDatabase | Messages table has no plaintext; SQLCipher encrypted | **Production** |
| `engine/lib/src/persistence/database/database_factory_native.dart` | SQLCipher on iOS/Android | path_provider, drift/native | PRAGMA key hex encoding, cipher_compat=4 | **Production** |
| `engine/lib/src/persistence/database/database_factory_web.dart` | WASM SQLite on web | drift/wasm | **ENCRYPTION KEY IGNORED — web DB is unencrypted** | **CRITICAL GAP** |
| `engine/lib/src/persistence/repositories/*.dart` | All 7 repository impls | AppDatabase, domain interfaces | Ciphertext-only storage; plaintext cache separate | **Production** |
| `engine/lib/src/sync/sync_coordinator.dart` | Sync orchestrator | OutboxWorker(null), WatermarkSync(null) | Typing/presence ephemeral | **Production with gaps — OutboxWorker & WatermarkSync are null** |
| `engine/lib/src/sync/outbox_worker.dart` | Timer-based outbox drain (2s) | AppDatabase, MessageGateway | Per-group serial ordering for ratchet safety | **Code complete but NOT WIRED (null)** |
| `engine/lib/src/sync/watermark_sync.dart` | Sequence-based gap sync | AppDatabase, MessageGateway | Incremental progress survives crash | **Code complete but NOT WIRED (null)** |
| `engine/lib/src/sync/outbox_processor.dart` | One-shot outbox drain on reconnect | OutboxRepository, SupabaseClient | Batch-of-5 parallel; 10 retry max | **Production (active)** |
| `engine/lib/src/sync/clock_sync.dart` | NTP-lite clock sync | HTTP HEAD to /api/health | Non-fatal fallback to device time | **Phantom — never called** |
| `engine/lib/src/domain/use_cases/send_message_use_case.dart` | Full 1:1 + group send pipeline | KeyStore, Supabase, repositories, GroupCipher | Two-phase ratchet commit; outbox cap 500 | **Production but: recipientDeviceId=1 hardcoded; sendMedia() is text stub** |
| `engine/lib/src/domain/use_cases/receive_message_use_case.dart` | Incoming message decrypt pipeline | KeyStore, repositories, GroupCipher | Own-message skip; SK distribution idempotency | **Production** |

### 3.3 Engine — Transport & Adapters

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `engine/lib/src/transport/supabase_client.dart` | Central HTTP/PostgREST wrapper | All adapters | Bearer token in headers; ciphertext-only payloads | **Production** |
| `engine/lib/src/transport/realtime_listener.dart` | Supabase Realtime subscriptions | SupabaseRealtimeGateway | Private channels; ciphertext metadata only | **Production** |
| `engine/lib/src/transport/realtime_receipts.dart` | Ephemeral delivery/read receipts | Abstract interface only | Receipt events contain only IDs/timestamps | **Dead Interface — no implementation** |
| `engine/lib/src/transport/typing_indicators.dart` | 5-second auto-clear typing | Session layer, RealtimeGateway | Ephemeral, no content | **Consumer: Production / Producer: Stub (empty body)** |
| `engine/lib/src/adapters/supabase_message_gateway.dart` | MessageGateway port impl | SupabaseClientWrapper | RLS-protected; ciphertext only | **Production (acknowledgeDelivery is no-op)** |
| `engine/lib/src/adapters/supabase_realtime_gateway.dart` | RealtimeGateway port impl | RealtimeListener | Private channels | **Subscribe: Production / publishPresence & publishTyping: EMPTY STUBS** |
| `engine/lib/src/adapters/supabase_transient_queue.dart` | TransientQueue port impl | SupabaseClientWrapper | Ciphertext only | **ALL METHODS ARE NO-OPS** |
| `engine/lib/src/adapters/firebase_push_adapter.dart` | PushAdapter port impl | None (no firebase_messaging import) | Push token management only | **Stub — getToken() returns null** |
| `engine/lib/src/adapters/sse_ai_adapter.dart` | SSE streaming for @hello AI | http, BrandConfig | Bearer token; prompt is plaintext (by design) | **Production** |
| `engine/lib/src/notifications/push_decryptor.dart` | Push payload decryption | Designed for crypto_isolate + Drift | Full TODO stub | **Stub — always returns "You may have new messages"** |

### 3.4 Engine — Public API & Devices

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `engine/lib/src/chat_engine_impl.dart` | 588-line composition root | All layers | Engine boundary enforced | **Production — dispose() doesn't close DB** |
| `engine/lib/src/chat_session_impl.dart` | Per-conversation session | Repositories, SyncCoordinator | Presence filter correct | **Production — getKeyFingerprint() returns zeroes** |
| `engine/lib/src/auth/auth_service.dart` | Firebase token → JWT exchange | HTTP to /api/phone-auth, /api/dev-auto-login, /api/join | Bearer token | **Production** |
| `engine/lib/src/devices/device_registry.dart` | DeviceInfo + DeviceRegistry interface | Abstract only | N/A | **Interface only — no implementation** |
| `engine/lib/src/devices/device_linking.dart` | QR linking protocol models | Abstract only | QR payload format defined | **Interface only — no implementation** |
| `engine/lib/src/contacts/private_discovery.dart` | Truncated SHA-256 phone hash discovery | Standalone | Privacy-preserving (10-byte hash) | **Production code but NEVER CALLED** |

### 3.5 Web — API Routes (Core)

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `web/src/app/api/phone-auth/route.ts` | Firebase OTP → Supabase JWT | Firebase Admin, Supabase, jose | AppCheck enforced; ALLOWED_PHONES whitelist; 24h JWT | **Production** |
| `web/src/app/api/message/route.ts` | E2EE message send (atomic RPC) | `send_e2ee_message` RPC | JWT; clock-skew guard; UUIDv7 idempotency | **Production** |
| `web/src/app/api/keys/bundle/route.ts` | Key bundle upload | Supabase, Redis cache invalidation | JWT; JTI replay protection; field length validation | **Production** |
| `web/src/app/api/keys/fetch/route.ts` | Atomic key bundle + OTK fetch | `fetch_key_bundle` RPC, Redis cache | JWT; JTI replay; user_id validation | **Production** |
| `web/src/app/api/hello/route.ts` | @hello 3-tier AI orchestrator | Gemini, SearchAPI, Apify, Supabase | JWT; membership check; 1000-char cap; garbage filter | **Production** |
| `web/src/app/api/hello/webhook/route.ts` | Apify async result receiver | Supabase | **NO WEBHOOK SIGNATURE VERIFICATION** | **Security Gap** |
| `web/src/app/api/invite/claim/route.ts` | Firebase invite claim + group join | Firebase Admin, Supabase RPC | Firebase token verify; **NO AppCheck** (inconsistent with phone-auth) | **Production (missing AppCheck)** |
| `web/src/app/api/devices/route.ts` | List/unlink devices | Supabase (4 tables) | JWT | **Production — DELETE is 4 non-transacted writes** |
| `web/src/app/api/local-action/route.ts` | Tier-1 mutations + auto-itinerary | Supabase, itinerary-generator | JWT; membership check | **Production** |

### 3.6 Web — API Routes (Xpensly)

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `web/src/app/api/xpensly/split/route.ts` | Split calculation | Local lib (pure math) | None needed | **Production (stateless)** |
| `web/src/app/api/xpensly/calculate/route.ts` | Settlement computation | Local lib | None needed | **Production (stateless)** |
| `web/src/app/api/xpensly/convert/route.ts` | Currency conversion | Local lib | None needed | **Production (stateless)** |
| `web/src/app/api/xpensly/simplify/route.ts` | Debt graph simplification | Local lib | None needed | **Production (stateless)** |
| `web/src/app/api/xpensly/trip/route.ts` | Create trip | **NONE — returns `trip_${Date.now()}`** | None | **STUB — no DB write** |
| `web/src/app/api/xpensly/trip/[tripId]/**` | All 9 trip CRUD endpoints | **NONE — all echo body or return empty** | None | **ALL STUBS — zero persistence** |

### 3.7 Web — Crypto (Browser)

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `web/src/lib/crypto/primitives.ts` | Core primitives (libsodium WASM) | All crypto modules | XChaCha20-Poly1305, Ed25519, X25519, HKDF, Argon2id | **Production** |
| `web/src/lib/crypto/encryption-service.ts` | High-level encrypt/decrypt bridge | Double Ratchet, Sender Keys, keystore, mutex | Two-phase commit; Web Locks cross-tab safety | **Production** |
| `web/src/lib/crypto/keystore.ts` | IndexedDB key storage | encrypted-store.ts for at-rest encryption | DB version 5; backward-compat for legacy formats | **Production** |
| `web/src/lib/crypto/encrypted-store.ts` | At-rest IndexedDB encryption (Argon2id) | keystore.ts | PIN-derived wrapping key; `plain:` fallback | **CRITICAL: `unlockStore()` never called — always unencrypted** |
| `web/src/lib/crypto/message-cache.ts` | Plaintext message cache (instant render) | Separate IndexedDB | Stores plaintext WITHOUT at-rest encryption | **Production (intentional tradeoff)** |
| `web/src/lib/crypto/kyber.ts` / `pqxdh.ts` | Post-quantum stub | StubKyber | encapsulate/decapsulate produce MISMATCHED secrets | **Stub — will silently break if Kyber keys uploaded** |
| `web/src/lib/crypto/message-franking.ts` | E2EE moderation reports | `/api/report` (does not exist) | messageKey and ciphertext always empty strings | **Dead — endpoint missing** |
| `web/src/lib/crypto/CryptoProvider.ts` | ECDSA P-256 identity (Capacitor) | Never imported anywhere | Incompatible with Ed25519 system | **Orphaned dead code** |

### 3.8 Web — Components (UI)

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `web/src/components/os/HelloChat.tsx` | Chat message stream + DM bridge | useHandshake, buildGroundingContext | Display only | **Production — DM bridge skips E2EE decrypt** |
| `web/src/components/os/DecisionBoard.tsx` | Decision card swim lanes | Supabase direct, useReactions, useE2EE | RLS enforced | **Production** |
| `web/src/components/os/AddItemModal.tsx` | Add item: photo+title → E2EE encrypt → Firebase | encryptFile, supabase.insert | **Image AES key in plaintext Supabase metadata** | **Security Gap** |
| `web/src/components/os/EncryptedMedia.tsx` | E2EE media download + decrypt | file-encryption.ts | AES-GCM decrypt, object URL revoked | **Broken for >1MB files (calls wrong decrypt fn)** |
| `web/src/components/os/MediaUpload.tsx` | Legacy unencrypted media upload | @/lib/media (no encryption) | **PLAINTEXT upload to Firebase** | **Security Concern** |
| `web/src/components/os/InlinePoll.tsx` | Live poll with voting | supabase direct, useReactions | Hardcoded `love_it` reaction for all votes | **Minor Issue** |

### 3.9 Flutter App

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `app/lib/main.dart` | App root + deferred engine init | Firebase.initializeApp, AuthService, ChatEngineImpl | No direct Supabase | **Production** |
| `app/lib/views/auth/auth_flow_page.dart` | Firebase Phone OTP → JWT → engine boot | FirebaseAuth, AuthService, initializeEngine | No direct Supabase | **Production** |
| `app/lib/views/home/home_layout.dart` | Main shell (Chats + Groups tabs) | **engine.findOrCreateChat() — DOES NOT EXIST** | No direct Supabase | **BROKEN — will throw** |
| `app/lib/views/chat/space_layout.dart` | Chat + decision tab | **engine as ChatEngineDecisions — unsafe cast** | No direct Supabase | **BROKEN — may throw CastError** |
| `app/lib/views/ai/spotlight_sheet.dart` | @hello AI chat | Stream.periodic(50ms) of hardcoded string | No direct Supabase | **COMPLETE MOCK** |
| `app/lib/views/invite/invite_surface.dart` | QR invite generation | Random(42) pixel art; Copy/Share do nothing | No direct Supabase | **COMPLETE MOCK** |
| `app/lib/views/invite/claim_sheet.dart` | Join via invite | setState(_isJoined = true) — local only | No direct Supabase | **COMPLETE MOCK** |
| `app/lib/views/settings/profile_edit.dart` | Profile edit | Hardcoded name; simulated photo picker | No direct Supabase | **COMPLETE MOCK** |
| `app/lib/views/settings/device_list.dart` | Device management | Hardcoded 3 devices; revoke is local splice | No direct Supabase | **COMPLETE MOCK** |
| `app/lib/views/settings/device_linking_page.dart` | QR device linking | 1500ms delay then pop | No direct Supabase | **COMPLETE MOCK** |
| `app/lib/widgets/encrypted_image_view.dart` | Encrypted image display | downloadMedia() → `/dev/null` | No direct Supabase | **BROKEN — all images resolve to /dev/null** |
| `app/lib/demov2/space_layout.dart` | Decide-First group shell | engine.encryptPayload, engine.addDecisionItem | Imports internal `src/` path | **Partial — internal API violation** |
| `app/lib/demov2/add_item_sheet.dart` | Add decision item (real E2EE) | engine.encryptPayload, engine.addDecisionItem | Real E2EE encryption | **Production** |
| `app/lib/demov2/chat_feed.dart` | Group chat in Decide tab | session.messages, session.sendText | `senderId == 'me'` hardcoded | **BROKEN** |
| `app/lib/demov2/plans_view.dart` | Decrypted plans view | decryptedPlansProvider (real E2EE) | Real decryption | **Partial Mock** |

### 3.10 Algo — Decision Engine

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `algo/src/engine/heart-sort.ts` | Weighted scoring (LoveIt=5, WorksForMe=1, NotForMe=-3) | Pure functions | N/A | **Production** |
| `algo/src/engine/green-lock.ts` | Commitment/lock with proof validation | Pure functions | Proof required; lock irreversible | **Production** |
| `algo/src/engine/consensus-engine.ts` | In-memory synchronous orchestrator | All engine modules | N/A | **Production** |
| `algo/src/engine/state-machine.ts` | 4 configurable state flows | state-flows.ts | N/A | **Production** |
| `algo/src/engine/ai-grounding.ts` | AI constraint injection | buildGroundingContext, generatePrompt | Server-blind to item content | **BROKEN: checkSuggestionConflicts() has `&& false` — always returns []** |
| `algo/src/engine/task-assignment.ts` | Task CRUD + assignment | Pure functions | N/A | **Production** |
| `algo/src/service/decision-service.ts` | Stateless async orchestrator | All ports | Auth + optimistic concurrency | **Production** |
| `algo/src/service/request-handler.ts` | Framework-agnostic HTTP router | DecisionService | 403/404/400 error mapping | **Production** |

### 3.11 Xpensly SDK

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `xpensly/xpensly_core/lib/src/engine/split_calculator.dart` | 4-mode expense splitting | Pure Dart | N/A | **Production** |
| `xpensly/xpensly_core/lib/src/engine/settlement_engine.dart` | Multi-expense settlement with refunds | CurrencyConverter | N/A | **Production** |
| `xpensly/xpensly_core/lib/src/engine/debt_simplifier.dart` | Graph-based minimum-transaction | Pure Dart | N/A | **Production** |
| `xpensly/xpensly_core/lib/src/adapters/supabase_data_source.dart` | Real Supabase persistence | Supabase `xp_*` tables | **No RLS on tables** | **Buggy — hardcodes USD, drops fields** |
| `xpensly/xpensly_core/lib/src/adapters/in_memory_data_source.dart` | In-memory test impl | None | N/A | **Production (for testing)** |
| `xpensly/xpensly_ui/` (9 widgets) | Dashboard, ExpenseEntry, Settlement, Debt, Payment | xpensly_core | N/A | **Production** |

### 3.12 Database Migrations

| Component Path | Feature | Connection Points | Security | Status |
|---|---|---|---|---|
| `migrations/001-003` | Foundation schema + RLS | All tables | **003 uses auth.uid() — wrong for text IDs** | **Partially fixed in later migrations** |
| `migrations/014-015` | E2EE key bundles + ciphertexts | /api/keys/*, /api/message | SECURITY DEFINER RPCs | **Production** |
| `migrations/016,023,024` | Security hardening passes | RLS, function privileges | auth.jwt()->>'sub' fixes | **Production** |
| `migrations/20260327*` | Fortress: sequences, atomic send, watermarks, partitions, PQXDH, devices | /api/message, /api/keys | Atomic RPC; clock-skew guard; partition by month | **Production** |
| `migrations/027` | Taste graph + consensus | /api/hello, /api/cron | GIN indexes; SECURITY DEFINER | **BROKEN after 031 (taste trigger references dropped column)** |
| `migrations/031` | Zero-knowledge decision items | Decision items | Drops plaintext columns; adds ciphertext | **Production — but breaks 027 trigger** |
| `supabase/20260404_xpensly.sql` | 8 Xpensly tables | SupabaseDataSource | **ZERO RLS — any user can read all data** | **Critical Security Gap** |

---

## 4. Critical Security Findings

### SEV-1: Must Fix Before Any Live Users

| # | Finding | Location | Impact | Fix Effort |
|---|---------|----------|--------|------------|
| **S1** | **Crypto isolate is a pass-through** — encrypt/decrypt echo input unchanged | `engine/lib/src/crypto/crypto_isolate.dart:266-349` | All messages sent via CryptoIsolateManager are **unencrypted** | High (wire ratchet + SK into isolate entry) |
| **S2** | **Web DB unencrypted** — encryption key parameter ignored | `engine/lib/src/persistence/database/database_factory_web.dart` | All local data on web is plaintext SQLite | Medium (integrate SQLCipher-WASM) |
| **S3** | **Xpensly tables have zero RLS** | `supabase/migrations/20260404000000_xpensly.sql` | Any authenticated user can SELECT all trips/expenses | Low (add RLS policies) |
| **S4** | **Apify webhook has no signature verification** | `web/src/app/api/hello/webhook/route.ts` | Attacker can inject decision items via guessed groupId+msgId | Low (add webhook secret) |
| **S5** | **AddItemModal stores image AES key in plaintext** in Supabase metadata | `web/src/components/os/AddItemModal.tsx` | Server/admin can decrypt all decision item images | Medium (encrypt key inside E2EE envelope) |
| **S6** | **IndexedDB at-rest encryption disabled** — unlockStore() never called | `web/src/lib/crypto/encrypted-store.ts` | All browser-side key material stored unencrypted | Medium (wire PIN/biometric flow) |
| **S7** | **MediaUpload.tsx uploads plaintext** to Firebase alongside E2EE AddItemModal | `web/src/components/os/MediaUpload.tsx` | Unencrypted media coexists with encrypted; no user indication | Low (remove or gate component) |

### SEV-2: Should Fix Before Scale

| # | Finding | Location | Impact |
|---|---------|----------|--------|
| **S8** | Multi-device fan-out hardcodes `recipientDeviceId = 1` | `engine/.../send_message_use_case.dart:141` | Messages only reach one device per user |
| **S9** | Migration 031 breaks taste trigger (references dropped `category` column) | `migrations/027 + 031` | Taste weights stop accumulating silently |
| **S10** | `unlink_device` RPC references `sk_acknowledgments` table that may not exist | `migrations/20260327190001` | Device revocation throws `relation does not exist` |
| **S11** | `EncryptedMedia.tsx` calls `decryptFile` instead of `decryptFileAuto` | `web/src/components/os/EncryptedMedia.tsx` | Files >1MB encrypted with streaming AEAD fail to decrypt |
| **S12** | DM bridge in HelloChat loads messages outside E2EE pipeline | `web/src/components/os/HelloChat.tsx` | DM messages shown unencrypted in DM bridge |

---

## 5. Phantom Limbs & Dead Code

Code that is **defined but never called or wired**:

| Location | What | Why It Matters |
|----------|------|----------------|
| `engine/lib/src/sync/clock_sync.dart` | NTP-lite sync — never called | UUIDv7 uses raw device time; server may reject skewed timestamps |
| `engine/lib/src/sync/conflict_resolver.dart:reconcileOutboxMessage()` | Method exists, no caller | OutboxWorker bypasses it |
| `engine/lib/src/persistence/repos/decrypted_message_repository_impl.dart:expireOlderThan()` | Cache eviction — never called | Plaintext cache grows unbounded |
| `engine/lib/src/persistence/repos/local_feed_repository.dart` | Entire class unused | ChatSessionImpl uses MessageRepositoryImpl directly |
| `engine/lib/src/media/upload_manager.dart` + `download_manager.dart` | Fully implemented, never wired in ChatEngineImpl | Media encrypt/upload pipeline disconnected |
| `engine/lib/src/contacts/private_discovery.dart` | Full phone hash impl, never called | ChatEngineImpl.discoverContacts() uses SupabaseClient directly |
| `engine/lib/src/domain/models/chat_engine_error.dart` | `engine.errors` stream — `_errorController.add()` never called | Error stream is always empty |
| `app/lib/providers/e2ee_state_provider.dart` | `markReady()` never called | E2EE readiness state always idle |
| `web/src/lib/rate-limit.ts` | Postgres rate limiter — all routes say "moved to edge proxy" | Dead module |
| `web/src/lib/postgres-pool.ts` | TCP pool initialized but `sql` export unused | Dead module |
| `web/src/lib/crypto/hardware-keys.ts` | wrapKey/unwrapKey never called | encrypted-store uses its own Argon2id key |
| `web/src/lib/crypto/CryptoProvider.ts` | ECDSA P-256 (incompatible with Ed25519) | Complete orphan from prior architecture |
| `web/src/hooks/useWhispers.ts` | `POLL_INTERVAL_MS = 60_000` defined but no setInterval | Whispers fetch once on mount only |

---

## 6. Broken UI Trails

Buttons/actions where the `onPress`/`onClick` trail **breaks before reaching backend**:

| UI Element | Location | Trail Breaks At | Severity |
|------------|----------|----------------|----------|
| Home search icon | `app/lib/views/home/home_layout.dart` | `onTap: () {}` — empty | Cosmetic |
| Privacy settings | `app/lib/views/settings/settings_page.dart` | `onTap: () {}` — empty | Cosmetic |
| Appearance settings | `app/lib/views/settings/settings_page.dart` | `onTap: () {}` — empty | Cosmetic |
| Fork & Resurrect Plan | `app/lib/demov2/time_scrubber.dart` | No `onTap` handler | Cosmetic |
| Copy Link (invite) | `app/lib/views/invite/invite_surface.dart` | HapticFeedback only — nothing on clipboard | Broken |
| Share (invite) | `app/lib/views/invite/invite_surface.dart` | HapticFeedback only — no share API call | Broken |
| Claim invite (join) | `app/lib/views/invite/claim_sheet.dart` | `setState(_isJoined = true)` — local only | Broken |
| Profile save | `app/lib/views/settings/profile_edit.dart` | Local state only — no engine call | Broken |
| Device revoke | `app/lib/views/settings/device_list.dart` | Local list splice — no engine call | Broken |
| Device linking | `app/lib/views/settings/device_linking_page.dart` | 1500ms delay then pop | Broken |
| Action card react | `app/lib/views/action_carousel_page.dart` | `onReact: () {}` — empty | Broken |
| Action card commit | `app/lib/views/action_carousel_page.dart` | `onPinCommit: () {}` — empty | Broken |
| LedgerPill payload text | `web/src/components/os/LedgerPill.tsx` | `cursor: pointer` but no onClick | Cosmetic |

---

## 7. 1,000-User Readiness Verdict

### Can the WEB APP serve 1,000 users?

**Conditionally YES** — if these 4 items are fixed:
1. Fix Apify webhook signature verification (S4)
2. Remove or gate `MediaUpload.tsx` (S7)
3. Fix `EncryptedMedia.tsx` to call `decryptFileAuto` (S11)
4. Add RLS to Xpensly tables (S3)

The web app's core messaging, auth, E2EE crypto, consensus voting, and AI orchestration are production-grade. Infrastructure (rate limiting, connection pooling, key caching, JWT replay) is solid.

### Can the FLUTTER APP serve 1,000 users?

**NO.** The Flutter app has:
- 6 completely mocked screens (AI, invite, settings, device linking)
- 3 broken screens (home layout, space layout, encrypted images)
- Multiple empty button handlers
- Auth is now wired (as of this session), but most features beyond basic chat are visual theater

### Can the ENGINE support 1,000 users?

**Partially.** The crypto primitives are real and correct (X3DH, Double Ratchet, Sender Keys). But:
- The crypto isolate echoes bytes unchanged (S1) — **this is the single biggest gap**
- Web DB is unencrypted (S2)
- Multi-device sends to device 1 only (S8)
- Media pipeline disconnected
- Push notifications always show generic fallback

### Can the ALGO engine support 1,000 users?

**YES.** 232 tests passing, hexagonal architecture, all algorithms correct. One minor fix needed (`checkSuggestionConflicts` has `&& false`).

### Can XPENSLY support 1,000 users?

**Core math: YES. Trip management: NO.** The calculation endpoints work. All 14 trip CRUD endpoints are stubs with zero database persistence. Xpensly tables have no RLS.

---

### Priority Fix Order for 1,000-User Launch

| Priority | Item | Effort | Unlocks |
|----------|------|--------|---------|
| **P0** | Wire crypto isolate (S1) or bypass it | 3-5 days | Real E2EE on Flutter |
| **P0** | Add Xpensly RLS (S3) | 2 hours | Data isolation |
| **P0** | Add webhook signature verification (S4) | 2 hours | Injection prevention |
| **P1** | Fix web DB encryption (S2) | 2-3 days | E2EE compliance on web |
| **P1** | Wire IndexedDB at-rest encryption (S6) | 1-2 days | Key material protection |
| **P1** | Fix AddItemModal AES key leak (S5) | 1 day | Image encryption integrity |
| **P1** | Fix EncryptedMedia streaming decrypt (S11) | 1 hour | Large media display |
| **P2** | Remove MediaUpload.tsx (S7) | 30 min | Eliminate plaintext upload |
| **P2** | Fix multi-device fan-out (S8) | 1 day | Multi-device support |
| **P2** | Fix migration 031 → 027 trigger conflict (S9) | 1 hour | Taste weight accumulation |
| **P3** | Wire Flutter app features (6 mocked screens) | 2-3 weeks | Flutter parity with web |
| **P3** | Implement Xpensly trip CRUD persistence | 3-5 days | Expense tracking |

---

*Report generated by 6 parallel forensic agents reading 297 source files.*
*Total agent computation: ~24 minutes across 376 tool calls.*
