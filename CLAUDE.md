XARK OS v2.0 — PRIME DIRECTIVE
Role: Staff Architect & Systemic Guardrail.
Mission: Build a biocompatible Group Operating System. This is a Human Companion, not a dashboard.

BOOTSTRAP (execute before any code work):
1. Read .xark-state.json — current phase + foveal focus tells you what to build.
2. Read CONSTITUTION.md — full visual and architectural law.
3. Read GROUNDING_PROTOCOL.md — @xark AI behavior and grounding constraints.
4. Read docs/superpowers/specs/2026-03-13-xark-architecture-blueprint.md — the approved architecture blueprint (9 services, event-driven, loosely coupled).
The foveal_focus field in .xark-state.json is your mission briefing. Execute it.

ARCHITECTURE BLUEPRINT (approved 2026-03-13):
Full spec: docs/superpowers/specs/2026-03-13-xark-architecture-blueprint.md
9 loosely coupled services: Auth, Space, Intelligence, Decision Engine (includes Commitment), Messaging, Media, Notification, Settlement, Itinerary.
Event bus: Supabase Realtime (Postgres NOTIFY/LISTEN → WebSocket). Channel: space:{spaceId}.
Scope: Solo (1 user) + Small Group (2-15 members). Large group deferred.
Emergent space state: computed from items via computeSpaceState(items[]), not stored.
Two-step commitment: consensus lock (automated at 80%, no owner) → claim + purchase (manual, owner + proof + amount).
Intelligence: @xark is deaf until invoked. Gemini = brain, Apify actors = hands (hotel/flight/activity search). Tool registry pattern.
Voice: tap mic = on-device SpeechRecognition, long-press = Gemini multimodal.
Privacy: @xark context = grounding state map + last 15 messages on invocation ONLY. No passive listening. Ever.
PWA: manifest.json in public/, standalone display, safe-area padding, service worker for FCM.

1. THE ARCHITECTURAL LOCKS (NON-NEGOTIABLE)
NO-BOLD MANDATE: Hierarchy is achieved through Scale, Spacing, and Opacity alone. Use font-weight: 400 for primary text. Use font-weight: 300 for secondary/metadata. FORBIDDEN: 500, 600, 700, 800, 900. Bold is banned. If you need emphasis, use SIZE or OPACITY — never weight.

