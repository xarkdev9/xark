# hello Monorepo — Full Architecture Status

**Date:** 2026-03-27 10:00 AM
**Monorepo:** ~/hello/

---

## Structure

```
~/hello/
├── engine/   → hello_engine (Dart)    — Headless E2EE chat engine
├── app/      → hello_app (Dart)       — Flutter UI shell
├── web/      → Next.js 16 (TypeScript) — React web app + API backend
├── algo/     → algo (TypeScript)      — Decision engine (pure logic)
└── docs/     → Architecture docs
```

---

## Database Tables (17 tables, 30+ RPCs)

| Table | Purpose |
|---|---|
| `groups` | Chat groups and DMs (`type`: 'group' or 'dm') |
| `group_members` | Membership (group_id, user_id) |
| `group_dates` | Trip/event dates |
| `group_ledger` | Activity audit trail |
| `group_invites` | Pending invitations |
| `group_tombstones` | Sender Key rotation triggers |
| `group_constraints` | Dietary, budget, accessibility rules |
| `invite_links` | Shareable join codes |
| `messages` | Message metadata (content always NULL for E2EE) |
| `message_ciphertexts` | E2EE payloads (per-recipient-device) |
| `key_bundles` | Identity + signed pre-keys per device |
| `one_time_pre_keys` | Consumable OTKs for X3DH |
| `decision_items` | Items being voted on |
| `reactions` | LoveIt (+5), WorksForMe (+1), NotForMe (-3) |
| `media` | Encrypted media metadata |
| `member_logistics` | Trip logistics per member |
| `rate_limits` | Per-user rate limiting |

### RPCs (30+)

| RPC | Purpose |
|---|---|
| `auth_user_group_ids()` | Returns group_ids for current JWT user (SECURITY DEFINER) |
| `auth_user_space_ids()` | Backwards-compat alias for above |
| `fetch_key_bundle(user_id, device_id)` | Atomic key bundle fetch + OTK consume (FOR UPDATE SKIP LOCKED) |
| `find_or_create_chat(user_id, other_user_id)` | WhatsApp-style 1:1 DM creation |
| `get_space_member_devices(group_id, exclude_user)` | All devices for SK distribution |
| `get_latest_messages_per_space(group_ids)` | Home feed message previews |
| `get_push_tokens_for_space(group_id)` | FCM tokens (filters muted) |
| `get_unread_counts(user_id)` | Per-group unread counts |
| `react_to_item(item_id, user_id, reaction)` | Signal voting with dedup |
| `lock_item(item_id, user_id)` | Green-lock commitment |
| `transfer_ownership(item_id, from, to)` | Ownership transfer |
| `claim_summon_link(code, user_id)` | Atomic invite claim |
| `join_via_invite(token, user_id)` | Name-only join |
| `mark_space_read(group_id, user_id)` | Reset unread count |
| `auto_lock_expired_consensus()` | Cron: auto-lock at 80% |
| `purge_expired_xark_messages()` | Cron: cleanup old AI messages |
| `purge_expired_summon_links()` | Cron: cleanup expired invites |
| `insert_system_message(group_id, content)` | System message injection |
| `save_taste_profile(user_id, profile)` | Onboarding preferences |
| `get_space_taste_profiles(group_id)` | Group taste intersection |
| `revoke_device(user_id, device_id)` | E2EE device revocation |
| `check_rate_limit(user_id, action)` | Per-action rate limiting |

---

## engine/ (290 tests, 66 source files)

**Package:** `hello_engine` v0.1.0 — headless, zero UI

### Files by Layer

