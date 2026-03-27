# Xark OS v2.0 — Session Dispatch

## Pre-Flight: Manual Steps (Run BEFORE Any Session)

### SQL Migrations (run in Supabase SQL Editor, in order)

All 4 migrations must be deployed before sessions start. Copy each SQL block and execute in the Supabase Dashboard → SQL Editor.

**Migration 1: `005_media_devices.sql`** (Task 8.1)
**Migration 2: `006_unreact_and_realtime.sql`** (Task 3.1)
**Migration 3: `007_system_messages_rpc.sql`** (Task 5.4)
**Migration 4: `008_join_via_invite.sql`** (Task 6.1)

The full SQL for each is in the implementation plan. Find them by searching for the filename.

### Environment Variables (add to `.env.local`)

```
GEMINI_API_KEY=<your-gemini-key>
APIFY_API_TOKEN=<your-apify-token>
FIREBASE_SERVICE_ACCOUNT_JSON=<json-string>
```

### NPM Packages (install once)

```bash
npm install @google/generative-ai apify-client firebase-admin
```

### Package Note

After `npm install`, commit `package.json` + `package-lock.json` before launching sessions:
```bash
git add package.json package-lock.json .env.example
git commit -m "chore: add intelligence + media + notification dependencies"
```

---

## Execution Waves

```
WAVE 1 (parallel — launch Sessions 1, 2, 3 simultaneously):
├── Session 1: Core Engine + Commitment Logic
├── Session 2: Intelligence + Chat Enhancements
└── Session 3: Home Screen + PWA + FCM

WAVE 2 (parallel — launch after Wave 1 merges):
├── Session 4: Decision UI + Space Page
└── Session 5: Media + Notifications + Guardrails
```

### Between Waves

After Sessions 1-3 complete:
1. Merge all 3 branches to `main`
2. Run `npx tsc --noEmit` — verify 0 errors
3. Run `npm run build` — verify clean build
4. Then launch Sessions 4-5

---

## Session 1: Core Engine + Commitment Logic

**Branch:** `feat/core-engine-commitment`
**Tasks:** 0.2, 0.3, 0.4, 3.3, 5.1, 5.2, 5.3, 10.1
**Files owned (ONLY modify these):**
- `src/lib/state-flows.ts` (CREATE)
- `src/lib/space-state.ts` (CREATE)
- `src/lib/spaces.ts` (MODIFY)
- `src/lib/heart-sort.ts` (MODIFY)
- `src/lib/handshake.ts` (MODIFY)
- `src/hooks/useHandshake.ts` (MODIFY)
- `src/lib/claims.ts` (MODIFY)
- `src/components/os/ClaimSheet.tsx` (CREATE)
- `src/components/os/PurchaseSheet.tsx` (CREATE)
- `src/lib/ledger.ts` (MODIFY)

### Prompt

