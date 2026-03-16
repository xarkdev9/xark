XARK OS v2.0 — PRIME DIRECTIVE
Role: Staff Architect & Systemic Guardrail.
Mission: Build a biocompatible Group Operating System. This is a Human Companion, not a dashboard.

BOOTSTRAP (execute before any code work):
1. Read primer.md — session changelog. What changed recently, what to watch for. START HERE.
2. Read .xark-state.json — current phase + foveal focus tells you what to build.
3. Read CONSTITUTION.md — full visual and architectural law.
4. Read GROUNDING_PROTOCOL.md — @xark AI behavior and grounding constraints.
5. Read SECURITY.md — E2EE architecture, privacy policy, law enforcement response, competitive position.
6. Read docs/superpowers/specs/2026-03-13-xark-architecture-blueprint.md — the approved architecture blueprint (9 services, event-driven, loosely coupled).
The foveal_focus field in .xark-state.json is your mission briefing. Execute it.

SESSION END PROTOCOL: Before ending any session, UPDATE primer.md with:
- What was built/changed this session
- Files created and significantly modified
- Architecture decisions made
- Known issues introduced or discovered
- What to do next

ARCHITECTURE BLUEPRINT (approved 2026-03-13):
Full spec: docs/superpowers/specs/2026-03-13-xark-architecture-blueprint.md
9 loosely coupled services: Auth, Space, Intelligence, Decision Engine (includes Commitment), Messaging, Media, Notification, Settlement, Itinerary.
Event bus: Supabase Realtime (Postgres NOTIFY/LISTEN → WebSocket). Channel: space:{spaceId}.
Scope: Solo (1 user) + Small Group (2-15 members). Large group deferred.
Emergent space state: computed from items via computeSpaceState(items[]), not stored.
Two-step commitment: consensus lock (automated at 80%, no owner) → claim + purchase (manual, owner + proof + amount).
Intelligence: @xark is deaf until invoked. Gemini = brain. Three-tier routing: gemini-local (fast, ~7-10s, casual queries), gemini-search (~40-50s, knowledge queries), apify (slow, 15-50s, booking queries). Tool registry pattern.
Voice: tap mic = on-device SpeechRecognition, long-press = Gemini multimodal.
Privacy: @xark context = grounding state map + last 15 messages on invocation ONLY. No passive listening. Ever.
PWA: manifest.json in public/, standalone display, safe-area padding, service worker for FCM.

1. THE ARCHITECTURAL LOCKS (NON-NEGOTIABLE)
NO-BOLD MANDATE: Hierarchy is achieved through Scale, Spacing, and Opacity alone. Use font-weight: 400 for primary text. Use font-weight: 300 for secondary/metadata. FORBIDDEN: 500, 600, 700, 800, 900. Bold is banned. If you need emphasis, use SIZE or OPACITY — never weight.

THEME SYSTEM (4 Themes): Xark OS ships with 4 themes across 2 axes — style (flat/depth) and mode (light/dark). hearth (flat light, default), hearth_dark (flat dark), vibe (depth light), vibe_dark (depth dark). All colors are CSS variables set by ThemeProvider. No hardcoded hex colors in components. ThemeProvider dynamically updates meta theme-color and input colorScheme for iOS keyboard matching.
- Hearth (flat light): text #111111, bg #F8F7F4, accent #FF6B35 (Action Orange).
- Hearth Dark (flat dark): text #E8E6E1, bg #0A0A0F, accent #40E0FF (Cyan).
- Vibe (depth light): text #0F0F0F, bg #FAF9F6, accent #E87040 (warm orange).
- Vibe Dark (depth dark): text #ECE8E2, bg #08080C, accent #50E8C0 (warm teal).
- ThemeStyle: "flat" | "depth". Flat = clean WhatsApp-like. Depth = floating shadows, HD photos, immersive.
- Text color: `var(--xark-white)` via `colors.white`. Theme-aware ink.
- Background: `var(--xark-void)` via `colors.void`. Theme-aware canvas.
- Accent: `var(--xark-accent)` via `colors.cyan`. Theme-aware identity color.
- Engine signals (amber, gold, green, orange, gray) are all CSS variables.
- `textColor(alpha)` from theme.ts returns `rgba(var(--xark-white-rgb), alpha)` — the APPROVED method for applying opacity to text. This is NOT an rgba violation; it reads from CSS variables and is theme-aware.
- `accentColor(alpha)` works the same way for accent color with opacity.
- Hierarchy is always expressed through opacity, never font-weight. Use `textColor(0.9)` for primary, `textColor(0.4)` for tertiary, etc.
- `ink.*` system: Solid text colors (`ink.primary`, `ink.secondary`, `ink.tertiary`, `ink.sender`) via CSS variables — set by ThemeProvider per theme. Use instead of `textColor(alpha)` for high-readability contexts (chat lists, People tab, settings). These are solid colors, never opacity-based.

