# Xark OS v2.0 — The Human-Centric Constitution

## 1. THE NO-BOLD MANDATE
- Hierarchy is achieved through Scale (24px vs 12px), Spacing, and Opacity (100% vs 30%). Bold is strictly forbidden.
- Weight 400 (Regular): Primary text, group names, all interactive elements.
- Weight 300 (Light): Secondary labels, metadata, timestamps.
- **BANNED**: font-weight 500, 600, 700, 800, 900. Any weight above 400 is a constitutional violation.
- If you need emphasis, use SIZE or OPACITY — never weight.

## 2. THE THEME SYSTEM (Replaces One-White)
- Xark OS ships with ONE theme: hearth (light, default).
- All colors are CSS variables (`--xark-white`, `--xark-void`, `--xark-accent`, etc.) set by ThemeProvider.
- Text color: `var(--xark-white)` via `colors.white`. Dark ink (#141414) on warm paper.
- Background: `var(--xark-void)` via `colors.void`. Warm off-white (#F0EEE9).
- Accent: `var(--xark-accent)` via `colors.cyan`. Hearth = `#FF6B35` (Action Orange).
- `textColor(alpha)` from `theme.ts` returns `rgba(var(--xark-white-rgb), alpha)` — the APPROVED method for applying opacity to text. This bakes opacity into the color for correct antialiasing.
- `accentColor(alpha)` works the same for accent color.
- All hierarchy expressed via opacity, never font-weight. `textColor(0.9)` for primary, `textColor(0.4)` for tertiary.
- Engine signal colors (amber, gold, green, orange, gray) are ALL CSS variables — adjusted per theme for contrast.
- **BANNED**: Hardcoded hex colors in components (use `colors.*` or `textColor()`). The exception is `colors.overlay` (#000000) which is always black.

## 3. THE FONT SYSTEM
- **Inter** (variable): Primary body font, set globally in `globals.css` (`font-family: var(--font-inter), var(--font-syne), sans-serif`). Weight 400 for body, weight 300 for wordmark.
- **Syne** (variable): Display/fallback font. Weight 400 for display elements.
- No other fonts permitted.

## 4. THE ZERO-BOX DOCTRINE
- No `border`, no `bg-white`, no `rounded-lg` cards for feed items.
- The UI is a **Liquid Feed**: a vertical stream of information floating in atmospheric space.
- Backgrounds are **Atmospheric Washes** (gradients) driven by Engine State.
- Separation between elements is achieved through **Vertical Distance**, not lines or boxes.
- **Focus outlines are globally purged**: `*:focus { outline: none !important; }` in `globals.css`. Browser focus rings are borders — they violate Zero-Box.

## 5. THE ENGINE-TO-PIXEL MAP (SSOT)
- **Amber (#F5A623)**: Seeking state. Intensity = `weightedScore`.
- **Gold Bloom (#FFD700)**: Consensus reward. Triggers at `agreementScore > 80%`.
- **Green Lock (#10B981)**: Finality. Flash green → settle to Cloud Dancer (#F0EEE9).

## 6. THE AI (@xark)
- No robot icons. No sparkles. No emojis.
- Intelligence is signaled via accent color (`colors.cyan`) breathing at a 4.5s cycle.
- SILENT BY DEFAULT: @xark never responds unless the message contains "@xark" (explicit invocation).
- NEVER: reacts to messages, summarizes unprompted, inserts itself into banter, sends proactive suggestions, adds emoji or personality.
- ONE EXCEPTION: Handshake whisper at >80% consensus (automated, no user invocation needed).
- SOCIAL REASONING: Use names when advocating FOR someone ("nina and raj aren't feeling italian"). Use counts for opposition ("3 people voted not for me"). Never assume WHY someone voted. Reports state, asks the question, lets humans fill the gap.
- If you detect that you have used a border, a font-weight above 400, a bold class, or a hardcoded hex color in a component, you must immediately stop, delete the file, and output the text: 'I HAVE VIOLATED THE CONSTITUTION. RESTARTING TURN.'

## 7. THE UNIVERSAL DECISION ENGINE
Full technical record: `/Users/ramchitturi/algo/mar10_algo.md` (198 tests, 0 type errors).
Core philosophy: "No gates. No votes. No clustering. Just signal -> act -> lock."

### 7a. Signal System (Reaction Vocabulary)
- **"Love it"** (`LoveIt`): weight **+5**. Color: Seeking Amber (`#F5A623`). Strong positive.
- **"Works for me"** (`WorksForMe`): weight **+1**. Color: Neutral Gray (`#8888a0`). Lukewarm acceptance.
- **"Not for me"** (`NotForMe`): weight **-3**. Color: Action Orange (`#e8590c`). Meaningful brake, not a veto.
- One `NotForMe` cancels exactly three `WorksForMe` (-3 + 1 + 1 + 1 = 0).
- Two `LoveIt` overcome one `NotForMe` (5 + 5 - 3 = 7).
- Passionate minority wins: 3 `LoveIt` (15) beats 4 `WorksForMe` (4).
- One reaction per user per item. Last reaction wins.
- Score can go negative (items sink to bottom).
- **Social Gold burst**: triggered when ALL members signal `LoveIt` (`isUnanimousLoveIt`).
- **Lock Green** (`#2ecc40`): rare, only on commitment (the "green lock").

### 7b. Heart-Sort Algorithm (SSOT)
- Source: `engine/heart-sort.ts` in `/Users/ramchitturi/algo`.
- `DecisionItem` interface: `id`, `spaceId`, `title`, `description`, `category` (open string), `state` (open string), `proposedBy`, `proposedAt`, `reactions[]`, `weightedScore`, `commitmentProof`, `ownership`, `ownershipHistory[]`, `lockedAt`, `version`, `metadata`.
- `BookableItem`: backwards-compat type alias = `DecisionItem & { groupId, bookingProof }`. Both field sets always in sync.
- `heartSort()`: Descending by `weightedScore`. Tie-break by `proposedAt` ascending (first proposed wins). O(n log n).
- `calculateWeightedScore()`: Sum of deduplicated reaction weights (one per user, last wins).
- `calculateAgreementScore()`: ALL reactors (including NotForMe) / totalMembers. `isGroupFavorite` = strictly > 80%.
- `getRankedSummary()`: Returns `reactionBreakdown { loveIt, worksForMe, notForMe, hearts, thumbsUp }`.
- All computation functions are **pure**: no mutation, no side effects, always return new objects.

### 7c. State Machine (4 Preset Flows)
- **BOOKING_FLOW** (default, EXTENDED): `proposed` -> [reaction] -> `ranked` -> [consensus] -> `locked` -> [claim] -> `claimed` -> [purchase] -> `purchased`. `locked` = consensus reached, no owner. `claimed` = someone stepped up, owner stamped. `purchased` = proof + amount submitted (terminal). Feeds settlement.
- **PURCHASE_FLOW**: `researching` -> [reaction] -> `shortlisted` -> [manual] -> `negotiating` -> [commitment] -> `purchased`.
- **SIMPLE_VOTE_FLOW**: `nominated` -> [reaction] -> `ranked` -> [commitment] -> `chosen`.
- **SOLO_DECISION_FLOW**: `considering` -> [reaction] -> `leaning` -> [commitment] -> `decided`.
- All flows allow skipping intermediate states via direct `[commitment]` from initial state.
- Three trigger types: `"reaction"` (automated), `"commitment"` (intentional with proof), `"manual"` (explicit).
- `DecisionItemState` is an open string for custom flows ("researching", "shortlisted", "negotiating", etc.).
- Unknown transitions silently ignored (permissive design, prevents crashes).
- **Shared module**: `src/lib/state-flows.ts` — `FLOW_TERMINAL_STATES`, `resolveTerminalState(state, flow?)`, `isTerminalState(state)`. Used by handshake.ts and claims.ts.

### 7d. Green-Lock Commitment Protocol
- Lock = real-world commitment confirmation (booking, purchase, contract), NOT a vote.
- `CommitmentProof`: `{ type, value, submittedBy, submittedAt }`. Type is open string ("confirmation_number", "screenshot", "receipt", "contract", "verbal").
- `commitItem()`: State-machine-aware, uses flow to determine locked state name.
- `lockItem()`: Legacy, hardcoded to `"locked"`. Deprecated but functional.
- On lock: committer stamped as owner `{ ownerId, assignedAt, reason: "booker" }`.
- `transferOwnership()`: reason `"transfer"`. Cannot self-transfer. Cannot transfer non-locked item.
- `ownershipHistory[]`: append-only audit trail.
- Validation: cannot lock already-locked (`GreenLockError`), cannot lock with empty proof, cannot react to locked item.

### 7e. AI Grounding (@xark Constraints)
- @xark MUST respect locked decisions. If the group booked the Hilton, @xark must not suggest alternative hotels.
- `GroundingConstraint` types: `"locked_decision"` (committed items), `"assigned_task"` (claimed tasks).
- STATE MAP APPROACH: Instead of rigid "forbidden categories," @xark receives a full state map of all items grouped by state (Locked → Voting → Proposed → Empty). Includes reaction counts per item. Lets Gemini reason about scope — "hotel" locked doesn't ban "Airbnb for a different city" if it's a different need.
- `checkSuggestionConflicts()`: Pre-call guard. Returns locked decisions in same category before AI generates suggestions. Run server-side before Gemini call.
- No locked decisions = "No locked decisions yet. You may suggest any options freely."

### 7f. Task Assignment
- Tasks are non-decidable. No consensus needed. `Created` -> `Assigned`.
- `createTask()`, `assignTask()`, `reassignTask()`, `unassignTask()`.
- No proof required. No reactions. No ranking. Self-reassignment throws `TaskAssignmentError`.
- IDs: `crypto.randomUUID()`. Prefix convention: `task_${uuid}`, `item_${uuid}`, `space_${uuid}`.

## 8. THE FIREBASE CLIENT
- `src/lib/firebase.ts` — Phone OTP authentication + E2EE multimedia storage.
- **Safe initialization**: When `NEXT_PUBLIC_FIREBASE_API_KEY` is missing or empty, Firebase is NOT initialized. `auth` and `storage` export `null`. Prevents SSR crash (`auth/invalid-api-key`).
- Singleton initialization: `getApps()` check prevents duplicate apps when API key is present.
- Exports: `auth` (`Auth | null` — phone OTP), `storage` (`FirebaseStorage | null` — E2EE binary blobs). Consumers must null-check.
- Environment: `NEXT_PUBLIC_FIREBASE_API_KEY`, `NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN`, `NEXT_PUBLIC_FIREBASE_PROJECT_ID`, `NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET`, `NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID`, `NEXT_PUBLIC_FIREBASE_APP_ID`.
- **BANNED**: Firestore, Firebase Realtime Database. Database operations use Supabase Postgres exclusively.

## 9. THE SUPABASE POSTGRES CLIENT
- `src/lib/supabase.ts` — Database-only client for Supabase Postgres.
- Package: `@supabase/supabase-js`. NOT `@supabase/auth`.
- Environment: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`. Placeholder fallback when env vars are missing (local dev renders without crash; queries fail silently, components use demo data).
- **BANNED**: Any auth configuration, session persistence, or token refresh via Supabase. Authentication is Firebase Auth exclusively.
- Used by: `ai-grounding.ts` (fetch locked items, tasks, all items), future decision engine queries.

## 10. THE AI GROUNDING IMPLEMENTATION
- `src/lib/ai-grounding.ts` — Live implementation of Section 8 of mar10_algo.md.
- Prevents @xark from suggesting a "Four Seasons" if the group has already locked the "Hilton."
- `REACTION_WEIGHTS`: `{ love_it: 5, works_for_me: 1, not_for_me: -3 }`. Embedded in all grounding prompts.
- `SpaceItem` interface: `{ id, title, category, description, state, weightedScore, agreementScore, ownership }`.
- `buildGroundingContext(spaceId)`: Fetches locked items (ordered by `locked_at` desc) + assigned tasks + all items (including `agreement_score`) from Supabase Postgres. Returns `GroundingContext { spaceId, constraints[], lockedCategories[], currentFavorites[], forbiddenCategories[] (legacy), forbiddenSuggestions[], topIgnitedTitle, recentlyLocked { title, ownerName } }`.
- `checkSuggestionConflicts(currentItems, proposedCategory)`: Pre-call guard (Section 8 conflict check). Filters "Locked"/"Finalized" items. Returns `ConflictResult { hasConflict, reason?, conflictingItemId? }`. Run server-side before Gemini call.
- `checkContextConflicts(context, category)`: Convenience wrapper using `GroundingContext`. Returns `GroundingConstraint[]`.
- `generateGroundingPrompt(context)`: Full state map for @xark system prompt. Groups items by state (Locked → Voting → Proposed → Empty). Includes reaction counts per item. Appends WEIGHTING RULES (-3/+1/+5). Lets Gemini reason about scope rather than imposing rigid category bans.
  - When empty: "No locked decisions yet. You may suggest any options freely."
- Supabase tables: `decision_items` (id, title, category, description, state, weighted_score, ownership, space_id, is_locked), `tasks` (id, title, assignee_id, space_id).

## 11. THE @XARK CHAT INTERFACE
- `src/components/os/XarkChat.tsx` — @xark intelligence conversation surface.
- **No chat bubbles. No boxes. No containers.** Text floats on atmospheric mesh gradient.
- MeshGradientBg: Radial ellipse accent glow (`opacity: 0.02`) behind all content. Atmospheric depth layer.
- All typography uses `theme.ts` text tokens. Hierarchy through **SCALE**, never weight.
- **FOVEAL OPACITY** (Liquid Stream Protocol): `fovealOpacity(index, total, role)` from `theme.ts`. @xark: `0.9 → 0.7 → 0.5 → 0.35 → 0.25 → floor(0.2)`. User: `0.6 → 0.45 → 0.35 → 0.25 → floor(0.2)`. Role labels capped at `min(0.35, msgOpacity)`. Timestamps inline, capped at `min(0.25, msgOpacity * 0.3)`. CSS `transition: opacity 0.6s ease`.
- **LAYOUT ANIMATION**: `AnimatePresence` + `motion.div` with `layout` prop. New messages enter from `{ opacity: 0, y: 8 }`. Layout shifts use `[0.22, 1, 0.36, 1]` at `0.2s`. WhatsApp-dense grouping: same-sender `mt-0.5`, different-sender `mt-3`.
- @xark responses: `text.body` (0.75rem), `colors.white`, foveal opacity (newest `0.9`), lineHeight 1.5. Left-aligned.
- User messages: `text.body` (0.75rem), `colors.white`, foveal opacity (newest `0.6`). Own = right-aligned. Others = left-aligned.
- Timestamps: `text.timestamp` (0.45rem), inline after content, `min(0.25, msgOpacity * 0.3)`.
- Role labels: `text.label` (0.6rem, uppercase, 0.2em tracking), capped at `min(0.35, msgOpacity)`. @xark = `colors.cyan`. Only on first message in sender group.
- Thinking state: `colors.cyan` dot breathing at 4.5s + "thinking" `text.hint` at opacity 0.4.
- **Greeting**: Shows when message stream is empty, anchored near bottom (flex spacer pushes it down). @xark label (`text.label`, `colors.cyan`, 0.4) + actionable hint (`text.hint`, 0.35): `try "@xark find hotels near the beach"`. Uses `getGreeting(context, spaceTitle)` for contextual examples.
- **Display-only**: XarkChat no longer contains input or send logic. All chat state (messages, input, isThinking, sendMessage) lives in the Space page (`src/app/space/[id]/page.tsx`). XarkChat receives `messages` and `isThinking` as props.
- **ChatInput** (`src/components/os/ChatInput.tsx`): Two-zone layout. **Textarea + mic** at 56px from bottom: auto-expanding textarea (`text.body`, max ~6 lines/120px) + mic SVG icon (14px) in input row. Enter sends, Shift+Enter newline. Top ambient accent line (content boundary). **Living ambient line** below text: grows with text length, breathes at 4.5s, fades cyan→transparent. Invisible when empty+unfocused. Solid `colors.void` bg. Mic: tap = dictate, long-press 500ms = @xark mode (breathing dot replaces icon). **Attach icon** (16px paperclip SVG): fixed at `left: 25%` at `layout.caretBottom`. **Camera icon** (16px camera SVG): fixed at `left: 75%` at `layout.caretBottom`. Both at `colors.white` opacity 0.5 → 0.8 hover, thin 1.5px stroke. Void fill 56px.
- **BANNED in ChatInput**: Buttons with backgrounds, text-label actions at dot level (use icons), full-width action bars, actions that shift position, static full-width underlines.
- Grounding-aware: Loads `GroundingContext` on mount.
- Grounding whisper: "grounded: [categories] locked" at opacity 0.2 when locked categories exist.
- **Handshake integration**: `useHandshake(spaceId)` from `src/hooks/useHandshake.ts`.
  - Whisper injected into message stream on proposal.
  - "confirm" (`colors.gold`, 0.9) and "wait" (`colors.white`, 0.4) as floating `text.label`. NO boxes. NO buttons.
  - **Committing**: Gold dot breathing + "locking" `text.hint`.
  - **Social Gold burst**: Radial gold gradient, `goldBurstPulse` 3s.
  - **Post-lock**: "locked. [title] is now committed." On dismiss: "understood. keeping this open for now."
- **Sender names**: `senderName` on group messages. Other users = name label (left-aligned). "you" = right-aligned. Tapping name with `SANCTUARY_MAP` entry opens Sanctuary Bridge.
- **Sanctuary Bridge**: Slide-up sheet. `colors.void` bg, 80vh max. Foveal opacity. Close at 0.4. Overlay #000 at 0.8. NO blur.
- **Demo**: 10 group (san diego), 5 sanctuary (ananya). Fallback when Supabase unreachable.
- **Message persistence**: `src/lib/messages.ts`. Realtime sync via INSERT subscription. Deduplication.
- **BANNED**: Chat bubbles, message containers, borders/backgrounds on messages, robot icons, emojis, font-weight above 400, buttons with borders/backgrounds.

## 12. THE CONSENSUS MARK
- `src/components/os/ConsensusMark.tsx` — SVG + Framer Motion consensus indicator.
- **Seeking** (0-30%): Amber (#F5A623) dashed ring. Tween pulse (`cubic-bezier(0.22, 1, 0.36, 1)`, `0.6s`, `repeatDelay: 1.4`). Slow rotation. NOTE: Spring animations require exactly 2 keyframes in Framer Motion — use tween for 3+ keyframe arrays.
- **Steady** (31-80%): Amber ring + Cyan (#40E0FF) breathing dot at 4.5s cycle.
- **Ignited** (80%+): Gold (#FFD700) ring + 6 radial flare particles. Gold center dot.
- No borders. No backgrounds. No containers. SVG floats in atmospheric space.

## 13. THE BLUEPRINT VIEW
- `src/components/os/Blueprint.tsx` — Vertical timeline of Green-Lock settled decisions.
- Every displayed item has passed the Commitment Protocol (`is_locked = true`).
- Data: Fetched from Supabase Postgres `decision_items` where `is_locked = true`, ordered by `locked_at` ascending.
- **Timeline**: 1px vertical line at `opacity: 0.1` using `colors.white`. Atmospheric anchor, NOT a border.
- **Category**: `10px`, `uppercase`, `letter-spacing: 0.2em`, `opacity: 0.3`.
- **Title**: `text.listTitle` (1rem), `opacity: 0.9`, `letterSpacing: -0.01em`.
- **Description**: `text.subtitle` (0.65rem), `opacity: 0.4`, `letterSpacing: 0.02em`.
- **Metadata row**: ConsensusMark in `ignited` state (The Mark of Truth) + commitment proof display + `lockedAt` timestamp at `opacity: 0.25`.
- **Finality wash**: Radial gradient using `currentColor` (#F0EEE9) at `opacity: 0.05`. No `rgba` white variants.
- **Animation**: Framer Motion staggered entrance (`delay: index * 0.1`, `y: 20 → 0`).
- **Empty state**: "no locked decisions yet" at `opacity: 0.2`.
- **Settlement Ledger** (The Subtle Settle): Below the timeline, uses `fetchSettlement(spaceId)` from `src/lib/ledger.ts`. Displays per-user paid totals with item breakdown. Debt deltas: "[name] owes [name] $[amount]". Payment deep links as floating Cyan text: "venmo" (`venmo://`) and "upi" (`upi://`). 1px atmospheric divider. Total committed at bottom at `opacity: 0.2`.
- **BANNED**: Cards, borders, containers, boxes around timeline items. Items float in atmospheric space.

## 13a. THE CLAIMS ENGINE
- `src/lib/claims.ts` — Manual item claim, outside the automated handshake flow.
- `claimItem(itemId, userId, proofValue?)`: Locks an item with ownership. Proof: free-form text ("Link to confirmation or drop receipt.") or verbal fallback.
- Flow-aware terminal state resolution (mirrors `handshake.ts`). Optimistic concurrency via `version` field.
- `ClaimProof`: `{ type: "receipt"|"verbal", value, submittedBy, submittedAt }`.
- On claim: owner stamped with `reason: "booker"`.

## 13b. THE SETTLEMENT LEDGER
- `src/lib/ledger.ts` — Financial resolution for locked decisions.
- `fetchSettlement(spaceId)`: Queries locked items, parses `metadata.price` (handles "$450/nt", "$95/person", "Free"). Groups by `ownership.ownerId`. Returns `Settlement { entries[], deltas[], totalSpent, fairShare, memberCount }`.
- `DebtDelta`: `{ fromUser, fromName, toUser, toName, amount }` — who owes whom.
- `generateVenmoLink(recipientName, amount, note)`: Returns `venmo://paycharge` deep link.
- `generateUPILink(upiId, recipientName, amount, note)`: Returns `upi://pay` deep link with INR currency.
- Rendered in Blueprint.tsx as floating atmospheric text. No boxes. No buttons. Cyan payment links.

## 14. THE NAVIGATION FLOW
- **Login → Galaxy → Space**: The full state management chain.
- **Login** (`src/app/login/page.tsx`): Brand identity screen. Wordmark "xark" (Inter 300). Brand line: "People. Plans. Memories." at `opacity: 0.45`. Sub-line: "All private, effortlessly in sync." at `opacity: 0.2`. Staggered fade-in (0.3s, 0.5s). Four phases — `arrive` (1.8s ambient orb), `input` (name entry with cyan underline), `photo` (profile photo upload or skip), `transit` (welcome message, then `router.push('/galaxy')` after 1.2s). Photo phase: "add a photo" (text.hint, 0.35) + "skip" (text.hint, 0.2). Uploads to Firebase Storage `profiles/{userId}/avatar`. Max 2MB.
- **Galaxy** (`src/app/galaxy/page.tsx`): The Active Mind — awareness stream home. Awareness stream (src/lib/awareness.ts) shows priority-sorted cross-space events. Amber swell on recent activity. Mesh Pulse (15s breath). Empty state: "who are you planning with?". Input at 56px from bottom (`text.body`), top ambient line, living ambient line below text, solid void bg, void fill 56px. Manifestation Loop. ControlCaret global. UserMenu visible on Galaxy only. Spectrum Wash.
- **Space** (`src/app/space/[id]/page.tsx`): Individual space. View toggle: `discuss` / `decide` / `itinerary` / `memories` + `share` action as floating `text.label`. Active = `colors.cyan` at 0.9, inactive = `colors.white` at 0.4. Chat state (messages, input, isThinking, sendMessage) lifted to Space page — persists across view switches. `ChatInput` always visible. `discuss` → XarkChat (display-only). `decide` → PossibilityHorizon. Fixed header with solid void bg + ambient accent line. ControlCaret global. No UserMenu.
- **Seed Data** (`src/lib/seed.ts`): Populates Postgres with demo spaces, items, and messages. "san diego trip" (4 items: Hotel Del 92% locked, surf lessons 45%, balboa park 45%, gaslamp 92% locked; 10 group messages), "ananya" (sanctuary, 5 messages — last: "did you see the surf lesson proposal?"), "tokyo neon nights" (2 items), "summer 2026" (empty). Run via `npx tsx src/lib/seed.ts`.
- **ControlCaret** (`src/components/os/ControlCaret.tsx`): The Persistent Memory. `colors.cyan` dot (`layout.caretSize`, 10px) at bottom center, breathing at 4.5s. GLOBAL via `GlobalCaret.tsx` in `layout.tsx`. Context-aware tap: inside space → back to Galaxy; on Galaxy → toggle slide-up. Slide-up shows Avatar (28px, round, no border) + `text.listTitle` space name + `text.subtitle` member names + decision state + `text.recency` timestamps. Recency-driven opacity via `recencyOpacity()`. Presence Ember (4px `colors.cyan` dot, breathing, on avatar when friend online). "invite a person" initiation seed at bottom. Overlay `#000` at 0.8 — NO blur. Data: `fetchSpaceList()` from `space-data.ts`, fallback to `DEMO_SPACES`.
- **Sanctuary Bridge** (in XarkChat): Tapping a sender name with SANCTUARY_MAP entry opens slide-up sheet. Sheet: `#0A0A0A` bg, slides from bottom, 80vh max. Foveal opacity on messages. Close text at opacity 0.4. Dark overlay `#000` at 0.8 — no blur.
- **Content Boundaries (THE TWO-LINE RULE)**: All scrollable content lives between two ambient accent lines — the header line (below title/toggle) and the input line (above ChatInput/Galaxy input). Header and input zones use **solid `colors.void` backgrounds** (not gradient fades). Content never bleeds above or below the ambient lines. This is a constitutional invariant across all views (Galaxy, Discuss, Decide, Itinerary, Memories).
- **BANNED**: Cards, tab bars, bordered navigation, buttons with backgrounds, `backdrop-filter: blur`, gradient fades on header/input backgrounds (use solid void). All navigation is atmospheric floating text. All overlays use opaque `#000` — 60fps on $100 devices.

## 15. THE POSSIBILITY HORIZON (DECIDE VIEW)
- `src/components/os/PossibilityHorizon.tsx` — Netflix-style vertical scroll of horizontal card bands, one per category.
- **Category Sections**: Categories pluralized (hotels, activities, flights, dining). Header in `text.label` at `textColor(0.35)`. No conviction strip — clean label only. 28px gap between sections.
- **Decision Cards**: 170×260px portrait. `borderRadius: 16px`. `boxShadow: 0 4px 24px rgba(0,0,0,0.12), 0 1px 4px rgba(0,0,0,0.08)` — floating depth, Airbnb/Netflix quality. Image or gradient placeholder. Vignette covers bottom 60% (1.0 → 0.95 at 30% → 0.5 at 55%). Amber wash. **Consensus Hero**: 1.5rem percentage in consensus color + 2px bar. Title (`text.body`, 0.9). Price (`text.recency`, 0.4). **Reactions**: float at card bottom (no container, no strip), `justify-between`, px-4. `text.subtitle` (0.65rem). Inactive: `colors.white` at 0.55 with `text-shadow: 0 1px 3px rgba(0,0,0,0.4)` for depth/readability. Active: signal color at 1.0 with color glow `text-shadow: 0 0 12px color, 0 0 4px color`. NOTE: `borderRadius` and `boxShadow` on Decide cards are an explicit user-approved exception to Zero-Box Doctrine — cards in the decision surface need physical depth to feel tappable and readable in sunlight.
- **Self-Resolving**: When all items in a category are locked, section collapses to a settled row: 4px `colors.green` breathing dot + category name + locked title at `textColor(0.3)`.
- **Input**: Shared `ChatInput` from Space page — always visible at bottom, persists draft across view switches. Not duplicated inside PossibilityHorizon.
- **Data**: Single Supabase query (ALL items, no `is_locked` filter). Batch reaction fetch. Client-side grouping by `category` (memoized). Single Realtime channel (UPDATE + INSERT).
- Items ordered by `heartSort()` within each category (weightedScore descending, locked items last).
- Snap scroll: `scroll-snap-type: x mandatory`, `scroll-snap-align: start`. Hidden scrollbar. 12px gap between cards.
- **BANNED**: `ConsensusMark` animated SVG on cards, conviction strips, buttons with borders/backgrounds. NOTE: Decision cards use `borderRadius: 16px` + `boxShadow` by explicit user approval — this exception does NOT extend to other components.

## 16. THE HANDSHAKE PROTOCOL
- `src/lib/handshake.ts` — The automated bridge between Consensus and Commitment.
- **Consensus Detection**: `subscribeToConsensus(spaceId, onHandshake)` subscribes to Supabase Realtime on `decision_items`. Monitors `agreement_score` field.
- **Trigger**: When an unlocked item's `agreement_score` exceeds `0.80` (strictly greater than, per Section 7b of mar10_algo.md), a `HandshakeProposal` fires.
- **Deduplication**: Each item triggers only once per subscription lifecycle. Prevents repeated proposals.
- **@xark Whisper**: `generateHandshakeWhisper()` returns: *"consensus reached on [Title]. shall i lock this in for the group?"*
- **Green-Lock Execution**: `confirmHandshake(itemId, confirmerId)` performs the full Commitment Protocol:
  - Fetches current item state + `version` for optimistic concurrency.
  - Guards: Cannot lock already-locked items (`GreenLockError`).
  - `CommitmentProof`: `{ type: "verbal", value: "group consensus confirmed via @xark handshake" }`.
  - Flow-aware terminal state resolution: `proposed`/`ranked` → `locked`, `nominated` → `chosen`, `researching`/`shortlisted`/`negotiating` → `purchased`, `considering`/`leaning` → `decided`.
  - Owner stamp: `{ ownerId: confirmerId, assignedAt, reason: "booker" }`.
  - Optimistic concurrency: `version` field incremented. Stale writes fail (HTTP 409 equivalent).
- **Visual Reward**: On successful lock, all connected clients trigger Social Gold burst (`goldBloom()` from `theme.ts`). Gold (#FFD700) radial bloom across the UI.
- **Cleanup**: `unsubscribeFromConsensus(channel)` removes Supabase Realtime channel.

## 17. HEXAGONAL ARCHITECTURE (Ports & Adapters)
Full source: `/Users/ramchitturi/algo`. Reference adapters are zero-dependency, in-memory.

| Port | Interface | Reference Adapter | Production Target |
|---|---|---|---|
| Persistence | `PersistencePort` | `MemoryPersistenceAdapter` | Supabase Postgres |
| Event Bus | `EventBusPort` | `MemoryEventBusAdapter` | Redis / WebSocket |
| Auth | `AuthPort` | `NoopAuthAdapter` | Firebase Auth (OTP) |
| Cache | `CachePort` (optional) | `MemoryCacheAdapter` | Redis |
| Messaging | `MessagingPort` | `PlaintextMessagingAdapter` | Slack / Discord / Telegram |

- `DecisionService`: Stateless orchestrator. Load from DB -> Compute (pure functions) -> Save -> Broadcast -> Invalidate cache. Horizontally scalable.
- `ConsensusEngine`: In-memory orchestrator for testing/embedded. Both coexist, neither deprecated.
- `RequestHandler`: Framework-agnostic HTTP router. `ServiceRequest { method, path, body, token }` -> `ServiceResponse { status, body }`. Works with Express, Fastify, Hono, Lambda, Workers.
- Optimistic concurrency: `version` field on every item. Incremented on mutation. Stale writes rejected (`VersionConflictError`, HTTP 409).
- Cache: Key `"ranked:{spaceId}"`, TTL 60s, invalidate-on-write.

### API Route Table

| Method | Path | Action |
|---|---|---|
| POST | `/spaces` | Create space |
| GET | `/spaces/:id` | Get space |
| POST | `/spaces/:id/items` | Add item |
| GET | `/spaces/:id/items/ranked` | Ranked summary |
| GET | `/spaces/:id/items/locked` | Locked items |
| POST | `/items/:id/react` | React |
| DELETE | `/items/:id/react` | Unreact |
| POST | `/items/:id/lock` | Lock/commit |
| POST | `/items/:id/transfer` | Transfer ownership |
| GET | `/items/:id/agreement` | Agreement score |
| GET | `/items/:id/signals` | Signal breakdown |
| POST | `/spaces/:id/tasks` | Add task |
| POST | `/tasks/:id/claim` | Claim task |
| GET | `/spaces/:id/grounding/prompt` | AI grounding prompt |
| GET | `/spaces/:id/conflicts` | Check conflicts |

## 18. ERROR TAXONOMY

| Error | When | HTTP | Recovery |
|---|---|---|---|
| `GreenLockError` | Already locked, empty proof, transfer non-locked, self-transfer | 422 | Fix input |
| `TaskAssignmentError` | Self-reassign, unassign non-assigned | 400 | Fix input |
| `VersionConflictError` | Stale version on save | 409 | Reload + retry |
| `AuthError` | Failed auth/authorization | 403 | Valid token |
| `NotFoundError` | Entity not in DB | 404 | Check ID |

## 19. THE INFRASTRUCTURE LOCK (HYBRID STACK)
The Xark OS backend is a locked hybrid of Firebase and Supabase. No substitutions.

| Component | Provider | Why |
|---|---|---|
| Phone OTP | Firebase Auth | Flawless SMS delivery and session management |
| Decision Engine | Supabase (Postgres) | SQL required for heart-sort ranking math |
| Multimedia (E2EE) | Firebase Storage | High-performance binary delivery with bucket security |
| Push Alerts | Firebase (FCM) | Native integration with iOS and Android |
| Intelligence | Gemini 2.5 Flash | @xark deep research and agentic planning |

- **BANNED**: Supabase Auth (`supabase/auth`, `@supabase/auth`, `createClient` with auth config for Supabase). All authentication flows use Firebase Auth exclusively.
- If you detect a Supabase Auth import or scaffold, you must immediately stop and output: 'I HAVE VIOLATED THE CONSTITUTION. RESTARTING TURN.'

## 20. THE INTELLIGENCE SERVICE
- `src/lib/intelligence/orchestrator.ts` — Gemini 2.5 Flash orchestrator. Parses user intent via Gemini → routes to Apify tool → synthesizes response. Stateless. Strips markdown code fences from Gemini JSON. Accepts spaceTitle for location context.
- `src/lib/intelligence/tool-registry.ts` — Tool registry pattern. Default tools: hotel, flight, activity, restaurant, general. `registerTool(name, { actorId, description, paramMap })`.
- `src/lib/intelligence/apify-client.ts` — Apify actor runner. `runActor(actorId, input)` → `ApifyResult[]`. Safe: returns empty array when `APIFY_API_TOKEN` missing.
- `/api/xark` endpoint: POST. Silent mode (no @xark = null response). Strips prefix, fetches space title for location context, builds grounding context, fetches last 15 messages, calls orchestrate(). Search results auto-upserted as decision_items in "proposed" state. Persists @xark response messages server-side via supabaseAdmin (returns messageId for client deduplication).
- `src/lib/supabase-admin.ts` — Server-side Supabase client with `SUPABASE_SERVICE_ROLE_KEY`. Bypasses RLS. Used by `/api/xark` and `/api/notify`.

## 21. THE CLAIM SHEET
- `src/components/os/ClaimSheet.tsx` — Slide-up sheet for claiming a locked item.
- "i'll handle this" (`colors.cyan`, `text.label`, 0.9 opacity) + "not yet" (`textColor(0.4)`, `text.label`).
- On claim: whisper "[name] is on it", auto-close after 1.5s.
- Sheet: `colors.void` bg, slides from bottom (Framer Motion tween), max-height 40vh.
- Overlay: `colors.overlay` (#000) at `opacity.overlay` (0.8). NO blur.
- **BANNED**: Buttons with borders/backgrounds. Actions are floating text only.

## 22. THE PURCHASE SHEET
- `src/components/os/PurchaseSheet.tsx` — Slide-up sheet for confirming purchase + entering amount.
- Amount input: `$` prefix + `text.input` + accent underline. Unit toggle cycles through "total" / "per night" / "per person".
- Proof input: placeholder "link to confirmation or drop receipt". Ghost opacity when empty.
- "done" action: `colors.cyan`, `text.label`. Disabled (0.3 opacity) when amount empty.
- State transition: `claimed` → `purchased` (terminal). Optimistic concurrency via version check.
- Whisper on success: "[name] booked [title] for $[amount]". Auto-close after 2s.
- Sheet: `colors.void` bg, max-height 50vh. Same overlay rules as ClaimSheet.
- **BANNED**: Buttons, dropdowns, select elements. All interactions via floating text and accent underlines.

## 23. THE MEDIA UPLOAD
- `src/components/os/MediaUpload.tsx` — Floating "add photo" text (`text.hint`, opacity 0.35).
- Hidden file picker triggered on tap. Optional caption input with accent underline.
- Upload indicator: `colors.cyan` breathing dot at 4.5s cycle.
- `src/lib/media.ts`: `uploadMedia(file, spaceId, userId, caption?)` → Firebase Storage blob + Supabase metadata row. `fetchMedia(spaceId)` → ordered list.
- **BANNED**: File upload buttons with borders/backgrounds. The trigger is floating atmospheric text.

## 24. THE NOTIFICATION SERVICE
- `src/lib/notifications.ts` — Server-side FCM push via Firebase Admin SDK. Lazy initialization from `FIREBASE_SERVICE_ACCOUNT_JSON` env var. No-op when unconfigured.
- `sendPush(tokens[], title, body, data?)` — Multicast push. webpush.fcmOptions.link for click-through.
- `/api/notify` endpoint: POST. Accepts `{ event, spaceId, title, body, excludeUserId }`. Queries `space_members` → `user_devices` for FCM tokens. Returns `{ sent: number }`.
- `src/components/os/ServiceWorkerRegistration.tsx` — Registers `/firebase-messaging-sw.js`, posts Firebase config via postMessage. Renders null. Only when API key exists.
- `public/firebase-messaging-sw.js` — Background notification handler for PWA.

## 25. THE VOICE INPUT
- `src/hooks/useVoiceInput.ts` — On-device `SpeechRecognition` for dictation and @xark invocation.
- Tap mic: `startListening()` — transcribes speech to text, no network required.
- Long-press mic: `startXarkListening()` — auto-prefixes `@xark` to transcript for direct intelligence invocation.
- Visual indicator: `colors.cyan` breathing dot when listening. `colors.amber` breathing dot when @xark listening.
- Graceful fallback: sets error string when `SpeechRecognition` API unavailable.
- **BANNED**: Microphone buttons with borders/backgrounds. Mic indicator is a breathing dot only.

## 27. THE SETTINGS SHEET
- `src/components/os/UserMenu.tsx` — Three-view drill-down navigation, all within a single file.
- **Main view**: Avatar (28px) + name (`text.body`, `opacity.primary`). "profile" and "system" links (`text.body`, `textColor(0.5)` → `0.8` on hover). "log out" (`text.recency`, `opacity.quaternary`).
- **Profile view**: "back" link (`text.recency`, `textColor(0.25)` → `0.4` on hover). Avatar preview (48px). "change photo" (`text.hint`, opacity 0.35) — hidden file input, Firebase Storage `profiles/{userId}/avatar`, max 2MB. Upload indicator: cyan breathing dot + "uploading" hint. Name input (`text.input`, bg-transparent, accent underline). On blur/Enter: saves to Supabase `users.display_name`. "saved" whisper (1.5s).
- **System view**: "back" link (same as profile). Single theme (hearth) — accent dot + label. Active = accent color at 0.8.
- **Animation**: `AnimatePresence mode="wait"` with horizontal slide variants (x: ±60px, 0.2s tween, `timing.layoutEase`). Direction state tracks drill-in (1) vs back (-1). View resets to "main" on sheet close (300ms delay for exit animation).
- **Sheet**: Slides from top (`y: -100% → 0`), `colors.void` bg, `overflow: hidden`. Overlay `colors.overlay` at `opacity.overlay`.
- **BANNED**: Buttons with borders/backgrounds, cards, containers. All actions are floating text.

## 26. EMERGENT SPACE STATE
- `src/lib/space-state.ts` — `computeSpaceState(items[])` pure function, no DB calls.
- States: `empty` → `exploring` → `converging` → `ready` → `active` → `settled`.
- `empty`: no items. `exploring`: all proposed/voting. `converging`: some locked + some open. `ready`: all items settled (v1 heuristic). `active`: dates within range + locked items. `settled`: all terminal + dates passed.
- UI reacts to computed state for ambient atmosphere adjustments.