```
You are implementing Xark OS v2.0. You will execute 8 tasks end-to-end. DO NOT STOP until all 8 are committed. Work on branch `feat/core-engine-commitment`.

BOOTSTRAP (execute first, no exceptions):
1. Read CLAUDE.md — primary directives
2. Read CONSTITUTION.md — visual/architectural law
3. Read .xark-state.json — current state
4. Read GROUNDING_PROTOCOL.md — @xark constraints
5. Read docs/superpowers/plans/2026-03-13-xark-full-implementation.md — the implementation plan (your source of truth for all code)

CONSTITUTIONAL NON-NEGOTIABLES:
- NO font-weight above 400. Bold is banned.
- NO borders, cards, rounded-lg (Zero-Box).
- ALL colors from theme.ts CSS variables. No hardcoded hex.
- ALL text sizes from theme.ts text object. No Tailwind text-size classes.
- NO Supabase Auth imports. Auth = Firebase only.
- NO backdrop-filter. Overlays = #000 at opacity 0.8.
- textColor(alpha) and accentColor(alpha) are the APPROVED opacity methods.

YOUR 8 TASKS (execute in this order, commit after each):

TASK 1 — Task 0.2: Extract Shared State Flows Module
- Create src/lib/state-flows.ts with FLOW_TERMINAL_STATES and resolveTerminalState(state, flow?)
- IMPORTANT: "ranked" is intentionally OMITTED from the flat map. resolveTerminalState handles it via flow parameter.
- Refactor src/lib/handshake.ts to import resolveTerminalState from state-flows.ts (remove inline flow map)
- Refactor src/lib/claims.ts to import resolveTerminalState from state-flows.ts (remove inline flow map)
- Run: npx tsc --noEmit — 0 errors
- Commit: "refactor: extract shared state-flows module from handshake + claims"

TASK 2 — Task 0.3: Compute Emergent Space State
- Create src/lib/space-state.ts with computeSpaceState(items[]) pure function
- Returns: empty/exploring/converging/ready/active/settled
- The "ready" comment must say: "v1 heuristic: ready when all items are settled. Full category coverage check is Gemini's job (blueprint Section 2 note)."
- Run: npx tsc --noEmit — 0 errors
- Commit: "feat: add computeSpaceState pure function for emergent space state"

TASK 3 — Task 0.4: Fix Bug B4 — Space Creator Membership
- Read src/lib/spaces.ts
- After space creation, add explicit space_members insert for the creator with role "owner"
- Use upsert with onConflict: "space_id,user_id"
- Run: npx tsc --noEmit — 0 errors
- Commit: "fix: explicitly add space creator to space_members (bug B4)"

TASK 4 — Task 3.3: Port Full Heart-Sort from /algo
- Read /Users/ramchitturi/algo/src/engine/heart-sort.ts (the full algorithm)
- Read the current src/lib/heart-sort.ts (simplified version)
- Port the full engine: DecisionItem, calculateWeightedScore, calculateAgreementScore, getRankedSummary, addReaction, removeReaction
- KEEP existing Possibility type + heartSort() + getConsensusState() for backwards compatibility
- ADD the full interfaces and functions as additional exports
- Rules: all functions PURE (no mutation), agreementScore = ALL reactors / totalMembers, isGroupFavorite strictly > 80%
- Run: npx tsc --noEmit && npm run build — 0 errors
- Commit: "feat: port full heart-sort engine from /algo (DecisionItem, reactions, scoring)"

TASK 5 — Task 5.1: Extend Handshake for Two-Step (Locked = No Owner)
- Read src/lib/handshake.ts (already modified in Task 1 for state-flows import)
- Modify confirmHandshake(): for BOOKING_FLOW items, set state:"locked" + is_locked:true but do NOT stamp owner
- For other flows (SIMPLE_VOTE_FLOW, SOLO_DECISION_FLOW): behavior unchanged, stamp owner
- Update whisper: "locked. waiting for someone to own it."
- Read src/hooks/useHandshake.ts and update post-lock whisper
- Run: npx tsc --noEmit — 0 errors
- Commit: "feat: two-step commitment — locked state has no owner in BOOKING_FLOW"

TASK 6 — Task 5.2: Create Claim Sheet Component
- Read src/lib/claims.ts
- Modify claimItem(): for items in "locked" state (BOOKING_FLOW), transition to "claimed", stamp owner { ownerId, assignedAt, reason: "booker" }. No proof required at claim step.
- Create src/components/os/ClaimSheet.tsx: slide-up sheet
  - Item title at text.listTitle, opacity 0.9
  - "i'll handle this" as floating text (text.label, colors.cyan, opacity 0.9)
  - "not yet" as floating text (text.label, colors.white, opacity 0.4)
  - Sheet: colors.void bg, 40vh max, slide from bottom (Framer Motion)
  - Overlay: #000 at opacity 0.8, NO blur, NO backdrop-filter
  - ZERO-BOX: no buttons with borders/backgrounds
- Run: npm run build — clean
- Commit: "feat: claim sheet for 'i'll handle this' on locked items"

TASK 7 — Task 5.3: Create Purchase Sheet Component
- Create src/components/os/PurchaseSheet.tsx: slide-up for confirming purchase + entering amount
  - Appears when user taps a claimed item they own
  - "how much?" input with cyan underline (text.input styling)
  - Optional unit toggle: "per night" / "per person" / "total" (text.label, tap to cycle)
  - Proof input: "link to confirmation or drop receipt" placeholder (text.input, opacity.ghost)
  - "done" as floating text (colors.cyan, text.label)
  - On submit: updates state to "purchased", sets metadata.price, commitment_proof, ownership
  - Sheet: void bg, 50vh max, slide up, #000 overlay at 0.8
  - ZERO-BOX: no buttons, no boxes, floating text only
- Run: npm run build — clean
- Commit: "feat: purchase sheet with amount entry and proof confirmation"

TASK 8 — Task 10.1: Fix Bug B3 — Settlement Member Count
- Read src/lib/ledger.ts
- Fix fetchSettlement(spaceId): query space_members table for actual member count instead of using entries.length
- fairShare = totalSpent / memberCount (from space_members)
- Run: npx tsc --noEmit — 0 errors
- Commit: "fix: settlement uses true space member count, not just payer count (B3)"

TIER 3 AUDIT (after all commits):
Run: grep -rn "font-bold\|font-semibold\|font-weight: [5-9]00\|supabase/auth\|@supabase/auth\|backdrop-filter\|backdropFilter" on all files you created/modified. If ANY match found, fix and recommit.

FINAL VERIFICATION:
npx tsc --noEmit — 0 errors
npm run build — clean build

DO NOT STOP. Execute all 8 tasks sequentially. Commit after each. If a build fails, fix it before moving to the next task.
```

---

## Session 2: Intelligence + Chat Enhancements

**Branch:** `feat/intelligence-chat`
**Tasks:** 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 5.4
**Files owned (ONLY modify these):**
- `src/lib/intelligence/tool-registry.ts` (CREATE)
- `src/lib/intelligence/apify-client.ts` (CREATE)
- `src/lib/intelligence/orchestrator.ts` (CREATE)
- `src/app/api/xark/route.ts` (CREATE)
- `src/lib/ai-grounding.ts` (MODIFY)
- `src/hooks/useVoiceInput.ts` (CREATE)
- `src/components/os/XarkChat.tsx` (MODIFY)
- `src/lib/messages.ts` (MODIFY)
- `supabase/migrations/007_system_messages_rpc.sql` (CREATE — file only, SQL already deployed)
- `.env.example` (MODIFY)