FONT SYSTEM: Inter (variable) for body text — primary font, set globally in globals.css. Syne (variable) for display/fallback. Inter (variable, weight 300) for the wordmark. No other fonts.

ZERO-BOX DOCTRINE: No border, no bg-white, no rounded-lg containers for feed items. Information must float in Atmospheric Space. Separation = Vertical Distance. Focus outlines are globally purged (*:focus { outline: none } in globals.css) — browser focus rings are borders and violate Zero-Box. No backdrop-filter blur anywhere. Overlays use #000 at opacity 0.8. No chat bubbles, no message containers, no cards, no rounded corners on feed items.

PORT DISCIPLINE: Run ONLY on Port 3000. If occupied, kill the process. Never jump to 3001.

IDENTITY & INFRASTRUCTURE LOCK (HYBRID STACK):
The Xark OS infrastructure is a locked hybrid of Firebase and Supabase. Do not deviate.
- Phone OTP: Firebase Auth. Do not scaffold Supabase Auth, @supabase/auth, or any supabase/auth import.
- Decision Engine: Supabase Postgres. All heart-sort ranking math runs in SQL here.
- Multimedia (E2EE): Firebase Storage. Binary blob delivery with bucket-level security rules.
- Push Alerts: Firebase Cloud Messaging (FCM). Native iOS/Android push.
- Intelligence: Gemini 2.5 Flash (gemini-2.5-flash). Three-tier: gemini-local for casual queries (coffee, sunset spots, bars — direct Gemini knowledge, ~7-10s), gemini-search for knowledge queries (Google Search grounding, ~40-50s), Apify actors for booking queries (hotels, flights — 15-50s). 8 tools: FAST (local_restaurant, local_activity) + SLOW (hotel, flight, restaurant, activity) + general. PII sanitized before all Gemini calls.
FORBIDDEN: Any use of Supabase Auth (supabase/auth, @supabase/auth, createClient.*auth for Supabase). Auth is Firebase-only.

GLOBAL TYPE SCALE: src/lib/theme.ts `text` object is the single source of truth for all typography. Every component spreads these into style={{}}. No Tailwind text-size classes. Read theme.ts for exact values.

ALGORITHM REFERENCE: Full technical decision record at /Users/ramchitturi/algo/mar10_algo.md (198 tests, 0 type errors, hexagonal architecture). Hexagonal ports & adapters architecture defined there. All ports are interfaces.