#### Crypto (15 files)
| File | Purpose |
|---|---|
| `crypto/crypto.dart` | Barrel export |
| `crypto/keys/key_types.dart` | IdentityKeyPair, PreKeyBundle, SessionState, SenderKeyRecord, etc. |
| `crypto/keys/key_store.dart` | Abstract key store interface |
| `crypto/keys/key_store_impl.dart` | Concrete key store (flutter_secure_storage) |
| `crypto/keys/ed25519_to_curve25519.dart` | Birational mapping (Ed25519 ↔ Curve25519) |
| `crypto/x3dh/x3dh.dart` | X3DH key agreement (initiator + responder) |
| `crypto/ratchet/double_ratchet.dart` | Double Ratchet with header encryption, skipped keys (max 1000) |
| `crypto/sender_keys/sender_key_store.dart` | Abstract sender key store |
| `crypto/sender_keys/group_cipher.dart` | Group encrypt/decrypt with Ed25519 signing |
| `crypto/media/media_crypto.dart` | AES-256-GCM file encryption |
| `crypto/profile/profile_crypto.dart` | Profile key management |

#### Transport (6 files)
| File | Purpose |
|---|---|
| `transport/supabase_client.dart` | REST + RPC wrapper over supabase_flutter |
| `transport/realtime_listener.dart` | Supabase Realtime subscriptions (postgres_changes + broadcast) |
| `transport/media_upload_client.dart` | Firebase Storage upload/download |
| `transport/dto/message_envelope.dart` | Wire format for POST /api/message (freezed, snake_case) |
| `transport/dto/realtime_event.dart` | RealtimeMessageEvent + SKRecoveryRequest |

#### Persistence (10 files)
| File | Purpose |
|---|---|
| `persistence/database/app_database.dart` | Drift database definition (10 tables) |
| `persistence/database/database_factory.dart` | WebDatabase (web) / SQLCipher (native) |
| `persistence/database/tables.dart` | Table definitions |
| `persistence/repositories/message_repository_impl.dart` | Two-table join (messages + ciphertexts) |
| `persistence/repositories/conversation_repository_impl.dart` | Conversation CRUD + watch |
| `persistence/repositories/receipt_repository_impl.dart` | Delivery/read receipts |
| `persistence/repositories/outbox_repository.dart` + `_impl.dart` | Offline message queue |
| `persistence/repositories/decrypted_message_repository.dart` + `_impl.dart` | Plaintext cache |
| `persistence/repositories/processed_distribution_repository.dart` + `_impl.dart` | SK dedup |

#### Sync (7 files)
| File | Purpose |
|---|---|
| `sync/sync_coordinator.dart` | Orchestrates outbox drain, gap fill, message processing |
| `sync/message_processor.dart` | Decrypt incoming messages (1:1 + group) |
| `sync/outbox_processor.dart` | Batch send queued messages (max 5 parallel) |
| `sync/gap_detector.dart` | Detect missed messages on reconnect |
| `sync/deduplication_set.dart` | LRU set (1000 per conversation) |
| `sync/sync_observer.dart` | Diagnostic mixin (onOutboxDrained, onSyncCompleted) |

#### Domain (15 files)
| File | Purpose |
|---|---|
| `domain/models/message.dart` | Message (freezed) — id, groupId, senderId, type, status, text |
| `domain/models/conversation.dart` | Conversation (freezed) — id, type, participants, unread |
| `domain/models/receipt.dart` | Receipt (freezed) — deliveredAt, readAt |
| `domain/models/typing_indicator.dart` | TypingIndicator (freezed) |
| `domain/models/presence_state.dart` | PresenceState (freezed) |
| `domain/models/contact_match.dart` | ContactMatch (freezed) |
| `domain/models/key_fingerprint.dart` | Safety number verification |
| `domain/models/decrypted_message.dart` | Internal decrypted payload (freezed) |
| `domain/models/chat_engine_error.dart` | Sealed class: 16 error types |
| `domain/models/connection_state.dart` | EngineConnectionState enum |
| `domain/models/media_payload.dart` | Raw media bytes + mime (freezed) |
| `domain/models/media_metadata.dart` | Encrypted file info (freezed) |
| `domain/repositories/message_repository.dart` | Abstract interface |
| `domain/repositories/conversation_repository.dart` | Abstract interface |
| `domain/repositories/receipt_repository.dart` | Abstract interface |
| `domain/use_cases/send_message_use_case.dart` | 1:1 + group send pipeline with two-phase commit |
| `domain/use_cases/receive_message_use_case.dart` | Decrypt + persist + cache |
| `domain/use_cases/mark_read_use_case.dart` | Mark read + reset unread |
| `domain/use_cases/delete_message_use_case.dart` | Delete for me / for everyone |

