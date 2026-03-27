# Hello OS — Session Primer

> For AI agents: Read this FIRST before any code work. Then read Mar20.json for the full codebase snapshot.

## Last Session: Mar 22-23, 2026 (Brand Rename + HelloPanel + SearchApi + Domain Migration + E2EE Fix)

### Brand Rename: xark → hello
- All user-facing text: "xark" → "hello" across 30+ files (login, galaxy, chat, demos, invite, OG, icons, manifest)
- Brand color: Deep Rose #D4536B → Action Orange #FF6B35 across all 4 themes + 15+ components + globals.css Liquid Fire gradient
- Liquid Fire gradient: #7C1D3E→#D4636E→#EF7C6E (rose) → #8B2500→#FF6B35→#FF9F43 (orange)
- AI invocation: @xark → @hello (API route, orchestrator prompt, ChatInput, demos, grounding)
- Cyan (#40E0FF) fully purged from DecisionCard + PossibilityHorizon
- @hello responses in chat: compact centered system lines (11px, brand color), not bubbles
- lucide-react installed for icons (Search, X, ChevronRight)

### HelloPanel (Raycast-style AI Panel)
- `src/components/os/HelloPanel.tsx` — replaces SpotlightSheet + ControlCaret
- Input at BOTTOM (thumb arc). Results grow UPWARD (justify-end). Drag-to-dismiss.
- Fluid entity extraction: type naturally → intent/location/budget chips auto-lock
- Actionable Receipts: category results show overlapping thumbnail stack + count + "→ decide"
- Glanceable Micro-Widgets: conversational answers at 36px font
- Ghost Recents: horizontal scrolling pills from localStorage history
- Three-tier confidence: 1.0 (intent chip → SearchApi direct), 0.5 (general → SearchApi), 0.0 (computational → Gemini direct)
- Silent mode: `silent: true` flag → no phantom receipt in chat, results returned in HTTP response body
- Auto-trigger: typing "@hello" in chat input opens HelloPanel

### SearchApi Integration
- `src/lib/intelligence/searchapi-client.ts` — Google Hotels, Flights, Local, Search APIs
- Replaces Apify as primary tier. Apify retained as fallback with correct param mapping.
- Hotels: real Google photos. Flights: airline logos. Local: Pexels fallback.
- `tool-registry.ts`: all 4 tools now `tier: "searchapi"` with `searchApiEngine` field
- Orchestrator: deterministic bypass when `slotPayload.confidence >= 0.5`, SearchApi → Apify fallback chain
- CSP updated: `*.googleusercontent.com`, `*.gstatic.com`, `photos.hotelbeds.com` added to img-src

### Domain Migration: xark.app → gethello.ai
- All hardcoded domain references updated: summon URLs, webhook URLs, feedback email, calendar UIDs
- `NEXT_PUBLIC_APP_URL=https://gethello.ai` set in Vercel production env
- Firebase authorized domains: gethello.ai + www.gethello.ai added
- Custom domain configured in Vercel, SSL provisioned (Let's Encrypt)
- Package name: xark-os → hello-os
- App icons: glyph "x" → "h"
- SW cache names: xark-v4 → hello-v5

### Supabase Client Fix
- `src/lib/supabase.ts` — single `createClient()` call, JWT injected via custom fetch wrapper
- Eliminated GoTrueClient instance storm (was creating 20+ instances per page load)
- Auth features disabled: `persistSession: false`, `autoRefreshToken: false`

### E2EE X3DH Session Fix
- **Root cause found**: `preDistributeSenderKeys()` called `prepareSenderKeyDistribution()` at boot, which created X3DH sessions and permanently deleted the `x3dhSessionMeta` map entry. When the first real message piggybacked another distribution for the same peer, the header had NO X3DH metadata → receiver couldn't establish session → "ciphertext cannot be decrypted"
- **Fix**: Removed `preDistributeSenderKeys()` entirely. SK distribution only happens via piggyback on real message sends (one session per peer, no double-call race)
- Reconciliation loop: added `failedMsgIds` set to prevent infinite retry on same failed messages

### Dead Code Removed
- `GlobalCaret.tsx` removed from layout.tsx (was mounting ControlCaret on every page, 5 Realtime presence channels)
- ControlCaret, SpotlightSheet, GhostInput, useSpotlight still exist as files but unmounted

### Security
- `fetch_key_bundle` RPC hardened: JWT + co-membership assertion (migration 031)
- `data:` added to CSP img-src for canvas thumbnails

### Files Created
- `src/components/os/HelloPanel.tsx` — Raycast-style AI panel
- `src/lib/intelligence/searchapi-client.ts` — SearchApi client
- `src/lib/media/thumbnail-generator.ts` — client-side thumbnail generation
- `supabase/migrations/031_fetch_key_bundle_jwt_guard.sql` — RPC security hardening

### Deployed
- Production: https://gethello.ai (also accessible via https://xark.app)

---

## Previous Session: Mar 21, 2026 (Screenshot → Decide Stream + PWA Share Target)

### Screenshot → Decide Stream
- `AddItemModal.tsx` — modal with title input + image dropzone + clipboard paste (CMD+V). E2EE pipeline: `generateInlineThumbnail` → `encryptFile` → Firebase upload → `decision_items` insert with `metadata.encrypted_image`.
- PossibilityHorizon.tsx — "+" FAB (Deep Rose circle, top-right), opens AddItemModal. `useE2EE` hook for encryption. `encrypted_image` parsed from metadata for inline thumbnail on cards.
- DecisionCard.tsx — `parseEncryptedImage()` utility. 3-path image rendering: E2EE (`EncryptedMediaRenderer fillContainer`), legacy plaintext URL, category gradient fallback.
- EncryptedMedia.tsx — new `fillContainer` prop: `absolute inset-0, object-fit cover` for DecisionCard; default chat bubble mode unchanged.

### PWA Share Target (Android)
- `manifest.json` — `share_target.action` changed to `/_share-target`, added `params.files` for `image/*` and `video/*`.
- `sw.js` — Service Worker intercepts `POST /_share-target`, stashes file in CacheStorage (`xark-shared-files`), redirects to `/share?has_local_file=true`. Raw file never touches the server.
- `/share` page — reads file from CacheStorage, shows preview + title input + SpacePicker. On space selection: full E2EE pipeline → `decision_items` insert → navigate to Decide tab.

### Firebase Storage
- CORS configured via `gsutil cors set` on `gs://xark-os.firebasestorage.app` (allows cross-origin blob downloads for `EncryptedMediaRenderer`).
- Storage rules updated: `application/octet-stream` allowed for encrypted blob uploads. Read set to `allow: if true` (privacy guaranteed by AES, not Firebase).

### Deployed
- Production: https://xark.app

---

## Previous Session: Mar 21, 2026 (E2EE Link Previews + Playwright Tests + Production Deploy)

### Link Previews (E2EE)
- `POST /api/proxy-scrape` — blind proxy. No auth, no logging, no DB writes. Returns `{ title, description, imageBase64 }`. SSRF-protected.
- ChatInput.tsx: 500ms debounced URL detection → scrape → dismissible mini preview above input pill
- sendMessage: if `pendingLinkPreview` has `imageBase64`, converts via `atob()` (not `fetch()` — avoids CSP), encrypts through media pipeline, uploads to Firebase, constructs `LinkPreviewPayload`
- `LinkPreviewCard.tsx`: renders domain, title (2-line clamp), description, optional `<EncryptedMediaRenderer>` for og:image
- Full type pipeline: `LinkPreviewPayload` in types.ts → `MediaPayload.linkPreview` → encrypt/decrypt/cache paths

### Playwright E2E Tests
- `tests/e2e/media-pipeline.spec.ts` — 5-image rapid-fire stress test (sender + receiver verification)
- `tests/e2e/link-preview-pipeline.spec.ts` — 5-URL rapid-fire with mocked proxy (8 tests, all passing)
- `tests/fixtures/generate-test-image.ts` — generates unique 100x100 PNGs
- `playwright.config.ts` — Chromium, 2min timeout, localhost:3000
- DOM-based E2EE readiness gate (textarea visible + enabled) replaced console listener race condition
- Test users: `alex chen` + `priya sharma` in `space_test_1774115020358` (hosted Supabase)

### Race Condition Fixes
- `onMediaSelected`: replaced `isThinking` boolean gate with `mediaUploadsInFlight` ref counter — allows concurrent uploads
- CSP: added `data:` to `img-src` in proxy.ts for canvas thumbnails
- CSP: replaced `fetch(dataUrl)` with `atob()` Base64 decode in sendMessage (avoids `connect-src` block)
- Firebase Storage CORS: `gsutil cors set` applied to `gs://xark-os.firebasestorage.app` for cross-origin blob downloads

### Deployed
- Production: https://xark.app

---

## Previous Session: Mar 21, 2026 (E2EE Media Pipeline — Symmetric-Blob Pattern)

### What happened
Implemented full E2EE media sharing (images/video) using the Symmetric-Blob pattern: encrypt locally with one-time AES-256-GCM key → upload encrypted blob to Firebase Storage → send AES key + IV via Double Ratchet/Sender Key E2EE channel. Server never sees plaintext media.

### Phase 1: File Encryption Utility
- New file: `src/lib/crypto/file-encryption.ts`
- `encryptFile(file: File)` → generates AES-256-GCM key + 12-byte IV, encrypts via `crypto.subtle`, returns `{ encryptedBlob, aesKeyBase64, ivBase64 }`
- `decryptFile(blob, key, iv, mimeType)` → decrypts via `crypto.subtle`, returns `URL.createObjectURL(decryptedBlob)`
- Pure Web Crypto API, no libsodium dependency

### Phase 2: Upload & Decrypt Pipeline
- `DecryptedMessage` type extended with `aesKeyBase64?`, `ivBase64?`, `mimeType?` (types.ts)
- `keystore.ts`: new `saveDecryptedMedia()` / `getDecryptedMedia()` — stores full media metadata as encrypted JSON in IndexedDB (keyed `media:${messageId}`). Text-only cache preserved for backward compat.
- `encryption-service.ts`: `encryptForSpace()` and `encryptForSanctuary()` accept optional `media?: MediaPayload`. New `MediaPayload` interface exported. `decryptMessage()` cache hit path checks media cache first, validation path extracts + caches media fields.
- `useE2EE.ts`: `encrypt()` wrapper accepts optional 3rd `media` parameter.
- `page.tsx` `ChatMessage` interface extended with `mediaUrl`, `aesKeyBase64`, `ivBase64`, `mimeType`. `onMediaSelected` rewritten: `encryptFile()` → upload encrypted blob → `e2ee.encrypt()` with media metadata → `/api/message` → broadcast.
- PHASE B batch decrypt: `decryptedMap` now carries full media metadata, merged into `ChatMessage` state.
- Realtime handler: captures `mediaFields` from decrypt result, spreads into `newMsg`.

### Phase 3: UI Render
- New component: `src/components/os/EncryptedMedia.tsx` — `<EncryptedMediaRenderer>` component.
- On mount: `fetch(mediaUrl)` → `decryptFile()` → local `blob://` URL. Cleanup: `URL.revokeObjectURL()` on unmount.
- States: loading skeleton, error fallback, success. Renders `<img>` or `<video>` based on `mimeType`.
- `XarkChat.tsx`: bubble content IIFE now branches on `msg.mediaUrl && msg.aesKeyBase64` to render `<EncryptedMediaRenderer>` + optional text caption.

### Files created
- `src/lib/crypto/file-encryption.ts` — AES-256-GCM file encrypt/decrypt
- `src/components/os/EncryptedMedia.tsx` — encrypted media renderer component
- `media-pipeline-context.md` — analysis report (not shipped)

### Files modified
- `src/lib/crypto/types.ts` — DecryptedMessage extended with media fields
- `src/lib/crypto/keystore.ts` — saveDecryptedMedia/getDecryptedMedia
- `src/lib/crypto/encryption-service.ts` — MediaPayload, encrypt/decrypt media paths, cache
- `src/hooks/useE2EE.ts` — encrypt wrapper accepts media parameter
- `src/app/space/[id]/page.tsx` — ChatMessage type, onMediaSelected, PHASE B, Realtime handler
- `src/components/os/XarkChat.tsx` — EncryptedMediaRenderer injection in bubble content

---

## Previous Session: Mar 21, 2026 (E2EE Debug Report — 7 Priority Fixes Deployed)

### What happened
Executed all 7 priorities from `claude-e2ee-debug-report.md` — a comprehensive audit of the E2EE lifecycle from key storage through decryption to UI rendering. The report identified 5 compounding root causes for the "waiting for this message..." / "decrypting..." symptom.

### Changes made

**Priority 0 — Catch-up decryption pass** (`page.tsx`)
- Added `useEffect` gated by `catchupRanRef` that fires once after PHASE B completes and E2EE is available
- Scans React state for messages still showing `[decryption pending]` or `[Error: Decryption Failed]` (stale PHASE A cache)
- Re-fetches ciphertexts, processes SK distributions, re-attempts decryption, patches state + local cache

**Priority 1 — Re-decrypt on Sender Key arrival** (`encryption-service.ts`, `page.tsx`)
- `processSenderKeyDistribution` now emits `sk-arrived` CustomEvent on `window` with `{ spaceId, senderId }`
- Space page listens for `sk-arrived`, finds failed messages from that sender, re-decrypts, patches state + cache
- Creates closed-loop recovery: SK request -> SK arrives -> failed messages auto-recover

**Priority 2 — Unacked ratchet recovery** (`useE2EE.ts`)
- Added `recoverUnackedRatchets()` function called on normal E2EE init (not fresh/re-registration)
- Entries older than 5 min: delete (chain index consumed, designed Signal gap)
- Recent entries: check outbox — if queued, leave for retry; if absent, clean up orphan

**Priority 3 — Deterministic distribution write** (`/api/message/route.ts`, `page.tsx`)
- API now returns `{ messageId, distribution_written: true/false }` — all DB writes committed before response
- Sender only broadcasts after receiving 200 OK (distribution confirmed written)
- Realtime handler cleaned up: no more 500ms/800ms nested retry hell, single immediate fetch + one 500ms safety-net

**Priority 4 — Realtime re-subscription gap** (`page.tsx`)
- Added `e2eeRef = useRef(e2ee)` synced via `useEffect`
- Realtime handler reads from `e2eeRef.current` instead of closure-captured `e2ee`
- Removed `e2ee.available` from dependency array — subscription never tears down during E2EE init

**Priority 5 — Persist skipped Sender Key message keys** (`sender-keys.ts`)
- `serializeSenderKeyForStorage` now extracts matching skipped keys from global Map, stores as `skippedKeys` array
- `deserializeSenderKey` restores persisted skipped keys back into global Map on load
- Out-of-order group message keys now survive page refresh (was permanent loss before)

**Priority 6 — Reset initRef on userId change** (`useE2EE.ts`)
- Added `prevUserIdRef` tracking, resets `initRef.current = false` when userId changes
- E2EE can now re-initialize after init failure or user logout/re-login without full page reload

### Files modified
- `src/app/space/[id]/page.tsx` — P0 catch-up, P1 sk-arrived listener, P3 handler cleanup, P4 ref-based E2EE
- `src/lib/crypto/encryption-service.ts` — P1 sk-arrived event emission
- `src/hooks/useE2EE.ts` — P2 unacked ratchet recovery, P6 initRef reset
- `src/app/api/message/route.ts` — P3 distribution_written flag
- `src/lib/crypto/sender-keys.ts` — P5 skipped key persistence in serialization/deserialization

### Architecture decisions
- DOM CustomEvent (`sk-arrived`) chosen over React state/context for SK arrival notification — decouples crypto layer from React render tree
- Ref-based E2EE state in Realtime handler prevents WebSocket teardown during async init — standard React pattern for mutable values in effect callbacks
- Unacked ratchet recovery is fire-and-forget on init — non-blocking, best-effort, 5-min staleness threshold

### Deployed
- Production: https://xark.app (Vercel, `vercel deploy --prod`)

---

## Previous Session: Mar 19, 2026 (Warm Coral Rebrand + Liquid Fire + Chat Bubbles + Layout Overhaul)

### Color System Overhaul
- **Brand: Deep Rose #D4536B** — Old Action Orange (#FF6B35/#FF4500) purged from theme.ts, globals.css, all components. Accent across all 4 themes is now #D4536B.
- **Liquid Fire gradient**: #7C1D3E → #D4636E → #EF7C6E. Two CSS classes in globals.css: `.xark-glow-anchor` (xarkBreathe 5s scale+brightness) + `.xark-text-led` (xarkLiquidFire 3s gradient sweep, background-clip: text). Applied to ControlCaret (40px, weight 200) and WelcomeScreen.
- **Chat palette**: Sent #EF7C6E (Saturated Coral), Received #E8E3DD (Warm Taupe), Canvas #F2EDE8 (Warm Linen). @xark label: #D4636E.
- **Cyan purged from brand**: Global sweep removed cyan (#40E0FF) from ControlCaret, theme accents. Cyan remains only as `--xark-cyan` CSS variable for AI intelligence signals.

### Chat Bubble Architecture
- Zero-Box Doctrine amended: **bubbles for dialogue** (research-backed cognitive scaffolding), zero-box for feeds.
- 16px radius, sent right (#EF7C6E), received left (#E8E3DD). @xark bubbles have Liquid Fire L-corner (`.xark-bubble-corner` CSS class with animated left+top edge).
- Inline timestamps (float right, same line). WhatsApp-style alignment.
- Brutalist monochrome mode for sunlight legibility applied to chat.
- Fake @xark "thinking" rogue state exterminated.

### Space Page Layout
- Navigation relocated from bottom void to **sticky top header** (commit 6962f6e).
- ChatInput rebuilt as **premium input pill** housing tools (attach, camera, voice) inside the pill.
- Solid architectural floor injected below input to occlude scrolling messages.
- GPU hardware acceleration (`transform: translateZ(0)`) on spatial occlusion layers to fix Safari z-index piercing.
- ControlCaret z-index raised to 60 (above space page z-50).

### @xark Privacy Restoration
- Removed illegal @xark injection from sendMessage (was sending plaintext to /api/xark, breaking E2EE).
- @xark invocable ONLY via SpotlightSheet. Chat pipeline is pure E2EE.
- No `xark_trigger`, no `hasXark`, no `e2ee_xark` message type in space page.

### SpotlightSheet Fixes
- Context pill fetches space title from DB (was showing raw hex ID).
- Overlay: #000 at 0.8 (removed backdrop-blur, constitution violation).
- GhostInput rebuilt with `<form onSubmit>` (Android IME fix).

### Android Keyboard Fix
- useKeyboard.ts: height drop detection now requires active input focus.
- Prevents Chrome address bar show/hide from falsely triggering isKeyboardOpen.

### Files significantly modified
- `src/lib/theme.ts` — All 4 themes updated: accent #D4536B, cyan #D4636E (Liquid Fire Rose)
- `src/app/globals.css` — Liquid Fire keyframes, xark-glow-anchor, xark-text-led, xark-bubble-corner classes
- `src/components/os/ControlCaret.tsx` — 40px Liquid Fire text, CSS glow, z-60, layout restructure
- `src/components/os/WelcomeScreen.tsx` — Liquid Fire brand text via CSS classes
- `src/components/os/XarkChat.tsx` — Bubble architecture, coral/taupe colors, L-corner for @xark, monochrome mode
- `src/components/os/ChatInput.tsx` — Premium input pill, architectural floor, GPU acceleration
- `src/app/space/[id]/page.tsx` — Sticky top header, sent message alignment, local device ID anchor
- `src/components/os/SpotlightSheet.tsx` — Title fetch, no blur, form submit

---

## Previous Session: Mar 18-19, 2026 (E2EE Complete — Send, Receive, Persist, Reload)

### E2EE Distribution & Routing (items 100-110)
- Piggybacked Sender Key distribution (atomic with message POST, always-distribute on every send).
- Device-strict ciphertext routing (`.find()` uses `recipient_device_id === e2ee.deviceId`).
- Signal Protocol responder fix: `initSessionAsResponder()` uses `signedPreKey` (not random DH pair).
- Client-authoritative message ID preserved through POST → DB → broadcast → fetchCiphertexts.
- E2EE key registration at app boot (Galaxy page `useE2EE(userId)`).

### E2EE Persistence & Lifecycle (items 111-114)
- **Encrypted plaintext cache** in IndexedDB (DB_VERSION 3). Argon2id-wrapped at rest.
- **Idempotent decrypt guard**: cache check before ratchet touch. Prevents reload corruption.
- **SK distribution dedup**: `processed-distributions` store. Each distribution processed exactly once.
- **Sender-side cache write**: called at send time (sender can't self-decrypt Sender Key ciphertexts).

### Key files modified
- `src/lib/crypto/keystore.ts` — DB_VERSION 3, decryptedMessages + processedDistributions stores
- `src/lib/crypto/encryption-service.ts` — plaintext cache guard, dedup guard, SPK fix, always-distribute
- `src/app/space/[id]/page.tsx` — sender-side cache, piggybacked distribution, device-strict routing
- `src/app/api/message/route.ts` — accepts client UUID

---

## Previous Session: Mar 18, 2026 (WhatsApp Chat + Contact Discovery + Performance)

- `find_or_create_chat` atomic RPC (migration 029) + `POST /api/chat/start` endpoint.
- Contact discovery: `POST /api/contacts/check` (phone lookup, never exposes display_name). Migration 030.
- PeopleDock shows real `display_name` from `users` table (was showing raw phone IDs).
- SummonPage `/s/[code]` refactored from hardcoded dark theme to ThemeProvider tokens.
- GlobalMesh removed from layout.tsx (was GPU-burning blur animations). File exists, not mounted.
- GlobalUserMenu removed from layout.tsx (was duplicate mount). File exists, not mounted.
- ControlCaret glow rewritten from Framer Motion to pure CSS `@keyframes xarkGlow` (later replaced by Liquid Fire in Mar 19).
- Galaxy dead code purge: 5 dead states, 3 dead callbacks, dead CSS keyframes removed.
- GLOSSARY.md created (120+ domain terms).

---

## Previous Session: Mar 18, 2026 (Summon Paradigm + Onboarding)

- Summon system: `summon_links` table (migration 028), `/api/summon` (generate), `/api/summon/validate`, `/api/summon/claim`, `/s/[code]` landing page, `InviteSurface.tsx` (renamed from SummonSurface).
- Server-authoritative spaceId (client no longer generates IDs).
- Sanctuary UX: 1-on-1 spaces show other person's name, hide decide/itinerary/memories tabs.
- E2EE Absolute Law added to all guardrail files.

---

## Previous Session: Mar 17, 2026 (XarkSpotlight + Security Hardening)

- SpotlightSheet.tsx + GhostInput.tsx: @xark invoked via ControlCaret half-sheet overlay, not inline in chat.
- Whisper Engine (src/lib/whispers.ts): P0 consensus_ready, P1 missing_category, P2 onboarding/nudge.
- Taste Graph (src/lib/taste.ts + /api/taste): Day 1 onboarding, Gemini parses → JSONB constraints.
- Consensus Closer: gold pulsing border, ConsensusTimer.tsx, ConsensusBanner.tsx, auto-lock cron.
- Security hardening: HSTS, COOP, CSP frame-ancestors, upgrade-insecure-requests, Firebase SW origin check.
- Migration 027 (taste profiles + consensus countdown).

---

## Previous Session: Mar 17, 2026 (E2EE Security Sprint)

- 26 E2EE protocol fixes: encrypted ratchet headers, sender key serialization split (ForStorage vs ForDistribution), X3DH OTK 4-DH, encrypt/decrypt mutexes, two-phase ratchet commit.
- @xark extracted from ChatInput and sendMessage (pure E2EE paths). Reconnected via SpotlightSheet.
- 12 security hardening fixes: nonce-based CSP, fail-closed E2EE, centralized Postgres rate limiter, privacy cascades (FK + PII scrub trigger).
- Dead code purge: memory-worker, local-recall, ContextCard, EnclaveTunnel, GuestLinker, DeviceLinker, LazyRotator, CRDT store, guest-vote route all removed.
- 4 new crypto modules: encrypted-store.ts, sk-recovery.ts, outbox.ts, dm-routing.ts.
- Migrations applied: 015, 023, 024, 025, 026.

---

## Previous Sessions: Mar 13-16, 2026 (Compressed)

- **Mar 16**: Ghost Playground (4 sandbox spaces, choreography engine). Tab-aware dream input. Share options sheet. Android keyboard fix. Swipe discuss/decide. Security audit (all C/H/M fixed). Per-item vote debounce. Unread badges (migration 019). PWA offline SW.
- **Mar 15**: E2EE Signal Protocol implementation (Double Ratchet + Sender Keys + X3DH). Full crypto module. Migration 014. UI overhaul: login video, 3-tone surface system, immersive decision cards, Magnetic Input. Pexels hero images.
- **Mar 15 (early)**: Three-Tier Intelligence (gemini-local, gemini-search, apify). Gemini responseMimeType fix. Anti-cringe voice engineering. Two-tier routing.
- **Mar 13-14**: PossibilityHorizon + DecisionCard rewrite. 4-theme system. Production perf (N+1 fix → 4 batched queries). PII sanitizer. Micro-space templates. Instant invite system. People-first Galaxy refactor.

---

## Known Issues (verified still present)

### E2EE
- Key rotation on member leave deferred to v2.
- Always-distribute overhead: one RPC + pairwise encrypt per message (fine for 2-15 members).
- P2P SK recovery is fire-and-forget with single 10s timeout (Priority 7 from debug report — persistence + exponential backoff deferred).
- Message cache startup sweep for legacy `[decryption pending]` entries deferred (Priority 8 from debug report).
- DB version contention in multi-tab scenarios (Priority S2 from debug report — low severity).
- Encrypted store wrapping key never activated (`unlockStore()` never called — keys stored unencrypted at rest).

### Features
- E2EE media: no file size limit enforcement client-side (Firebase has 5GB limit but large files will OOM on decrypt).
- iOS share sheet: PWA `share_target` only works on Android. iOS needs in-app paste/upload fallback.
- No push notifications (FCM wired but notification loop not complete).
- WebAuthn PRF not implemented (encrypted store uses Argon2id password prompt).
- Pexels API key is client-side (NEXT_PUBLIC) — should be server-side proxy.

### E2EE
- "decrypting..." after inactivity — X3DH session establishment works (4-DH confirmed, OTKs found), but messages may show "decrypting..." after period of inactivity. Root cause under investigation — may be related to Realtime subscription dropping during idle and catch-up pass timing.
- preDistributeSenderKeys REMOVED — was causing double-call X3DH session race. SK distribution now only via piggyback on real sends.

### Performance
- ControlCaret removed from layout (GlobalCaret unmounted). 5 presence channels freed.
- Current channels per space: 3 (Messages, Ledger, Decision Items). Multiplex to 1 at 30+ concurrent users.
- Firebase SDK is 39MB (modular tree-shaking deferred).
- Supabase Pro: 2-core ARM dedicated, 8GB RAM. ~200 concurrent Postgres connections.

### Scale Limits
- ~166 concurrent WebSocket users (3 channels × 500 Supabase Realtime limit)
- ~200 concurrent Postgres connections (Pro dedicated PgBouncer)
- ~20 simultaneous new E2EE sessions (OTK FOR UPDATE SKIP LOCKED contention)
- AI orchestration: 2-5s via SearchApi (was 15-50s via Apify)
- Microservices: NOT recommended. Scale current BaaS model until it breaks.

### Dead Code (files exist but unmounted)
- ControlCaret.tsx, GlobalCaret.tsx, SpotlightSheet.tsx, GhostInput.tsx, useSpotlight.ts
- GlobalMesh.tsx, GlobalUserMenu.tsx

---

## What to Do Next

- **E2EE inactivity test** — Monitor "decrypting..." after idle periods. Check if Realtime subscription drops and catch-up pass fires correctly.
- **Push notifications** — Complete the FCM loop (message → /api/notify → push).
- **WebSocket multiplexing** — Consolidate 3 channels → 1 per space (at 30+ users).
- **Software queue** — In-memory async queue for key fetching (swap to Redis later).
- **Dead code cleanup** — Delete ControlCaret, SpotlightSheet, GhostInput, useSpotlight files.
- **HelloPanel improvements** — Per hellopanel.md spec: refine entity extraction, add more intent keywords.
- **Media file size limits** — Enforce 25MB client-side before encrypt.
- **Tagline** — Choose bold tagline for gethello.ai metadata/OG.
