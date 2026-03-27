# Xark OS v2.0 — Intelligence + Daily Use Design Spec

**Date**: 2026-03-14
**Status**: Approved (brainstorming complete)
**Goal**: Evolve @xark from trip planner to daily-use human companion. Target: daily usage, not user count. Planet-scale scalability, Apple-scale robustness, secure and private with AI grounding.

**Constitutional amendments**: This spec introduces a second theme (midnight) and two Galaxy layouts (stream, split). CLAUDE.md, CONSTITUTION.md, and .xark-state.json must be updated during implementation to reflect these changes. The "1 Theme" lock becomes "2 Themes" with hearth as default.

**Color SSOT**: `src/lib/theme.ts` is the single source of truth. Hearth values: bg `#F8F7F4`, text `#111111`, accent `#FF6B35`. All color references in this spec use theme.ts values.

**Prerequisites**: Migration `012_perf_optimizations.sql` must be applied before `013_daily_use.sql`.

---

## Section 1: Intelligence Architecture

### Two-Tier Intelligence Stack

**Tier 1 — Gemini Search Grounding (local, free)**
- `tools: [{ googleSearch: {} }]` in Gemini API call
- Returns structured local data: phone numbers, hours, addresses, ratings, reviews
- Use case: "find me a sushi place near downtown" — Gemini returns real Google results with contact info
- No Apify cost, no scraping, instant response

**Tier 2 — Apify Deep Search (travel, e-commerce)**
- Existing tool registry: booking-scraper, airbnb, flight search, activity search
- Use case: hotel comparison, flight pricing, Airbnb listings — structured data that requires scraping
- Higher latency, cost per call, richer data

**Intelligence Orchestrator routing** (`src/lib/intelligence/orchestrator.ts`):
- Local queries (restaurants, bars, activities, phone numbers) → Gemini Search first
- Travel/booking queries (hotels, flights, airbnb) → Apify actors
- Ambiguous → Gemini Search first, escalate to Apify if results insufficient
- Tool registry in `tool-registry.ts` adds a new `tier` field per tool: `"gemini-search" | "apify"`

**Gemini Search implementation details:**
- Uses `generateContent()` with `tools: [{ googleSearch: {} }]` parameter
- The orchestrator checks tool tier before routing: if `tier === "gemini-search"`, call Gemini with search grounding; if `tier === "apify"`, call existing Apify actor path
- Tier 1 results are upserted as decision_items (same as Tier 2) with `metadata.search_tier: "gemini-search"` for tracking
- Phone numbers from Gemini Search are extracted from grounding chunks and stored in `metadata.phone` on the decision_item
- Local query detection: keyword matching against categories like "restaurant", "bar", "cafe", "gym", "salon", "store", "nearby" — anything Google Maps would answer well
- Travel query detection: "hotel", "flight", "airbnb", "booking", "hostel" — structured scraping needed

### Grounding Layer (existing, enhanced)

`buildGroundingContext(spaceId)` remains the core. State map approach:
- Locked items: do not reopen
- Voting items: respect current signal
- Proposed items: fair game
- Empty categories: suggest freely

### Privacy — Message Sanitizer

**`src/lib/intelligence/sanitize.ts`** — PII redaction before Gemini calls.

Applied to last 15 messages before they enter the Gemini prompt. Messages stay as-is in Supabase (users typed them, they should see them). Only the copy sent to intelligence gets scrubbed.

**What it strips (regex, Luhn-validated, no AI):**
- Credit/debit card numbers: 13-19 digit sequences with optional spaces/dashes, Luhn-validated to avoid false positives
- SSN patterns: XXX-XX-XXXX
- Bank routing/account numbers: 8-17 digit sequences preceded by keywords (account, routing, iban)
- CVV/CVC: 3-4 digit sequences preceded by cvv, cvc, security code

**What it does NOT strip:**
- Phone numbers (intentional — restaurant numbers from Gemini Search are valuable)
- Addresses (needed for logistics context)
- Names (needed for social reasoning)