### Prompt

```
You are implementing Xark OS v2.0. You will execute 7 tasks end-to-end. DO NOT STOP until all 7 are committed. Work on branch `feat/intelligence-chat`.

BOOTSTRAP (execute first, no exceptions):
1. Read CLAUDE.md — primary directives
2. Read CONSTITUTION.md — visual/architectural law
3. Read .xark-state.json — current state
4. Read GROUNDING_PROTOCOL.md — @xark constraints
5. Read docs/superpowers/plans/2026-03-13-xark-full-implementation.md — the implementation plan (your source of truth for all code)

CONSTITUTIONAL NON-NEGOTIABLES:
- NO font-weight above 400. Bold is banned.
- NO borders, cards, rounded-lg (Zero-Box).
- ALL colors from theme.ts CSS variables. No hardcoded hex.
- ALL text sizes from theme.ts text object. No Tailwind text-size classes.
- NO Supabase Auth imports. Auth = Firebase only.
- NO backdrop-filter. Overlays = #000 at opacity 0.8.
- textColor(alpha) and accentColor(alpha) are the APPROVED opacity methods.

IMPORTANT INFRASTRUCTURE NOTES:
- supabaseAdmin already exists at src/lib/supabase-admin.ts — use it for server-side routes instead of inline createClient
- supabase (anon client) exists at src/lib/supabase.ts — use for client-side queries
- @google/generative-ai, apify-client, and firebase-admin are already installed (npm install was done pre-flight)
- SQL migration 007_system_messages_rpc.sql is already deployed in Supabase

YOUR 7 TASKS (execute in this order, commit after each):

TASK 1 — Task 2.1: Create Tool Registry
- Create src/lib/intelligence/ directory
- Create src/lib/intelligence/tool-registry.ts
- Register default tools: hotel, flight, activity, restaurant, general
- Each tool: actorId (Apify actor), description, paramMap function
- Exports: registerTool(), getTool(), listTools()
- See implementation plan Task 2.1 for exact code
- Run: npx tsc --noEmit — 0 errors
- Commit: "feat: add Apify tool registry for @xark intelligence"

TASK 2 — Task 2.2: Create Apify Client
- Create src/lib/intelligence/apify-client.ts
- Import ApifyClient from apify-client
- Safe init: when APIFY_API_TOKEN missing, client is null, runActor returns []
- runActor(actorId, input): runs actor, normalizes results to ApifyResult interface
- Add APIFY_API_TOKEN to .env.example
- See implementation plan Task 2.2 for exact code
- Run: npx tsc --noEmit — 0 errors
- Commit: "feat: add Apify actor client for @xark search"

TASK 3 — Task 2.3: Create Intelligence Orchestrator
- Create src/lib/intelligence/orchestrator.ts
- Import GoogleGenerativeAI from @google/generative-ai
- Model: gemini-2.0-flash (NOT gemini-3.1-ultra)
- Safe init: when GEMINI_API_KEY missing, genAI is null
- orchestrate(input): Step 1 parse intent via Gemini → Step 2 route (search/reason/propose) → Step 3 synthesize results
- @xark voice: silent, precise, no emojis, no personality
- Add GEMINI_API_KEY to .env.example
- See implementation plan Task 2.3 for exact code
- Run: npx tsc --noEmit — 0 errors
- Commit: "feat: add @xark intelligence orchestrator (Gemini + Apify routing)"

TASK 4 — Task 2.4: Rewrite /api/xark Route
- Create src/app/api/xark/route.ts
- CRITICAL: Import supabaseAdmin from @/lib/supabase-admin (NOT createClient from @supabase/supabase-js)
- Silent mode: if message doesn't contain "@xark", return { response: null }
- Strip "@xark" prefix before passing to orchestrator
- Build grounding context + grounding prompt
- Fetch last 15 messages (privacy: on invocation ONLY)
- If search results: insert as decision_items via supabaseAdmin
- See implementation plan Task 2.4 for exact code
- Run: npm run build — clean build
- Commit: "feat: add /api/xark endpoint with Gemini orchestration and silent mode"

TASK 5 — Task 2.5: Fix Bug B1 + B2 in ai-grounding.ts
- Read src/lib/ai-grounding.ts
- B1 FIX: In checkSuggestionConflicts(), change filter from "Locked"/"Finalized" (capitalized) to lowercase: "locked", "purchased", "chosen", "decided"
- B2 FIX: Rewrite generateGroundingPrompt(context) to use state map approach:
  - Group items by state: Locked/Purchased (committed, do not reopen), Voting (has reactions, not locked), Proposed (no reactions), Empty (no items)
  - Include reaction counts per item
  - Append WEIGHTING RULES (-3/+1/+5)
  - Let Gemini reason about scope
- Run: npx tsc --noEmit && npm run build — 0 errors
- Commit: "fix: lowercase state matching (B1) + state map grounding prompt (B2)"

TASK 6 — Task 2.6: Voice Input Hook
- Create src/hooks/useVoiceInput.ts
- v1 simplification: BOTH tap and long-press use on-device SpeechRecognition
- Tap: startListening() — transcribes to text
- Long-press: startXarkListening() — same transcription but auto-prefixes "@xark"
- Gemini multimodal path (audio blob) is deferred to future phase
- Read src/components/os/XarkChat.tsx
- Add mic indicator to Thumb-Arc zone: tap = startListening, long-press (500ms) = startXarkListening
- When isXarkListening: cyan breathing dot + "@xark is listening..." placeholder
- When transcript arrives: populate input field
- Mic is floating text, NOT a button with border/background
- See implementation plan Task 2.6 for exact code
- Run: npm run build — clean build
- Commit: "feat: add voice input (tap: on-device, long-press: @xark mode)"

TASK 7 — Task 5.4: System Messages for Lifecycle Events
- Create supabase/migrations/007_system_messages_rpc.sql (file only — SQL already deployed)
- Read src/lib/messages.ts
- Add saveSystemMessage(spaceId, content): calls supabase.rpc("insert_system_message", ...). Silent fail.
- Add systemMessages preset object: itemLocked, itemClaimed, itemPurchased, memberJoined
- Read src/components/os/XarkChat.tsx (you already modified it in Task 6)
- Add system message rendering: role="system" → text.subtitle (0.65rem), textColor(0.25), centered, no role label, no timestamp, foveal floor 0.15
- Run: npm run build — clean build
- Commit: "feat: system messages via SECURITY DEFINER RPC (RLS-safe)"

TIER 3 AUDIT (after all commits):
Run: grep -rn "font-bold\|font-semibold\|font-weight: [5-9]00\|supabase/auth\|@supabase/auth\|backdrop-filter\|backdropFilter\|createClient" on all files you created/modified. If ANY match found, fix and recommit. NOTE: createClient should NOT appear in any API route — use supabaseAdmin.

FINAL VERIFICATION:
npx tsc --noEmit — 0 errors
npm run build — clean build

DO NOT STOP. Execute all 7 tasks sequentially. Commit after each. If a build fails, fix it before moving to the next task.
```