#### Media (5 files)
| File | Purpose |
|---|---|
| `media/upload_manager.dart` | Compress → encrypt → upload → return metadata |
| `media/download_manager.dart` | Download → verify SHA-256 → decrypt → cache |
| `media/media_cache.dart` | LRU in-memory cache (20 items) |
| `media/upload_progress.dart` | Progress events (freezed) |

#### Public API (5 files)
| File | Purpose |
|---|---|
| `public_api/chat_engine.dart` | Abstract ChatEngine interface |
| `public_api/chat_session.dart` | Abstract ChatSession interface |
| `public_api/chat_engine_config.dart` | Config: authToken, userId, deviceId, pushToken, serverBaseUrl, supabaseAnonKey |
| `chat_engine_impl.dart` | Concrete ChatEngine with static initialize() factory |
| `chat_session_impl.dart` | Concrete ChatSession wrapping use cases |

### Crypto Parameters (HKDF info strings)
| String | Used For |
|---|---|
| `'XarkE2EE-x3dh'` | X3DH shared secret derivation |
| `'XarkE2EE-ratchet'` | Double Ratchet chain key derivation |
| `'XarkE2EE-header-secret'` | Header encryption key derivation |
| `'XarkE2EE-header-key'` | Per-message header encryption |

### Wire Formats
- **1:1 message:** `nonce(24) + ciphertext` → base64
- **Group message:** `nonce(24) + signature(64) + iteration(4 BE) + ciphertext` → base64
- **Header:** JSON `{ publicKey, previousCount, messageNumber }` → XChaCha20 encrypted → `nonce(24) + headerCiphertext`
- **Media:** AES-256-GCM (key + IV sent via ratchet)

### Key Dependencies
- `cryptography: ^2.7.0` — Pure Dart crypto
- `drift: ^2.18.0` + `drift_sqflite: ^2.0.1` — SQL database
- `supabase_flutter: ^2.8.0` — Supabase SDK
- `firebase_messaging: ^15.0.0` — Push notifications
- `freezed_annotation: ^2.4.0` — Immutable models
- `rxdart: ^0.27.7` — Reactive streams
- `uuid: ^4.4.0` — UUID v7 generation

---

## app/ (18 source files)

**Package:** `hello_app` — Flutter UI consuming engine/

### Providers (6 files)
| File | Purpose |
|---|---|
| `main.dart` | Entry point, ChatEngineImpl.initialize(), Riverpod container, lifecycle hooks |
| `providers/action_card_provider.dart` | Filters messages to extract @hello action cards |
| `providers/consensus_listener.dart` | Watches actions, triggers haptic at consensus, manages global lock |
| `providers/conversation_controller.dart` | StreamProvider wrapping engine.getSession(groupId).messages |
| `providers/e2ee_state_provider.dart` | E2EE readiness state (isReady, isGeneratingKeys, deviceId) |
| `providers/engine_error_listener.dart` | Headless error bus: KeyVerificationFailed → lock UI, AuthTokenExpired → /login |

### Screens & Views (4 files)
| File | Purpose |
|---|---|
| `screens/conversation_screen.dart` | Main screen: PageView of MessageFeedPage + ActionCarouselPage |
| `screens/chat_screen.dart` | Simple chat layout (AppBar + ChatFeed + ChatInput) |
| `views/message_feed_page.dart` | Column: ChatFeed + InlinePollWidget |
| `views/action_carousel_page.dart` | PageView carousel of action cards (0.85 viewport fraction) |

