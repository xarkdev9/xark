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

THEME SYSTEM (3 Themes): Xark OS ships with three themes — hearth (light, default), signal (dark), ember (warm dark). All colors are CSS variables set by ThemeProvider. No hardcoded hex colors in components.
- Text color: `var(--xark-white)` via `colors.white`. In hearth mode this is #141414 (ink), in signal mode #B2EBF2 (cyan-white), in ember mode #FFF4EC (warm cream).
- Background: `var(--xark-void)` via `colors.void`. In hearth mode #F0EEE9 (warm paper), in signal/ember dark canvases.
- Accent: `var(--xark-accent)` via `colors.cyan`. Hearth = #FF6B35 (warm orange), Signal = #40E0FF (cyan), Ember = #FF8C42.
- Engine signals (amber, gold, green, orange, gray) are all CSS variables — adjusted per theme for contrast.
- `textColor(alpha)` from theme.ts returns `rgba(var(--xark-white-rgb), alpha)` — the APPROVED method for applying opacity to text. This is NOT an rgba violation; it reads from CSS variables and is theme-aware.
- `accentColor(alpha)` works the same way for accent color with opacity.
- Hierarchy is always expressed through opacity, never font-weight. Use `textColor(0.9)` for primary, `textColor(0.4)` for tertiary, etc.

FONT SYSTEM: Inter (variable) for body text — primary font, set globally in globals.css. Syne (variable) for display/fallback. Inter (variable, weight 300) for the wordmark. No other fonts.

ZERO-BOX DOCTRINE: No border, no bg-white, no rounded-lg containers for feed items. Information must float in Atmospheric Space. Separation = Vertical Distance. Focus outlines are globally purged (*:focus { outline: none } in globals.css) — browser focus rings are borders and violate Zero-Box.

PORT DISCIPLINE: Run ONLY on Port 3000. If occupied, kill the process. Never jump to 3001.

IDENTITY & INFRASTRUCTURE LOCK (HYBRID STACK):
The Xark OS infrastructure is a locked hybrid of Firebase and Supabase. Do not deviate.
- Phone OTP: Firebase Auth. Do not scaffold Supabase Auth, @supabase/auth, or any supabase/auth import.
- Decision Engine: Supabase Postgres. All heart-sort ranking math runs in SQL here.
- Multimedia (E2EE): Firebase Storage. Binary blob delivery with bucket-level security rules.
- Push Alerts: Firebase Cloud Messaging (FCM). Native iOS/Android push.
- Intelligence: Gemini 2.0 Flash (gemini-2.0-flash). Powers @xark deep research and agentic planning.
FORBIDDEN: Any use of Supabase Auth (supabase/auth, @supabase/auth, createClient.*auth for Supabase). Auth is Firebase-only.

ALGORITHM REFERENCE: Full technical decision record at /Users/ramchitturi/algo/mar10_algo.md (198 tests, 0 type errors, hexagonal architecture).