---

## Session 3: Home Screen + PWA + FCM

**Branch:** `feat/homescreen-pwa-fcm`
**Tasks:** 0.1, 1.1, 1.2, 1.3, 1.4, 9.1
**Files owned (ONLY modify these):**
- `public/manifest.json` (CREATE)
- `public/icons/` (CREATE)
- `src/app/layout.tsx` (MODIFY)
- `src/app/globals.css` (MODIFY)
- `src/lib/awareness.ts` (MODIFY)
- `src/lib/space-data.ts` (MODIFY)
- `src/app/galaxy/page.tsx` (MODIFY)
- `src/components/os/ControlCaret.tsx` (MODIFY)
- `public/firebase-messaging-sw.js` (CREATE)

### Prompt

```
You are implementing Xark OS v2.0. You will execute 6 tasks end-to-end. DO NOT STOP until all 6 are committed. Work on branch `feat/homescreen-pwa-fcm`.

BOOTSTRAP (execute first, no exceptions):
1. Read CLAUDE.md — primary directives
2. Read CONSTITUTION.md — visual/architectural law
3. Read .xark-state.json — current state
4. Read GROUNDING_PROTOCOL.md — @xark constraints
5. Read docs/superpowers/plans/2026-03-13-xark-full-implementation.md — the implementation plan (your source of truth for all code)

CONSTITUTIONAL NON-NEGOTIABLES:
- NO font-weight above 400. Bold is banned.
- NO borders, cards, rounded-lg (Zero-Box).
- ALL colors from theme.ts CSS variables. No hardcoded hex.
- ALL text sizes from theme.ts text object. No Tailwind text-size classes.
- NO Supabase Auth imports. Auth = Firebase only.
- NO backdrop-filter. Overlays = #000 at opacity 0.8.
- textColor(alpha) and accentColor(alpha) are the APPROVED opacity methods.

IMPORTANT NOTES:
- Seed data is already deployed (npx tsx src/lib/seed.ts was run previously)
- The Supabase tables exist: spaces, space_members, decision_items, messages, reactions, users
- Read src/lib/theme.ts to understand all available tokens BEFORE writing any component code
- Read src/hooks/useAuth.ts to understand the auth pattern

YOUR 6 TASKS (execute in this order, commit after each):

TASK 1 — Task 0.1: PWA Manifest + Meta Tags
- Create public/manifest.json (see plan for exact JSON)
- Create public/icons/ with placeholder 192x192 and 512x512 PNG icons (solid #0A0A0A bg with cyan "x")
- Read src/app/layout.tsx
- Add metadata export with manifest, appleWebApp config
- Add SEPARATE viewport export (NOT nested in metadata — Next.js 14+ requirement)
- Read src/app/globals.css
- Append PWA CSS: -webkit-touch-callout:none, user-select:none, overscroll-behavior-y:contain, safe-area padding classes
- Run: npm run build && npm run dev — verify manifest loads in Chrome DevTools → Application
- Commit: "feat: add PWA manifest, meta tags, and safe-area CSS"

TASK 2 — Task 1.1: Wire Awareness Stream to Real Supabase Data
- Read src/lib/awareness.ts
- Ensure fetchAwareness(userId) queries REAL Supabase tables:
  1. space_members (get all spaces for this user)
  2. decision_items (needs_vote, ignited, locked items)
  3. messages (recent messages)
- Build AwarenessEvent[] with priority weights from AwarenessKind
- Apply time decay via exponential function
- KEEP getDemoAwareness() as graceful fallback when Supabase fails
- Run: npm run dev — verify awareness events appear for seeded data
- Commit: "feat: wire awareness stream to real Supabase queries with demo fallback"

TASK 3 — Task 1.2: Wire Space Data to Real Supabase Queries
- Read src/lib/space-data.ts
- Ensure fetchSpaceList(userId) queries REAL tables:
  1. space_members WHERE user_id = userId
  2. spaces with those IDs
  3. Enrich: member names, decision summary via decisionStateLabel(), last message
  4. Sort by lastActivityAt descending
- RLS NOTE: users table has RLS (users_select_self). Co-member lookups may need service-level access. For dev mode, the JWT from dev-auto-login works.
- KEEP DEMO_SPACES as graceful fallback
- Run: npm run dev — verify real space data in ControlCaret
- Commit: "feat: wire space data to real Supabase queries with demo fallback"

TASK 4 — Task 1.3: Galaxy Page — Real Awareness Feed
- Read src/app/galaxy/page.tsx
- Ensure it passes authenticated user's ID (from useAuth hook) to fetchAwareness(uid)
- Verify awareness events render with correct opacity (awarenessOpacity), whisper text, space context, recency
- Test end-to-end: login as "ram" → Galaxy shows events from san diego, ananya, tokyo, summer
- Commit: "feat: Galaxy page renders real awareness feed from Supabase"

TASK 5 — Task 1.4: ControlCaret — Real Space List + Presence
- Read src/components/os/ControlCaret.tsx
- Ensure it calls fetchSpaceList(userId) with authenticated user's ID
- Verify: Avatar (28px, round, no border) + text.listTitle name + text.subtitle members + text.recency timestamps
- Verify Supabase Realtime Presence subscription drives Presence Ember (4px cyan dot)
- Test: tap cyan dot → slide-up shows real spaces with member names
- Commit: "feat: ControlCaret renders real space list from Supabase"

TASK 6 — Task 9.1: FCM Service Worker
- Create public/firebase-messaging-sw.js
- Config injected via postMessage from main thread (not hardcoded)
- Background message handler: shows notification with icon, deep-links to space
- notificationclick handler: opens space URL
- Read src/app/layout.tsx (you already modified it in Task 1)
- Add ServiceWorkerRegistration component: registers SW on mount, posts Firebase config
- Add <ServiceWorkerRegistration /> inside ThemeProvider in layout.tsx
- Only registers if "serviceWorker" in navigator AND NEXT_PUBLIC_FIREBASE_API_KEY exists
- Commit: "feat: FCM service worker for background push notifications"

TIER 3 AUDIT (after all commits):
Run: grep -rn "font-bold\|font-semibold\|font-weight: [5-9]00\|supabase/auth\|@supabase/auth\|backdrop-filter\|backdropFilter" on all files you created/modified. If ANY match found, fix and recommit.

FINAL VERIFICATION:
npx tsc --noEmit — 0 errors
npm run build — clean build

DO NOT STOP. Execute all 6 tasks sequentially. Commit after each. If a build fails, fix it before moving to the next task.
```