### Widgets (8 files)
| File | Purpose |
|---|---|
| `widgets/chat_feed.dart` | ListView.builder watching conversationControllerProvider |
| `widgets/chat_bubble.dart` | Message bubble with asymmetric tail, color mapping |
| `widgets/chat_input.dart` | TextField with @hello detection, sends via engine |
| `widgets/action_card_widget.dart` | Dark gradient card (260x380) with agreement %, spring physics |
| `widgets/encrypted_image_view.dart` | Download → decrypt → blur-to-clear animation |
| `widgets/inline_poll_widget.dart` | Live poll with weighted_score bars |
| `widgets/liquid_fire_text.dart` | HelloAnimation: sliding gradient shader over "hello" text |
| `theme.dart` | HelloColors, HelloTypography (no-bold mandate), HelloTheme |

### Engine Connection
- Import: `package:hello_engine/chat_engine.dart`
- Provider: `engineProvider` (Riverpod singleton)
- Init: `ChatEngineImpl.initialize(config)` with Supabase credentials
- Streams: `engine.getSession(groupId).messages`, `engine.errors`
- Lifecycle: `engine.resume()` / `engine.suspend()` on app foreground/background

---

## web/ (43 components, 23 API routes, 11 hooks, 35 migrations)

**Stack:** Next.js 16, React 19, TypeScript 5, Supabase, Firebase, libsodium, Gemini AI

### API Routes (23)
| Endpoint | Method | Purpose |
|---|---|---|
| `/api/message` | POST | E2EE message + ciphertext + piggybacked SK distribution |
| `/api/keys/bundle` | POST | Upload identity + signed pre-key |
| `/api/keys/otk` | POST | Upload one-time pre-keys (max 200) |
| `/api/keys/fetch` | POST | Atomic key bundle fetch + OTK consume |
| `/api/chat/start` | POST | Find-or-create 1:1 DM |
| `/api/contacts/check` | POST | Phone number registration lookup (max 500) |
| `/api/hello` | POST | @hello AI intelligence (3-tier, 60s max) |
| `/api/hello/webhook` | POST | Async AI webhook receiver |
| `/api/phone-auth` | POST | Firebase OTP → Supabase JWT |
| `/api/dev-auto-login` | POST | Dev passwordless login (returns 404 in production) |
| `/api/dev-auth` | POST | Dev password login |
| `/api/invite` | POST | Generate invite link (128-bit hex) |
| `/api/invite/claim` | POST | Claim invite → create space → JWT |
| `/api/invite/validate` | GET | Validate invite code |
| `/api/join` | POST | Name-only invite join |
| `/api/local-action` | POST | Atomic mutations (rename, revert, create) |
| `/api/notify` | POST | FCM push to group members |
| `/api/og` | POST | OG metadata extraction (SSRF-protected) |
| `/api/onboarding` | POST | Taste profile via Gemini |
| `/api/proxy-scrape` | POST | Blind OG proxy (no auth) |
| `/api/share` | POST | PWA share target handler |
| `/api/cron/consensus` | GET | Auto-lock expired consensus (daily) |
| `/api/cron/purge` | GET | Purge expired messages + invites (daily) |

### Pages (14)
| Path | Purpose |
|---|---|
| `/` | Root redirect to /login |
| `/login` | Phone OTP + dev mode login |
| `/galaxy` | Home hub (People / Plans / Memories tabs) |
| `/space/[id]` | Group/DM view (discuss/decide toggle) |
| `/s/[code]` | Invite landing page |
| `/j/[token]` | Quick join |
| `/share` | PWA share target |
| `/prototype` | Component lab |
| `/demo` | Scripted demo |
| `/demo/travel` | Travel demo |
| `/demo/welcome` | Welcome demo |
| `/demo-sphere` | Sphere visualization |
| `/land` | Landing page |
| `/ad` | Ad demo |

