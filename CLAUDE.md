# CLAUDE.md — e2ee_chat_sdk Monorepo

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Structure
- engine/   — White-label E2EE chat SDK (package: e2ee_chat_sdk, 144 source files)
- app/      — Flutter app shell (package: hello_app, imports e2ee_chat_sdk)
- web/      — Next.js 16 web app (React + 18 API routes + Xpensly REST API)
- algo/     — Decision engine (TypeScript, 198 tests, hexagonal architecture)
- xpensly/  — Expense splitting SDK (xpensly_core + xpensly_ui, 88 files, 85 tests)
- docs/     — Architecture specs, plans, test results, handoff docs

## SDK Identity
- **Package name:** `e2ee_chat_sdk` (renamed from `hello_engine`)
- **Barrel file:** `engine/lib/e2ee_chat.dart` (backward-compat: `chat_engine.dart` re-exports)
- **BrandConfig:** White-label via `BrandConfig(appName, aiName, aiEndpoint, pushChannelId)`
- **Default brand:** `appName: 'hello'`, `aiName: '@hello'`, `aiEndpoint: '/api/hello'`

## Terminology
| Term | Meaning | Old name |
|------|---------|----------|
| group | Shared conversation space | space |
| dm | 1:1 direct message | sanctuary |
| home | Main screen | galaxy |
| hello | The AI assistant (configurable via BrandConfig) | xark, @xark |
| group_id | FK to groups table | space_id |
| invite | Join link | summon |
| suggestions | Proactive hints | whispers |
| consensus | Voting module | handshake |
| MessageType.ai | AI assistant message type | MessageType.hello |

**Exception:** HKDF crypto info strings (`XarkE2EE-*`) intentionally retain the "Xark" prefix — these are cryptographic constants and must not be renamed.

## Commands
```bash
cd engine && flutter test             # E2EE engine tests
cd engine && dart analyze             # Static analysis (0 errors target)
cd engine && dart run build_runner build --delete-conflicting-outputs  # Freezed/Drift codegen
cd app    && flutter run -d chrome    # Flutter app
cd web    && npm run dev              # Next.js web app (port 3000)
cd web    && npm run build            # Production build
cd web    && npx tsx tests/sdk-validation.ts  # 100 SDK validation tests
cd algo   && npm test                 # Decision engine tests (198)
cd xpensly/xpensly_core && dart test  # Xpensly core tests (69)
cd xpensly/xpensly_core && dart analyze  # Xpensly core analysis
cd xpensly/xpensly_ui && flutter test    # Xpensly UI widget tests (16)
```

## Architecture Blueprint
9 loosely coupled services: Auth, Group, Intelligence, Decision Engine, Messaging, Media, Notification, Settlement, Itinerary.
- **Event bus:** Supabase Realtime (Postgres NOTIFY/LISTEN -> WebSocket). Channel: `chat:{groupId}`.
- **Scope:** Solo (1 user) + Small Group (2-15 members). Large group deferred.
- **Two-step commitment:** consensus lock (automated at >80%) -> claim + purchase (manual, owner + proof).
- **@hello AI:** Silent by default. Three-tier: gemini-local (~7-10s), gemini-search (~40-50s), apify (15-50s).
- **Privacy:** @hello context = grounding state map + last 15 messages on invocation ONLY. No passive listening.

## Security Boundary (Iron Rule)
**The Flutter UI NEVER talks to the backend directly.** All data flows through the engine.
```
FORBIDDEN:  supabase.from('users').select(...)     // NEVER from UI
REQUIRED:   engine.getProfile(userId)               // Always through engine
FORBIDDEN:  http.post(Uri.parse('/api/hello'))      // NEVER from UI
REQUIRED:   engine.streamHelloResponse(prompt, gid) // Always through engine
```
The engine is the API. Supabase and Firebase are implementation details the UI never sees.

## Key Constraints
- **E2EE is absolute law.** No plaintext fallback. If encryption fails, the message does not send. If a feature cannot work with E2EE, the feature does not ship.
- **No-bold mandate.** font-weight 400 (primary), 300 (secondary). Weights 500-900 are forbidden.
- engine/ is headless — zero UI code. UI lives in app/.
- User IDs are text format (e.g., `name_ram`), not UUIDs.
- RLS uses `auth.jwt()->>'sub'` (not `auth.uid()`).
- Port 3000 only for web dev server.
- Database encrypted via SQLCipher (key from platform Keychain). Biometric app lock is optional UI-layer concern.

## Engine Public API (e2ee_chat_sdk)