---

## Session 4: Decision UI + Space Page

**Branch:** `feat/decision-ui-space-page`
**Tasks:** 3.2, 4.1, 6.1, 10.2, 10.3
**Depends on:** Wave 1 complete (Sessions 1-3 merged to main)
**Files owned (ONLY modify these):**
- `src/hooks/useReactions.ts` (CREATE)
- `src/components/os/PossibilityHorizon.tsx` (MODIFY)
- `src/app/space/[id]/page.tsx` (MODIFY)
- `src/components/os/ItineraryView.tsx` (CREATE)
- `src/components/os/MemoriesView.tsx` (CREATE)
- `supabase/migrations/008_join_via_invite.sql` (CREATE — file only, SQL already deployed)

### Prompt

```
You are implementing Xark OS v2.0. You will execute 5 tasks end-to-end. DO NOT STOP until all 5 are committed. Work on branch `feat/decision-ui-space-page`.

PREREQUISITE: Sessions 1-3 have been merged to main. Pull latest main before starting:
git checkout main && git pull && git checkout -b feat/decision-ui-space-page

BOOTSTRAP (execute first, no exceptions):
1. Read CLAUDE.md — primary directives
2. Read CONSTITUTION.md — visual/architectural law
3. Read .xark-state.json — current state
4. Read GROUNDING_PROTOCOL.md — @xark constraints
5. Read docs/superpowers/plans/2026-03-13-xark-full-implementation.md — the implementation plan
6. Read src/lib/theme.ts — ALL available tokens (you'll need these for every component)
7. Read src/lib/heart-sort.ts — the full ported engine (from Session 1)
8. Read src/lib/space-state.ts — computeSpaceState (from Session 1)

CONSTITUTIONAL NON-NEGOTIABLES:
- NO font-weight above 400. Bold is banned.
- NO borders, cards, rounded-lg (Zero-Box).
- ALL colors from theme.ts CSS variables. No hardcoded hex.
- ALL text sizes from theme.ts text object. No Tailwind text-size classes.
- NO Supabase Auth imports. Auth = Firebase only.
- NO backdrop-filter. Overlays = #000 at opacity 0.8.
- textColor(alpha) and accentColor(alpha) are the APPROVED opacity methods.

IMPORTANT INFRASTRUCTURE:
- supabase (anon client): src/lib/supabase.ts — for client-side queries
- react_to_item RPC: 2 params (p_item_id, p_signal). Uses auth.uid() internally. Column is "signal" not "reaction_type".
- unreact_to_item RPC: 1 param (p_item_id). Uses auth.uid() internally.
- join_via_invite RPC: 1 param (p_space_id). SECURITY DEFINER. Already deployed.
- SQL migration 008_join_via_invite.sql is already deployed

YOUR 5 TASKS (execute in this order, commit after each):

TASK 1 — Task 3.2: Create useReactions Hook
- Create src/hooks/useReactions.ts
- react(itemId, reaction): calls supabase.rpc("react_to_item", { p_item_id, p_signal })
- unreact(itemId): calls supabase.rpc("unreact_to_item", { p_item_id })
- getUserReaction(itemId, userId): queries reactions table, column is "signal" (NOT "reaction_type")
- ReactionType: "love_it" | "works_for_me" | "not_for_me"
- See implementation plan Task 3.2 for exact code
- Run: npx tsc --noEmit — 0 errors
- Commit: "feat: add useReactions hook for item voting"

TASK 2 — Task 4.1: PossibilityHorizon Reaction Surface
- Read src/components/os/PossibilityHorizon.tsx (current placeholder)
- Read src/lib/heart-sort.ts (the full ported engine)
- Read CONSTITUTION.md for visual law
- REWRITE PossibilityHorizon as an Airbnb-style horizontal scroll:
  - Edge-to-edge images with bottom-vignette overlays. NO cards. NO borders.
  - Items sorted by heartSort() using weightedScore
  - Snap-scroll (snap-x, snap-mandatory, snap-center). Hidden scrollbar.
  - Each item: image (metadata.image_url, gradient placeholder fallback), title (text.listTitle), price, source
  - Reaction signals as FLOATING TEXT — Love It (amber), Works For Me (gray), Not For Me (orange)
  - Tapped reaction glows to full opacity, others fade to 0.2
  - ConsensusMark for consensus state
  - Wire useReactions() for voting
  - Amber atmospheric wash intensity driven by weightedScore via amberWash()
  - Data: fetch decision_items WHERE space_id AND is_locked = false
  - Subscribe to Supabase Realtime for live score updates
  - ZERO-BOX: no rounded corners, no cards, no button borders. Reactions are floating text.
- Run: npm run build — clean build
- Commit: "feat: PossibilityHorizon reaction surface with voting and live scores"

TASK 3 — Task 6.1: Share Link + Join via Invite
- Create supabase/migrations/008_join_via_invite.sql (file only — already deployed)
- Read src/app/space/[id]/page.tsx
- Enhance share action: generates URL with ?invite=true
- Mobile: navigator.share({ title, text, url })
- Desktop: clipboard copy + "link copied" whisper 2s
- Handle invite=true query param:
  1. If not logged in → redirect to /login?redirect=/space/{id}&invite=true
  2. After login → call supabase.rpc("join_via_invite", { p_space_id })
  3. System message auto-inserted by RPC
  4. Remove ?invite=true from URL
- Commit: "feat: share link + join_via_invite RPC (RLS-safe membership)"

TASK 4 — Task 10.2: Create Itinerary View
- Create src/components/os/ItineraryView.tsx
  - Fetches decision_items WHERE state IN ('purchased', 'locked', 'claimed')
  - Ordered by metadata.date or metadata.check_in ascending
  - Date label (text.recency), ConsensusMark (ignited), title (text.listTitle), cost + owner (text.subtitle)
  - 1px timeline line at opacity 0.1
  - Framer Motion staggered entrance
  - Empty: "no confirmed plans yet" at opacity 0.2
  - ZERO-BOX: no cards, no borders. Float on timeline.
- Read src/app/space/[id]/page.tsx (you already modified in Task 3)
- Add "itinerary" as third view toggle (floating text alongside "discuss" / "decide")
- Only visible when computeSpaceState(items) returns "ready", "active", or "settled"
- Commit: "feat: itinerary view with chronological purchased items"

TASK 5 — Task 10.3: Create Memories View (Post-Trip)
- Create src/components/os/MemoriesView.tsx
  - Photos in horizontal scroll (snap-x, snap-mandatory, snap-center) grouped by date
  - Edge-to-edge images, bottom vignette, caption at text.body opacity 0.7
  - "trip details" as floating text (text.hint, opacity 0.25) — tap expands itinerary + settlement
  - Empty: "no photos yet" at opacity 0.2
  - ZERO-BOX: no cards, no borders
- Read src/app/space/[id]/page.tsx (already modified in Task 4)
- When computeSpaceState returns "settled": show MemoriesView by default
- Toggle becomes: "memories" (default, active) / "details" (itinerary + settlement)
- Commit: "feat: memories view — photo-first post-trip experience"

TIER 3 AUDIT (after all commits):
Run: grep -rn "font-bold\|font-semibold\|font-weight: [5-9]00\|supabase/auth\|@supabase/auth\|backdrop-filter\|backdropFilter" on all files you created/modified. If ANY match found, fix and recommit.

FINAL VERIFICATION:
npx tsc --noEmit — 0 errors
npm run build — clean build

DO NOT STOP. Execute all 5 tasks sequentially. Commit after each. If a build fails, fix it before moving to the next task.
```

