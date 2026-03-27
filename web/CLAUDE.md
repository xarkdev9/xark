XARK OS v2.0 — PRIME DIRECTIVE
Role: Staff Architect & Systemic Guardrail.
Mission: Build a biocompatible Group Operating System. This is a Human Companion, not a dashboard.

BOOTSTRAP (execute before any code work):
1. Read primer.md — session changelog. What changed recently, what to watch for. START HERE.
2. Read .xark-state.json — current phase + foveal focus tells you what to build.
3. Read CONSTITUTION.md — full visual and architectural law.
4. Read GROUNDING_PROTOCOL.md — @xark AI behavior and grounding constraints.
5. Read SECURITY.md — E2EE architecture, privacy policy, law enforcement response, competitive position.
6. Read docs/superpowers/specs/2026-03-17-xark-architecture-blueprint.md — the approved architecture blueprint (9 services, E2EE, event-driven, loosely coupled).
The foveal_focus field in .xark-state.json is your mission briefing. Execute it.

SESSION END PROTOCOL: Before ending any session, UPDATE primer.md with:
- What was built/changed this session
- Files created and significantly modified
- Architecture decisions made
- Known issues introduced or discovered
- What to do next

ARCHITECTURE BLUEPRINT (approved 2026-03-13):
9 loosely coupled services: Auth, Space, Intelligence, Decision Engine, Messaging, Media, Notification, Settlement, Itinerary.
Event bus: Supabase Realtime (Postgres NOTIFY/LISTEN -> WebSocket). Channel: space:{spaceId}.
Scope: Solo (1 user) + Small Group (2-15 members). Large group deferred.
Two-step commitment: consensus lock (automated at 80%) -> claim + purchase (manual, owner + proof).
Intelligence: @xark deaf until invoked. Three-tier: gemini-local (~7-10s), gemini-search (~40-50s), apify (15-50s).
Privacy: @xark context = grounding state map + last 15 messages on invocation ONLY. No passive listening. Ever.
PWA: manifest.json in public/, standalone display, safe-area padding, service worker for FCM.

1. THE ARCHITECTURAL LOCKS (NON-NEGOTIABLE)
NO-BOLD MANDATE: Hierarchy is achieved through Scale, Spacing, and Opacity alone. Use font-weight: 400 for primary text. Use font-weight: 300 for secondary/metadata. FORBIDDEN: 500, 600, 700, 800, 900. Bold is banned. If you need emphasis, use SIZE or OPACITY — never weight.

THEME SYSTEM (4 Themes): Xark OS ships with 4 themes across 2 axes — style (flat/depth) and mode (light/dark). hearth (flat light, default), hearth_dark (flat dark), vibe (depth light), vibe_dark (depth dark). All colors are CSS variables set by ThemeProvider. No hardcoded hex colors in components. ThemeProvider dynamically updates meta theme-color and input colorScheme for iOS keyboard matching.
- Hearth (flat light): text #1A1A1A, bg #F2EDE8 (Warm Linen), accent #D4536B (Deep Rose).
- Hearth Dark (flat dark): text #F8F7F4, bg #111111, accent #D4536B (Deep Rose).
- Vibe (depth light): text #111111, bg #F8F7F4, accent #D4536B (Deep Rose).
- Vibe Dark (depth dark): text #F8F7F4, bg #111111, accent #D4536B (Deep Rose).
- ThemeStyle: "flat" | "depth". Flat = clean WhatsApp-like. Depth = floating shadows, HD photos, immersive.
- Text color: `var(--xark-white)` via `colors.white`. Theme-aware ink.
- Background: `var(--xark-void)` via `colors.void`. Theme-aware canvas.
- Accent: `var(--xark-accent)` via `colors.accent`. Theme-aware identity color.
- Engine signals (amber, gold, green, orange, gray) are all CSS variables.
- `textColor(alpha)` from theme.ts returns `rgba(var(--xark-white-rgb), alpha)` — the APPROVED method for applying opacity to text. This is NOT an rgba violation; it reads from CSS variables and is theme-aware.
- `accentColor(alpha)` works the same way for accent color with opacity.
- Hierarchy is always expressed through opacity, never font-weight. Use `textColor(0.9)` for primary, `textColor(0.4)` for tertiary, etc.
- `ink.*` system: Solid text colors (`ink.primary`, `ink.secondary`, `ink.tertiary`, `ink.sender`) via CSS variables — set by ThemeProvider per theme. Use instead of `textColor(alpha)` for high-readability contexts. These are solid colors, never opacity-based.
- `surface.*` system: 3-tone depth hierarchy (`surface.chrome`, `surface.canvas`, `surface.recessed`) via CSS variables. Chrome = elevated UI. Canvas = content areas. Recessed = wells (avatars, input fields). Depth without borders — just color hierarchy.
- Xark Brand Color: Deep Rose #D4536B. Liquid Fire gradient: #7C1D3E -> #D4636E -> #EF7C6E. Used for the Living Brand Anchor, tab indicators, @xark labels, CTAs. Chat bubbles: Sent #EF7C6E (Saturated Coral), Received #E8E3DD (Warm Taupe), Canvas #F2EDE8 (Warm Linen).