### Core (ChatEngine)
```dart
// Initialization
final engine = await ChatEngine.initialize(ChatEngineConfig(
  authToken, userId, deviceId, pushToken, serverBaseUrl,
  brand: BrandConfig(appName: 'hello', aiName: '@hello'),
));

// Streams
engine.conversations           // Stream<List<Conversation>>
engine.connectionState         // Stream<EngineConnectionState>
engine.totalUnreadCount        // Stream<int>
engine.errors                  // Stream<ChatEngineError>

// Actions
engine.getProfile(userId)      // Future<UserProfile>
engine.updateProfile(...)      // Future<void>
engine.getDevices()            // Future<List<DeviceInfo>>
engine.unlinkDevice(deviceId)  // Future<void>
engine.getDisplayName(userId)  // Future<String> (cached)
engine.createGroup(title)      // Future<Conversation>
engine.generateInvite()        // Future<InviteLink>
engine.claimInvite(code)       // Future<JoinResult>
engine.discoverContacts(hashes)// Future<List<ContactMatch>>
engine.streamHelloResponse(prompt, groupId)  // Stream<HelloResponseChunk>

// Lifecycle
engine.suspend() / engine.resume() / engine.dispose()
```

### Per-Conversation (ChatSession)
```dart
final session = engine.getSession('group_123');
session.messages   // Stream<List<Message>>
session.typing     // Stream<List<TypingIndicator>>
session.receipts   // Stream<List<Receipt>>
session.presence   // Stream<PresenceState>
session.sendText(plaintext)
session.sendMedia(MediaPayload(...))
session.sendTyping()
session.markRead(messageId)
session.react(messageId, emoji)
session.loadMore(limit: 50)
session.getKeyFingerprint()
```

### Optional: Decision Engine (ChatEngineDecisions mixin)
```dart
if (engine is ChatEngineDecisions) {
  engine.getDecisionItems(groupId)  // Future<List<DecisionItem>>
  engine.reactToItem(itemId, signal)
  engine.lockItem(itemId, proof)
}
```

### Auth (AuthService — called BEFORE engine.initialize)
```dart
final auth = AuthService(serverBaseUrl);
final result = await auth.authenticateWithFirebase(firebaseIdToken: token);
// result.accessToken → feed into ChatEngineConfig.authToken
```

## Engine Architecture (144 source files)
```
engine/lib/src/
├── adapters/        # Supabase/Firebase/SSE adapter implementations
├── auth/            # AuthService, AppLockManager
├── config/          # BrandConfig
├── contacts/        # Private contact discovery (truncated SHA-256)
├── crypto/          # Signal Protocol (X3DH, Double Ratchet, Sender Keys, PQXDH)
│   ├── keys/        # Key management, hardware key store, database key manager
│   ├── media/       # Streaming AEAD (64KB chunks), BlurHash
│   ├── pqxdh/       # Post-quantum hybrid (X25519 + Kyber-1024)
│   ├── ratchet/     # Double Ratchet with bounded skipped-key dictionary
│   ├── sender_keys/ # Group cipher, SK recovery handler
│   ├── x3dh/        # Extended Triple Diffie-Hellman
│   ├── franking/    # Cryptographic message franking (E2EE moderation)
│   └── profile/     # Profile key encryption
├── devices/         # Multi-device registry (Sesame protocol), device linking
├── domain/          # Freezed models (Message, Conversation, Receipt, etc.)
├── extensions/      # ChatEngineDecisions mixin
├── intelligence/    # On-device SLM, constraint detection
├── media/           # Background uploader, link unfurling
├── notifications/   # Push decryptor, method channel bridge, interactive actions
├── observer/        # ChatEngineObserver, E2EE metrics
├── persistence/     # Drift ORM + SQLCipher, repositories, local feed
├── ports/           # Transport interfaces (MessageGateway, RealtimeGateway, TransientQueue, PushAdapter, AIAdapter)
├── public_api/      # ChatEngine, ChatSession, ChatEngineConfig
├── sync/            # SyncCoordinator, OutboxWorker, WatermarkSync, ConflictResolver
└── transport/       # SupabaseClientWrapper, RealtimeListener, typing indicators, realtime receipts
```

## Decide-First Group UX (app/lib/demov2/)
The group interior defaults to the Decide tab (Netflix swim lanes), with Chat accessible via swipe.
- `space_layout.dart` — Decide (idx 0) | Chat (idx 1), FAB opens AddItemSheet
- `decision_board.dart` — Orchestrator: groups DecisionItems by category, renders swim lane rails
- `swim_lane_rail.dart` — Horizontal card rail (78% width, 55% height) with vital labels
- `group_summary_card.dart` — Compact group pulse (active/locked/new counts, hottest item %)
- `add_item_sheet.dart` — [+] bottom sheet (photo + title + category, 3-second flow)
- `gold_burst.dart` — GoldBurstOverlay: 40 gold particles on consensus >= 80%, wraps ActionCardWidget
- Smart category routing mirrors React `DecisionBoard.tsx` (hotels, restaurants, things to do, experiences, flights, dining, gifts, decorations, ideas)
- Mock data: 15 Bali items, 8 Sarah items, 12 Tokyo items across 5 categories each