SIGNAL SYSTEM (Reaction Vocabulary):
- "Love it" (LoveIt): weight +5. Color: Amber (#F5A623).
- "Works for me" (WorksForMe): weight +1. Color: Neutral Gray (#8888a0).
- "Not for me" (NotForMe): weight -3. Color: Action Orange (#e8590c).
- One NotForMe cancels exactly three WorksForMe (-3 + 1 + 1 + 1 = 0).
- Two LoveIt overcome one NotForMe (5 + 5 - 3 = 7).
- Passionate minority wins: 3 LoveIt (15) beats 4 WorksForMe (4).
- One reaction per user per item. Last reaction wins (deduplication).
- Score can go negative. Negative-score items sink to bottom.

GLOBAL TYPE SCALE (src/lib/theme.ts — text object):
Single source of truth for all typography. Every component spreads these into style={{}}. No Tailwind text-size classes.
- text.hero: 1.5rem, weight 400, lineHeight 1.6, letterSpacing -0.01em. Used by Galaxy hero.
- text.spaceTitle: clamp(1.25rem, 3vw, 1.5rem), weight 400. Used by Space View header.
- text.listTitle: 1rem, weight 400. Used by ControlCaret space names, awareness event text.
- text.body: 0.75rem, weight 400, lineHeight 1.5, letterSpacing 0.01em. Used by XarkChat messages, awareness whispers.
- text.subtitle: 0.65rem, weight 300, letterSpacing 0.02em. Used by member names, decision state subtitles.
- text.label: 0.6rem, weight 300, uppercase, letterSpacing 0.2em. Used by role labels, view toggles.
- text.recency: 0.5rem, weight 300, letterSpacing 0.15em. Used by timestamps, space context.
- text.timestamp: 0.45rem, weight 300. Used by inline message timestamps.
- text.input: clamp(0.9rem, 2vw, 1.05rem), weight 400, letterSpacing 0.04em. Used by all input fields.
- text.hint: 0.6rem, weight 300, letterSpacing 0.15em. Used by floating action hints, thinking/locking labels.

HEART-SORT ENGINE (src/lib/heart-sort.ts):
This is the SSOT for all decision ranking. Every UI component must reflect its logic.
Source of truth algo: /Users/ramchitturi/algo (engine/heart-sort.ts, 198 tests).
KNOWN GAP: The app's heart-sort.ts currently has a simplified Possibility type and 2 functions (heartSort, getConsensusState). The full algo (DecisionItem, calculateWeightedScore, addReaction, removeReaction, calculateAgreementScore, getRankedSummary) lives only in /Users/ramchitturi/algo. Phase 4 of todo_mar12.md addresses porting the full engine.
- APP VERSION: Possibility interface { id, title, imageUrl, weightedScore, agreementScore, isLocked, createdAt }. heartSort() sorts descending by weightedScore, locked items sink to end. getConsensusState() maps agreementScore to "seeking"/"steady"/"ignited".
- FULL ALGO (in /algo, not yet ported): DecisionItem, BookableItem, calculateWeightedScore, calculateAgreementScore (ALL reactors / totalMembers, isGroupFavorite strictly > 80%), getRankedSummary, addReaction, removeReaction. Pure functions, no mutation.

STATE MACHINE (4 Preset Flows):
- BOOKING_FLOW (default, EXTENDED): proposed -> [reaction] -> ranked -> [consensus] -> locked -> [claim] -> claimed -> [purchase] -> purchased.
  - locked = consensus reached, no owner ("waiting for someone to own it"). is_locked = true.
  - claimed = someone stepped up, owner stamped. is_locked remains true.
  - purchased = proof + amount submitted. Terminal state. Feeds settlement.
- PURCHASE_FLOW: researching -> [reaction] -> shortlisted -> [manual] -> negotiating -> [commitment] -> purchased.
- SIMPLE_VOTE_FLOW: nominated -> [reaction] -> ranked -> [commitment] -> chosen.
- SOLO_DECISION_FLOW: considering -> [reaction] -> leaning -> [commitment] -> decided.
- All flows allow skipping to terminal state via direct [commitment] from initial state.
- Triggers: "reaction" (automated), "commitment" (intentional with proof), "manual" (explicit).
- DecisionItemState is an open string (not enum) for custom flows.
- SHARED MODULE: FLOW_TERMINAL_STATES and resolveTerminalState(state, flow?) must live in src/lib/state-flows.ts (eliminates duplication between handshake.ts and claims.ts). The "ranked" state is intentionally omitted from the flat map because it appears in both BOOKING_FLOW (→ locked) and SIMPLE_VOTE_FLOW (→ chosen). resolveTerminalState() accepts an optional flow parameter to disambiguate.

SOLO SPACE BEHAVIOR:
Solo spaces (1 member): no consensus threshold. React = decide. "Ready to lock?" appears after any reaction. No handshake needed — user locks directly via claims flow.

GREEN-LOCK COMMITMENT PROTOCOL:
- Lock = real-world commitment confirmation, not a vote. Proof required (confirmation_number, screenshot, receipt, contract, verbal).
- commitItem(): State-machine-aware. Uses flow to determine locked state name.
- lockItem(): Legacy, hardcoded to "locked" state. Deprecated but works.
- Cannot lock already-locked item (GreenLockError). Cannot lock with empty proof.
- On lock: committer stamped as owner { ownerId, assignedAt, reason: "booker" }.
- transferOwnership(): reason: "transfer". Cannot self-transfer. Cannot transfer non-locked item.
- ownershipHistory: append-only audit trail.
- Both commitmentProof and bookingProof set to same object (backwards compat).

AI GROUNDING (@xark Constraint System):
- When @xark generates suggestions, it MUST respect locked decisions and current consensus state.
- GroundingConstraint types: "locked_decision" (committed items), "assigned_task" (claimed tasks).
- STATE MAP APPROACH: Instead of "forbidden categories," @xark receives a full state map of all items grouped by state: Locked (committed, do not reopen), Voting (reactions in progress), Proposed (new, no reactions yet), Empty (categories with no items). @xark reasons about scope — e.g., "hotel" locked doesn't ban "Airbnb for a different city" if it's a different need.
- checkSuggestionConflicts(): Pre-call guard. Returns locked decisions in same category before generating suggestions. Server-side check before Gemini call.
- getGreeting(context, spaceTitle?): Deterministic greeting, no AI call. Logic A: agreementScore > 0.8 (ignited, unlocked) → "morning. the group is leaning toward [title]. should we lock it?" Logic B: recently locked item → "[ownerName] just locked in [title]. we're all set." Logic C: fallback → "ready to plan [space title]? tell me what's on your mind."
- No locked decisions = "You may suggest any options freely."

@XARK BEHAVIOR RULES:
- SILENT BY DEFAULT: @xark never responds unless the message contains "@xark" (explicit invocation).
- NEVER: reacts to messages ("nice idea!", "sounds fun"), summarizes conversation unprompted, inserts itself into banter, sends proactive suggestions, adds emoji or personality.
- ONE EXCEPTION: Handshake whisper at >80% consensus (automated, no user invocation needed).
- PASSIVE INFO DISPLAY (no interruption): Decision state subtitles on first screen, grounding constraints when asked.
- /api/xark endpoint: Check for "@xark" prefix before calling Gemini. If absent, return { response: null } (silent mode).

@XARK SOCIAL REASONING:
- @xark receives reaction details (with user names) in grounding context for reasoning.
- USE NAMES when advocating FOR someone: "nina and raj aren't feeling italian — want to explore other options?"
- USE COUNTS when describing opposition: "3 people voted not for me" (not "nina, raj, kate don't like it").
- NEVER assume WHY someone voted a certain way. NEVER suggest alternatives on behalf of someone's preference.
- Reports state, asks the question, lets humans fill the gap.
- The test: would the named person feel INCLUDED or EXPOSED?

TASK ASSIGNMENT SYSTEM:
- Tasks are non-decidable items. No consensus needed. Created -> Assigned.
- createTask(), assignTask(), reassignTask(), unassignTask(). No proof required.
- Self-reassignment throws TaskAssignmentError. IDs use crypto.randomUUID().

HEXAGONAL ARCHITECTURE (Ports & Adapters):
Algo source: /Users/ramchitturi/algo. All ports are interfaces. Reference adapters are zero-dependency, in-memory.
- PersistencePort: Async CRUD. Version checking on save (VersionConflictError). Build: PostgresAdapter for Supabase.
- EventBusPort: Channel-based pub/sub ("space:{spaceId}"). Build: Redis/WebSocket adapter.
- AuthPort: Authenticate + Authorize. 10 action types. Build: FirebaseAuthAdapter (OTP locked).
- CachePort: Optional. deleteByPrefix() for bulk invalidation. TTL default 60s. Key: "ranked:{spaceId}".
- MessagingPort: Format (outgoing) + Parse (incoming). richContent for platform payloads.
- DecisionService: Stateless orchestrator. Load -> Compute (pure functions) -> Save -> Broadcast. Horizontally scalable.
- ConsensusEngine: In-memory orchestrator for testing/embedded use. Both coexist, neither deprecated.
- RequestHandler: Framework-agnostic HTTP. ServiceRequest { method, path, body, token } -> ServiceResponse { status, body }.
- Optimistic concurrency: version field incremented on every mutation. Stale writes rejected (HTTP 409).

SUPABASE POSTGRES CLIENT (src/lib/supabase.ts):
DB queries ONLY. This client connects to Supabase Postgres for decision engine operations.
- Import: @supabase/supabase-js (NOT @supabase/auth).
- Env vars: NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY.
- Placeholder fallback: When env vars are missing, uses placeholder URL so the app renders locally without crashing. Queries will fail silently — components use demo data fallbacks.
- No auth features. No session persistence. Authentication is Firebase Auth exclusively.
- Used by: ai-grounding.ts (fetch locked items + tasks), messages.ts (chat persistence + Realtime), future decision engine queries.
Do not add auth configuration to this client. Do not import supabase/auth.

FIREBASE CLIENT (src/lib/firebase.ts):
Phone OTP authentication + E2EE multimedia storage. Database is Supabase Postgres (see supabase.ts).
- Safe initialization: When NEXT_PUBLIC_FIREBASE_API_KEY is missing/empty, Firebase is NOT initialized. auth and storage export null.
- Singleton app initialization (getApps() check) when API key is present.
- Exports: auth (Auth | null — phone OTP only), storage (FirebaseStorage | null — E2EE binary blobs).
- Env vars: NEXT_PUBLIC_FIREBASE_API_KEY, NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN, NEXT_PUBLIC_FIREBASE_PROJECT_ID, NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET, NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID, NEXT_PUBLIC_FIREBASE_APP_ID.
- Consumers MUST null-check auth/storage before use. useAuth hook handles this gracefully.
Do not use Firebase for database operations. Do not use Firestore. Database = Supabase Postgres.

AUTH HOOK (src/hooks/useAuth.ts):
React hook wrapping Firebase onAuthStateChanged with fallback to URL name param.
- useAuth(fallbackName?): Returns { user: XarkUser | null, isAuthenticated, isLoading }.
- XarkUser: { uid, displayName }. Firebase user gets real uid. Fallback gets "name_[name]" uid.
- When Firebase is unconfigured (no env vars), onAuthStateChanged fires with null → fallback kicks in.
- Used by XarkChat to resolve user identity for message attribution and handshake confirmation.
- Firebase-only. No Supabase Auth. No session tokens from Supabase.

MESSAGE PERSISTENCE (src/lib/messages.ts):
Supabase Postgres chat message storage + Realtime sync.
- Table: messages (id text PK, space_id text, role text, content text, user_id text nullable, sender_name text nullable, created_at timestamptz).
- fetchMessages(spaceId): Returns all messages for a space ordered by created_at ascending.
- saveMessage({id, spaceId, role, content, userId}): Persists a single message. Fire-and-forget (catch silently).
- subscribeToMessages(spaceId, onMessage): Supabase Realtime subscription on INSERT to messages table. Returns RealtimeChannel.
- unsubscribeFromMessages(channel): Cleanup.
- Graceful fallback: When Supabase is unreachable, fetch returns [], save is silent no-op, Realtime is inert.

AI GROUNDING IMPLEMENTATION (src/lib/ai-grounding.ts):
The live implementation of Section 8 of mar10_algo.md. Prevents @xark from suggesting a "Four Seasons" if the group locked the "Hilton."
- REACTION_WEIGHTS constant: { love_it: 5, works_for_me: 1, not_for_me: -3 }. Embedded in grounding prompts.
- SpaceItem interface: { id, title, category, description, state, weightedScore, agreementScore, ownership }.
- buildGroundingContext(spaceId): Fetches locked items (ordered by locked_at desc) + assigned tasks + all items (including agreement_score) from Supabase Postgres. Builds full GroundingContext with lockedCategories, currentFavorites (top 3 unlocked), topIgnitedTitle (highest unlocked item with agreementScore > 0.8), recentlyLocked { title, ownerName }.
- checkSuggestionConflicts(currentItems, proposedCategory): Pre-call guard (Section 8 conflict check). Filters items in "Locked"/"Finalized" state. Returns { hasConflict: boolean, reason?: string, conflictingItemId?: string }. Run server-side before calling Gemini.
- checkContextConflicts(context, category): Convenience wrapper using GroundingContext. Returns GroundingConstraint[].
- generateGroundingPrompt(context): Full state map for @xark system prompt. Groups items by state (Locked → Voting → Proposed → Empty). Includes reaction counts per item. Appends WEIGHTING RULES (-3/+1/+5). Lets Gemini reason about scope rather than imposing rigid category bans.
- GroundingContext: { spaceId, constraints[], lockedCategories[], currentFavorites[], forbiddenCategories[] (legacy, being replaced by state map), forbiddenSuggestions[], topIgnitedTitle (string | null), recentlyLocked ({ title, ownerName } | null) }.
- Supabase tables: "decision_items" (id, title, category, description, state, weighted_score, ownership, space_id, is_locked), "tasks" (id, title, assignee_id, space_id).

HANDSHAKE HOOK (src/hooks/useHandshake.ts):
React hook that wraps the Handshake Protocol for component consumption.
- useHandshake(spaceId): Returns { proposal, whisper, confirm, dismiss, isCommitting, goldBurst }.
- proposal: Active HandshakeProposal or null. Null = silent (no consensus yet).
- whisper: Pre-generated @xark message from generateHandshakeWhisper(). Null when no proposal.
- confirm(confirmerId): Executes full Green-Lock via confirmHandshake(). On success: clears proposal, triggers goldBurst for 3s.
- dismiss(): Clears proposal. Group chose to wait.
- isCommitting: True during the lock operation.
- goldBurst: True for 3s after successful lock. Drives Social Gold visual reward.
- Subscribes to Supabase Realtime on mount. Unsubscribes on unmount. One channel per spaceId.

XARK CHAT (src/components/os/XarkChat.tsx):
@xark intelligence interface. Atmospheric conversation. No chat bubbles. No boxes. No containers.
- MeshGradientBg: Radial ellipse accent glow (opacity 0.02) behind all content. Atmospheric depth.
- Hierarchy through SCALE (text.body for all messages), never through weight. All sizes from theme.ts text tokens.
- FOVEAL OPACITY: Messages dim as they age. fovealOpacity(index, total, role) from theme.ts maps distance-from-end to opacity steps. @xark: 0.9→0.7→0.5→0.35→0.25→floor(0.2). User: 0.6→0.45→0.35→0.25→floor(0.2). Role labels cap at min(0.35, msgOpacity). Timestamps inline after message content. CSS transition: opacity 0.6s ease.
- LAYOUT ANIMATION: AnimatePresence + motion.div with layout prop. New messages enter from y:8 opacity:0. Layout shifts use ease [0.22, 1, 0.36, 1] at 0.2s. WhatsApp-dense grouping: same-sender messages stack tight (mt-0.5), different-sender gets mt-3.
- @xark responses: text.body (0.75rem), color: colors.white, foveal opacity (newest 0.9), lineHeight 1.5, letterSpacing 0.01em. Left-aligned.
- User messages: text.body (0.75rem), color: colors.white, foveal opacity (newest 0.6). Own messages right-aligned (marginLeft: auto). Other users' messages left-aligned.
- Timestamps: text.timestamp (0.45rem), inline after message content, opacity min(0.25, msgOpacity * 0.3).
- Role labels ("@xark", "you", sender names): text.label (0.6rem), uppercase, letter-spacing 0.2em, foveal-capped opacity min(0.35, msgOpacity). @xark label uses colors.cyan. Only shown on first message in a sender group.
- Thinking state: Cyan dot (colors.cyan) breathing at 4.5s cycle + "thinking" text.hint at opacity 0.4.
- GREETING: Shows when message stream is empty. Data-driven via getGreeting(groundingContext, spaceTitle) when context loads, or descriptive fallback when Supabase unreachable. Renders with text.body at opacity 0.9, with @xark cyan label.
- THUMB-ARC ACTION ZONE (Spatial Separation): Two distinct thumb zones. Input zone fixed 96px from bottom edge (layout.inputBottom). ControlCaret stays at 32px (layout.caretBottom). Prevents accidental galaxy jumps mid-thought. bg-transparent. Accent caret. Accent underline glows + breathes only on input focus. Placeholder opacity 0.12 (opacity.ghost).
- Message stream: paddingBottom 30vh to keep eye level mid-screen, away from thumb area.
- Bottom fade: Linear gradient from void to transparent. Not a box.
- Grounding-aware: Loads GroundingContext on mount. Passes grounding prompt into every /api/xark request.
- Grounding status whisper: When locked categories exist, displays "grounded: [categories] locked" at opacity 0.2.
- Handshake integration: Uses useHandshake(spaceId) hook. When proposal fires, @xark whisper is injected into message stream. Two floating text options: "confirm" (colors.gold, opacity 0.9) and "wait" (colors.white, opacity 0.4). NO boxes. NO buttons. Just text with text.label styling.
- Committing state: Gold breathing dot + "locking" text.hint at 4.5s cycle.
- Social Gold burst: On successful lock, full-screen radial gold gradient (goldBurstPulse animation, 3s ease-out). Fades from center outward.
- Post-lock confirmation: @xark whispers "locked. [title] is now committed." On dismiss: "understood. keeping this open for now."
- SENDER NAMES: Group messages include senderName field. Messages from other users show their name as role label (left-aligned). Messages from "you" show "you" (right-aligned). @xark messages unchanged.
- SANCTUARY BRIDGE: Tapping a sender name that has a SANCTUARY_MAP entry opens a slide-up sheet with the 1:1 private stream. SANCTUARY_MAP maps sender names to space IDs. Sheet: colors.void bg, slides from bottom (Framer Motion), 80vh max-height. Foveal opacity applied to sanctuary messages. Close text at top right, opacity 0.4. Dark overlay #000 at opacity 0.8. NO backdrop-filter. NO blur. 60fps safe.
- DEMO MESSAGES: DEMO_GROUP_MESSAGES and DEMO_SANCTUARY_MESSAGES provide fallback data when Supabase is unreachable. 10 group messages for san diego, 5 sanctuary messages for ananya.
- Infrastructure: References src/lib/firebase.ts (Auth), src/lib/supabase.ts (Postgres), src/lib/messages.ts (persistence), src/hooks/useAuth.ts (auth), src/hooks/useHandshake.ts (consensus).
Do not add chat bubbles, message containers, borders, or backgrounds to messages. No robot icons. No emojis. No backdrop-filter blur.

CONTROL CARET (src/components/os/ControlCaret.tsx):
The Persistent Memory — the physical anchor of the OS. Lives on EVERY screen (except /login) via GlobalCaret.tsx in layout.tsx.
- Dot: 10px diameter (layout.caretSize), colors.cyan, breathing at 4.5s (ambientBreath). Fixed 32px from bottom edge (layout.caretBottom). Stops breathing when open.
- CONTEXT-AWARE TAP: Inside a space → navigates back to Galaxy. On Galaxy/other pages → slides up vertical space list.
- Overlay: #000000 at opacity 0.8. NO backdrop-filter. NO blur. Tap overlay to close.
- Space list: Each space shows Avatar (28px, round, no border) + text.listTitle for space name + subtitle with member names and decision state. Recency timestamps aligned right via text.recency. Sorted by lastActivityAt descending.
- AVATAR: Profile photo (round, object-cover) if available. Falls back to first letter of name at opacity 0.3 on subtle bg. No border on either variant.
- MEMBER NAMES: Under group spaces, listed via text.subtitle at textColor(0.35). Sanctuaries show last message content instead.
- DECISION STATE: text.subtitle showing "2 locked · 1 needs your vote · 1 exploring" via decisionStateLabel(). Empty spaces show "empty — start dreaming."
- RECENCY: text.recency at textColor(0.25) — "now", "2h ago", "3 days", etc. via recencyLabel().
- RECENCY OPACITY: Space title opacity driven by recencyOpacity() — last hour 0.9, last day 0.7, last week 0.5, older 0.4.
- PRESENCE EMBER: 4px (layout.emberSize) colors.cyan dot breathing at 4.5s, overlaps bottom-right of avatar when presenceCount > 1. Wired to Supabase Realtime Presence. A digital soul — "someone is here."
- INITIATION SEED: "invite a person" at the bottom of the slide-up list. text.hint styling, colors.white at opacity.tertiary. A whisper, not a button. Navigates to Galaxy. Appears last with staggered delay.
- Staggered entrance animation (delay: index * timing.staggerDelay).
- Navigates to /space/[id]?name=... on tap.
- Fetches via fetchSpaceList() from space-data.ts, falls back to DEMO_SPACES + DEMO_PRESENCE.
- Data layer: src/lib/space-data.ts provides SpaceListItem type, fetchSpaceList(), recencyLabel(), recencyOpacity(), decisionStateLabel(), DEMO_SPACES.
Do not add borders, backgrounds, or containers.

CONSENSUS MARK (src/components/os/ConsensusMark.tsx):
SVG + Framer Motion indicator driven by agreementScore from heart-sort.ts.
- Seeking (0-30%): Amber dashed ring. Tween pulse (cubic-bezier 0.22,1,0.36,1, 0.6s, repeatDelay 1.4s). Slow rotation.
- Steady (31-80%): Amber ring + 4.5s breathing cyan dot.
- Ignited (80%+): Gold ring + 6 radial flare particles.
- NOTE: Do NOT use spring animations with 3+ keyframes — Framer Motion only supports 2 keyframes for spring type. Use tween instead.
Do not add borders, backgrounds, or containers to this component.

POSSIBILITY HORIZON (src/components/os/PossibilityHorizon.tsx):
Horizontal scroll stream. Airbnb-scale slider. No cards. No borders. No boxes.
- Edge-to-edge images with bottom-vignette overlays.
- Items sorted by heartSort() using weightedScore.
- Amber atmospheric wash intensity driven by weightedScore via amberWash().
- Snap-scroll (snap-x, snap-mandatory, snap-center). Hidden scrollbar.
- Pointer-based drag. No touch libraries.
Do not wrap items in cards or add rounded corners.

BLUEPRINT VIEW (src/components/os/Blueprint.tsx):
Vertical timeline of Green-Lock settled decisions + Settlement Ledger. Every item has passed the Commitment Protocol.
- Fetches locked items from Supabase Postgres (decision_items where is_locked = true), ordered by locked_at ascending.
- 1px vertical timeline line at opacity 0.1 — atmospheric anchor, NOT a border.
- Category label: 10px uppercase, tracking 0.2em, opacity 0.3.
- Title: text.listTitle (1rem), opacity 0.9. Description: text.subtitle (0.65rem), opacity 0.4.
- Metadata row: ConsensusMark in "ignited" state (The Mark of Truth), commitment proof type/value, lockedAt timestamp.
- Finality wash: radial gradient using currentColor (#F0EEE9) at opacity 0.05. No rgba white variants.
- Framer Motion staggered entrance (delay: index * 0.1).
- Empty state: "no locked decisions yet" at opacity 0.2.
- SETTLEMENT STRIP: Below the timeline. Uses fetchSettlement(spaceId) from ledger.ts. Per-user paid totals with item breakdown. Debt deltas: "[name] owes [name] $[amount]". Payment deep links as floating Cyan text: "venmo" and "upi" (venmo:// and upi:// protocols). Total committed at the bottom. 1px atmospheric divider separates timeline from settlement.
Do not add cards, borders, or containers. Items float in atmospheric space along the timeline.

CLAIMS ENGINE (src/lib/claims.ts):
Manual item claim — locks an item outside the automated handshake flow.
- claimItem(itemId, userId, proofValue?): Fetches current item + version. Guards against double-lock. Builds ClaimProof with type "receipt" (if proof provided) or "verbal" (fallback). Flow-aware terminal state resolution (mirrors handshake.ts). Commits with optimistic concurrency. Stamps owner { ownerId, assignedAt, reason: "booker" }.
- ClaimResult: { success, itemId, lockedAt, proof, error? }.
- Proof input: free-form text — "Link to confirmation or drop receipt." Owner-only in UI.

EMERGENT SPACE STATE (src/lib/space-state.ts):
computeSpaceState(items[]) returns empty/exploring/converging/ready/active/settled. Pure function, no DB calls. UI reacts to computed state. "ready" = all items settled (v1 heuristic; full category coverage check is Gemini's job).

SETTLEMENT LEDGER (src/lib/ledger.ts):
Financial settlement from locked decision items. The Subtle Settle.
- fetchSettlement(spaceId): Fetches all locked items. Parses price from metadata.price (handles "$450/nt", "$95/person", "Free"). Groups by ownership.ownerId. memberCount from space_members table (true group size, not just payers). fairShare = totalSpent / memberCount. Returns Settlement { entries, deltas, totalSpent, fairShare, memberCount }.
- LedgerEntry: { userId, displayName, totalPaid, items[] }.
- DebtDelta: { fromUser, fromName, toUser, toName, amount }. Who owes whom.
- generateVenmoLink(recipientName, amount, note): Returns venmo://paycharge deep link.
- generateUPILink(upiId, recipientName, amount, note): Returns upi://pay deep link.
- Blueprint.tsx renders settlement at bottom: "[Name] is ahead $[Amount]", debt deltas with venmo/upi floating text links in Cyan.

HANDSHAKE PROTOCOL (src/lib/handshake.ts):
The automated bridge between Consensus and Commitment. When agreementScore crosses 80% (ignited), @xark proposes a lock.
- subscribeToConsensus(spaceId, onHandshake): Subscribes to Supabase Realtime on decision_items. Fires HandshakeProposal when an unlocked item's agreement_score > 0.80 (strictly greater). Deduplicates: each item triggers only once per subscription.
- generateHandshakeWhisper(proposal): Returns "@xark whisper" message: "consensus reached on [Title]. shall i lock this in for the group?"
- confirmHandshake(itemId, confirmerId): Executes Green-Lock Commitment Protocol. Fetches current item + version. Guards against double-lock (GreenLockError). Builds CommitmentProof { type: "verbal", value: "group consensus confirmed via @xark handshake" }. Resolves terminal state via flow map (proposed->locked, nominated->chosen, researching->purchased, considering->decided). Commits with optimistic concurrency (version check). Stamps owner { ownerId, assignedAt, reason: "booker" }.
- unsubscribeFromConsensus(channel): Removes Supabase Realtime channel.
- HandshakeProposal: { itemId, title, category, agreementScore, spaceId, timestamp }.
- HandshakeResult: { success, itemId, lockedAt, proof, error? }.
- Flow terminal states: proposed/ranked->locked, nominated->chosen, researching/shortlisted/negotiating->purchased, considering/leaning->decided.
- NOTE: In BOOKING_FLOW, locked is an intermediate state (no owner). The handshake confirms consensus but does NOT stamp an owner. Ownership is assigned at the claim step. Terminal state is purchased.
- Visual reward: On successful lock, connected clients should trigger Social Gold burst (goldBloom from theme.ts).

LOGIN FLOW (src/app/login/page.tsx):
The "First Breath" — atmospheric login with wordmark, brand identity, name input, profile photo, and transition.
- Wordmark: "xark" in Inter weight 300, scale hierarchy via clamp(3.5rem, 8vw, 6rem), opacity 0.9.
- Brand line: "People. Plans. Memories." at opacity 0.45, clamp(0.95rem, 2.2vw, 1.15rem), letterSpacing 0.08em. Fades in at 0.3s delay.
- Sub-line: "All private, effortlessly in sync." at opacity 0.2, clamp(0.65rem, 1.5vw, 0.8rem), letterSpacing 0.15em. Fades in at 0.5s delay.
- Four phases: arrive (orb breathes in), input (name field with cyan underline), photo (profile photo upload or skip), transit (welcome message + redirect).
- Photo phase: "add a photo" (text.hint, opacity 0.35) + "skip" (text.hint, opacity 0.2). Uploads to Firebase Storage at profiles/{userId}/avatar. Max 2MB. Saves photo_url to Supabase users table.
- The Exhale: After 1.2s transit phase, router.push('/galaxy?name=...') sends user to Galaxy View.
- Privacy signal: Shield icon + "end-to-end encrypted" at opacity 0.2.

GALAXY VIEW (src/app/galaxy/page.tsx):
The Active Mind — a living awareness stream of cross-space activity. No Decide mode. No toggle. The ControlCaret IS the galaxy.
- Spectrum Wash: Dual radial gradients — accent at top-left (opacity.meshCyan), amber at bottom-right (opacity.meshAmber). Amber swell intensifies to 0.05 when any event has activity within 15 minutes.
- Hero text: "ready, [name]?" (or "ready?" if no name) using text.hero, colors.white at opacity.primary. Left margin 44px for visual breathing room.
- Mesh Pulse: Radial white glow breathing on 15s cycle (timing.meshPulse).
- AWARENESS STREAM (src/lib/awareness.ts): Priority-sorted events from all spaces. Each event shows whisper text (text.body at awarenessOpacity(priority)) + space context and recency label below (text.recency at capped opacity). AwarenessKind: needs_vote (0.95), ignited (0.90), proposal (0.75), assigned (0.70), message (0.50), locked (0.40), joined (0.30). Time decay via exponential function. Tap event → navigate to its space.
- Empty state: "who are you planning with?" at text.listTitle, opacity.tertiary. Shows when no awareness events exist.
- Input at 96px from bottom (layout.inputBottom). Placeholder: "a trip, a dinner, an idea..." at opacity.whisper. Underline: opacity.rule default, opacity.focusUnderline on focus.
- THE MANIFESTATION LOOP: On submit → Stage 1 (optimistic router.push via getOptimisticSpaceId, instant) → Stage 2 (createSpace() fires in background, non-blocking).
- SPACE CREATION (src/lib/spaces.ts): createSpace(dream, ownerId) inserts space + seed item + @xark welcome message. getOptimisticSpaceId(dream) generates slug for instant navigation. Seed item: "sunset at [destination]" or "explore [dream]". Kills cold-start and ghost-town problems.
- ControlCaret renders globally via layout.tsx — always present on this page.
Zero-box: No cards. No borders. No headers. No toggles. Atmospheric wash only.

SPACE VIEW (src/app/space/[id]/page.tsx):
Individual space view. Contains discuss (chat) and decide (visual stream) toggle, plus share action.
- Header: Space title using text.spaceTitle (clamp(1.25rem, 3vw, 1.5rem)), colors.white at opacity 0.9. Fixed with gradient fade from void to transparent.
- View toggle: "discuss" and "decide" as floating text using text.label styling (0.6rem, uppercase, tracking 0.2em, outline-none). Human-action labels, not system internals. Active = colors.cyan at opacity 0.9. Inactive = colors.white at opacity 0.4. Transition via timing.transition.
- SHARE ACTION: "share" floating text (text.label) right-aligned at opacity 0.4. Mobile: navigator.share() with space title + URL. Desktop fallback: clipboard copy, "link copied" whisper at opacity 0.7 for 2s. No share button with border/background — just floating text.
- Demo data fallback: When Supabase is unreachable, space title resolved from demo space map (includes ananya sanctuary).
- Chat view: Renders XarkChat with spaceId, userId, and spaceTitle.
- Horizon view: Placeholder for PossibilityHorizon integration (cyan breathing dot + "possibilities loading" label).
- ControlCaret renders globally via layout.tsx — no local import needed.
- UserMenu (profile icon + theme selector) does NOT appear on space pages — only on Galaxy page.
No tabs. No boxes. No borders on the toggle. No focus outlines. Floating text selection only.

SEED DATA (src/lib/seed.ts):
Populates Supabase Postgres with high-signal demo data. Run via: npx tsx src/lib/seed.ts
- "san diego trip" space: 4 decision items (Hotel Del 92% locked, surf lessons 45% steady, balboa park 45% steady, gaslamp dinner 92% locked) + 10 group messages (tests foveal opacity at scale, multi-user with sender_name).
- "ananya" sanctuary space: 1:1 private stream. 5 messages seeded. Last message: "did you see the surf lesson proposal?"
- "tokyo neon nights" space: 2 items (shibuya 15% seeking, teamlab 72% steady).
- "summer 2026" space: Empty, seeking state.

IMPLEMENTED SERVICES (all operational):
- src/lib/intelligence/orchestrator.ts — Gemini 2.0 Flash orchestrator (see INTELLIGENCE SERVICE above).
- src/lib/intelligence/tool-registry.ts — Apify tool registry (see INTELLIGENCE SERVICE above).
- src/lib/intelligence/apify-client.ts — Apify actor runner (see INTELLIGENCE SERVICE above).
- src/lib/media.ts — Firebase Storage media upload/download (see MEDIA SERVICE above).
- src/lib/notifications.ts — FCM push notification service (see NOTIFICATION SERVICE above).
- src/lib/state-flows.ts — Shared flow terminal states (see STATE FLOWS MODULE above).
- src/lib/space-state.ts — Emergent space state pure function (see EMERGENT SPACE STATE above).
- src/lib/supabase-admin.ts — Server-side Supabase client (see SUPABASE ADMIN CLIENT above).
- src/hooks/useVoiceInput.ts — Voice dictation + @xark invocation (see VOICE INPUT above).
- src/components/os/ClaimSheet.tsx — Item claim UI (see CLAIM SHEET above).
- src/components/os/PurchaseSheet.tsx — Purchase confirmation UI (see PURCHASE SHEET above).
- src/components/os/MediaUpload.tsx — Photo upload UI (see MEDIA SERVICE above).
- src/components/os/ServiceWorkerRegistration.tsx — FCM service worker registration (see NOTIFICATION SERVICE above).

KNOWN BUGS (from architecture audit, addressed in implementation plan):
- B1: ai-grounding.ts buildGroundingContext() fetches agreement_score but column may not exist in all environments. Fix: add column check or migration guard.
- B2: ai-grounding.ts generateGroundingPrompt() doesn't include reaction details per item (user names + types). Fix: join reactions table in buildGroundingContext.
- B3: ledger.ts fetchSettlement() uses entries.length for memberCount instead of space_members table. Fix: query space_members for true group size.
- B4: spaces.ts createSpace() doesn't add creator as space member. Fix: insert into space_members after space creation.
All four bugs are addressed in the implementation plan (Tasks 0.4, 2.5, 10.4).

INTELLIGENCE SERVICE (src/lib/intelligence/):
@xark's brain (Gemini 2.0 Flash) + hands (Apify actors). Stateless orchestration — no state stored.
- orchestrator.ts: orchestrate(input) parses intent via Gemini → routes to Apify tool → synthesizes response. OrchestratorInput: { userMessage (stripped of "@xark"), groundingPrompt, recentMessages (last 15), spaceId }. OrchestratorResult: { response, searchResults?, action ("search"|"reason"|"propose"), tool? }. Intent parsing returns JSON with action type. Search results auto-inserted as decision_items via /api/xark.
- tool-registry.ts: registerTool(name, { actorId, description, paramMap }). Default tools: hotel, flight, activity, restaurant, general. paramMap transforms user params to Apify input format. getTool(name) returns ToolDefinition or null. listTools() returns registered tool names.
- apify-client.ts: runActor(actorId, input) executes Apify actor and normalizes results to ApifyResult { title, price?, imageUrl?, description?, externalUrl?, rating?, source }. Safe: returns [] when APIFY_API_TOKEN is missing.
- /api/xark endpoint (src/app/api/xark/route.ts): POST handler. Silent mode: returns { response: null } if message doesn't contain "@xark". Strips prefix, builds grounding context, fetches last 15 messages, calls orchestrate(). Search results auto-upserted into decision_items as "proposed" state items. Uses supabaseAdmin for server-side writes.

STATE FLOWS MODULE (src/lib/state-flows.ts):
Shared state flow definitions. Single source of truth for terminal state resolution.
- FLOW_TERMINAL_STATES: Record<string, string>. Maps current state to terminal state. "ranked" intentionally omitted (ambiguous between BOOKING_FLOW and SIMPLE_VOTE_FLOW).
- resolveTerminalState(currentState, flow?): Resolves "ranked" based on optional flow parameter. Defaults to "locked" for unknown states.
- isTerminalState(state): Returns true for "purchased", "chosen", "decided".
- Imported by handshake.ts and claims.ts — eliminates duplication.

MEDIA SERVICE (src/lib/media.ts):
Firebase Storage for blobs, Supabase Postgres for metadata.
- uploadMedia(file, spaceId, userId, caption?): Uploads to Firebase Storage at `spaces/{spaceId}/media/{mediaId}`, saves metadata to Supabase `media` table. Returns MediaItem or null when Storage is unconfigured.
- fetchMedia(spaceId): Returns all media items for a space ordered by created_at ascending.
- MediaItem: { id, spaceId, uploadedBy, storagePath, thumbnailUrl?, caption?, createdAt }.
- MediaUpload component (src/components/os/MediaUpload.tsx): "add photo" floating text (text.hint, opacity 0.35), hidden file picker, optional caption input, cyan breathing dot during upload. Zero-Box compliant.

NOTIFICATION SERVICE (src/lib/notifications.ts):
Server-side FCM push via Firebase Admin SDK. Lazy initialization — no-op when unconfigured.
- getAdmin(): Dynamically imports firebase-admin, initializes once from FIREBASE_SERVICE_ACCOUNT_JSON env var. Singleton pattern.
- sendPush(tokens[], title, body, data?): Sends multicast push via FCM. No-op when tokens empty or Admin not configured. webpush.fcmOptions.link defaults to "/galaxy".
- /api/notify endpoint (src/app/api/notify/route.ts): POST handler. Accepts { event, spaceId, title, body, excludeUserId }. Queries space_members → user_devices for FCM tokens. Uses supabaseAdmin for service-role access. Returns { sent: number }.
- ServiceWorkerRegistration (src/components/os/ServiceWorkerRegistration.tsx): Client component. Registers /firebase-messaging-sw.js, posts Firebase config to service worker via postMessage. Renders null. Only registers when NEXT_PUBLIC_FIREBASE_API_KEY exists.
- firebase-messaging-sw.js (public/): Background notification handler. Receives Firebase config via postMessage from main thread.

VOICE INPUT (src/hooks/useVoiceInput.ts):
On-device SpeechRecognition for dictation and @xark invocation.
- useVoiceInput(): Returns { isListening, isXarkListening, transcript, startListening, startXarkListening, stopListening, error }.
- startListening(): Tap mic — on-device speech-to-text, no network required. Sets transcript.
- startXarkListening(): Long-press — auto-prefixes "@xark " to transcript for direct intelligence invocation.
- Graceful fallback: sets error when SpeechRecognition API unavailable.

CLAIM SHEET (src/components/os/ClaimSheet.tsx):
Slide-up sheet for claiming a locked item. "i'll handle this" — stamps owner on BOOKING_FLOW locked items.
- Props: { isOpen, onClose, itemId, itemTitle, userId, onClaimed? }.
- Actions: "i'll handle this" (colors.cyan, text.label) + "not yet" (textColor(0.4), text.label). No buttons, no boxes.
- Uses claimItem() from claims.ts. On success: whisper "[name] is on it", auto-close after 1.5s.
- Constitutional: #000 overlay at opacity 0.8, colors.void bg, no blur.

PURCHASE SHEET (src/components/os/PurchaseSheet.tsx):
Slide-up sheet for confirming purchase + entering amount. Appears when user taps a claimed item they own.
- Props: { isOpen, onClose, itemId, itemTitle, userId, currentVersion, onPurchased? }.
- Amount input with $ prefix + unit cycle toggle (total / per night / per person). Proof input (link/receipt, optional — falls back to verbal).
- State: claimed → purchased (terminal). Optimistic concurrency via version check.
- "done" action (colors.cyan, text.label). Whisper on success: "[name] booked [title] for $[amount]".
- Constitutional: accent underline on inputs, no buttons, no boxes.

PROFILE PHOTO UPLOAD (Login Flow):
- Login page has 4 phases: arrive → input → photo → transit (was 3 phases before).
- Photo phase: "add a photo" (text.hint, opacity 0.35) + "skip" (text.hint, opacity 0.2) floating text.
- handlePhotoSelect: Uploads to Firebase Storage at `profiles/{userId}/avatar`, saves URL to users.photo_url in Supabase. Max 2MB.
- UserMenu.tsx: Fetches photo_url from Supabase users table. Shows profile photo in both small (32px) and large (48px) avatars. Falls back to letter initial.

SUPABASE ADMIN CLIENT (src/lib/supabase-admin.ts):
Server-side Supabase client with service-role key for API routes.
- Uses SUPABASE_SERVICE_ROLE_KEY (not the anon key). Bypasses RLS for server-side operations.
- Used by: /api/xark (insert decision_items from search), /api/notify (query space_members + user_devices).
- Exports null when env vars are missing. Consumers must null-check.

PWA MANIFEST (public/manifest.json):
Progressive Web App configuration for homescreen installation.
- name: "xark", display: "standalone", theme_color matches void.
- Safe-area padding handled in globals.css (env(safe-area-inset-*)).
- Service worker registered via ServiceWorkerRegistration component in layout.tsx.

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