FONT SYSTEM: Inter (variable) for body text — primary font, set globally in globals.css. Syne (variable) for display/fallback. Inter (variable, weight 369) for the brand wordmark. No other fonts.

LIQUID FIRE SYSTEM (Brand Animation): Wherever "xark" text is displayed, use the Liquid Fire CSS classes from globals.css. Container: `className="xark-glow-anchor"` (xarkBreathe 5s — subtle scale 0.98->1.02 + brightness pulse). Text: `className="xark-text-led"` (xarkLiquidFire 3s — gradient sweep: #7C1D3E->#D4636E->#EF7C6E->#D4636E->#7C1D3E, background-clip: text, linear infinite). Active: scale(0.85). Used by ControlCaret and WelcomeScreen. NEVER use static colors, text-shadow glow, or Framer Motion for "xark" brand text. @xark message bubbles get a Liquid Fire L-corner (`xark-bubble-corner` class: ::before 3px vertical + ::after 36px horizontal, animated).

ZERO-BOX DOCTRINE (AMENDED): Zero-Box applies to FEED content (AwarenessStream, PeopleDock, plans). Chat messages use BUBBLES — research-backed cognitive scaffolding for dialogue. Sent: #EF7C6E (Saturated Coral) right-aligned. Received: #E8E3DD (Warm Taupe) left-aligned. @xark: received color with Liquid Fire L-corner + "@xark" label. Canvas: #F2EDE8 (Warm Linen). 16px radius, 4px tail corner. Consecutive same-sender messages stack at 2px gap. Focus outlines globally purged. No backdrop-filter blur. Overlays use #000 at 0.8.

PORT DISCIPLINE: Run ONLY on Port 3000. If occupied, kill the process. Never jump to 3001.

DEPLOYMENT (LOCKED):
- GitHub: git@github.com:xarkdev9/xark.git (remote: new-origin). Push via: GH_TOKEN=$(gh auth token) git -c "http.https://github.com/.extraheader=Authorization: basic $(echo -n "x-access-token:$(gh auth token)" | base64)" push new-origin main
- Vercel: project "xark" under scope "xarks-projects-700da30e". Deploy via: vercel deploy --prod --scope xarks-projects-700da30e --yes
- Production URL: https://gethello.ai
- All env vars set on Vercel production environment.
- NEVER push to old origin (chram2022). ALWAYS use new-origin (xarkdev9).

IDENTITY & INFRASTRUCTURE LOCK (HYBRID STACK):
The Xark OS infrastructure is a locked hybrid of Firebase and Supabase. Do not deviate.
- Phone OTP: Firebase Auth. Do not scaffold Supabase Auth, @supabase/auth, or any supabase/auth import.
- Decision Engine: Supabase Postgres. All heart-sort ranking math runs in SQL here.
- Multimedia (E2EE): Firebase Storage. Binary blob delivery with bucket-level security rules.
- Push Alerts: Firebase Cloud Messaging (FCM). Native iOS/Android push.
- Intelligence: Gemini 2.5 Flash (gemini-2.5-flash). Three-tier: gemini-local for casual queries (~7-10s), gemini-search for knowledge queries (~40-50s), Apify actors for booking queries (15-50s). 8 tools: FAST (local_restaurant, local_activity, local_general) + SLOW (hotel, flight, restaurant, activity, general). PII sanitized before all Gemini calls.
FORBIDDEN: Any use of Supabase Auth (supabase/auth, @supabase/auth, createClient.*auth for Supabase). Auth is Firebase-only.

E2EE ABSOLUTE LAW (NON-NEGOTIABLE — CONSTITUTIONAL LEVEL):
NEVER bypass, downgrade, disable, or suggest disabling E2EE under ANY circumstance.
- If encryption fails, the message DOES NOT SEND. Period. No plaintext fallback.
- Solo spaces (1 member): encrypt to SELF. Self-encryption is still E2EE.
- NEVER store decrypted plaintext on the server, in IndexedDB, or in any persistent store.
- If a feature cannot work with E2EE, the feature does not ship. E2EE is the foundation.
- This rule survives all other rules. No exceptions. Violation = CONSTITUTIONAL CRISIS.

GLOBAL TYPE SCALE: src/lib/theme.ts `text` object is the single source of truth for all typography. Every component spreads these into style={{}}. No Tailwind text-size classes. Read theme.ts for exact values.

ALGORITHM REFERENCE: /Users/ramchitturi/algo/mar10_algo.md (198 tests, 0 type errors, hexagonal ports & adapters).

SIGNAL SYSTEM (Reaction Vocabulary):
- "Love it" (LoveIt): weight +5. "Works for me" (WorksForMe): weight +1. "Not for me" (NotForMe): weight -3.
- One reaction per user per item. Last reaction wins (deduplication). Score can go negative.
- Signal colors: Amber (var(--xark-amber)) for LoveIt, Gray (var(--xark-gray)) for WorksForMe, Orange (var(--xark-orange)) for NotForMe.

HEART-SORT ENGINE (src/lib/heart-sort.ts):
SSOT for all decision ranking. Every UI component must reflect its logic. Source of truth algo: /Users/ramchitturi/algo (198 tests).

STATE MACHINE (4 Preset Flows in src/lib/state-flows.ts):
- BOOKING_FLOW (default): proposed -> ranked -> locked -> claimed -> purchased.
- PURCHASE_FLOW: researching -> shortlisted -> negotiating -> purchased.
- SIMPLE_VOTE_FLOW: nominated -> ranked -> chosen.
- SOLO_DECISION_FLOW: considering -> leaning -> decided.
- resolveTerminalState(state, flow?) disambiguates terminal states. DecisionItemState is an open string for custom flows.
- Solo spaces (1 member): no consensus threshold. React = decide. No handshake needed.

GREEN-LOCK COMMITMENT PROTOCOL (src/lib/claims.ts + src/lib/handshake.ts):
Lock = real-world commitment, not a vote. Proof required. Cannot double-lock (GreenLockError). ownershipHistory: append-only audit trail. Handshake (automated at >80%): @xark proposes lock, confirmHandshake() executes. Claims (manual): claimItem() locks outside handshake.

@XARK AI BEHAVIOR:
Full spec in GROUNDING_PROTOCOL.md. Key rules:
- COOL FRIEND PERSONA: @xark texts like a real friend in a group chat. brief, lowercase, punchy, max 20 words. no AI cringe. zero or one contextual emoji. warm but never corny.
- SILENT BY DEFAULT: Never responds unless invoked via SpotlightSheet. One exception: handshake whisper at >80% consensus.
- STATE MAP APPROACH: @xark receives full state map (Locked/Voting/Proposed/Empty). Reasons about scope, not rigid category bans.
- SOCIAL REASONING: Use names when advocating FOR someone. Use counts for opposition. Never assume why someone voted.
- NATIVE JSON MODE: Intent parsing uses `responseMimeType: "application/json"`.
- getGreeting(): Deterministic, no AI call. See ai-grounding.ts for logic.
- /api/xark: Check for "@xark" prefix before calling Gemini. Parallelized pre-Gemini fetches via Promise.all. Persists @xark response messages server-side via supabaseAdmin.
- Tier 1 (local-agent.ts): <1ms regex for admin commands. PARKED — needs browser debugging.
- Tier 2 (local-recall + memory-worker): DELETED — stored plaintext in IndexedDB, violated E2EE.
- Tier 3 (Gemini cloud): gemini-local (~7-10s), gemini-search (~40-50s), apify (15-50s).

SUPABASE POSTGRES CLIENT (src/lib/supabase.ts):
DB queries ONLY. Import @supabase/supabase-js (NOT @supabase/auth). Do not add auth configuration.
- PROXY PATTERN: Exports Proxy that delegates to authenticated client (with JWT) or default anon client. setSupabaseToken(token) switches clients for RLS enforcement.

SUPABASE ADMIN CLIENT (src/lib/supabase-admin.ts):
Server-side client with SUPABASE_SERVICE_ROLE_KEY. Bypasses RLS. Used by /api/xark, /api/notify, /api/dev-auto-login, /api/join, /api/og. Null-check before use.

SUPABASE RLS POLICIES:
All SELECT policies use a shared SECURITY DEFINER function to avoid infinite recursion:
- auth_user_space_ids(): Returns space_ids where user_id = auth.jwt()->>'sub'. SECURITY DEFINER bypasses RLS on the inner query.
- All tables (spaces, space_members, decision_items, messages, reactions) filter via this function.
- IMPORTANT: auth.uid() requires UUID format. Our user IDs are text (e.g., "name_ram"), so policies use auth.jwt()->>'sub' instead.

DEV AUTH (/api/dev-auto-login):
Passwordless dev login. Gated by DEV_MODE=true.
- POST { username } -> looks up user by display_name -> signs JWT with jose (sub: user.id, role: authenticated).
- Client calls from useAuth hook, then sets JWT via setSupabaseToken(token) for RLS.
- Returns 404 in production. Falls back to name-only mode (no RLS, demo data).

FIREBASE CLIENT (src/lib/firebase.ts):
Phone OTP + E2EE storage. Exports auth (Auth|null) and storage (FirebaseStorage|null). Safe init — no-op when env vars missing. Consumers must null-check. Do not use Firebase for database. Do not use Firestore.

AUTH HOOK (src/hooks/useAuth.ts):
Returns { user: XarkUser|null, isAuthenticated, isLoading }. Auth chain: Firebase -> dev-auto-login (JWT for RLS) -> name-only fallback. Firebase-only. No Supabase Auth. IDENTITY FIX: handleFallback and initialSession restore verify cached session matches requested fallbackName.

E2EE (End-to-End Encryption):
Full architecture documented in SECURITY.md. Signal Protocol: Double Ratchet (1:1 sanctuaries), Sender Keys (groups 2-15). Three-layer architecture: L1 (key management), L2 (message encryption, zero-knowledge), L3 (structured intelligence, @xark reads only this). Server never sees plaintext or private keys. XChaCha20-Poly1305 AEAD. Ed25519 signing. Curve25519 DH. HKDF-SHA-256. Argon2id backups. libsodium-wrappers-sumo (WASM). Client-side only — never import crypto modules on server.

E2EE MODULE MAP (src/lib/crypto/ — client-side only):
- types.ts — All E2EE types (RawKeyPair, IdentityKeyPair, SessionState, SenderKeyState, EncryptedPayload, DecryptedMessage, MessageType, KeyBackupBlob).
- primitives.ts — libsodium-wrappers-sumo wrapper. XChaCha20-Poly1305 AEAD, Ed25519, Curve25519 DH, HKDF-SHA-256, Argon2id, constant-time comparison.
- keystore.ts — IndexedDB-backed persistent key storage (DB_VERSION 3). Identity keys, signed pre-keys, OTKs, sessions, sender keys, device ID, unacked ratchets, decrypted-messages store (encrypted plaintext cache), processed-distributions store (SK distribution dedup).
- encrypted-store.ts — Encrypted IndexedDB wrapper. All E2EE keys and session state encrypted at rest. AES-GCM with device-derived key.
- x3dh.ts — X3DH key agreement (initiator + responder). 4 DH operations. Returns shared secret + ephemeral key.
- double-ratchet.ts — Double Ratchet with bounded skipped-key dictionary (max 1000). Per-message forward secrecy.
- sender-keys.ts — Sender Key generation, encrypt/decrypt with chain advancement, Ed25519 message signing.
- key-manager.ts — registerKeys(), fetchPeerKeyBundle() (via RPC), replenishOTKsIfNeeded(), createKeyBackup/restoreKeyBackup (Argon2id + AES).
- encryption-service.ts — encryptForSanctuary() (Double Ratchet), encryptForSpace() (Sender Keys + always-distribute via prepareSenderKeyDistribution()), decryptMessage() (with plaintext cache guard), processSenderKeyDistribution() (with dedup guard). Two-phase ratchet commit. Encrypt/decrypt mutexes. JWT gatekeeper.
- sk-recovery.ts — On Sender Key decrypt failure, re-fetches sender's key from server and retries.
- dm-routing.ts — Deterministic 1:1 space ID generation. getDMSpaceId() — both peers compute identical ID.
- outbox.ts — Outbox pattern for E2EE messages. Persists encrypted message before send, removes on server ACK.
- file-encryption.ts — AES-256-GCM file encrypt/decrypt for E2EE media. encryptFile(File) → { encryptedBlob, aesKeyBase64, ivBase64 }. decryptFile(blob, key, iv, mime) → blob:// URL. Pure Web Crypto API.
- CryptoProvider.ts — React context provider for E2EE crypto lifecycle.
- index.ts — Barrel export for all crypto modules.
- src/lib/constraints.ts — On-device constraint detection (dietary, budget, accessibility, alcohol). Sender's device only.
- src/hooks/useE2EE.ts — React lifecycle hook. Dynamic imports (SSR-safe). Graceful degradation if migration 014 not applied.

API ROUTES:
- /api/chat/start — POST: WhatsApp-style find-or-create 1:1 chat via find_or_create_chat RPC. JWT auth, 20/min rate limit.
- /api/contacts/check — POST: phone number registration lookup. Takes { phones: string[] max 500 }, returns { registered: [{ phone, userId }] }. JWT auth, 5/min rate limit.
- /api/message — POST: E2EE message endpoint. Atomic: message + ciphertext + piggybacked SK distribution. JWT auth, 10/min rate limit.
- /api/xark — POST: Intelligence orchestration. 3-tier routing. maxDuration 60s. JWT auth, 10/min rate limit.
- /api/phone-auth — POST: Exchange Firebase phone OTP token for Supabase-compatible JWT. Creates/updates user.
- /api/keys/bundle — POST: E2EE key bundle upload.
- /api/keys/otk — POST: OTK batch upload (max 200 keys).
- /api/keys/fetch — POST: Atomic key bundle fetch via fetch_key_bundle RPC (FOR UPDATE SKIP LOCKED).
- /api/summon — POST: Generate 128-bit hex cryptographic invite link.
- /api/summon/validate — GET: public, validate code, return creator name.
- /api/summon/claim — POST: Firebase auth -> atomic claim RPC -> create 2-player space -> JWT.
- /api/join — POST: Name-only invite join. Validates token, creates user, signs JWT.
- /api/local-action — POST: Tier 1 mutations: update_dates, rename_space, revert, create_space. Atomic mutation + space_ledger audit.
- /api/notify — POST: FCM push to space members. Filters muted spaces.
- /api/og — POST: OG metadata extraction with SSRF protection. Optional insertAsItem.
- /api/taste — POST: Day 1 taste onboarding. Gemini parses natural language -> JSONB constraints.
- /api/share — POST: PWA share target handler for URL/text shares. Redirects to /share page.
- /api/proxy-scrape — POST: Blind OG metadata proxy. No auth, no logging, no DB writes. Returns { title, description, imageBase64 }. SSRF-protected. Used by ChatInput link preview detection.
- /api/dev-auth — POST: Dev login with password (bcrypt). Returns 404 in production.
- /api/dev-auto-login — POST: Passwordless dev login. Returns 404 if NODE_ENV=production.
- /api/cron/consensus — GET: Auto-lock expired consensus countdowns. Daily.
- /api/cron/purge — GET: Purge expired @xark messages + summon links. Daily.

KEY MODULE MAP:
- src/lib/messages.ts — Supabase Postgres chat persistence + Realtime sync. Paginated: fetchMessages(spaceId, { limit?, before? }). MessageType (e2ee/e2ee_xark/xark/system/legacy). fetchCiphertexts(messageId).
- src/lib/ai-grounding.ts — buildGroundingContext(), checkSuggestionConflicts(), generateGroundingPrompt(), getGreeting(). State map approach.
- src/lib/awareness.ts — Priority-sorted cross-space events. Time decay. Parallelized queries. fetchPersonalChats() uses get_latest_messages_per_space RPC.
- src/lib/space-data.ts — SpaceListItem, fetchSpaceList() (batched 4-query pattern + RPC), recencyLabel(), recencyOpacity(), DEMO_SPACES.
- src/lib/spaces.ts — createSpace() + getOptimisticSpaceId() for instant navigation (Manifestation Loop).
- src/lib/ledger.ts — Settlement math. fetchSettlement(). venmo/upi deep links.
- src/lib/space-state.ts — computeSpaceState(items[], tripDates?, expiresAt?) -> empty/exploring/converging/ready/active/settled.
- src/lib/space-templates.ts — 6 micro-space templates with categories and lifetimes.
- src/lib/og-extract.ts — Server-side OG metadata extraction. Used by /api/og.
- src/lib/intelligence/ — orchestrator.ts (3-tier routing), tool-registry.ts (8 tools), apify-client.ts, sanitize.ts (PII redaction with Luhn).
- src/lib/local-agent.ts — Tier 1 fast-path router. PARKED — needs browser debugging.
- src/lib/taste.ts — Taste Graph: intersectTasteProfiles(), buildTastePromptInjection().
- src/lib/whispers.ts — Proactive whisper engine: deterministic checks (onboarding P2, consensus_ready P0, missing_category P1, nudge_vote P2).
- src/lib/unread.ts — fetchUnreadCounts() + markSpaceRead(). Badge: Deep Rose pill (#D4536B) on AwarenessStream + PeopleDock.
- src/lib/unsplash.ts — Photo fetcher: Pexels API primary -> Unsplash fallback.
- src/lib/auth-verify.ts — Server JWT verification via jose.
- src/lib/rate-limit.ts — Centralized rate limiter. Supabase Postgres RPC + in-memory fallback.
- src/lib/storage.ts — Provider-agnostic storage adapter. Firebase implementation.
- src/lib/user-id.ts — User ID format: makeUserId, extractDisplayName, getUserIdType.
- src/lib/media.ts — Firebase Storage upload/download + Supabase metadata.
- src/lib/notifications.ts — Server-side FCM push. Lazy init. /api/notify uses get_push_tokens_for_space RPC.
- src/lib/seed.ts — Demo data: san diego trip, ananya sanctuary, tokyo neon nights, summer 2026. Run: npx tsx src/lib/seed.ts
- src/lib/playground.ts — Ghost Playground data. 5 friends, 4 spaces, detection, getters. Client-side only, zero DB.

COMPONENTS:
- ControlCaret.tsx — Living Brand Anchor. "xark" text (40px, weight 369) via Liquid Fire CSS: `.xark-glow-anchor` + `.xark-text-led`. CSS :active scale(0.85). Thumb arc show/hide via CSS transition (no Framer Motion for show/hide). Tap opens SpotlightSheet, long-press opens space panel (500ms). SpotlightSheet mounted here. Global via GlobalCaret.tsx. z-index 60. Presence channels limited to top 5.
- XarkChat.tsx — Chat stream with bubble architecture. Sent right (#EF7C6E), received left (#E8E3DD), @xark has Liquid Fire L-corner (xark-bubble-corner class). 12px different sender, 2px same sender spacing. Foveal opacity. Handshake proposal/confirm. LedgerPills interleaved. InlinePoll support for xark_poll messages.
- ChatInput.tsx — Input pill with @xark chip detection, voice input, media attach, URL detection. Gradient border in @xark mode. Auto-resize. Form submit for Android IME.
- PossibilityHorizon.tsx — Netflix-style decision card rails. Hero banner (deterministic hash). CategoryRail (memoized). heartSort ranking. Per-item reactions with debounce.
- DecisionCard.tsx — Immersive card: 82% viewport x clamp(320px, 50dvh, 440px). Full-bleed photo, cinematic gradient. 56px score. ConsensusTimer. Reactions with haptic.
- UserMenu.tsx — 4-view settings sheet: main -> profile/notifications/about. Avatar trigger (32px). Photo upload to Firebase. FCM toggle. Per-space mute. Theme toggles (flat/vibe + light/dark). Logout with crypto shredding.
- PeopleDock.tsx — 1:1 chat list (sanctuary spaces). Real display names. Unread badges (#D4536B). Realtime message updates.
- AwarenessStream.tsx — Space summary list. Priority-sorted. Time decay. Unread badges (#D4536B). Vibe-aware styling.
- SpotlightSheet.tsx — @xark invocation overlay. GhostInput with whisper pre-fill. Space chips on Galaxy. 800ms morph dismiss. Overlay: #000 at 0.8 (no blur).
- GhostInput.tsx — Input with ghost text pre-fill. Type = shatter ghost. Send = accept.
- ThemeProvider.tsx — Global theme context. Sets 20+ CSS variables on :root. Dynamic meta theme-color. localStorage + Supabase sync.
- InviteSurface.tsx — People tab empty state. Mesh gradient + invite CTA. Generates /s/[code] invite links.
- Avatar.tsx — Photo or letter fallback. Circle (flat) or square (vibe). surface.recessed background.
- ConsensusBanner.tsx — Pinned banner above chat during consensus countdown.
- ConsensusTimer.tsx — Live countdown on DecisionCard. Red when <60s.
- LedgerPill.tsx — System pill for space_ledger events. Icon + actor + verb + payload + undo.
- InlineCardPreview.tsx — Mini decision card for chat timeline. 100px tall, photo left, score right.
- InlinePoll.tsx — Inline poll widget rendered inside xark_poll messages in XarkChat.
- EncryptedMedia.tsx — E2EE media renderer. Downloads encrypted blob from Firebase, decrypts with AES-GCM key from E2EE channel, renders <img>/<video>. URL.revokeObjectURL on unmount. fillContainer mode for DecisionCard. Used by XarkChat, DecisionCard, LinkPreviewCard.
- AddItemModal.tsx — Screenshot upload modal for Decide tab. File picker + clipboard paste (CMD+V). E2EE pipeline: thumbnail → encrypt → Firebase → decision_items insert with metadata.encrypted_image. Opened from PossibilityHorizon "+" FAB.
- LinkPreviewCard.tsx — E2EE link preview card. Domain bar + title (2-line clamp) + description + optional EncryptedMediaRenderer for og:image. Injected below message text in XarkChat.
- ClaimSheet.tsx — Slide-up for claiming locked items. Stamps owner.
- PurchaseSheet.tsx — Slide-up for purchase confirmation + amount. Terminal state.
- PlaygroundSpace.tsx — Ghost demo space. Mock reactions, mock @xark, choreography engine. No Supabase.
- PlaygroundWhisper.tsx — Diegetic whisper. Breathing opacity 30->60%. Auto-dismiss.
- OnboardingWhispers.tsx — Coaching hints. One-time show. localStorage persistence.
- WelcomeScreen.tsx — Login entrance. 4-phase choreography (spark->collision->reveal->idle). Liquid Fire brand text (weight 369).
- GalaxyLayout.tsx — Layout registry: stream (vertical) vs split (side-by-side).
- SpacePicker.tsx — Space selection for share flow. Recent spaces sorted by activity.
- ItineraryView.tsx — Committed items timeline for ready/active spaces.
- MemoriesView.tsx — Photo stream for settled spaces.
- MemoriesTab.tsx — Memories tab on Galaxy. In development.
- Blueprint.tsx — Vertical timeline of Green-Lock settled decisions + Settlement Ledger.
- GlobalCaret.tsx — Wrapper: renders ControlCaret on all pages except /login and /.
- GlobalMesh.tsx — REMOVED from layout. File exists but is NOT mounted. Was GPU-burning blur animations.
- GlobalUserMenu.tsx — File exists but NOT imported anywhere. Dead code.
- ServiceWorkerRegistration.tsx — Registers sw.js + firebase-messaging-sw.js. Global.

HOOKS:
- useAuth.ts — Firebase phone OTP -> dev-auto-login JWT -> name-only fallback. Sets Supabase JWT for RLS.
- useE2EE.ts — E2EE lifecycle. Initializes crypto, registers keys, tracks device ID. Graceful degradation.
- useHandshake.ts — Consensus monitor. Triggers at >80% agreement. Executes Green-Lock on confirm.
- useReactions.ts — Voting hook. JWT guard. Per-item debounce.
- useWhispers.ts — Proactive whisper queue. 60s poll.
- useKeyboard.ts — Virtual keyboard detection via visualViewport. Input-focus gated.
- useVoiceInput.ts — On-device SpeechRecognition. Tap = dictation, long-press = @xark prefix.
- useSpotlight.ts — Spotlight sheet state. 800ms morph. Routes to /api/xark.
- useDeviceTier.ts — Device capability detection. Low: memory <= 2GB, cores <= 4.
- usePlaygroundChoreography.ts — Timer-based demo choreography. All timers cleaned on unmount.
- useDisplayName.ts — Display name resolution hook. Used by space page.

PAGES:
- / — Root redirect to /login.
- /login — Phone OTP auth with Firebase. Dev mode password login. WelcomeScreen child.
- /galaxy — Home hub. 3 tabs: People | Plans | Memories. UserMenu top-right. Contact discovery. E2EE key registration.
- /space/[id] — Space view. discuss/decide toggle with swipe. Full E2EE messaging. Batch SK distribution.
- /s/[code] — Summon invite landing. Theme-aware (uses ink/surface/colors tokens, no hardcoded dark).
- /j/[token] — Quick invite join. Name input -> POST /api/join -> redirect to space.
- /share — PWA share target. OG metadata extraction + SpacePicker.
- /prototype — Component lab with interactive prototypes.
- /demo — Scripted ad demo.

LAYOUT TREE (src/app/layout.tsx):
ThemeProvider -> {children} -> GlobalCaret (ControlCaret on all pages except /login, /) -> ServiceWorkerRegistration.
REMOVED from layout: GlobalMesh (GPU drain), GlobalUserMenu (duplicate).

MIGRATIONS (supabase/migrations/):
001_foundation_schema, 002_functions_triggers, 003_rls_policies, 004_dev_verify_password, 005_media_devices, 007_system_messages_rpc, 008_join_via_invite, 009_space_dates, 010_member_logistics, 011_fix_reaction_rpcs, 012_perf_optimizations, 013_daily_use, 014_e2ee, 015_e2ee_wiring, 016_security_hardening, 017_hybrid_brain, 018_security_hardening_v2, 019_unread_counts, 020_self_join, 021_fix_proposed_by_trigger, 022_lane_four_wiring, 023_e2ee_rls_perf, 024_security_definer_lockdown, 025_rate_limiter, 026_privacy_cascades, 027_taste_graph_consensus, 028_summon_links, 029_find_or_create_chat, 030_contacts_check.

2. THE ENGINE-TO-PIXEL MAP
Amber (var(--xark-amber)): Seeking/Anticipation. Wash intensity maps to weightedScore.
Gold (var(--xark-gold)): Social Gold. Radial bloom triggers at agreementScore > 80%.
Green (var(--xark-green)): Finality. Settle upon isLocked.
Rose (#D4636E): @xark Intelligence. Liquid Fire gradient on brand anchor + @xark message corner.

3. THE 3-TIER SENTINEL PROTOCOL
Before every code write, you must perform these three internal checks:
Tier 1 (Status): Read .xark-state.json. Verify the current 'Foveal Focus'.
Tier 2 (Logic): Verify that the UI component strictly reflects the logic in src/lib/heart-sort.ts.
Tier 3 (Audit): Scan the diff for border-1, font-bold, font-semibold, font-weight above 400, rgba(240,238,233), supabase/auth, or @supabase/auth. If found, PURGE and restart the turn.

4. THE DRIFT FAILURE RESTART
If you detect that you have hallucinated a card-based UI, a bold font, any weight above 400, or a hardcoded color instead of theme.ts tokens, you must stop immediately and output: 'I HAVE VIOLATED THE CONSTITUTION. RESTARTING TURN.'

5. LOSSLESS CONTEXT RECALL
All conversation history is saved to ~/.claude/lossless/context.db (SQLite with FTS5). When context was compacted, when the user references something from earlier, or when you need to recall past decisions/code/feedback, search the database:
- FTS search: sqlite3 ~/.claude/lossless/context.db "SELECT role, substr(content,1,200) FROM messages WHERE id IN (SELECT rowid FROM messages_fts WHERE messages_fts MATCH 'keyword') ORDER BY created_at DESC LIMIT 10"
- Pattern search: sqlite3 ~/.claude/lossless/context.db "SELECT role, substr(content,1,200) FROM messages WHERE content LIKE '%term%' ORDER BY created_at DESC LIMIT 10"
- Full message: sqlite3 ~/.claude/lossless/context.db "SELECT content FROM messages WHERE id = N"
Use LIMIT always. Use substr() for previews before fetching full content.