### Components (43)
| Component | Purpose |
|---|---|
| XarkChat.tsx | Chat stream (E2EE bubbles, @hello Liquid Fire corner) |
| DecisionBoard.tsx | Netflix-style decision card rails |
| DecisionCard.tsx | Immersive card (82% viewport, cinematic gradient, score) |
| ChatInput.tsx | Input pill (@hello chip, voice, media, URL detection) |
| HelloPanel.tsx | @hello AI panel (Raycast-style) |
| EncryptedMedia.tsx | E2EE media renderer (download → decrypt → display) |
| ControlCaret.tsx | Living Brand Anchor ("hello" text, Liquid Fire CSS) |
| SpotlightSheet.tsx | @hello invocation overlay (800ms morph) |
| ThemeProvider.tsx | 4 themes (hearth/hearth_dark/vibe/vibe_dark) |
| UserMenu.tsx | Settings (profile, notifications, theme, logout + crypto shred) |
| PeopleDock.tsx | 1:1 DM list with unread badges |
| AwarenessStream.tsx | Group summary list (priority-sorted, time decay) |
| ConsensusBanner.tsx | Pinned consensus countdown |
| ConsensusTimer.tsx | Live countdown on DecisionCard |
| InviteSurface.tsx | Invite CTA + link generation |
| AddItemModal.tsx | Screenshot upload → E2EE → decision_items |
| LinkPreviewCard.tsx | E2EE link preview (OG metadata) |
| InlinePoll.tsx | Poll widget in chat |
| WelcomeScreen.tsx | Login entrance (4-phase choreography) |
| Avatar.tsx | Photo or letter fallback |
| GhostInput.tsx | Ghost text pre-fill input |
| LedgerPill.tsx | Ledger event pill |
| ClaimSheet.tsx | Claim locked items |
| PurchaseSheet.tsx | Purchase confirmation |
| PlaygroundSpace.tsx | Demo space (no DB) |
| GalaxyLayout.tsx | Stream vs split layout |
| MediaUpload.tsx | File uploader with E2EE |
| *(+17 more)* | |

### Hooks (11)
| Hook | Purpose |
|---|---|
| useAuth.ts | Firebase OTP → JWT → RLS |
| useE2EE.ts | Crypto lifecycle + key registration |
| useHandshake.ts | Consensus monitor (>80% trigger) |
| useHelloAI.ts | @hello invocation + 800ms morph |
| useReactions.ts | Signal voting (LoveIt/WorksForMe/NotForMe) |
| useWhispers.ts | Proactive suggestions (60s poll) |
| useVoiceInput.ts | Speech-to-text |
| useKeyboard.ts | Virtual keyboard detection |
| useDeviceTier.ts | Device capability detection |
| useDisplayName.ts | Name resolution |
| usePlaygroundChoreography.ts | Demo animation sequencing |

### Crypto Module (10 files in src/lib/crypto/)
| File | Purpose |
|---|---|
| primitives.ts | libsodium-wrappers-sumo (XChaCha20, Ed25519, Curve25519, HKDF, Argon2id) |
| x3dh.ts | X3DH key agreement |
| double-ratchet.ts | Double Ratchet (1:1 forward secrecy) |
| sender-keys.ts | Sender Keys (group O(1) encryption) |
| encryption-service.ts | High-level API (1,468 lines) — encrypt/decrypt orchestration |
| keystore.ts | IndexedDB key storage (version 4) |
| key-manager.ts | Key registration, fetch, replenishment, backup |
| file-encryption.ts | AES-256-GCM media (Web Crypto API) |
| message-cache.ts | Encrypted plaintext cache |
| outbox.ts | Offline message queue |

### Intelligence Module (6 files in src/lib/intelligence/)
| File | Purpose |
|---|---|
| orchestrator.ts | 3-tier routing: local → search → Gemini cloud |
| tool-registry.ts | 8 tools: FAST (restaurant, activity, general) + SLOW (hotel, flight, etc.) |
| searchapi-client.ts | SearchApi integration (2-5s) |
| apify-client.ts | Apify actor integration (15-50s) |
| sanitize.ts | PII redaction (Luhn, SSN, CVV) before LLM |