```typescript
export function sanitizeForIntelligence(messages: ChatMessage[]): ChatMessage[] {
  return messages.map(m => ({
    ...m,
    content: redactPII(m.content)
  }));
}
```

Redacted content replaced with `[redacted]`. Pure function, server-side only in `/api/xark`, <1ms latency.

### Confirmation Flows (existing, unwired)

Backend already handles `pendingConfirmation` flag from `/api/xark` for actions like `set_dates` and `populate_logistics`. Space page currently ignores this flag.

Implementation: When `/api/xark` returns `pendingConfirmation`, the Space page renders a confirmation whisper inline in the chat stream (same style as handshake whisper — floating text, "confirm" / "wait" options). On confirm, Space page calls the pending action endpoint. No new component needed — reuse the existing handshake whisper pattern from `useHandshake.ts`.

---

## Section 2: User-Created Decision Items + Share Pipeline

### Problem
Decisions live only inside xark. People discover things everywhere — Instagram, Amazon, Google Maps, a friend's text. Getting those into the decision stream must be effortless.

### Three Entry Paths, One Destination (decision_items table)

**Path A — Share Sheet (primary, mobile-native)**

User finds something anywhere on phone → Share → picks xark → picks space → done.

- `share_target` in manifest.json (Android PWA). iOS: clipboard detection as interim, native share via future wrapper.
- Shared content types:
  - **URL**: Server-side OG metadata extraction → auto-populates decision card (title, image, price, description)
  - **Image/screenshot**: Firebase Storage, displayed as card photo. No AI vision. The image IS the content.
  - **Text**: Plain text becomes item title + description.
- Flow: share → xark opens → space picker (recent spaces, sorted by last activity) → item appears in Decide stream as "proposed". Under 3 taps.

**Path B — In-chat paste**

User pastes URL in chat input. xark detects URL pattern, offers subtle prompt: "add to decisions?" (floating text, not modal). Yes → OG extraction → decision card. No/ignore → stays as message.

**Path C — Camera/screenshot in-app**

Existing camera icon in ChatInput. Tap → capture or gallery → goes directly to Decide stream in current space.

### OG Link Preview Card

Looks exactly like a hotel card today. Photo top 40% (from og:image), title, subtitle (site name), price if present. Same DecisionCard component, same 3 sizes. No new component.

### Server-Side OG Extraction

`src/lib/og-extract.ts`: fetch URL, parse `<meta property="og:...">` tags, return `{ title, image, description, price?, siteName }`. Runs in /api route (CORS). Cached in decision_item metadata.

---

## Section 3: Micro-Spaces + Instant Invite + Galaxy

### Space Lifecycle

Conceptual arc (maps to existing `SpaceState` type in `space-state.ts`):
```
empty → exploring → converging → ready → active → settled
```

No new states added. The existing `computeSpaceState(items[])` already handles the full lifecycle. The "memory" concept is a UI behavior within `settled` state — settled spaces with media attached render as photo streams via `MemoriesView.tsx`. The "born" concept is `empty` state (space created, no items yet).

### Micro-Space Templates

One-tap creation with pre-loaded structure. `src/lib/space-templates.ts` — pure data, no UI logic.

| Template | Pre-loaded categories | Default lifetime | Example |
|---|---|---|---|
| dinner tonight | restaurant, time | 8 hours | "where should we eat?" |
| weekend plan | activity, place | 3 days | "what are we doing saturday?" |
| trip | hotel, flight, activity, restaurant | 30 days | "san diego spring break" |
| buy together | product, store | 7 days | "gift for mom's birthday" |
| watch/listen | movie, show, music | 24 hours | "movie night picks" |
| open | (none) | no expiry | freeform |

**Auto-settle**: When lifetime expires AND all items are terminal (purchased/chosen/decided) or space is empty, `computeSpaceState()` returns `settled`. Settled spaces sink in Galaxy, dimmed. Not deleted — they become memories (photos/videos in MemoriesView).