SIGNAL SYSTEM (Reaction Vocabulary):
- "Love it" (LoveIt): weight +5. "Works for me" (WorksForMe): weight +1. "Not for me" (NotForMe): weight -3.
- One reaction per user per item. Last reaction wins (deduplication). Score can go negative.
- Signal colors: Amber (#F5A623) for LoveIt, Neutral Gray (#8888a0) for WorksForMe, Action Orange (#e8590c) for NotForMe.

HEART-SORT ENGINE (src/lib/heart-sort.ts):
SSOT for all decision ranking. Every UI component must reflect its logic. Source of truth algo: /Users/ramchitturi/algo (198 tests).
KNOWN GAP: App has simplified Possibility type + 2 functions (heartSort, getConsensusState). Full algo (DecisionItem, calculateWeightedScore, addReaction, removeReaction, calculateAgreementScore) lives in /algo only. Port pending.

STATE MACHINE (4 Preset Flows in src/lib/state-flows.ts):
- BOOKING_FLOW (default): proposed → ranked → locked (consensus, no owner) → claimed (owner stamped) → purchased (terminal, feeds settlement).
- PURCHASE_FLOW: researching → shortlisted → negotiating → purchased.
- SIMPLE_VOTE_FLOW: nominated → ranked → chosen.
- SOLO_DECISION_FLOW: considering → leaning → decided.
- resolveTerminalState(state, flow?) disambiguates "ranked" (→ locked in BOOKING, → chosen in SIMPLE_VOTE). DecisionItemState is an open string for custom flows.
- Solo spaces (1 member): no consensus threshold. React = decide. No handshake needed.

GREEN-LOCK COMMITMENT PROTOCOL (src/lib/claims.ts + src/lib/handshake.ts):
Lock = real-world commitment, not a vote. Proof required. Cannot double-lock (GreenLockError). On lock: owner stamped { ownerId, assignedAt, reason: "booker" }. ownershipHistory: append-only audit trail.
- Handshake (automated): When agreementScore > 80%, @xark proposes lock. confirmHandshake() executes Green-Lock. In BOOKING_FLOW, locked is intermediate (no owner) — ownership assigned at claim step. Terminal = purchased.
- Claims (manual): claimItem() locks outside handshake. Flow-aware terminal state resolution.

@XARK AI BEHAVIOR:
Full spec in GROUNDING_PROTOCOL.md. Key rules:
- COOL FRIEND PERSONA: @xark texts like a real friend in a group chat. brief, lowercase, punchy, max 20 words. no AI cringe (OMG, epic, vibes, 🎉, ✨). zero or one contextual emoji. warm but never corny.
- SILENT BY DEFAULT: Never responds unless message contains "@xark". One exception: handshake whisper at >80% consensus.
- STATE MAP APPROACH: @xark receives full state map (Locked/Voting/Proposed/Empty). Reasons about scope, not rigid category bans.
- SOCIAL REASONING: Use names when advocating FOR someone. Use counts for opposition. Never assume why someone voted. "No Man Left Behind" rule for minority constraints.
- NATIVE JSON MODE: Intent parsing uses `responseMimeType: "application/json"` — no markdown fighting, no format rebellion. USER REQUEST at bottom of prompt to prevent example hallucination.
- getGreeting(): Deterministic, no AI call. See ai-grounding.ts for logic.
- /api/xark: Check for "@xark" prefix before calling Gemini. If absent, return { response: null }. Parallelized pre-Gemini fetches via Promise.all (space title + grounding context + last 15 messages). Search results include search_batch + search_label (user's query text, not tool category — each search gets its own Decide rail) metadata for grouped display. Persists @xark response messages server-side via supabaseAdmin (returns messageId to client for deduplication).
- THREE-TIER LOCAL INTELLIGENCE (client-side, in sendMessage): Tier 1 (local-agent.ts, <1ms regex) → Tier 2 (local-recall.ts + memory-worker.ts, lexical search) → Tier 3 (Gemini cloud). Tier 1 runs even while isThinking. Tier 2 strict halts on zero results (cloud is E2EE-blind). Local intelligence is PARKED — needs browser debugging.

SUPABASE POSTGRES CLIENT (src/lib/supabase.ts):
DB queries ONLY. Import @supabase/supabase-js (NOT @supabase/auth). Do not add auth configuration.
- PROXY PATTERN: Exports Proxy that delegates to authenticated client (with JWT) or default anon client. setSupabaseToken(token) switches clients for RLS enforcement.
- Placeholder fallback: When env vars missing, renders locally with demo data fallbacks.

SUPABASE ADMIN CLIENT (src/lib/supabase-admin.ts):
Server-side client with SUPABASE_SERVICE_ROLE_KEY. Bypasses RLS. Used by /api/xark, /api/notify, /api/dev-auto-login, /api/join, /api/og. Null-check before use.

SUPABASE RLS POLICIES:
All SELECT policies use a shared SECURITY DEFINER function to avoid infinite recursion:
- auth_user_space_ids(): Returns space_ids where user_id = auth.jwt()->>'sub'. SECURITY DEFINER bypasses RLS on the inner query.
- All tables (spaces, space_members, decision_items, messages, reactions) filter via this function.
- IMPORTANT: auth.uid() requires UUID format. Our user IDs are text (e.g., "name_ram"), so policies use auth.jwt()->>'sub' instead.

DEV AUTH (/api/dev-auto-login):
Passwordless dev login. Gated by DEV_MODE=true.
- POST { username } → looks up user by display_name → signs JWT with jose (sub: user.id, role: authenticated).
- Client calls from useAuth hook, then sets JWT via setSupabaseToken(token) for RLS.
- Returns 404 in production. Falls back to name-only mode (no RLS, demo data).

FIREBASE CLIENT (src/lib/firebase.ts):
Phone OTP + E2EE storage. Exports auth (Auth|null) and storage (FirebaseStorage|null). Safe init — no-op when env vars missing. Consumers must null-check. Do not use Firebase for database. Do not use Firestore.

AUTH HOOK (src/hooks/useAuth.ts):
Returns { user: XarkUser|null, isAuthenticated, isLoading }. Auth chain: Firebase → dev-auto-login (JWT for RLS) → name-only fallback. Firebase-only. No Supabase Auth. IDENTITY FIX: handleFallback and initialSession restore now verify cached session matches requested fallbackName (prevents tab duplication inheriting wrong user's session via shared sessionStorage).

E2EE (End-to-End Encryption):
Full architecture documented in SECURITY.md. Signal Protocol: Double Ratchet (1:1 sanctuaries), Sender Keys (groups 2-15). Three-layer architecture: L1 (key management), L2 (message encryption, zero-knowledge), L3 (structured intelligence, @xark reads only this). Server never sees plaintext or private keys. XChaCha20-Poly1305 AEAD. Ed25519 signing. Curve25519 DH. HKDF-SHA-256. Argon2id backups. libsodium-wrappers-sumo (WASM). Client-side only — never import crypto modules on server.

E2EE MODULE MAP (src/lib/crypto/ — client-side only):
- src/lib/crypto/types.ts — All E2EE types (RawKeyPair, IdentityKeyPair, SessionState, SenderKeyState, EncryptedPayload, DecryptedMessage, MessageType, KeyBackupBlob, DetectedConstraint).
- src/lib/crypto/primitives.ts — libsodium-wrappers-sumo wrapper. XChaCha20-Poly1305 AEAD, Ed25519 signing, Curve25519 DH, HKDF-SHA-256, Argon2id, constant-time comparison. All functions require initCrypto() first.
- src/lib/crypto/keystore.ts — IndexedDB-backed persistent key storage. Identity keys, signed pre-keys, OTKs, sessions, sender keys, device ID.
- src/lib/crypto/x3dh.ts — X3DH key agreement (initiator + responder). 4 DH operations. Returns shared secret + ephemeral key.
- src/lib/crypto/double-ratchet.ts — Double Ratchet with bounded skipped-key dictionary (max 1000). Per-message forward secrecy. Serialize/deserialize for IndexedDB persistence.
- src/lib/crypto/sender-keys.ts — Sender Key generation, encrypt/decrypt with chain advancement, Ed25519 message signing. Serialize/deserialize for persistence.
- src/lib/crypto/key-manager.ts — registerKeys() (full key registration), fetchPeerKeyBundle() (via RPC), replenishOTKsIfNeeded(), createKeyBackup/restoreKeyBackup (Argon2id + AES).
- src/lib/crypto/encryption-service.ts — encryptForSanctuary() (Double Ratchet), encryptForSpace() (Sender Keys), decryptMessage(), resolveMessageContent() (anti-injection message type guard).
- src/lib/constraints.ts — On-device constraint detection (dietary, budget, accessibility, alcohol). Conservative allowlists. Sender's device only.
- src/hooks/useE2EE.ts — React lifecycle hook. Dynamic imports (SSR-safe). Graceful degradation if migration 014 not applied. Exposes ready, available, deviceId, encrypt(), decrypt().
- src/app/api/message/route.ts — Unified E2EE message endpoint. Atomic: insert message + ciphertext + optional @xark trigger. Rate limited (10/min per user).
- src/app/api/keys/bundle/route.ts — Key bundle upload (identity + signed pre-key + signature).
- src/app/api/keys/otk/route.ts — OTK batch upload (100 per batch).
- src/app/api/keys/fetch/route.ts — Atomic key bundle fetch via fetch_key_bundle RPC (FOR UPDATE SKIP LOCKED).
- supabase/migrations/014_e2ee.sql — Tables (key_bundles, one_time_pre_keys, message_ciphertexts, user_constraints, space_constraints, constraint_prompts), RPCs (fetch_key_bundle, revoke_device, purge_expired_xark_messages), RLS, indexes, Realtime publication.
- SECURITY.md — Complete E2EE architecture, law enforcement response, competitive analysis, privacy policy, audit readiness.

KEY MODULE MAP (read the source for implementation details):
- src/lib/messages.ts — Supabase Postgres chat persistence + Realtime sync. Paginated: fetchMessages(spaceId, { limit?, before? }) — default 50, DESC order reversed client-side. MessageType field (e2ee/e2ee_xark/xark/system/legacy). fetchCiphertexts(messageId). Graceful fallback when unreachable.
- src/lib/ai-grounding.ts — buildGroundingContext(), checkSuggestionConflicts(), generateGroundingPrompt(). State map approach.
- src/lib/awareness.ts — Priority-sorted cross-space events. Time decay. AwarenessKind weights: needs_vote(0.95), ignited(0.90), proposal(0.75), assigned(0.70), message(0.50), locked(0.40), joined(0.30). Parallelized queries (items + logistics via Promise.all). fetchPersonalChats() uses get_latest_messages_per_space RPC (single query replaces unbounded fetch).
- src/lib/space-data.ts — SpaceListItem, fetchSpaceList(), recencyLabel(), recencyOpacity(), decisionStateLabel(), DEMO_SPACES. Batched queries: 4 queries total (members, users, items, messages via get_latest_messages_per_space RPC) instead of 60+ N+1 pattern. Assembled from in-memory Maps.
- src/lib/spaces.ts — createSpace() + getOptimisticSpaceId() for instant navigation (Manifestation Loop).
- src/lib/ledger.ts — Settlement math. fetchSettlement(). memberCount from space_members (true group size). venmo/upi deep links.
- src/lib/space-state.ts — computeSpaceState(items[], tripDates?, expiresAt?) → empty/exploring/converging/ready/active/settled. Pure function. expiresAt enables auto-settle for micro-space templates.
- src/lib/space-templates.ts — 6 micro-space templates (dinner_tonight, weekend_plan, trip, buy_together, watch_listen, open) with categories and lifetimes.
- src/lib/og-extract.ts — Server-side OG metadata extraction (parseOGTags, fetchOGMetadata). Used by /api/og for share pipeline.
- src/hooks/useKeyboard.ts — Virtual keyboard height detection via visualViewport API. Used by ChatInput for keyboard-aware positioning.
- src/components/os/GalaxyLayout.tsx — Layout registry for Galaxy page. 2 layouts: stream (default, vertical) + split (side-by-side: chats left, awareness right). Components are independent ReactNode slots.
- src/components/os/AwarenessStream.tsx — Extracted from Galaxy page. Independent data fetching, realtime subscriptions, space creation flow.
- src/components/os/PeopleDock.tsx — People dock component. Personal chats list with contact picker. Independent data fetching.
- src/components/os/SpacePicker.tsx — Space selection for share flow. Shows recent spaces sorted by activity.
- src/lib/intelligence/ — orchestrator.ts (Gemini 2.5 Flash, three-tier routing: gemini-local for casual queries via geminiLocalSearch(), gemini-search for knowledge queries via geminiSearchGrounded(), apify for booking via runActor(). Intent prompt: 8 tools across FAST + SLOW tiers. buildStaticPrompt()/buildDynamicPrompt() split for context caching readiness. Flash model guard.), tool-registry.ts (tier field: apify + gemini-search. 8 tools: hotel, flight, activity, restaurant, general, local_restaurant, local_activity, local_general), apify-client.ts, sanitize.ts (PII redaction with Luhn validation before Gemini calls).
- src/lib/local-agent.ts — Tier 1 fast-path router. tryLocalAgent() intercepts @xark admin commands (<1ms, zero AI). Commands: date management (set/change dates to month day-day), space rename, state queries (status, who hasn't voted). Returns LocalResult with ledgerEntry/uiAction/whisper. First gate in sendMessage(), runs even while isThinking. Falls through to Tier 2/3 on no match. PARKED — needs browser debugging.
- src/lib/local-recall.ts — Tier 2 recall detection. isRecallQuestion() with tuned regex patterns (avoids false-positive vs Tier 3 searches). getRecallWhisper() returns tier-aware coaching copy.
- src/workers/memory-worker.ts — Tier 2 Web Worker. MiniSearch lexical search. 1000-message cap, FIFO eviction, 3s debounced persistence, timestamp-based delta sync watermark, 2000-char truncation. Communicates via postMessage.
- src/hooks/useLocalMemory.ts — React hook for Tier 2 Worker bridge. IndexedDB blob persistence (xark-memory store). SSR-safe. Exposes search(), indexMessage(), deleteBlob().
- src/app/api/local-action/route.ts — Tier 1 mutation endpoint. JWT + membership check, supabaseAdmin writes. Atomic: mutation + space_ledger entry. Actions: update_dates (upserts spaces.metadata + space_dates), rename_space, revert. Revert uses revert_target_id for undo linkage.
- src/components/os/LedgerPill.tsx — Interactive system pill for space_ledger events. Icon + actor + verb + [tappable payload] + undo. Interleaved chronologically in XarkChat timeline.
- src/components/os/ContextCard.tsx — Actionable context card for Tier 2 recall results. Jump to Message (scroll + cyan pulse) + Quote to Group (loads into composer as reply). Slides up above ChatInput.
- supabase/migrations/017_hybrid_brain.sql — space_ledger table (Layer 3, unencrypted admin audit trail). RLS via auth_user_space_ids(). Realtime publication for live pill rendering.
- src/lib/media.ts — Firebase Storage upload/download + Supabase metadata.
- src/lib/notifications.ts — Server-side FCM push. Lazy init from FIREBASE_SERVICE_ACCOUNT_JSON. /api/notify uses get_push_tokens_for_space RPC (single query replaces 2-query chain).
- src/lib/seed.ts — Demo data: san diego trip (4 items, 10 msgs), ananya sanctuary (5 msgs), tokyo neon nights (2 items), summer 2026 (empty). Run: npx tsx src/lib/seed.ts
- src/hooks/useHandshake.ts — Wraps handshake protocol for React. Returns { proposal, whisper, confirm, dismiss, isCommitting, goldBurst }.
- src/hooks/useVoiceInput.ts — On-device SpeechRecognition. Long-press auto-prefixes "@xark ".
- src/components/os/ClaimSheet.tsx — Slide-up for claiming locked items. "i'll handle this" stamps owner.
- src/components/os/PurchaseSheet.tsx — Slide-up for purchase confirmation + amount entry. claimed → purchased.
- src/components/os/UserMenu.tsx — Settings sheet: 4-view drill-down (main → profile, main → notifications, main → about). Props: userName, userId. Main: profile card (avatar + name + phone), inline theme toggles (flat/vibe + light/dark), menu rows (notifications, invite, about), log out. Profile: avatar (48px) + change photo (storageAdapter) + name input + phone display. Notifications: master toggle (FCM token registration via getMessagingInstance), per-space mute list (users.preferences.muted_spaces). About: version + feedback link. Theme sync: localStorage primary, Supabase fallback read + fresh-fetch-before-write on toggle.
- src/components/os/PossibilityHorizon.tsx — Decide view: Netflix-style fluid horizontal card rails with Framer Motion entrance choreography (whileInView, staggered). DecisionCard component (3 sizes: hero 200×280, standard 165×240, mini 110×150). Unsplash hero image at top with fade-in. Category vitals in rail headers. Shimmer placeholders during load. Smooth momentum scroll (no snap). Self-resolving: locked categories collapse to green dot. No input — shared ChatInput from Space page. Items capped at 100 (ordered by weighted_score DESC). CategoryRail wrapped with React.memo + custom comparator. Groups by metadata.search_label when present (search results get own rail), else by category. Card images lazy-loaded after first 3 per rail.
- src/components/os/DecisionCard.tsx — Shared decision card component. 3 size variants (hero/standard/mini). No borders. Photo via native img element with lazyImage prop (loading="lazy" for off-screen cards), single scrim gradient, solid dark data zone. Consensus % is brightest element. Fixed light text colors (theme-independent card surfaces). Framer Motion whileInView entrance + consensus bar animation.
- src/lib/unsplash.ts — Unsplash API client. fetchDestinationPhoto(query) returns imageUrl + photographer attribution. Called at space creation, stored in spaces.metadata.hero_url.
- src/hooks/useDeviceTier.ts — Detects low-end devices (deviceMemory ≤ 2, hardwareConcurrency ≤ 4, prefers-reduced-motion). Returns "high" or "low".
- src/components/os/Avatar.tsx — Reusable avatar component for space/user avatars.
- src/components/os/OnboardingWhispers.tsx — Gentle onboarding hints that dismiss after first interaction.
- src/components/os/XarkChat.tsx — Display-only chat stream. Receives messages and isThinking as props from Space page. No input, no send, no fetch. Handshake protocol, sanctuary bridge (limit: 30 msgs), greeting. No layout prop on message motion.divs (eliminates layout thrashing).
- src/components/os/ChatInput.tsx — Three-element layout. TEXTAREA + MIC: fixed at 56px from bottom, auto-expanding textarea (text.body) + mic icon (SVG, 14px) in the input row. Top ambient line + bottom ambient line (grows with text width, breathes, fades from cyan to transparent), solid void bg. ATTACH ICON: 16px paperclip SVG at left 25% (halfway dot-to-left-edge), caretBottom level. CAMERA ICON: 16px camera SVG at left 75% (halfway dot-to-right-edge), caretBottom level. Icons at colors.white opacity 0.5→0.8 hover, thin 1.5px stroke. Mic: tap=dictate, long-press=@xark mode. Reduced void (56px).
- src/components/os/ItineraryView.tsx — Committed items timeline view for ready/active spaces.
- src/components/os/MemoriesView.tsx — Photo stream view, default for settled spaces.
- next.config.ts — serverExternalPackages: ["apify-client"] to fix dynamic require bundling issue.
- supabase/migrations/012_perf_optimizations.sql — RPCs (get_latest_messages_per_space, get_push_tokens_for_space), indexes (reactions user_id, messages space+created_at DESC), Realtime publication (messages, decision_items, space_members).

KNOWN BUGS (from architecture audit, addressed in implementation plan):
- B1: ai-grounding.ts buildGroundingContext() — agreement_score column may not exist in all environments.
- B2: ai-grounding.ts generateGroundingPrompt() — doesn't include reaction details per item.
- B3: ledger.ts fetchSettlement() — uses entries.length for memberCount instead of space_members.
- B4: spaces.ts createSpace() — doesn't add creator as space member.

2. THE ENGINE-TO-PIXEL MAP
Amber (#F5A623): Seeking/Anticipation. Wash intensity maps to weightedScore.
Gold (#FFD700): Social Gold. Radial bloom triggers at agreementScore > 80%.
Green (#10B981): Finality. Settle to Cloud Dancer (#F0EEE9) upon isLocked.
Cyan (#40E0FF): @xark Intelligence. 4.5s Ambient Breath only.

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