### Key Dependencies
- `next@16.1.6`, `react@19.2.3` — Framework
- `@supabase/supabase-js@2.99.0` — Database
- `firebase@12.10.0` — Auth + Storage + FCM
- `libsodium-wrappers-sumo@0.8.2` — E2EE crypto
- `@google/generative-ai@0.24.1` — Gemini 2.5 Flash
- `@capacitor/core@8.2.0` — Native bridge
- `framer-motion@12.35.2` — Animations
- `jose@6.2.1` — JWT

---

## algo/ (198 tests, hexagonal architecture)

**Package:** `algo` v1.0.0 — pure TypeScript, zero dependencies

### Engine Layer (8 files)
| File | Purpose |
|---|---|
| heart-sort.ts | Weighted scoring: LoveIt (+5), WorksForMe (+1), NotForMe (-3) |
| green-lock.ts | Commitment protocol: lock, transfer, ownership history |
| state-machine.ts | Configurable state machine |
| state-flows.ts | 4 presets: BOOKING, PURCHASE, SIMPLE_VOTE, SOLO_DECISION |
| consensus-engine.ts | In-memory orchestrator |
| ai-grounding.ts | AI constraint system |
| task-assignment.ts | Task lifecycle |
| persistence.ts | Legacy adapter |

### Ports Layer (5 files)
| Port | Purpose |
|---|---|
| PersistencePort | DB CRUD with optimistic concurrency |
| EventBusPort | Pub/sub with channels |
| AuthPort | Identity + authorization |
| CachePort | Read caching with TTL |
| MessagingPort | Chat platform formatting |

### Adapters Layer (5 files)
| Adapter | Purpose |
|---|---|
| MemoryPersistenceAdapter | Map-based, version-checked |
| MemoryEventBusAdapter | In-process pub/sub |
| MemoryCacheAdapter | Map with TTL |
| NoopAuthAdapter | Dev: trusts token as userId |
| PlaintextMessagingAdapter | Text formatting, /command parsing |

### Service Layer (2 files)
| File | Purpose |
|---|---|
| DecisionService | Stateless orchestrator (async, persistent, scalable) |
| RequestHandler | Framework-agnostic HTTP adapter |

---

## Overall Status

| Metric | Value |
|---|---|
| **engine tests** | 290 pass, 5 skip, 1 pre-existing fail |
| **algo tests** | 198/198 pass |
| **app tests** | None yet (UI only) |
| **web TypeScript** | 0 errors (tsc clean) |
| **DB migration 030** | Applied and validated |
| **Terminology rename** | Complete (0 stale references) |
| **Interop tests** | 11 offline crypto + 5 live (all pass) |
| **Production URL** | https://gethello.ai |
| **Deployment** | Vercel (web), Flutter (app) |
| **Originals** | Archived at ~/hello_archive/ |

## Phase Status

| Phase | Status | What's Done |
|---|---|---|
| **Phase 1 — Foundation** | ✅ Complete | Crypto, persistence, transport, sync, messaging, media, public API, interop tests |
| **Phase 2 — Feature Core** | Not started | Group chats (Sender Key distribution), media pipeline, read receipts, typing, push, reply/quote |
| **Phase 3 — Parity** | Not started | Reactions, disappearing messages, view-once, search, link previews, key verification, app lock |
| **Phase 4 — Portability** | Not started | Package publication, host app guide, theming API, a11y, perf profiling, security audit |

## Architectural Constraints

- **E2EE is non-negotiable** — no plaintext fallback, ever
- **engine/ is headless** — zero UI code, UI lives in app/
- **User IDs are text** (e.g., `name_ram`), not UUIDs
- **RLS uses** `auth.jwt()->>'sub'` (not `auth.uid()`)
- **Port 3000 only** for web dev server
- **No bold fonts** — hierarchy via size, spacing, opacity only
- **4 themes** — hearth/hearth_dark/vibe/vibe_dark, all via CSS variables