**Auto-settle mechanism**: Evaluated client-side on Galaxy page load. `computeSpaceState()` already checks dates for settled/active transitions. Template lifetime adds an `expires_at` column on `spaces` table (set at creation: `created_at + template.lifetime`). `computeSpaceState()` receives `expires_at` as an optional parameter — if past and no active items, returns `settled`. No server-side cron needed for v1.

### Micro-Spaces as Shared Media Containers

The space lifecycle serves the full arc of a human moment: plan it → decide it → live it → remember it.

- **During event**: Camera icon uploads directly to Firebase Storage (E2EE), metadata in Supabase. Already built in `media.ts`.
- **After event**: `MemoriesView.tsx` renders photo/video stream. Space sinks in Galaxy as a memory.
- **Live capture**: Space stays "active" during event window. Everyone's uploads appear in real-time via Supabase Realtime.
- **Video support**: Firebase Storage handles any blob. Short clips (< 60s, max 50MB) inline playback in MemoriesView. Client-side compression for videos > 50MB before upload.

Replaces: AirDrop sharing, "send me the pics" WhatsApp groups, Google Photos shared albums.

### Instant Invite — No Accounts Required

User creates micro-space → gets link (e.g., `xark.app/j/abc123`). Share via iMessage, WhatsApp, text.

- Recipient taps link → lands in space. Name prompt (one field, no signup). Can vote, propose, chat immediately.
- Join tokens: short-lived UUID in `space_invites` table. Maps to space_id.
- Name-only participants: `user_id = "name_[input]"`, same as current dev auth pattern.
- Upgrade path: phone OTP signup later merges name_* identity via invite token history.

**`space_invites` table schema:**
```sql
CREATE TABLE space_invites (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  token TEXT UNIQUE NOT NULL DEFAULT encode(gen_random_bytes(6), 'hex'),  -- short 12-char token
  space_id TEXT NOT NULL REFERENCES spaces(id),
  created_by TEXT NOT NULL,         -- user who created the invite
  expires_at TIMESTAMPTZ NOT NULL DEFAULT now() + interval '7 days',
  max_uses INTEGER DEFAULT NULL,    -- null = unlimited
  use_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX idx_space_invites_token ON space_invites(token);
```

**Join flow for name-only users** (`src/app/j/[token]/page.tsx`):
- Client-side page renders name prompt
- On submit: POST to `/api/join` with `{ token, displayName }`
- `/api/join/route.ts` uses supabaseAdmin (bypasses RLS) to: validate token + check expiry + increment use_count + upsert user with `id: "name_[displayName]"` + insert space_member + sign JWT via jose (same as dev-auto-login pattern)
- Returns JWT → client calls `setSupabaseToken(jwt)` → redirects to space
- This bypasses the existing `join_via_invite()` RPC which requires `auth.uid()` — the server route handles auth for name-only users directly

### People-First Galaxy

**People dock — fixed at bottom, thumb zone:**

Faces of everyone you share spaces with. Sorted by last chat activity. Tap face → opens 1:1 sanctuary. Most active contacts sort left (closest to thumb). ~6 visible, scroll for more. [+] at end for inviting new person.

**Awareness stream — scrolls above:**

Calm consensus summaries from `awareness.ts`. Not action items. Not urgency. Just state:
- "san diego trip — 2 locked, 1 exploring"
- "dinner tonight — 3 exploring"

Tap any → opens that space. No hunting for where to vote — the awareness stream surfaces it.