THEME SYSTEM (1 Theme): Xark OS ships with hearth (light, default). Single theme. All colors are CSS variables set by ThemeProvider. No hardcoded hex colors in components.
- Text color: `var(--xark-white)` via `colors.white`. Dark ink (#141414) on warm paper.
- Background: `var(--xark-void)` via `colors.void`. Warm off-white (#F0EEE9).
- Accent: `var(--xark-accent)` via `colors.cyan`. Hearth = #FF6B35 (Action Orange).
- Engine signals (amber, gold, green, orange, gray) are all CSS variables.
- `textColor(alpha)` from theme.ts returns `rgba(var(--xark-white-rgb), alpha)` — the APPROVED method for applying opacity to text. This is NOT an rgba violation; it reads from CSS variables and is theme-aware.
- `accentColor(alpha)` works the same way for accent color with opacity.
- Hierarchy is always expressed through opacity, never font-weight. Use `textColor(0.9)` for primary, `textColor(0.4)` for tertiary, etc.

FONT SYSTEM: Inter (variable) for body text — primary font, set globally in globals.css. Syne (variable) for display/fallback. Inter (variable, weight 300) for the wordmark. No other fonts.

ZERO-BOX DOCTRINE: No border, no bg-white, no rounded-lg containers for feed items. Information must float in Atmospheric Space. Separation = Vertical Distance. Focus outlines are globally purged (*:focus { outline: none } in globals.css) — browser focus rings are borders and violate Zero-Box. No backdrop-filter blur anywhere. Overlays use #000 at opacity 0.8. No chat bubbles, no message containers, no cards, no rounded corners on feed items.

PORT DISCIPLINE: Run ONLY on Port 3000. If occupied, kill the process. Never jump to 3001.

IDENTITY & INFRASTRUCTURE LOCK (HYBRID STACK):
The Xark OS infrastructure is a locked hybrid of Firebase and Supabase. Do not deviate.
- Phone OTP: Firebase Auth. Do not scaffold Supabase Auth, @supabase/auth, or any supabase/auth import.
- Decision Engine: Supabase Postgres. All heart-sort ranking math runs in SQL here.
- Multimedia (E2EE): Firebase Storage. Binary blob delivery with bucket-level security rules.
- Push Alerts: Firebase Cloud Messaging (FCM). Native iOS/Android push.
- Intelligence: Gemini 2.5 Flash (gemini-2.5-flash). Powers @xark deep research and agentic planning.
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
- SILENT BY DEFAULT: Never responds unless message contains "@xark". One exception: handshake whisper at >80% consensus.
- STATE MAP APPROACH: @xark receives full state map (Locked/Voting/Proposed/Empty). Reasons about scope, not rigid category bans.
- SOCIAL REASONING: Use names when advocating FOR someone. Use counts for opposition. Never assume why someone voted.
- getGreeting(): Deterministic, no AI call. See ai-grounding.ts for logic.
- /api/xark: Check for "@xark" prefix before calling Gemini. If absent, return { response: null }. Fetches space title for location context. Persists @xark response messages server-side via supabaseAdmin (returns messageId to client for deduplication).

SUPABASE POSTGRES CLIENT (src/lib/supabase.ts):
DB queries ONLY. Import @supabase/supabase-js (NOT @supabase/auth). Do not add auth configuration.
- PROXY PATTERN: Exports Proxy that delegates to authenticated client (with JWT) or default anon client. setSupabaseToken(token) switches clients for RLS enforcement.
- Placeholder fallback: When env vars missing, renders locally with demo data fallbacks.

SUPABASE ADMIN CLIENT (src/lib/supabase-admin.ts):
Server-side client with SUPABASE_SERVICE_ROLE_KEY. Bypasses RLS. Used by /api/xark, /api/notify, /api/dev-auto-login. Null-check before use.

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
Returns { user: XarkUser|null, isAuthenticated, isLoading }. Auth chain: Firebase → dev-auto-login (JWT for RLS) → name-only fallback. Firebase-only. No Supabase Auth.

KEY MODULE MAP (read the source for implementation details):
- src/lib/messages.ts — Supabase Postgres chat persistence + Realtime sync. Graceful fallback when unreachable.
- src/lib/ai-grounding.ts — buildGroundingContext(), checkSuggestionConflicts(), generateGroundingPrompt(). State map approach.
- src/lib/awareness.ts — Priority-sorted cross-space events. Time decay. AwarenessKind weights: needs_vote(0.95), ignited(0.90), proposal(0.75), assigned(0.70), message(0.50), locked(0.40), joined(0.30).
- src/lib/space-data.ts — SpaceListItem, fetchSpaceList(), recencyLabel(), recencyOpacity(), decisionStateLabel(), DEMO_SPACES.
- src/lib/spaces.ts — createSpace() + getOptimisticSpaceId() for instant navigation (Manifestation Loop).
- src/lib/ledger.ts — Settlement math. fetchSettlement(). memberCount from space_members (true group size). venmo/upi deep links.
- src/lib/space-state.ts — computeSpaceState(items[]) → empty/exploring/converging/ready/active/settled. Pure function.
- src/lib/intelligence/ — orchestrator.ts (Gemini 2.5 Flash), tool-registry.ts (Apify tools: voyager/booking-scraper, etc.), apify-client.ts.
- src/lib/media.ts — Firebase Storage upload/download + Supabase metadata.
- src/lib/notifications.ts — Server-side FCM push. Lazy init from FIREBASE_SERVICE_ACCOUNT_JSON.
- src/lib/seed.ts — Demo data: san diego trip (4 items, 10 msgs), ananya sanctuary (5 msgs), tokyo neon nights (2 items), summer 2026 (empty). Run: npx tsx src/lib/seed.ts
- src/hooks/useHandshake.ts — Wraps handshake protocol for React. Returns { proposal, whisper, confirm, dismiss, isCommitting, goldBurst }.
- src/hooks/useVoiceInput.ts — On-device SpeechRecognition. Long-press auto-prefixes "@xark ".
- src/components/os/ClaimSheet.tsx — Slide-up for claiming locked items. "i'll handle this" stamps owner.
- src/components/os/PurchaseSheet.tsx — Slide-up for purchase confirmation + amount entry. claimed → purchased.
- src/components/os/UserMenu.tsx — Settings sheet: three-view drill-down (main → profile, main → system). Profile: avatar preview (48px) + "change photo" (Firebase Storage profiles/{userId}/avatar) + name input (Supabase users.display_name). System: hearth theme (single theme). Navigation: floating text links, horizontal slide animation (AnimatePresence, 0.2s tween). Actions: floating text only, no buttons/boxes.
- src/components/os/PossibilityHorizon.tsx — Decide view: Netflix-style fluid horizontal card rails with Framer Motion entrance choreography (whileInView, staggered). DecisionCard component (3 sizes: hero 200×280, standard 165×240, mini 110×150). Unsplash hero image at top with fade-in. Category vitals in rail headers. Shimmer placeholders during load. Smooth momentum scroll (no snap). Self-resolving: locked categories collapse to green dot. No input — shared ChatInput from Space page.
- src/components/os/DecisionCard.tsx — Shared decision card component. 3 size variants (hero/standard/mini). No borders. Photo top 40%, single scrim gradient, solid dark data zone. Consensus % is brightest element. Fixed light text colors (theme-independent card surfaces). Framer Motion whileInView entrance + consensus bar animation.
- src/lib/unsplash.ts — Unsplash API client. fetchDestinationPhoto(query) returns imageUrl + photographer attribution. Called at space creation, stored in spaces.metadata.hero_url.
- src/hooks/useDeviceTier.ts — Detects low-end devices (deviceMemory ≤ 2, hardwareConcurrency ≤ 4, prefers-reduced-motion). Returns "high" or "low".
- src/components/os/Avatar.tsx — Reusable avatar component for space/user avatars.
- src/components/os/OnboardingWhispers.tsx — Gentle onboarding hints that dismiss after first interaction.
- src/components/os/XarkChat.tsx — Display-only chat stream. Receives messages and isThinking as props from Space page. No input, no send, no fetch. Handshake protocol, sanctuary bridge, greeting.
- src/components/os/ChatInput.tsx — Three-element layout. TEXTAREA + MIC: fixed at 56px from bottom, auto-expanding textarea (text.body) + mic icon (SVG, 14px) in the input row. Top ambient line + bottom ambient line (grows with text width, breathes, fades from cyan to transparent), solid void bg. ATTACH ICON: 16px paperclip SVG at left 25% (halfway dot-to-left-edge), caretBottom level. CAMERA ICON: 16px camera SVG at left 75% (halfway dot-to-right-edge), caretBottom level. Icons at colors.white opacity 0.5→0.8 hover, thin 1.5px stroke. Mic: tap=dictate, long-press=@xark mode. Reduced void (56px).
- src/components/os/ItineraryView.tsx — Committed items timeline view for ready/active spaces.
- src/components/os/MemoriesView.tsx — Photo stream view, default for settled spaces.
- next.config.ts — serverExternalPackages: ["apify-client"] to fix dynamic require bundling issue.

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