## Web Infrastructure (Added in Fortress Sprint)
- `web/src/lib/postgres-pool.ts` — TCP connection pool singleton (globalThis, idle_timeout: 10s)
- `web/src/lib/rate-limit-edge.ts` — Upstash Redis rate limiting (token bucket + sliding window, fail-open/closed)
- `web/src/lib/key-cache.ts` — Key bundle Redis cache (SETNX, 5min TTL, X-Bypass-Cache)
- `web/src/lib/jwt-replay.ts` — JWT replay protection (jti + Redis SETNX)
- `web/src/lib/appcheck.ts` — Firebase AppCheck device attestation
- `web/src/lib/crypto/mutex.ts` — Web Locks API (cross-tab E2EE safety, 5s AbortController timeout)
- `web/src/lib/crypto/uuidv7.ts` — Client-side UUIDv7 generator with clock delta correction
- `web/src/lib/ports/` — Strangler Fig extraction interfaces (MessageGateway, RealtimeGateway, TransientQueue)
- `web/src/proxy.ts` — Rate limiting in middleware (blocks before serverless function invocation)

## Database Migrations (Fortress)
- `group_sequences` — O(1) per-group monotonic sequence counters
- `send_e2ee_message` — Atomic RPC (membership + clock skew + sequence + idempotent insert + ciphertext fan-out)
- `read_watermarks` — Replaces unread_counts (no deadlocks)
- `sk_acknowledgments` — O(1) sender key distribution tracking
- `uuidv7_to_timestamptz` — Extract timestamp from UUIDv7 for partition pruning
- `tombstone_message` — GDPR deletion with partition-pruned ciphertext removal
- PQXDH columns on `key_bundles` and `one_time_pre_keys` (nullable, backward-compat)
- `user_devices` — Multi-device registry (5-device limit trigger)

## E2EE Architecture
Signal Protocol implementation with post-quantum upgrade path:
- **L1:** Key management (identity keys, signed pre-keys, OTKs, Kyber pre-keys)
- **L2:** Message encryption (zero-knowledge — server never sees plaintext)
- **L3:** Structured intelligence (AI reads only server_content, never E2EE payloads)
- **1:1 (dm):** Double Ratchet with X3DH key agreement (3-DH fallback when no OTK)
- **Groups (2-15):** Sender Keys with Ed25519 message signing + ACK-based distribution
- **Post-quantum:** PQXDH hybrid X25519 + Kyber-1024 (backward-compatible)
- **Multi-device:** Sesame protocol (5 devices, fan-out encryption, QR linking)
- **Media:** Streaming AEAD (64KB chunks, up to 2GB, AES-256-GCM)
- **Push:** iOS NSE + Android Service + Web SW (fallback: "You may have new messages")
- **Primitives:** XChaCha20-Poly1305 AEAD, Ed25519, Curve25519 DH, HKDF-SHA-256, Argon2id
- **Runtime (web):** libsodium-wrappers-sumo (WASM), client-side only
- **Runtime (engine):** `cryptography` package (pure Dart, cross-platform)
- **HKDF info strings use `XarkE2EE-*` prefix** — crypto constants, do not rename
- **Crypto isolate:** Dedicated background isolate, TransferableTypedData, 10s watchdog, 3 max respawns

## Xpensly SDK (Expense Splitting)
Reusable expense-splitting SDK extracted from hello's settlement ledger. Three-layer architecture:
- **`xpensly_core`** (pure Dart) — split calculator, settlement engine, debt simplifier, currency converter, recurrence expander, trip aggregator
- **`xpensly_ui`** (Flutter) — 9 composable themed widgets (ExpenseEntry, SettlementCard, DebtCard, PaymentButton, ExpenseList, BalanceBar, TripSummaryWidget, SplitModeToggle, XpenslyDashboard)
- **REST API** (`web/src/app/api/xpensly/`) — 19 TypeScript route handlers (5 stateless calculation + 14 stateful trip management)

Split modes: equal, exact, percentage, shares. Debt simplification: graph-based minimum-transaction (default), pairwise toggle.
Payment providers: Venmo, UPI, PayPal, Stripe, Razorpay (pluggable via `XpenslyPaymentProvider` interface).
Data layer: pluggable via `XpenslyDataSource` interface (ships with `InMemoryDataSource`, `SupabaseDataSource` stub).
Theme presets: `hello()` (dark/cyan), `material()` (M3), `minimal()`.

```dart
// Flutter usage
final xpensly = Xpensly(
  dataSource: InMemoryDataSource(),
  paymentProviders: [VenmoPayment(), UpiPayment()],
  config: XpenslyConfig(baseCurrency: 'EUR', simplifyDebts: true),
);
```