**People dock serves three purposes with one UI element:**
1. Private chat entry (tap → sanctuary)
2. Ambient awareness (subtle preview of recent activity on avatar)
3. Social map (who's in your world)

**[+] in People Dock** replaces the existing "invite a person" initiation seed in ControlCaret. Single entry point for adding new contacts.

---

## Section 4: Component Architecture + Theme System + Keyboard

### Loose Coupling — 30-Minute Layout Swaps

Every Galaxy zone is an independent component with zero knowledge of siblings:

```
GalaxyPage (layout shell — picks from layout registry)
  ├── AwarenessStream    → props: userId, onSpaceTap
  ├── PeopleDock         → props: userId, onPersonTap
  └── ControlCaret       → (already independent)
```

Each component fetches its own data (or receives via props), emits callbacks, has no position awareness. Parent layout shell decides placement.

### GalaxyLayout Registry

```typescript
const LAYOUTS = {
  stream: StreamLayout,
  split: SplitLayout,
} as const;

interface GalaxyLayoutProps {
  awarenessStream: ReactNode;
  peopleDock: ReactNode;
  controlCaret: ReactNode;
}
```

**Layout A — Stream (default):**
```
┌─────────────────────────┐
│   awareness stream      │  ← scroll zone
│   (consensus summaries) │
│                         │
│   ○ ○ ○ ○ ○ ○  [+]    │  ← people dock (thumb zone)
├──────────[●]────────────┤  ← ControlCaret
```

**Layout B — Split:**
```
┌─────────────────────────┐
│            │            │
│  private   │  awareness │
│  chats     │  stream    │
│  (people)  │  (groups)  │
│            │            │
├──────────[●]────────────┤  ← ControlCaret
```

Split: private chats on LEFT, awareness stream on RIGHT.

Adding a third layout = one new component, one registry entry. Components never know which layout they're in.

### Two Themes — Hearth + Midnight

Colors from theme.ts SSOT. Midnight values are new additions:

```
hearth (light, default)        midnight (dark)
─────────────────              ─────────────
bg:     #F8F7F4 (warm paper)   bg:     #0A0A0F (deep dark)
text:   #111111 (dark ink)     text:   #E8E6E1 (light ink)
accent: #FF6B35 (orange)      accent: #40E0FF (cyan)
amber:  #9E6A06               amber:  #D4A017 (brighter for dark bg)
gold:   #8B6914               gold:   #C9A81E (brighter for dark bg)
green:  #047857               green:  #10B981 (brighter for dark bg)
orange: #C43D08               orange: #E8590C
gray:   #8A8A94               gray:   #8A8A94
```

`ThemeName` type expands: `"hearth" | "midnight"`. `themes` Record gets midnight entry.

Implementation:
- New color map object in `theme.ts` (~50 lines)
- `ThemeProvider` reads user preference, applies correct map to CSS variables
- Toggle in UserMenu system settings
- All components already use `var(--xark-void)`, `var(--xark-white)`, `textColor()` — zero component changes

### Keyboard Color Fix (Multi-Layer)

**Root cause**: layout.tsx has static `viewport: { themeColor: "#F8F7F4" }` which Next.js compiles into `<meta name="theme-color">` at build time — never updates. ThemeProvider sets `root.style.colorScheme = t.mode` but does NOT update the meta tag. The user confirmed that adding dynamic meta tag update alone did not fix the issue.

**Fix approach (layered, each layer targets different browsers/OS):**

1. **Remove static themeColor from layout.tsx viewport config** — it conflicts with dynamic updates
2. **ThemeProvider adds `updateThemeColor(hex: string)` method:**
   ```typescript
   // Called in applyTheme() after setting CSS variables
   const meta = document.querySelector('meta[name="theme-color"]');
   if (meta) meta.setAttribute("content", hex);
   else {
     const m = document.createElement("meta");
     m.name = "theme-color";
     m.content = hex;
     document.head.appendChild(m);
   }
   ```
3. **ChatInput textarea explicit styling** — the most reliable iOS keyboard fix:
   - `background-color: var(--xark-void)` on the textarea element
   - `color: var(--xark-white)` on the textarea element
   - iOS reads the input element's computed background color to determine keyboard appearance
   - This works even when system is in dark mode
4. **`color-scheme` on inputs** — already in globals.css line 139, but must be theme-aware:
   - hearth: `color-scheme: light`
   - midnight: `color-scheme: dark`
   - ThemeProvider updates this per theme
5. **Device testing matrix**: iOS Safari 16+, Chrome Android, Samsung Internet. Each handles keyboard color differently. The textarea background approach (step 3) is the most universally reliable.

### User Preferences

Stored in Supabase `users.preferences` (JSONB column):
```json
{
  "theme": "hearth",
  "layout": "stream"
}
```

Accessible from UserMenu → system settings. Two toggles. Persists across sessions and devices.

---

## Section 5: Booking Bridge + Settlement

### Flow

```
consensus (80%) → handshake lock → claim ("i'll handle this") → book externally → confirm + enter amount → settlement splits
```

Already built: handshake.ts, claims.ts, ledger.ts, PurchaseSheet.tsx, venmo/upi deep links.

### Card as Booking Bridge

Decision card metadata contains URL (from Apify search / OG extraction) or phone number (from Gemini Search).

- **Locked item + claimed**: Tap card → opens booking URL directly (booking.com page, airbnb listing, restaurant page). User books externally, returns to xark, taps card again → PurchaseSheet → enters amount → done.
- **Restaurant with phone**: Tap card → native phone dialer opens with number. Call to reserve, return, confirm.
- No in-app booking. No payment processing. xark surfaces the link/phone, human does the booking.

### Settlement

- `ledger.ts` calculates per-person splits from purchased items (memberCount bug B3 already fixed — uses space_members query)
- Deep links: venmo://paycharge, upi://pay — one-tap payment
- Visible in ItineraryView when space reaches "active" state
- "settle up" section shows who owes whom with payment links

---

## Section 6: Daily Use + Growth Strategy

### Daily Decision Moments

| Frequency | Moment | Template |
|---|---|---|
| Daily | "where should we eat tonight?" | dinner tonight |
| Daily | "what should we watch?" | watch/listen |
| Weekly | "what are we doing this weekend?" | weekend plan |
| Weekly | "group grocery run" | buy together |
| Monthly | "birthday gift for alex" | buy together |
| Quarterly | "trip planning" | trip |

### Organic Growth Loop

```
user creates "dinner tonight" space
  → shares link via iMessage/WhatsApp to 3 friends
    → friends join (no signup, name-only)
      → they experience frictionless group decision-making
        → they create their own space next time
          → they invite THEIR friends
```

Every micro-space is a viral moment. The invite link IS the acquisition channel.

### Conversion Path

1. First visit: name-only, no friction, full participation
2. Second visit: "save your spaces" prompt → phone OTP signup
3. After signup: their face appears in other people's Galaxy → they're in the network

### Retention = Daily Decisions

The person who used xark for "dinner tonight" opens it again tomorrow. The people dock shows friends. The awareness stream shows what's happening. They check xark like WhatsApp — not for messages, but for "what's the plan?"

### Why Xark Wins vs Group Chat

- WhatsApp: 47 messages, no resolution, someone texts "so what are we doing?"
- Xark: 3 options proposed, everyone reacts, consensus reached, done. 2 minutes.

### Push Notifications (FCM, already built)

- "dinner tonight — 3 options, pick one" (new proposals)
- "consensus reached on sushi spot" (handshake)
- "nina shared photos from saturday" (memory phase)

No spam. Only meaningful state changes.

### Privacy as Growth Feature

- @xark is deaf until invoked
- PII scrubbed before intelligence calls
- No passive data collection, no ads, no tracking
- "the app that doesn't spy on your group chats" — the marketing message

### Growth Math

- 1 user creates 1 space → invites 3 friends
- 1 of 3 creates a space next week → invites 3 more
- 10 weeks organic = ~10,000 exposed users
- 20% retention (daily decisions) = 2,000 daily active users
- Push notifications re-engage lapsed users for new invitations

No paid acquisition. Product IS the growth channel.

---

## Files to Create/Modify

### New Files
- `src/lib/intelligence/sanitize.ts` — PII redaction (regex + Luhn)
- `src/lib/og-extract.ts` — server-side OG metadata extraction
- `src/lib/space-templates.ts` — micro-space template definitions
- `src/hooks/useKeyboard.ts` — visualViewport keyboard height detection, returns `{ keyboardHeight: number, isKeyboardOpen: boolean }`. ChatInput uses `keyboardHeight` to set `bottom` style. ControlCaret hides when `isKeyboardOpen`. Uses `window.visualViewport` resize event (iOS 13+, all Android)
- `src/components/os/GalaxyLayout.tsx` — layout registry + stream/split layouts
- `src/components/os/AwarenessStream.tsx` — extracted from Galaxy page
- `src/components/os/PeopleDock.tsx` — faces dock component
- `src/components/os/SpacePicker.tsx` — space selection for share sheet flow
- `src/app/j/[token]/page.tsx` — instant invite join page
- `src/app/api/og/route.ts` — OG extraction API endpoint
- `src/app/api/share/route.ts` — POST endpoint for Android PWA share_target (receives shared URL/text/files, returns redirect to space picker)
- `src/app/api/join/route.ts` — POST endpoint for name-only invite join (validates token, creates user, signs JWT via jose, bypasses RLS via supabaseAdmin)
- `supabase/migrations/013_daily_use.sql` — space_invites table, users.preferences JSONB column, spaces.expires_at column, indexes

### Modified Files
- `src/lib/theme.ts` — midnight theme color map
- `src/components/os/ThemeProvider.tsx` — dynamic meta theme-color, theme switching
- `src/lib/intelligence/orchestrator.ts` — Gemini Search grounding integration
- `src/lib/intelligence/tool-registry.ts` — search tier routing
- `src/app/api/xark/route.ts` — sanitizeForIntelligence() before Gemini call
- `src/app/galaxy/page.tsx` — significant refactor: extract awareness fetching + rendering into AwarenessStream.tsx, extract personal chats + people rendering into PeopleDock.tsx. Galaxy page becomes a thin shell that picks layout and passes components. State that stays in Galaxy: userId, layout preference. State that moves to children: awareness data (AwarenessStream), personal chats + contacts (PeopleDock). Space creation logic stays in Galaxy (shared across layouts)
- `src/components/os/UserMenu.tsx` — theme + layout toggles
- `src/components/os/ChatInput.tsx` — URL detection, keyboard color fix
- `src/components/os/ClaimSheet.tsx` — booking link surfacing
- `src/components/os/DecisionCard.tsx` — tappable booking URL for locked/claimed items
- `src/lib/space-state.ts` — add optional `expiresAt` parameter to `computeSpaceState()` for template lifetime auto-settle
- `src/app/space/[id]/page.tsx` — wire pendingConfirmation UI
- `public/manifest.json` — share_target config, dynamic theme_color
- `src/app/layout.tsx` — remove static themeColor (handled by ThemeProvider)

---

## Architecture Principles

1. **Loose coupling**: Every component fetches its own data, emits callbacks. No sibling awareness. Layout changes in 30 minutes.
2. **Privacy by design**: PII never reaches external APIs. @xark deaf until invoked. No passive listening.
3. **Progressive disclosure**: Name-only → OTP signup → full member. No gates on participation.
4. **Template-driven spaces**: Pure data templates, no UI logic. New space types = new data entry.
5. **Card as bridge**: Decision cards link to external booking. No in-app payment processing.
6. **Media as memory**: Spaces hold photos/videos. Events become albums. Replace AirDrop/WhatsApp sharing.
7. **Thumb-arc navigation**: Most frequent actions at bottom of screen. People dock in thumb zone.
8. **AI vision scope**: Shared images/screenshots are NOT analyzed by AI — the image IS the content, humans interpret it. Voice input (long-press mic) still uses Gemini for speech understanding. These are separate features.
9. **OG cache**: Metadata fetched once at item creation, stored in decision_item metadata. No refresh mechanism for v1 (known limitation — price changes won't update).