---

## Session 5: Media + Notifications + Guardrails

**Branch:** `feat/media-notifications-guardrails`
**Tasks:** 8.2, 8.3, 9.2, 10.4, 7.1, 11.1, 11.2, 11.3, 11.4
**Depends on:** Wave 1 complete (Sessions 1-3 merged) + ideally Session 4 merged
**Files owned (ONLY modify these):**
- `src/lib/media.ts` (CREATE)
- `src/components/os/MediaUpload.tsx` (CREATE)
- `src/app/login/page.tsx` (MODIFY)
- `src/components/os/UserMenu.tsx` (MODIFY)
- `src/lib/notifications.ts` (CREATE)
- `src/app/api/notify/route.ts` (CREATE)
- `src/components/os/Blueprint.tsx` (MODIFY)
- `.xark-state.json` (MODIFY)
- `CLAUDE.md` (MODIFY)
- `CONSTITUTION.md` (MODIFY)
- `GROUNDING_PROTOCOL.md` (MODIFY)
- `supabase/migrations/005_media_devices.sql` (CREATE — file only, SQL already deployed)

### Prompt

```
You are implementing Xark OS v2.0. You will execute 9 tasks end-to-end. DO NOT STOP until all 9 are committed. Work on branch `feat/media-notifications-guardrails`.

PREREQUISITE: Sessions 1-3 have been merged to main. Pull latest:
git checkout main && git pull && git checkout -b feat/media-notifications-guardrails

BOOTSTRAP (execute first, no exceptions):
1. Read CLAUDE.md — primary directives
2. Read CONSTITUTION.md — visual/architectural law
3. Read .xark-state.json — current state
4. Read GROUNDING_PROTOCOL.md — @xark constraints
5. Read docs/superpowers/plans/2026-03-13-xark-full-implementation.md — the implementation plan

CONSTITUTIONAL NON-NEGOTIABLES:
- NO font-weight above 400. Bold is banned.
- NO borders, cards, rounded-lg (Zero-Box).
- ALL colors from theme.ts CSS variables. No hardcoded hex.
- ALL text sizes from theme.ts text object. No Tailwind text-size classes.
- NO Supabase Auth imports. Auth = Firebase only.
- NO backdrop-filter. Overlays = #000 at opacity 0.8.
- textColor(alpha) and accentColor(alpha) are the APPROVED opacity methods.

IMPORTANT INFRASTRUCTURE:
- supabaseAdmin: src/lib/supabase-admin.ts — for ALL server-side routes. NEVER use inline createClient.
- supabase: src/lib/supabase.ts — for client-side queries
- Firebase Storage: src/lib/firebase.ts exports `storage` (nullable). Consumers MUST null-check.
- firebase-admin is already installed
- SQL migrations 005-008 are already deployed

YOUR 9 TASKS (execute in this order, commit after each):

TASK 1 — Task 8.2: Media Upload Library
- Create supabase/migrations/005_media_devices.sql (file only — SQL already deployed)
- Create src/lib/media.ts
  - uploadMedia(file, spaceId, userId, caption?): upload to Firebase Storage → save metadata to Supabase
  - fetchMedia(spaceId): query media table
  - Safe: when Firebase Storage not configured, return null / empty
- Create src/components/os/MediaUpload.tsx
  - "add photo" as floating text (text.hint, opacity 0.35). NOT a button with border.
  - File picker (accept="image/*")
  - Optional caption input (text.input, cyan underline)
  - Upload progress: cyan breathing dot
  - ZERO-BOX: no borders, no buttons
- See implementation plan Task 8.2 for exact code
- Run: npm run build — clean build
- Commit: "feat: media upload via Firebase Storage with Supabase metadata"

TASK 2 — Task 8.3: Profile Photo Upload
- Read src/app/login/page.tsx
- After name input (transit phase), add optional photo upload:
  - "add a photo" floating text (text.hint, opacity 0.35)
  - "skip" floating text (text.hint, opacity 0.2)
  - Upload to profiles/{userId}/avatar in Firebase Storage
  - Save URL to users.photo_url in Supabase
  - Max 2MB, compress client-side if needed
- Read src/components/os/UserMenu.tsx
- Show profile photo if photo_url exists
- Commit: "feat: profile photo upload at login + display in UserMenu"

TASK 3 — Task 9.2: Notification Library + API Route
- Create src/lib/notifications.ts
  - Firebase Admin SDK singleton initialization
  - sendPush(tokens, title, body, data?): sends multicast FCM notification
  - Safe: when firebase-admin not configured, no-op
- Create src/app/api/notify/route.ts
  - CRITICAL: Import supabaseAdmin from @/lib/supabase-admin (NOT createClient)
  - Query space_members for user IDs, then user_devices for FCM tokens
  - Send push via sendPush()
  - See implementation plan Task 9.2 for exact code (uses supabaseAdmin, not createClient)
- Run: npm run build — clean build
- Commit: "feat: notification service with FCM push via /api/notify"

TASK 4 — Task 10.4: Enhanced Blueprint Settlement
- Read src/components/os/Blueprint.tsx
- Verify it fetches items in claimed and purchased states (is_locked = true)
- Enhance Settlement Strip:
  - Total committed amount
  - Per-user breakdown: "[name] paid $[total] — [item1 $X, item2 $Y]"
  - Debt deltas: "[name] owes [name] $[amount]"
  - Payment links: "venmo" and "upi" as floating cyan text (no buttons)
  - All amounts from metadata.price
- Commit: "feat: enhanced settlement display with real purchased amounts"

TASK 5 — Task 7.1: Handshake Verification (no file changes, verification only)
- Check that handshake.ts, useHandshake.ts, claims.ts, ClaimSheet.tsx, PurchaseSheet.tsx all exist and compile
- Run npm run build — verify clean
- Document any issues found, fix them, commit with: "fix: handshake verification fixes from end-to-end test"
- If no issues, skip the commit

TASK 6 — Task 11.1: Update .xark-state.json
- Read .xark-state.json
- Update foveal_focus: "Full implementation complete. 9 services operational. Next: production hardening."
- Add to component_registry: ClaimSheet, PurchaseSheet, MediaUpload, ItineraryView, MemoriesView, VoiceInput (all "active")
- Add to xark_intelligence: intelligence/orchestrator.ts, intelligence/tool-registry.ts, intelligence/apify-client.ts, notifications.ts, media.ts, state-flows.ts, space-state.ts
- Commit: "sync: update .xark-state.json with full implementation state"

TASK 7 — Task 11.2: Update CLAUDE.md
- Read CLAUDE.md
- Add documentation for ALL new components and modules:
  - Intelligence Service (orchestrator, tool registry, Apify client)
  - state-flows.ts shared module (with flow-aware resolveTerminalState(state, flow?))
  - space-state.ts emergent state (computeSpaceState)
  - ClaimSheet + PurchaseSheet commitment flow
  - Media service (media.ts, MediaUpload.tsx)
  - Notification service (notifications.ts, FCM service worker)
  - ItineraryView + MemoriesView
  - Voice input (useVoiceInput hook)
  - System messages in XarkChat
  - PWA manifest + meta tags
- Update BOOKING_FLOW documentation:
  "proposed → [voting] → locked → claimed → purchased"
  "locked: consensus reached, no owner"
  "claimed: someone stepped up, owner stamped"
  "purchased: proof + amount confirmed, feeds settlement"
- Commit: "sync: update CLAUDE.md with full implementation documentation"

TASK 8 — Task 11.3: Update CONSTITUTION.md + GROUNDING_PROTOCOL.md
- Read CONSTITUTION.md
- Add visual specs for: ClaimSheet, PurchaseSheet, ItineraryView, MemoriesView, voice mic indicator, system messages, MediaUpload
- Read GROUNDING_PROTOCOL.md
- Add voice input section, system message format, update intelligence architecture
- Commit: "sync: update CONSTITUTION.md + GROUNDING_PROTOCOL.md with full spec"

TASK 9 — Task 11.4: Final Build Verification
- Run: npx tsc --noEmit — expect 0 errors
- Run: npm run build — expect clean build
- Run Tier 3 Audit: grep -rn "font-bold\|font-semibold\|font-weight: [5-9]00\|supabase/auth\|@supabase/auth\|backdrop-filter\|backdropFilter\|createClient" src/
  - createClient should ONLY appear in src/lib/supabase.ts and src/lib/supabase-admin.ts (the actual client construction files)
  - If found elsewhere, fix and recommit
- Commit: "chore: final build verification — all clear"

DO NOT STOP. Execute all 9 tasks sequentially. Commit after each. If a build fails, fix it before moving to the next task.
```

---

## Post-Dispatch

After all 5 sessions complete:

1. Merge all branches to main (in order: Session 4, Session 5)
2. Run final verification:
   ```bash
   npx tsc --noEmit
   npm run build
   npm run dev
   ```
3. Smoke test the full lifecycle:
   - Login → Galaxy → create space → add items → react → consensus → lock → claim → purchase → settlement
