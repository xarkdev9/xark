# apr4.md — Full Codebase Audit & Enterprise Roadmap
## Date: 2026-04-04 | Reviewer: Claude Opus 4.6 | Scope: All 6 packages, 45 migrations, 12 docs

---

## TL;DR

| Package | Files | Tests | Production Ready | Enterprise Ready | B2B Extractable |
|---------|-------|-------|-----------------|-----------------|-----------------|
| **engine/** (Dart SDK) | 159 | 33 files | 70% | 55% | YES (6 modules) |
| **web/** (Next.js) | 51 routes, 43 components | 12 files | 90% | 80% | YES (7 modules) |
| **algo/** (Decision Engine) | 22 files | 198 tests | 95% | 75% | YES (standalone) |
| **xpensly/** (Expense SDK) | 88 files | 18 files (85 tests) | 85% (core) | 55% | YES (standalone) |
| **app/** (Flutter) | 32 views, 10 widgets | 1 file (702 LOC) | 75% | 60% | NO (app shell) |
| **DB** (Supabase) | 45 migrations | 92/100 passing | 70% | 50% | N/A |

**Headline:** Core algorithms and crypto are production-grade. Backend wiring, push notifications, and multi-device fan-out are the critical gaps. 8 extractable B2B modules identified.

---

## SECTION 1: ENGINE (e2ee_chat_sdk) — 159 Files

### What's COMPLETE & Production-Ready

| Component | Files | Test Coverage | Notes |
|-----------|-------|--------------|-------|
| Double Ratchet | `crypto/ratchet/` | 100% | Signal Protocol 1:1. Bounded 1000-key skip dict. Forward secrecy per message. |
| X3DH Key Agreement | `crypto/x3dh/` | 100% | Initiator + responder. 3-DH fallback when no OTK. Ed25519 verification. |
| Sender Keys (Group) | `crypto/sender_keys/` | 100% | Ed25519 signing. O(1) distribution with ACK tracking. NACK recovery. |
| Streaming AEAD | `crypto/media/` | 100% | 64KB chunked AES-256-GCM. Files up to 2GB. Per-chunk nonce XOR. |
| Message Franking | `crypto/franking/` | 100% | Per-message key extraction for E2EE moderation. |
| Profile Crypto | `crypto/profile/` | 100% | AES-256-GCM profile encryption + key distribution interface. |
| Key Management | `crypto/keys/` | Tested | Ed25519 + X25519 identity keys, signed pre-keys (7-day rotation), OTK (100 batch). |
| SQLCipher Database | `persistence/` | Tested | Drift ORM, platform-aware encryption, Keychain-derived key. |
| Local Feed | `persistence/local_feed_repository.dart` | Tested | Reactive Drift streams. Zero network in render path. |
| Outbox Worker | `sync/outbox_worker.dart` | Tested | Serial per-group drain. Exponential backoff. 10 max retries. |
| Watermark Sync | `sync/watermark_sync.dart` | Tested | Paginated gap fill on reconnect. Bulk insert with dedup. |
| Conflict Resolver | `sync/conflict_resolver.dart` | Tested | Reconciles optimistic vs server state. Tombstone handling. |
| Sync Coordinator | `sync/sync_coordinator.dart` | Tested | Orchestrates all background workers. |
| Domain Models | `domain/` | Tested | Freezed immutable: Message, Conversation, Receipt, PresenceState, etc. |
| Public API | `public_api/` | Tested | ChatEngine (19 methods) + ChatSession (13 methods). Zero Flutter deps. |
| Transport Adapters | `adapters/` + `ports/` | Tested | MessageGateway, RealtimeGateway, TransientQueue — Supabase optional. |
| Push Adapters | `adapters/` | Tested | FirebasePushAdapter / NoopPushAdapter. |
| AI Adapters | `adapters/` | Tested | SSEAIAdapter / NoopAIAdapter. |
| BrandConfig | `config/` | N/A | White-label: appName, aiName, aiEndpoint, pushChannelId. |
| ChatEngineObserver | `observer/` | N/A | Diagnostic hooks. Never exposes plaintext/keys. |
| Error Taxonomy | `public_api/` | N/A | 15 typed `ChatEngineError` variants with recovery paths. |

### What's STUBBED or INCOMPLETE

| Component | File | Issue | Severity |
|-----------|------|-------|----------|
| **Push Decryption** | `notifications/push_decryptor.dart:70-90` | TODO stubs. Returns fallback "You may have new messages". Not wired to crypto isolate. | CRITICAL |
| **Multi-Device Fan-Out** | `send_message_use_case.dart:141` | `const recipientDeviceId = 1;` — hardcoded to device 1. Devices 2-5 orphaned. | CRITICAL |
| **Sender Key Persistence** | `chat_engine_impl.dart:123` | `_InMemorySenderKeyStore()` — group keys lost on app restart. Users see decryption failures until new SK distribution. | HIGH |
| **Contact Discovery** | `contacts/contacts.dart` | `// TODO(phase2): Implement ContactDiscovery and ProfileKeyDistributor.` | HIGH |
| **Device Linking** | `devices/devices.dart` | `// TODO(phase2): Implement DeviceRegistry, DeviceLinkingProtocol, and KeyRotationService.` | HIGH |
| **Profile Key Distribution** | Not implemented | No code for sending profile encryption key to new contacts. | HIGH |
| **PQXDH (Kyber)** | `crypto/pqxdh/pqxdh.dart:329` | Uses 32-byte test keys instead of real Kyber-1024 (1568 bytes). Placeholder. Falls back to X3DH safely. | LOW |
| **Crypto Isolate Persistence** | `crypto_isolate.dart:359` | `// TODO: Wire to Drift DB write when ratchet state caching is implemented` — ratchet state lost on force-kill. | MEDIUM |
| **Background Uploader** | `media/background_uploader.dart:113` | `// TODO(MOBILE-05): Wire StreamingAead` — queue management complete, actual encrypt/upload stubbed. | MEDIUM |
| **BlurHash** | `media/blurhash.dart:15` | `// TODO: Integrate blurhash_dart` — placeholder generation. | LOW |
| **Hardware Key Store** | `crypto/keys/hardware_key_store.dart` | Interface exists. Only `SoftwareKeyStore` implemented (flutter_secure_storage fallback). iOS Secure Enclave / Android StrongBox not wired. | MEDIUM |
| **Certificate Pinning** | Not implemented | Relies on OS certificate validation. No custom pins for production domains. | MEDIUM |
| **On-Device SLM** | `intelligence/on_device_slm.dart` | `isAvailable()` returns false. Regex-based fallback only. CoreML/NNAPI not wired. | LOW |

### Improvement Roadmap

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P0 | Persist sender keys to Drift DB (`sender_keys` table + `DriftSenderKeyStore`) | 1 day | Groups work after restart |
| P0 | Multi-device fan-out (fetch recipient devices, encrypt to each) | 2-3 days | Multi-device parity |
| P0 | Wire push decryption (iOS NSE + Android Service + crypto isolate via IsolateNameServer) | 3-5 days | Encrypted notification previews |
| P1 | Contact discovery (hashed phone lookup, truncated SHA-256) | 2-3 days | Find friends by phone |
| P1 | Device linking protocol (QR code + encrypted history transfer) | 5-7 days | Add new devices |
| P1 | Profile key distribution (send key via E2EE message type) | 2-3 days | Encrypted profile photos |
| P2 | Certificate pinning (custom HTTP client per platform) | 1 day/platform | MitM protection |
| P2 | Wire streaming AEAD to background uploader | 2 days | E2EE media uploads |
| P2 | Crypto isolate state persistence (Drift snapshots) | 1-2 days | Survive force-kill |
| P3 | Real Kyber-1024 (FFI binding or pure-Dart impl) | 3-5 days | Post-quantum forward secrecy |
| P3 | Hardware key store (iOS Secure Enclave, Android StrongBox) | 3 days | HSM-backed keys |

---

## SECTION 2: WEB (Next.js 16) — 51 Routes, 43 Components, 5,950 LOC Crypto

### What's COMPLETE & Production-Ready

| Layer | Count | Status | Notes |
|-------|-------|--------|-------|
| **API Routes (Core)** | 32/32 | COMPLETE | E2EE messaging, auth (Firebase OTP + AppCheck), key management, consensus, AI (@hello 3-tier), discovery, push, cron jobs |
| **API Routes (Xpensly)** | 11/19 | COMPLETE (logic) | Settlement engine, split calculator, currency converter, debt simplifier, payment links all working |
| **Components** | 43/43 | COMPLETE | HelloChat, DecisionBoard, SpotlightSheet, ClaimSheet, PeopleDock, AwarenessStream, all interactive sheets — zero stubs |
| **Hooks** | 11/11 | COMPLETE | useAuth, useE2EE, useHelloAI, useHandshake, useReactions, useWhispers, useVoiceInput, useKeyboard, useDisplayName, useDeviceTier, usePlaygroundChoreography |
| **Crypto Module** | 24 files, 5,950 LOC | COMPLETE | Full Signal Protocol: Double Ratchet, Sender Keys, X3DH, PQ-X3DH (Kyber768), device linking, outbox, SK recovery, cross-tab mutex, IndexedDB keystore (encrypted at rest) |
| **Infrastructure** | 15+ modules | COMPLETE | Postgres TCP pool, Upstash Redis rate limiting, JWT replay protection, key bundle cache, Firebase AppCheck, auth-verify |
| **Business Logic** | 15+ modules | COMPLETE | heart-sort, consensus, space-state, ai-grounding, claims, state-flows, home-feed, ledger, suggestions, typing indicators |
| **Migrations** | 45 files | COMPLETE | Progressive, versioned, reversible. UUIDv7 helpers, partitioning, SK acknowledgments, PQXDH columns |
| **Theme System** | 4 themes, 20+ CSS vars | COMPLETE | Dynamic meta theme-color. No-bold mandate enforced. |

### What's STUBBED or INCOMPLETE

| Component | Issue | Severity |
|-----------|-------|----------|
| **Xpensly Trip CRUD** (8 routes) | `/api/xpensly/trip/[tripId]/*` — Validate body + return mock IDs. `// TODO: DB storage`. Core math logic works. | MEDIUM |
| **Structured Logging** | `console.error/warn` only. No Axiom/LogRocket/Sentry structured logging. | MEDIUM |
| **APM/Observability** | E2EE observability module exists. No Vercel Analytics or error tracking wired. | MEDIUM |
| **CLAUDE.md (web)** | Documents 23 routes. Codebase has 51. Outdated. | LOW |
| **Admin Dashboard** | No admin UI for user/space management. | LOW |

### Improvement Roadmap

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P1 | Wire Xpensly trip CRUD to Supabase (8 routes) | 3-5 days | Complete expense API |
| P1 | Add structured logging (Axiom or Vercel Log Drain) | 1 day | Debugging in production |
| P2 | APM integration (Sentry + Vercel Analytics) | 1 day | Error tracking |
| P2 | Update web/CLAUDE.md (51 routes, not 23) | 0.5 day | Accurate docs |

---

## SECTION 3: ALGO (Decision Engine) — 22 Files, 198 Tests

### What's COMPLETE & Production-Ready

| Component | Tests | Status | Notes |
|-----------|-------|--------|-------|
| **Heart-Sort Algorithm** | 25 | COMPLETE | Weighted scoring (LoveIt +5, WorksForMe +1, NotForMe -3). O(n log n) stable sort. Agreement score. Immutable, pure functions. |
| **Green-Lock Commitment** | 20 | COMPLETE | State machine-based commitItem(). 6 proof types. Ownership audit trail. Transfer support. |
| **State Machine** | 21 | COMPLETE | 4 preset flows (BOOKING, PURCHASE, SIMPLE_VOTE, SOLO_DECISION). Custom flows supported. |
| **Consensus Engine** | 16 | COMPLETE | In-memory orchestrator. Spaces, Groups, Items, Tasks, Events. Event listener pattern. |
| **AI Grounding** | 8 | COMPLETE | Locked decisions ground AI. Prevents reopening settled choices. Conflict detection by category. |
| **Task Assignment** | 8 | COMPLETE | Lightweight ownership for non-decidables. UUID-based IDs. |
| **Decision Service** | 17 | COMPLETE | Stateless, async, persistent orchestrator. DI via ports. Optimistic concurrency. Cache integration. |
| **Request Handler** | 22 | COMPLETE | Framework-agnostic HTTP router. 15 RESTful routes. Proper HTTP status codes. |
| **Persistence Adapter** | 35 (in adapters) | COMPLETE | In-memory with version conflicts. structuredClone() for copy-on-read. |
| **Event Bus Adapter** | Tested | COMPLETE | In-process pub/sub. Channel-scoped. Error isolation. |
| **Cache Adapter** | Tested | COMPLETE | TTL-aware Map. Lazy expiry. Prefix deletion. |
| **Auth Adapter** | Tested | COMPLETE | Noop (dev). Fine-grained actions: space:*, item:*, task:*. |
| **Messaging Adapter** | Tested | COMPLETE | Plaintext formatter. Command parser (/love, /works, /nope, /lock, /rank). |
| **Backwards Compatibility** | 18 | COMPLETE | Deprecated aliases maintained (Heart->LoveIt, HeartSorted->Locked). |

### What Needs Fixing

| Issue | File | Severity |
|-------|------|----------|
| **Duplicate `GroupId` declaration** | `models/types.ts:14-15`, `consensus-engine.ts:24,27`, `decision-service.ts:32,36`, `index.ts:22-23` | CRITICAL (breaks `npm run build`) |
| **Duplicate `groupId` field** | `consensus-engine.ts:198` | MEDIUM (TS2717 warning) |

### What's Missing for Enterprise B2B

| Gap | Current State | Needed |
|-----|--------------|--------|
| **Production Persistence** | In-memory only | PostgreSQL / DynamoDB / MongoDB adapter |
| **Production Auth** | Noop adapter (trusts token) | JWT / OAuth2 / Clerk adapter |
| **Production Event Bus** | In-process pub/sub | Redis pub/sub / WebSocket / SSE adapter |
| **Production Cache** | In-memory Map | Redis / Memcached adapter |
| **Input Validation** | TypeScript only (no runtime) | zod / yup schema validation |
| **Logging & Metrics** | None | winston/pino + OpenTelemetry |
| **Rate Limiting** | None | Token bucket middleware |
| **Webhooks** | None | Customer event subscriptions |
| **Soft Deletes** | Hard delete only | `deletedAt` field + archive |
| **Messaging Adapters** | Plaintext only | Slack Block Kit, Discord Embeds, Teams Adaptive Cards |

### Improvement Roadmap

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P0 | Fix 4 duplicate `GroupId` declarations | 15 min | Unblocks build |
| P1 | PostgreSQL persistence adapter | 3-5 days | Real multi-user deployment |
| P1 | JWT auth adapter | 1-2 days | Secure production access |
| P1 | Redis event bus + cache adapters | 2 days | Distributed deployment |
| P2 | Input validation (zod schemas) | 1-2 days | Security hardening |
| P2 | Logging + OpenTelemetry | 1-2 days | Observability |
| P3 | Slack/Discord messaging adapters | 2-3 days each | B2B integration channels |
| P3 | Webhook system | 3-5 days | Customer event subscriptions |

---

## SECTION 4: XPENSLY (Expense SDK) — 88 Files, 85 Tests

### What's COMPLETE & Production-Ready

| Component | Status | Notes |
|-----------|--------|-------|
| **SplitCalculator** | COMPLETE | 4 modes: equal, exact, percentage, shares. Handles rounding to cents. |
| **SettlementEngine** | COMPLETE | Aggregates expenses + refunds + prior settlements. Multi-currency. Point-in-time (`computeAsOf`). |
| **DebtSimplifier** | COMPLETE | Net-balance greedy algorithm. Minimizes transactions. Pairwise toggle. |
| **CurrencyConverter** | COMPLETE | Multi-currency with exchange rates. Formula: `amount * (toRate / fromRate)`. |
| **RecurrenceExpander** | COMPLETE | Daily/weekly/monthly. ID suffix generation. |
| **TripAggregator** | COMPLETE | Analytics: total/per-person/per-day, top payer/spender, timeline, category/phase breakdown. |
| **Models** (12 classes) | COMPLETE | Expense, Member, Trip, Settlement, DebtDelta, SplitResult, Payer, Refund, etc. |
| **InMemoryDataSource** | COMPLETE | Full XpenslyDataSource CRUD. Filtering. Auto-increment IDs. Good for testing. |
| **FixedRateProvider** | COMPLETE | Immutable hardcoded rates. Testing/offline use. |
| **VenmoPayment** | COMPLETE | `venmo://paycharge` deep links. |
| **UpiPayment** | COMPLETE | `upi://pay` URIs. QR-capable. |
| **PaypalPayment** | COMPLETE | `paypal.me/{user}/{amount}` URLs. |
| **9 Flutter Widgets** | COMPLETE | DebtCard, BalanceBar, SettlementCard, ExpenseEntry, ExpenseList, SplitModeToggle, PaymentButton, TripSummaryWidget, XpenslyDashboard |
| **Theme System** | COMPLETE | XpenslyThemeData with 3 presets: hello(), material(), minimal(). |
| **Tests (Core)** | 69 | 7 engine + 5 scenario test files. All split modes, multi-currency, edge cases. |
| **Tests (UI)** | 16 | 6 widget test files. Form validation, tab navigation, rendering. |

### What's STUBBED or INCOMPLETE

| Component | Issue | Severity |
|-----------|-------|----------|
| **StripePayment** | Mock URL only. Real Stripe requires server-side `/v1/checkout/sessions`. | HIGH |
| **RazorpayPayment** | Mock URL only. Real Razorpay requires server-side `POST /v2/orders`. | HIGH |
| **SupabaseDataSource** | NOT IMPLEMENTED. No real persistence backend. | CRITICAL for B2B |
| **Live Rate Provider** | Only FixedRateProvider. No API integration (OpenExchangeRates, Xe.com). | HIGH |
| **Web API Trip CRUD** | 8/19 routes return mock IDs (`trip_${Date.now()}`). Need DB wiring. | MEDIUM |

### What's Missing for Enterprise B2B

| Gap | Impact |
|-----|--------|
| **No authentication/authorization** | Any user can see/modify any trip |
| **No real-time sync** | Multi-user trips don't stay in sync |
| **No audit logging** | Can't resolve expense disputes |
| **No receipt storage** | `receiptUrl` field exists but no upload endpoint |
| **No notifications** | No "you owe $X" reminders |
| **No offline mode** | Requires network for all operations |
| **No item-level splits** | Can't split appetizer vs beverage |
| **No expense edit history** | No version tracking |
| **No accessibility** | No semantic labels for screen readers |

### Improvement Roadmap

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P0 | Implement SupabaseDataSource | 3-5 days | Real persistence |
| P1 | Fix Stripe adapter (server-side sessions) | 2-3 days | Real payments |
| P1 | Fix Razorpay adapter (server-side orders) | 2-3 days | Real payments (India) |
| P1 | Live exchange rate provider (OpenExchangeRates API) | 1-2 days | Accurate rates |
| P1 | Wire 8 trip CRUD routes to Supabase | 3-5 days | Complete REST API |
| P2 | Real-time sync (Supabase Realtime) | 2-3 days | Multi-user trips |
| P2 | Receipt upload (Supabase Storage) | 1-2 days | Photo receipts |
| P2 | Auth + RLS policies | 2-3 days | Trip-level permissions |
| P3 | Audit logging (changelog table) | 1-2 days | Dispute resolution |
| P3 | Push notifications for payment reminders | 2-3 days | User engagement |

---

## SECTION 5: APP (Flutter Shell) — 32 Views, 10 Widgets

### What's COMPLETE & Production-Ready

| Area | Status | Notes |
|------|--------|-------|
| **Auth Flow** | COMPLETE | Phone entry -> OTP -> verify. Animated transitions. Haptic feedback. |
| **Home Layout** | COMPLETE | 3-tab PageView: Chats, Groups, Memories. Bottom bar. |
| **Chat View** | COMPLETE | Message feed with Riverpod streams. Presence, typing, receipts. LiquidChatComposer. |
| **Decide-First UX (demov2)** | COMPLETE | Decision board, swim lane rails, plans view, gold burst, add item sheet, time scrubber, group summary. 2,492 LOC. |
| **Discover/Explore** | COMPLETE | Search, category chips, 2-column grid, carousel, suggestion cards, error/feedback sheets. |
| **Settings** | COMPLETE | Profile edit, device list, device linking page. |
| **AI (Spotlight)** | COMPLETE | Streaming response simulation. Backdrop blur. Auto-scroll. Ghost input. |
| **Invite Flow** | COMPLETE | Claim sheet (spring animation), invite surface. |
| **Providers** | COMPLETE | 5 Riverpod providers: E2EE state, conversation controller, action card, consensus listener, error listener. |
| **Widgets** | COMPLETE | ChatBubble, ChatFeed, LiquidChatComposer, SpatialSearchBar, ActionCardWidget, EncryptedImageView, InlinePollWidget, KeyboardAwareInput, LiquidFireText, VirtualizedChatList. |
| **Theme** | COMPLETE | HelloColors + HelloTypography. Zero-Box, No-Bold mandate enforced. |
| **Mock Engine** | COMPLETE | MockChatEngine + MockChatSession. Realistic simulation for dev. |
| **Platform (iOS)** | READY | Podfile, Runner.xcodeproj, Info.plist configured. |
| **Platform (Android)** | READY | build.gradle.kts (Kotlin DSL), Gradle wrapper configured. |

### What's MISSING or NEEDS WORK

| Gap | Issue | Severity |
|-----|-------|----------|
| **Test coverage** | Only discover module tested (1 file, 702 LOC). Auth, chat, settings, providers untested. | HIGH |
| **Custom fonts** | Theme references "Inter"/"Syne" but not in pubspec.yaml assets. | MEDIUM |
| **Web platform** | No Flutter web configuration. | MEDIUM |
| **Mock engine in prod** | `_useLiveEngine = false` is a const. Should be env-based or build variant. | MEDIUM |
| **Image caching** | No `cached_network_image`. Discovery items may OOM on large lists. | MEDIUM |
| **demov1 redundancy** | ~3,000 LOC of duplicate code. Superseded by demov2. | LOW |
| **Push notifications** | iOS NSE skeleton exists but not integrated. Android not wired. | HIGH (blocked by engine) |
| **Analytics** | No firebase_analytics, Mixpanel, or equivalent. | MEDIUM |

### Improvement Roadmap

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P1 | Expand test coverage (auth, chat, providers) | 3-5 days | Confidence for refactors |
| P1 | Wire `_useLiveEngine` to environment/build variant | 0.5 day | Prevent shipping mock engine |
| P2 | Add custom fonts to pubspec.yaml or remove references | 0.5 day | Consistent typography |
| P2 | Add `cached_network_image` for discovery/media | 0.5 day | Memory safety |
| P2 | Archive demov1 to branch | 0.5 day | Reduce APK size |
| P3 | Add Flutter web platform support | 1-2 days | Web client option |
| P3 | Add analytics (Firebase Analytics or Mixpanel) | 1 day | User behavior data |

---

## SECTION 6: DATABASE — 45 Migrations, 29 Tables

### Schema State

**Foundation:** users, spaces, space_members, messages, message_ciphertexts, space_invites
**Encryption:** key_bundles (with PQXDH columns), one_time_pre_keys (with PQXDH columns)
**Activity:** reactions, decision_items, guest_votes, space_tombstones, read_watermarks, sk_acknowledgments, group_sequences
**Devices:** user_devices, linked_devices, media
**Trip/Settlement:** space_dates, space_constraints, user_constraints, constraint_prompts
**Logistics:** member_logistics, user_taste_profiles
**RPCs:** send_e2ee_message (atomic), fetch_key_bundle (atomic OTK), find_or_create_chat, mark_group_read, uuidv7_to_timestamptz

### Critical Gaps (8 Issues from Validation)

| # | Issue | Test Failure | Severity | Fix |
|---|-------|-------------|----------|-----|
| 1 | `tombstone_message()` RPC missing | CRYPTO-39 | CRITICAL | Create SQL function for GDPR message deletion |
| 2 | 5-device limit trigger missing | CRYPTO-35 | CRITICAL | Add `BEFORE INSERT` trigger on `user_devices` |
| 3 | Dedup broken in `send_e2ee_message()` | STRESS-23, CRYPTO-16, CRYPTO-17 | CRITICAL | Fix `ON CONFLICT (id)` to return original row's server_seq + created_at |
| 4 | `update_read_watermark()` RPC not exposed | N/A | HIGH | Create function for engine's `session.markRead()` |
| 5 | `get_group_sequence()` RPC not exposed | N/A | HIGH | Expose current_val query (avoids O(n) MAX scan) |
| 6 | Partition auto-creation cron missing | N/A | MEDIUM | Add `pg_cron` job for monthly partition creation |
| 7 | `profile_keys` table missing | N/A | MEDIUM | Explicit table for profile key distribution |
| 8 | Push fallback text leaks encryption mention | CRYPTO-50 | LOW | Change to "New message" |

### Xpensly Tables (NOT YET CREATED)

The following tables are defined in the Xpensly SDK spec but have no migrations:

- `xpensly_trips`
- `xpensly_trip_members`
- `xpensly_expenses`
- `xpensly_expense_payers`
- `xpensly_expense_splits`
- `xpensly_settlements`
- `xpensly_refunds`
- `xpensly_exchange_rates`

### Improvement Roadmap

| Priority | Task | Effort | Impact |
|----------|------|--------|--------|
| P0 | Fix deduplication in send_e2ee_message() | 0.5 day | No duplicate messages |
| P0 | Add 5-device limit trigger | 0.5 day | Security: prevent device flooding |
| P0 | Create tombstone_message() RPC | 0.5 day | GDPR message deletion |
| P1 | Create update_read_watermark() RPC | 0.5 day | Read receipts work |
| P1 | Create get_group_sequence() RPC | 0.5 day | O(1) sequence lookup |
| P1 | Create 8 Xpensly tables + RLS policies | 2-3 days | Expense persistence |
| P2 | Add pg_cron partition job | 0.5 day | Auto-manage partition growth |
| P2 | Create profile_keys table | 0.5 day | Encrypted profile distribution |

---

## SECTION 7: DOCUMENTATION STATE

### What Exists

| Document | Location | Quality |
|----------|----------|---------|
| **CLAUDE.md** (root) | `/CLAUDE.md` | Excellent (306 lines). Architecture, public API, security boundaries, all rules. |
| **CLAUDE.md** (web) | `/web/CLAUDE.md` | Good but OUTDATED (23 routes documented, 51 exist). |
| **CLAUDE.md** (docs) | `/docs/CLAUDE.md` | DUPLICATE of root. Should be removed. |
| **apr3.md** | `/apr3.md` | Good feature inventory. Claims all features "Built". |
| **FEATURES.md** | `/engine/FEATURES.md` | WhatsApp parity chart. Good reference. |
| **HANDOFF_STATE.md** | `/HANDOFF_STATE.md` | Phase 2 handoff context. UI doctrines. |
| **FRONTEND_TO_BACKEND_HANDOFF.md** | Root | 477 lines. Detailed Phase 2 wiring guide. 10 sections, API contracts, error types. |
| **PHASE_1_FRONTEND_MANIFEST.md** | Root | Phase 1 frontend state. 63 lines. |
| **crypto.md** | Root | 50-task engineering checklist. |
| **4PM_Goal.md** | `/docs/4PM_Goal.md` | 42-step planet-scale blueprint. |
| **Design Specs** | `/docs/superpowers/specs/` | 10 dated specs: Fortress, Vault, Engine, SDK, Xpensly, Decide-First UX, Discovery, Clarity Canvas. |
| **Implementation Plans** | `/docs/superpowers/plans/` | 2 plans: Fortress, Decide-First UX. |
| **Test Results** | `/docs/test-results/` | 1 report (2026-03-28). 92/100 passing. |

### What's MISSING (Enterprise Blockers)

| Document | Purpose | Severity |
|----------|---------|----------|
| **DEPLOYMENT.md** | Production runbook (Vercel + Supabase + Firebase setup) | CRITICAL |
| **RUNBOOK.md** | On-call troubleshooting, SLO definitions, alerting rules | CRITICAL |
| **INCIDENT_RESPONSE.md** | Crypto key compromise, data breach, DDoS playbooks | CRITICAL |
| **SECURITY_AUDIT.md** | Pen test results, threat model, known vulnerabilities | CRITICAL |
| **PERFORMANCE_BASELINE.md** | Benchmark results (init, encrypt/decrypt latency, sync drain) | HIGH |
| **MIGRATION_RUNBOOK.md** | Zero-downtime schema migration strategy | HIGH |
| **ARCHITECTURE_DECISION_LOG.md** | Why Supabase > Firestore, Signal > WireGuard, etc. | MEDIUM |
| **API_CONTRACT.md** | Versioning policy, deprecation timeline, stability guarantees | MEDIUM |
| **OBSERVABILITY.md** | Structured logging plan, Sentry config, dashboards | MEDIUM |

---

## SECTION 8: EXTRACTABLE B2B MODULES

These are components that can be published as standalone packages for enterprise customers:

### 1. E2EE Crypto Kit (Dart + Web)
**Source:** `engine/lib/src/crypto/` + `web/src/lib/crypto/`
**Publish as:** `e2ee_crypto_kit` (pub.dev) + `@hello/e2ee-crypto` (npm)
**Includes:** Signal Protocol (Double Ratchet, X3DH, Sender Keys), media AEAD, key management, hardware key store interface
**Completeness:** 95% (Dart), 100% (Web)
**Use cases:** Any messaging app needing E2EE. Banks, healthcare, government.

### 2. Decision Engine (TypeScript)
**Source:** `algo/`
**Publish as:** `@hello/decision-engine` (npm)
**Includes:** Heart-Sort, Green-Lock commitment, state machines, AI grounding, consensus orchestration, RESTful request handler
**Completeness:** 95% (fix GroupId dupes)
**Use cases:** Group planning apps, team coordination tools, collaborative decision-making platforms, Slack/Discord bots.

### 3. Xpensly Expense SDK (Dart + REST)
**Source:** `xpensly/` + `web/src/app/api/xpensly/`
**Publish as:** `xpensly` (pub.dev) + `@hello/xpensly` (npm)
**Includes:** Split calculator, settlement engine, debt simplifier, currency converter, trip aggregator, 9 Flutter widgets, 19 REST routes
**Completeness:** 85% (core logic), 55% (backend)
**Use cases:** Travel apps, roommate apps, corporate expense tools.

### 4. Multi-Device Protocol (Sesame)
**Source:** `engine/lib/src/devices/` + `web/src/lib/crypto/device-*.ts`
**Publish as:** `@hello/sesame-protocol`
**Includes:** Device registry, QR linking, fan-out encryption, key rotation on unlink
**Completeness:** 40% (Dart stubbed, Web complete)
**Use cases:** Any app needing secure multi-device with E2EE.

### 5. AI Intelligence Orchestrator
**Source:** `web/src/lib/intelligence/` + `web/src/app/api/hello/`
**Publish as:** `@hello/ai-orchestrator`
**Includes:** 3-tier LLM routing (Gemini -> SearchAPI -> Apify), tool registry (8 tools), taste intersection, grounding context
**Completeness:** 95%
**Use cases:** Travel chatbots, lifestyle assistants, search-augmented AI agents.

### 6. Discovery Engine
**Source:** `web/src/lib/discovery/` + `web/src/app/api/discovery/`
**Publish as:** `@hello/discovery-engine`
**Includes:** Multi-provider architecture, seeded catalog, Gemini enrichment, Apify scraping, deduplication, priority ranking
**Completeness:** 100%
**Use cases:** Catalog/marketplace apps, travel platforms, recommendation engines.

### 7. Offline-First Sync Engine (Dart)
**Source:** `engine/lib/src/sync/` + `engine/lib/src/persistence/`
**Publish as:** `e2ee_sync_engine` (pub.dev)
**Includes:** OutboxWorker, WatermarkSync, GapDetector, ConflictResolver, SyncCoordinator, Drift ORM with SQLCipher
**Completeness:** 90%
**Use cases:** Any Flutter app needing offline-first with encrypted local storage.

### 8. Consensus / Voting Widget Kit (Flutter + React)
**Source:** `app/lib/demov2/` + `web/src/components/DecisionBoard.tsx`
**Publish as:** `@hello/consensus-ui`
**Includes:** Decision board, swim lane rails, action cards, gold burst celebration, consensus banner/timer
**Completeness:** 100% (UI), depends on algo/ for logic
**Use cases:** Group coordination, team polling, product feature voting.

---

## SECTION 9: ENTERPRISE READINESS SCORECARD

| Dimension | Score | Key Gaps |
|-----------|-------|----------|
| **Architecture** | 90/100 | Hexagonal everywhere. Clean separation. Port/adapter pattern. |
| **Cryptography** | 85/100 | Signal Protocol complete. Push decrypt stubbed. PQXDH placeholder. |
| **Database** | 65/100 | 29 tables. 8 critical gaps (missing RPCs, triggers, dedup). Xpensly tables missing. |
| **API Completeness** | 85/100 | 51 web routes. Engine public API solid. Xpensly trip CRUD stubbed. |
| **UI/UX** | 90/100 | 43 web components + 32 Flutter views. Zero stubs. Professional animations. |
| **Testing** | 75/100 | 198 algo + 85 xpensly + 92/100 SDK. Flutter app undertested. |
| **Security** | 70/100 | E2EE solid. No pen test. No incident response. Certificate pinning missing. |
| **Observability** | 30/100 | ChatEngineObserver exists. No structured logging. No APM. No dashboards. |
| **Documentation** | 60/100 | Specs excellent. Ops docs missing. Fragmented handoffs. |
| **Deployment/Ops** | 25/100 | Vercel deployed. No runbook. No SLOs. No alerting. No CI/CD for tests. |
| **B2B Readiness** | 55/100 | 8 extractable modules identified. None published. No versioning/release pipeline. |

### Overall: 66/100 — STRONG BETA, NOT YET ENTERPRISE

---

## SECTION 10: PRIORITY EXECUTION PLAN

### Week 1: Critical Fixes (Unblock Production)
- [ ] Fix algo/ duplicate GroupId declarations (15 min)
- [ ] Fix DB: send_e2ee_message deduplication (0.5 day)
- [ ] Fix DB: 5-device limit trigger (0.5 day)
- [ ] Fix DB: tombstone_message() RPC (0.5 day)
- [ ] Fix DB: update_read_watermark() RPC (0.5 day)
- [ ] Engine: Persist sender keys to Drift (1 day)

### Week 2: Multi-Device & Push (User-Facing Blockers)
- [ ] Engine: Multi-device fan-out (remove hardcoded deviceId=1) (2-3 days)
- [ ] Engine: Wire push decryption (iOS NSE + Android Service) (3-5 days)
- [ ] DB: Create Xpensly tables + RLS policies (2-3 days)

### Week 3: Backend Completion
- [ ] Web: Wire 8 Xpensly trip CRUD routes to Supabase (3-5 days)
- [ ] Algo: PostgreSQL persistence adapter (3-5 days)
- [ ] Algo: JWT auth adapter (1-2 days)

### Week 4: Enterprise Hardening
- [ ] Create DEPLOYMENT.md, RUNBOOK.md, INCIDENT_RESPONSE.md (3 days)
- [ ] Add structured logging (Axiom/Sentry) across all packages (2 days)
- [ ] Engine: Contact discovery + profile key distribution (4-6 days)

### Backlog (Ongoing)
- [ ] Engine: Device linking protocol (QR + history transfer) — 5-7 days
- [ ] Engine: Certificate pinning — 2 days
- [ ] Xpensly: Fix Stripe/Razorpay payment adapters — 4-6 days
- [ ] Xpensly: Live exchange rate provider — 1-2 days
- [ ] App: Expand Flutter test coverage — 3-5 days
- [ ] Performance baseline measurements + CI regression tests
- [ ] Security audit (external)
- [ ] Algo: Redis event bus + cache adapters — 2 days
- [ ] Algo: Slack/Discord messaging adapters — 4-6 days
- [ ] Engine: Real Kyber-1024 (post-quantum) — 3-5 days

---

## SECTION 11: WHAT WE SHOULD BE THINKING BIGGER ABOUT

### From the apr3.md closing question: "Are we thinking small?"

**No.** The foundation is Instagram/Snapchat-caliber in architecture. What separates you from them is execution completeness, not ambition. Here's where to think bigger:

**1. B2B Platform Play**
You have 8 extractable modules. If published as SDKs, any messaging app could license your E2EE, consensus engine, or expense splitting. This is a **platform business** (like Twilio for chat), not just a consumer app.

**2. Protocol Standardization**
Your Signal Protocol + Decision Engine + Consensus Protocol combination is unique. No other platform has E2EE + group decision-making. Consider publishing the protocol spec (like Signal did) to build an ecosystem.

**3. Composable Social Primitives**
Each module (crypto, consensus, settlement, discovery, AI) is a **social primitive**. Think Lego blocks: any developer combines them to build their own social app. This is bigger than one app.

**4. Enterprise Compliance**
With E2EE + audit trails (franking) + GDPR deletion (tombstones) + multi-device, you're positioned for healthcare (HIPAA), finance (SOC 2), and government (FedRAMP). These markets pay 10-100x consumer.

**5. AI-Native Messaging**
@hello's 3-tier architecture (local SLM -> Gemini -> Apify deep research) is ahead of every chat app. The grounding system (AI respects locked decisions) is novel. This is the future of AI-augmented group coordination.

---

*Generated by full codebase review across engine/ (159 files), web/ (51 routes, 43 components), algo/ (22 files, 198 tests), xpensly/ (88 files, 85 tests), app/ (32 views, 10 widgets), and 45 database migrations.*