**Spec:** `docs/superpowers/specs/2026-04-02-xpensly-sdk-design.md`
**DB tables:** `xpensly_trips`, `xpensly_trip_members`, `xpensly_expenses`, `xpensly_expense_payers`, `xpensly_expense_splits`, `xpensly_settlements`, `xpensly_refunds`, `xpensly_exchange_rates`

## Pluggable Adapters (White-Label SDK)
The engine uses port interfaces — implementations are swappable:
- **TransportAdapter:** `MessageGateway`, `RealtimeGateway`, `TransientQueue` (default: Supabase)
- **PushAdapter:** `FirebasePushAdapter` / `NoopPushAdapter` (default: Firebase)
- **AIAdapter:** `SSEAIAdapter` / `NoopAIAdapter` (default: SSE to brand's aiEndpoint)
- Supabase and Firebase are optional — customers can provide their own adapters

## Infrastructure Lock (Default Stack)
| Service | Provider | Purpose |
|---------|----------|---------|
| Auth (Phone OTP) | Firebase Auth | Phone verification, identity |
| Database | Supabase Postgres | All data, decision engine, RLS |
| Realtime | Supabase Realtime | WebSocket event bus |
| Storage (E2EE) | Firebase Storage | Encrypted media blobs |
| Push | Firebase Cloud Messaging | iOS/Android/Web push |
| Intelligence | Gemini 2.5 Flash | @hello AI, intent parsing |
| Rate Limiting | Upstash Redis | Edge rate limiting, key cache, JWT replay |

**FORBIDDEN:** Supabase Auth, Firestore, direct Supabase queries from Flutter UI.

## Signal System (Reaction Vocabulary)
- **LoveIt:** weight +5. Color: `var(--hello-amber)`.
- **WorksForMe:** weight +1. Color: `var(--hello-gray)`.
- **NotForMe:** weight -3. Color: `var(--hello-orange)`.
- One reaction per user per item. Last reaction wins. Score can go negative.

## State Machine (4 Preset Flows)
Defined in `algo/src/engine/state-flows.ts`:
- **BOOKING_FLOW** (default): proposed -> ranked -> locked -> claimed -> purchased.
- **PURCHASE_FLOW:** researching -> shortlisted -> negotiating -> purchased.
- **SIMPLE_VOTE_FLOW:** nominated -> ranked -> chosen.
- **SOLO_DECISION_FLOW:** considering -> leaning -> decided.

## RLS Policies
- `auth_user_group_ids()`: SECURITY DEFINER function, returns group_ids for the authenticated user.
- All tables filter via this function.
- **IMPORTANT:** `auth.uid()` requires UUID. Our IDs are text (e.g., `name_ram`), so use `auth.jwt()->>'sub'`.

## Deployment
- **GitHub:** `git@github.com:xarkdev9/xark.git` (remote: new-origin)
- **Vercel:** project under scope `xarks-projects-700da30e`
- **Production URL:** https://gethello.ai
- Push: `GH_TOKEN=$(gh auth token) git -c "http.https://github.com/.extraheader=Authorization: basic $(echo -n "x-access-token:$(gh auth token)" | base64)" push new-origin main`

## CSS Variables
All theme tokens use `--hello-*` prefix (defined in `web/src/app/globals.css`). See `web/CLAUDE.md` for the full list.

## Test Results
- **SDK validation:** 92/100 (50 stress + 50 crypto) — see `docs/test-results/`
- **PR:** https://github.com/xarkdev9/xark/pull/1
- **Code review:** 12 issues found, 2 critical (DatabaseFactory disabled, crypto isolate stub)

## Key Documents
- `docs/FRONTEND_HANDOFF.md` — Frontend team integration guide
- `docs/FRONTEND_TO_BACKEND_HANDOFF.md` — Backend tasks from frontend team
- `PHASE_1_FRONTEND_MANIFEST.md` — Phase 1 UI completion state
- `docs/superpowers/specs/` — All design specs (Fortress, Vault, Engine, Polish, Moat, SDK, Xpensly, Decide-First UX)
- `docs/superpowers/specs/2026-04-03-decide-first-group-ux-design.md` — Decide-first group UX design spec
- `docs/superpowers/specs/2026-04-02-xpensly-sdk-design.md` — Xpensly SDK design spec
- `docs/superpowers/plans/` — Implementation plans
- `docs/superpowers/plans/2026-04-03-decide-first-ux-plan.md` — Decide-first UX plan (8 tasks, all implemented)
- `docs/test-results/` — SDK validation reports
- `crypto.md` — 50-task engineering checklist (all implemented)
- `docs/4PM_Goal.md` — 42-step planet-scale blueprint (all implemented)
