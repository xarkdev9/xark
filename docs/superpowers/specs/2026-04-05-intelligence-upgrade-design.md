# @hello Intelligence Tier Upgrade — Design Spec

**Date:** 2026-04-05
**Author:** Ram + Claude Opus 4.6
**Status:** Draft
**Scope:** 13 pieces — fli flights, flight cache, deep-links, SearchAPI retention, geospatial-validated auto-itinerary, living itinerary (slot mutations), dreaming mode (date-less planning), AI-mediated conflict resolution, proof-of-life grounding, recommendation engine, BYOAI architecture, Gemini Pro upgrade, airline logos

---

## 1. Problem Statement

The current @hello intelligence tier has three issues:

1. **Flight search is limited.** SearchAPI `google_flights` returns max 10 results with minimal data. The fli library (Google Flights reverse-engineered API) returns 30-150 results with airline codes, exact times, multi-leg layover data, and cheapest-date search — for free, with no API key.

2. **No auto-itinerary.** When a group sets trip dates and destination, nothing happens. The `ItineraryView` component exists (228 lines) but only displays manually committed items. There is no day-by-day plan generation.

3. **Recommendation engine is stub.** Discovery system architecture exists (provider registry, 8 API routes, types) but `GeminiEnrichmentProvider` returns template strings and `ApifyScrapingProvider` returns empty arrays. Taste scores exist in the data model but aren't used for filtering.

4. **Response quality degrading.** Gemini 2.5 Flash (current model) produces lower quality synthesis and itinerary planning than Gemini 2.5 Pro. System prompt is tuned but model capability is the bottleneck.

5. **Vendor lock-in.** All AI intelligence is hardwired to Gemini. No abstraction layer exists to swap providers. Future BYOAI (Bring Your Own AI) would require rewriting the orchestrator.

---

## 2. Architecture

```
User message "@hello plan our Bali trip"
    |
    v
+--------------------------------------------------+
|  AIProvider interface (BYOAI-ready)               |
|  Default: GeminiProvider (gemini-2.5-pro)         |
|  Future: ClaudeProvider, OpenAIProvider, etc.     |
|  Methods: parseIntent(), plan(), synthesize()     |
+------------------+-------------------------------+
                   |
          Gemini native function calling
          (10 existing + 1 new: generate_itinerary)
                   |
    +--------------+--------------+----------------+
    |              |              |                 |
    v              v              v                 v
 FLIGHTS        HOTELS        LOCAL            ITINERARY
 /api/fli/      SearchAPI     SearchAPI        Gemini Pro
 search         google_       google_          two-pass:
 (Python)       hotels        local            1. skeleton
    |              |              |             2. fill slots
    v              v              v                 |
 fallback:      results       results              v
 SearchAPI                                   Recommendations
 google_flights                              (auto-populated)
    |
    v
 results
    |
    v
+--------------------------------------------------+
|  OUTPUT: decision_items + recommendations         |
|  Pre-cached airline logos (727 PNGs)              |
|  ItineraryView + Recommendations section          |
+--------------------------------------------------+
```

---

## 3. Piece 1: fli on Vercel Python Function

### What
A Vercel Python serverless function that wraps the fli library (`pip install flights`) and exposes flight search as HTTP endpoints for the orchestrator to call.

### Files

| File | Purpose |
|------|---------|
| `web/api/fli/route.py` | Vercel Python function — flight search endpoint |
| `web/api/fli/dates/route.py` | Vercel Python function — cheapest dates endpoint |
| `web/api/cron/warm/route.ts` | Cron job pings fli every 5 min to prevent cold starts |
| `web/src/lib/intelligence/fli-client.ts` | TypeScript HTTP client calling `/api/fli/*` |
| `web/public/airline-logos/*.png` | 727 pre-cached airline logo PNGs (7.5 MB total) |
| `web/requirements.txt` | Python deps: `flights>=0.8.0` |

### API Contract

**POST `/api/fli/search`**
```json
// Request
{
  "origin": "JFK",
  "destination": "BKK",
  "date": "2026-08-01",
  "cabin": "economy",
  "max_stops": null,
  "max_results": 20
}

// Response
{
  "results": [
    {
      "price": 528.0,
      "currency": "USD",
      "duration": 1245,
      "stops": 1,
      "legs": [
        {
          "airline": "Qatar Airways",
          "airline_code": "QR",
          "flight_number": "704",
          "departure_airport": "JFK",
          "arrival_airport": "DOH",
          "departure_time": "2026-08-01T11:20:00",
          "arrival_time": "2026-08-02T06:40:00",
          "duration": 740
        },
        {
          "airline": "Qatar Airways",
          "airline_code": "QR",
          "flight_number": "828",
          "departure_airport": "DOH",
          "arrival_airport": "BKK",
          "departure_time": "2026-08-02T08:10:00",
          "arrival_time": "2026-08-02T19:05:00",
          "duration": 415
        }
      ]
    }
  ],
  "count": 150,
  "source": "fli"
}
```

**POST `/api/fli/dates`**
```json
// Request
{
  "origin": "JFK",
  "destination": "BKK",
  "start_date": "2026-07-25",
  "end_date": "2026-08-10"
}

// Response
{
  "dates": [
    { "date": "2026-07-25", "price": 612.0, "currency": "USD" },
    { "date": "2026-07-26", "price": 528.0, "currency": "USD" },
    ...
  ],
  "cheapest": { "date": "2026-07-26", "price": 528.0 },
  "source": "fli"
}
```

### Keep-Warm Strategy

Vercel cron (`vercel.json` or `vercel.ts`):
```json
{ "crons": [{ "path": "/api/cron/warm", "schedule": "*/5 * * * *" }] }
```

`/api/cron/warm` makes a lightweight POST to `/api/fli/search` with a dummy JFK→LAX query. Response is discarded. Purpose: prevent Python cold starts (2-3s) by keeping the function instance alive.

### fli-client.ts

```typescript
// Simplified contract — actual implementation will handle errors, timeouts, normalization
export async function searchFlightsFli(params: {
  origin: string;
  destination: string;
  date: string;
  cabin?: string;
  maxStops?: number;
}): Promise<ApifyResult[]>

export async function searchCheapestDates(params: {
  origin: string;
  destination: string;
  startDate: string;
  endDate: string;
}): Promise<Array<{ date: string; price: number; currency: string }>>
```

### Cascade Order for Flights

```
0. Flight Cache — Vercel KV lookup (instant, <50ms)
       ↓ (cache miss)
1. fli /api/fli/search (primary — 2-5s, 30-150 results, free)
       ↓ (if fails or times out after 10s)
2. SearchAPI google_flights (fallback — 2-5s, 10 results, paid)
       ↓ (if SearchAPI key missing or 0 results)  
3. Apify actor (last resort — 15-40s)
       ↓ (if Apify token missing or 0 results)
4. Gemini Search grounding (text only, no prices)
```

### Flight Intelligence Cache

Protects against fli downtime and speeds up repeat searches on popular routes.

- **Storage**: Vercel KV (or Upstash Redis — already used for rate limiting)
- **Key format**: `flights:{origin}:{destination}:{date}` (e.g., `flights:JFK:BKK:2026-08-01`)
- **TTL**: 4 hours (prices change but not minute-to-minute)
- **Write**: After every successful fli search, cache the top 20 results
- **Read**: Before calling fli, check cache. If hit and <4h old, return immediately
- **Size**: ~2KB per cached route. 1000 cached routes = 2MB. Well within Vercel KV free tier.
- **Invalidation**: TTL-based only. No manual invalidation needed.

### Deep-Links to Booking (Zero-Friction Action Loop)

Every flight card includes a one-click link to Google Flights with the search pre-filled. Users don't have to re-type anything.

**URL construction from fli data:**
```
https://www.google.com/travel/flights/search?tfs=CBwQ...
```

Simplified fallback URL (works for all routes):
```typescript
function buildGoogleFlightsUrl(origin: string, destination: string, date: string): string {
  return `https://www.google.com/travel/flights?q=flights+from+${origin}+to+${destination}+on+${date}`;
}
```

- Stored in `metadata.booking_url` on the decision_item
- DecisionCard renders a "Book" button that opens the URL
- For hotels: `https://www.google.com/travel/hotels/${location}?dates=${checkIn}-${checkOut}`
- For restaurants: `metadata.external_url` from SearchAPI (already returned, currently unused)

### Airline Logos

- 727 PNGs pre-downloaded from `pics.avs.io/200/200/{IATA}.png`
- Served from `web/public/airline-logos/{IATA}.png`
- All 38 major airlines verified present (AA, DL, UA, B6, QR, NH, EK, SQ, LH, BA, etc.)
- Average 8.5 KB per logo, 7.5 MB total
- Flight cards reference logos via `/airline-logos/${airline_code}.png`
- Fallback for missing codes: generic plane icon

---

## 4. Piece 2: SearchAPI Retained for Hotels/Local/General

### What Changes
- `searchFlights()` in `searchapi-client.ts` stays but becomes the fallback (not primary)
- Tool registry: flight tool `tier` changes from `"searchapi"` to `"fli"`
- New tier value: `"fli"` added to ToolDefinition type

### What Stays
- `searchHotels()` — primary for hotel search (google_hotels engine)
- `searchLocal()` — primary for restaurants + activities (google_local engine)
- `searchGeneral()` — primary for knowledge queries (google engine)
- All existing SearchAPI env var and billing — unchanged

### Tool Registry Changes

```typescript
// BEFORE
registerTool("flight", {
  tier: "searchapi",
  searchApiEngine: "google_flights",
  ...
});

// AFTER
registerTool("flight", {
  tier: "fli",
  searchApiEngine: "google_flights",  // kept for fallback
  ...
});
```

---

## 5. Piece 3: Auto-Itinerary via Gemini Pro

### Trigger

When BOTH conditions are met:
1. `space_dates` has `start_date` AND `end_date` set (via `set_dates` action)
2. Space has a destination (from space title matching a location pattern, or explicit `destination` in space metadata)

The orchestrator auto-fires itinerary generation. No user prompt needed.

### Where It Fires

In `/api/local-action/route.ts`, after `update_dates` mutation succeeds:
1. Check if destination is resolvable from space title
2. If yes, call `generateItinerary()` asynchronously (via `after()`)
3. Results written to `decision_items` table with `category: "recommendation"` and `metadata.itinerary_day`

### Two-Pass Generation

**Pass 1: Gemini Pro generates day-by-day skeleton**

New function declaration in tool-registry:
```typescript
{
  name: "generate_itinerary",
  description: "Generate a day-by-day trip itinerary. Called automatically when dates + destination are set.",
  parameters: {
    type: "OBJECT",
    properties: {
      destination: { type: "STRING", description: "Trip destination" },
      start_date: { type: "STRING", description: "YYYY-MM-DD" },
      end_date: { type: "STRING", description: "YYYY-MM-DD" },
      group_size: { type: "NUMBER", description: "Number of travelers" },
      constraints: { type: "STRING", description: "Budget, dietary, accessibility constraints" },
    },
    required: ["destination", "start_date", "end_date"],
  },
}
```

Gemini Pro returns structured JSON:
```json
{
  "days": [
    {
      "date": "2026-06-10",
      "label": "Arrival Day",
      "slots": [
        { "time": "afternoon", "type": "hotel", "query": "beachfront resorts Seminyak", "note": "check in, decompress" },
        { "time": "evening", "type": "restaurant", "query": "sunset dinner Seminyak beach", "note": "first night dinner with ocean view" }
      ]
    },
    {
      "date": "2026-06-11",
      "label": "Temples & Rice Terraces",
      "slots": [
        { "time": "morning", "type": "activity", "query": "Tirta Empul temple Bali", "note": "morning temple visit, bring sarong" },
        { "time": "afternoon", "type": "activity", "query": "Tegallalang rice terrace", "note": "iconic photo spot" },
        { "time": "evening", "type": "restaurant", "query": "authentic Balinese dinner Ubud", "note": "local cuisine" }
      ]
    }
  ]
}
```

**Pass 2: Geospatial validation (prevents impossible itineraries)**

LLMs are terrible at spatial reasoning. Gemini might suggest a morning temple in North Bali and lunch in South Bali — a 3-hour drive. Before filling slots with real data, validate geography:

1. For each consecutive slot pair in a day, call Google Maps Distance Matrix API (`/maps/api/distancematrix/json`) with the two location queries
2. If travel time >60 minutes between consecutive slots:
   - Re-prompt Gemini: "Your suggested lunch spot is too far from the morning activity at {location}. Find a highly-rated alternative within 5km of {morning_location}."
   - OR insert a `"type": "travel"` block between slots: `{ "time": "midday", "type": "travel", "duration": 90, "note": "1.5hr drive from North Bali to Seminyak" }`
3. Cost: Google Distance Matrix is $5/1000 elements. A 5-day trip with 3 slots/day = 10 API calls = $0.05 per itinerary.

New env var: `GOOGLE_MAPS_API_KEY` (Distance Matrix enabled)

**Pass 3: Orchestrator fills each slot with real data**

For each slot in the validated skeleton:
- `type: "hotel"` → SearchAPI `searchHotels(query)`
- `type: "restaurant"` → SearchAPI `searchLocal(query)` — constrained to within 5km of previous slot's location
- `type: "activity"` → SearchAPI `searchLocal(query)`
- `type: "flight"` (arrival/departure days) → fli `searchFlightsFli()`
- `type: "travel"` → No search needed — rendered as a travel card with duration + map link

Each filled slot becomes a `RecommendationItem` with real title, price, image, rating, source, and `metadata.lat`/`metadata.lng` for future proximity queries.

### Output

Recommendation items are written to `decision_items` table:
```typescript
{
  group_id: groupId,
  title: "Tirta Empul Temple",
  category: "recommendation",
  description: "Sacred water temple in Tampaksiring. Morning visit recommended.",
  state: "proposed",
  metadata: {
    itinerary_day: "2026-06-11",
    itinerary_slot: "morning",
    itinerary_label: "Temples & Rice Terraces",
    price: "Free entry (sarong rental $2)",
    image_url: "https://...",
    rating: 4.7,
    source: "searchapi",
    search_tier: "google_local",
    recent_review: "Visited last month, the purification ritual was beautiful — Traveler, Mar 2026",
    verified_recent: true,
    booking_url: "https://maps.google.com/?q=Tirta+Empul+Temple",
  }
}
```

### Itinerary in UI

`ItineraryView.tsx` extended to show two sections:
1. **Committed** (existing) — locked/purchased items sorted by date
2. **Recommendations** (new) — items with `category: "recommendation"`, grouped by `metadata.itinerary_day` and `metadata.itinerary_slot`

Users can vote on recommendations (LoveIt/WorksForMe/NotForMe). High-voted recommendations graduate to locked/committed status.

### Plans Tab UI Architecture

The existing group interior has two tabs: **Chat | Plans**. The Plans tab gets a dual-mode view.

**Mode toggle at top of Plans tab:**
```
[ Category View ]  [ Timeline View ]
```

**Category View (existing, enhanced):**
```
Plans tab — Category View
  ├── "Itinerary" category (NEW — auto-generated plan items)
  │    └── [Day 1 arrival] [Day 2 temples] [Day 3 beach] →
  ├── Hotels ──── [card] [card] [card] →
  ├── Flights ─── [card] [card] →
  ├── Restaurants─ [card] [card] [card] →
  └── Activities── [card] [card] →
```

The "Itinerary" category is a new swim lane that appears at the top when auto-generated plan items exist. Cards are ordered by day+time within this lane.

**Timeline View (NEW):**
```
Plans tab — Timeline View
  ├── Day 1 — Arrival (Jun 10)
  │    ├── afternoon: "Beachfront Resort Seminyak" [$180/night] [+2 alternatives]
  │    ├── ── 20 min drive ──  (travel block)
  │    └── evening: "Sunset Dinner at La Lucciola" [$45] [+4 alternatives]
  │
  ├── Day 2 — Temples & Rice Terraces (Jun 11)
  │    ├── morning: "Tirta Empul Temple" [Free] [+1 alternative]
  │    ├── ── 35 min drive ──  (travel block)
  │    ├── afternoon: "Tegallalang Rice Terrace" [$15] [+2 alternatives]
  │    ├── ── 15 min walk ──  (travel block)
  │    └── evening: "Locavore Ubud" [$60] [+3 alternatives]
  │
  ├── Day 3 — Beach Day (Jun 12)
  │    └── ...
  │
  └── Day 5 — Departure (Jun 14)
       └── morning: "QR 829 BKK→DOH" [$528] [Book →]
```

**Collapsed overflow:**
- Each slot shows the top-voted/AI-recommended item as the hero card
- Small chip: `+3 alternatives` — taps to expand a mini-list of other search results for that slot
- Alternatives are the other SearchAPI results that filled that slot in Pass 3
- Alternatives can be voted on. If an alternative gets more votes than the hero, they swap.

**Travel blocks:**
- Thin connector cards between slots (not full decision cards)
- Shows duration + transport mode icon (car/walk/transit)
- Tapping opens Google Maps directions link
- Styled differently: no voting, no image, muted color, smaller height

**New card type needed: `TravelBlock`**
```typescript
{
  category: "travel",
  metadata: {
    duration_minutes: 35,
    mode: "drive",  // "drive" | "walk" | "transit"
    from_location: "Tirta Empul Temple",
    to_location: "Tegallalang Rice Terrace",
    maps_url: "https://maps.google.com/..."
  }
}
```

**Mode persistence:** Last-used mode saved to `localStorage`. Default: Category View. Switches to Timeline View automatically when itinerary items exist and user hasn't explicitly chosen Category.

### Living Itinerary (Conversational Mutations)

The itinerary is not write-once. Users can modify it through natural language:

**New function declaration: `modify_itinerary`**
```typescript
{
  name: "modify_itinerary",
  description: "Modify a specific day/slot in the existing itinerary. Use when user says 'swap', 'change', 'I'm tired on day 3', 'too touristy', 'something more adventurous'.",
  parameters: {
    type: "OBJECT",
    properties: {
      day: { type: "STRING", description: "Date YYYY-MM-DD or relative ('Tuesday', 'Day 3')" },
      slot: { type: "STRING", description: "morning, afternoon, evening, or 'all'" },
      instruction: { type: "STRING", description: "What to change: 'more adventurous', 'closer to hotel', 'cheaper', 'chill'" },
    },
    required: ["instruction"],
  },
}
```

**Examples:**
- "@hello swap Tuesday morning for something more adventurous" → `modify_itinerary({day: "2026-06-11", slot: "morning", instruction: "more adventurous"})`
- "@hello I'm tired on Day 3, make it a rest day" → `modify_itinerary({day: "2026-06-12", slot: "all", instruction: "rest day, spa, light lunch, no temples"})`
- "@hello too touristy" → `modify_itinerary({slot: "all", instruction: "less touristy, local hidden gems"})`

**Handler:**
1. Load existing itinerary items for the target day from `decision_items` where `category = 'recommendation'` and `metadata.itinerary_day` matches
2. Send to Gemini Pro with the original slot data + the user's instruction + geospatial constraint (stay near the other slots that day)
3. Gemini returns replacement slot(s)
4. Run geospatial validation on the new slot(s)
5. Fill with real SearchAPI data
6. Replace old recommendation items in DB (upsert by day+slot)
7. Response: "swapped the morning temple for a hidden waterfall hike. 20 min from your hotel."

### Dreaming Mode (Date-less Planning)

Most groups don't start with dates. They start with a vibe — "should we do Bali or Japan?" — and spend days debating before anyone opens a calendar. By the time dates are set, the magic of discovery is over.

**The fix:** `generate_itinerary` works WITHOUT dates.

**Trigger:** User asks "@hello what would 5 days in Bali look like?" — no dates in the space, no dates in the message.

**How it works:**
1. Gemini Pro generates a skeleton with generic days: `Day 1 (Arrival)`, `Day 2 (Culture)`, `Day 3 (Nature)`, etc.
2. Geospatial validation runs normally (locations are real, just dates are generic)
3. Pass 3 fills slots with real places from SearchAPI — images, ratings, descriptions — but **no prices** (prices are date-dependent)
4. Flight slots show route info but say "Set dates to see prices"
5. Hotel slots show properties but say "Set dates for availability"

**The hook:** Once the dream plan exists, a whisper fires:
```
"your Bali blueprint looks solid. lock in your dates and I'll fill in real prices and availability."
```

When dates are set later, the orchestrator re-hydrates the existing skeleton:
- Keeps the same places (group already voted on them)
- Adds real prices via SearchAPI with actual dates
- Adds real flights via fli with actual dates
- Updates `metadata.itinerary_day` from "Day 1" to "2026-06-10"

**Schema:** `metadata.itinerary_day` accepts both `"Day 1"` (dream mode) and `"2026-06-10"` (real mode). The UI renders accordingly.

### AI-Mediated Conflict Resolution (Consensus Gap)

Voting (LoveIt/NotForMe) is binary. If 3 people love a fancy restaurant and 1 person hates it because they're on a budget, the hero card stays the fancy restaurant. The budget traveler feels ignored.

**The fix:** Detect split votes and trigger a mediator whisper.

**Detection logic** (in `suggestions.ts`):
```typescript
// New whisper type: "consensus_split" (P0)
// Trigger: item has ≥3 reactions AND (NotForMe count / total reactions) ≥ 0.25
// i.e., at least 25% of voters disagree
```

**When triggered:**
1. Load the split item + all reactions + reaction user profiles
2. Send to Gemini Pro with context: "Item X has split votes. Users A and B love it. User C voted NotForMe. User C's taste profile says: budget-conscious, vegetarian. Find a compromise."
3. Gemini returns a search query for a compromise option
4. SearchAPI fills it with real data
5. The compromise is inserted as a new decision item in the same category with `metadata.mediator = true`

**Whisper message (dropped in chat, not notification spam):**
```
"looks like you're split on La Petite Maison. found a spot with the same ocean 
view but 40% cheaper — and they have a solid veggie menu. take a look in Plans."
```

**Rules:**
- Never name WHO voted NotForMe (privacy). Say "some of you" or "the group is split."
- Always name the compromise positively — frame it as an upgrade for everyone, not a concession.
- Max 1 mediator whisper per item. Don't nag.
- The mediator item gets a subtle "Compromise" badge in the UI.

### Proof-of-Life Grounding (Trust Gap)

If the AI recommends a restaurant that closed in 2024, users will never trust flight prices or hotel suggestions again. Trust is the product.

**The fix:** Every recommendation card shows evidence it's current.

**In Pass 3 (slot filling), for each SearchAPI result:**
1. Extract `recent_review` — the most recent review snippet from SearchAPI's `local_results[].reviews[]` or `extensions[]`
2. Extract `verified_recent` — true if the review is from the last 6 months (check date if available, otherwise true if review text exists)
3. Store both in `metadata.recent_review` and `metadata.verified_recent`

**UI rendering on each card:**
- If `verified_recent`: small "Verified Recent" badge (green dot + text)
- If `recent_review` exists: one-line snippet below the description in muted text, e.g., *"Amazing sunset views — visited Feb 2026"*
- If neither: no badge. Absence of badge is the signal (no fake "verified" for unverifiable items).

**For flights:** No review needed. Flights are inherently current (they're live API data). Instead show: `"Price as of {cached_time}"` — see cache staleness below.

### Operational Safeguards (1,000-User Survival)

**1. Price cache staleness label:**
Flight cards cached for up to 4 hours. When the user taps "Book →", the Google Flights price might differ.
- Every flight card with cached data shows: `"Price from {time_ago}. Verify on Google Flights."` in small muted text
- `time_ago` computed from `metadata.cached_at` timestamp
- Fresh results (<15 min) show no label

**2. Batched intelligence notifications:**
Auto-generating a 5-day itinerary creates ~15 items. Do NOT send 15 whispers.
- After itinerary generation completes, send ONE message to chat:
  `"your Bali blueprint is ready — 5 days, 15 spots, 3 hotel options. check Plans."`
- No individual item notifications. The Plans tab badge shows the count.
- Whispers (consensus_split, missing_category) are throttled: max 2 per hour per group.

**3. modify_itinerary bulletproofing:**
This is the most important function in the spec. Edge cases:
- User says "change everything" → treat as full regeneration, not slot mutation
- User references a day that doesn't exist → "your trip is 5 days. which day?"
- User modifies a LOCKED item → "that's already booked. want to unlock it first?"
- Multiple users modify simultaneously → last-write-wins with version check (existing optimistic concurrency pattern)
- Modification fails (Gemini error, SearchAPI down) → keep original slot, respond "couldn't find a replacement. keeping the current plan."

---

## 6. Piece 4: Recommendation Engine

### How It Complements Itinerary

After the itinerary skeleton is generated and slots are filled, the recommendation engine runs a second enrichment pass:

1. **For each day**, query SearchAPI `google_local` for 3-5 additional options per slot (e.g., 3 more restaurants near the evening's planned location)
2. **Apply taste filtering** — use group taste profiles (hardConstraints, softPreferences) to rank results. Vegetarian constraint → filter out steakhouses. Budget constraint → sort by price.
3. **Cross-reference locked decisions** — if hotel is already locked, recommend restaurants/activities near that hotel's location, not the general destination.

### Whisper Integration

Extend `suggestions.ts`:
```
New whisper type: "itinerary_ready" (P1)
Trigger: dates set + destination resolved + no recommendations exist
Message: "dates are locked. building your Bali plan..."
Auto-action: fire generateItinerary()
```

Extend existing whisper:
```
Existing: "missing_category" — dates set but no hotel
Extended: also detect "has itinerary but no activities for Day 3"
```

### Discovery Provider Upgrade

Wire `GeminiEnrichmentProvider` to real Gemini Pro calls:
- Currently returns template strings ("AI Pick: Best {category}")
- After upgrade: calls Gemini Pro with destination + taste context → returns real place recommendations
- These feed into `/api/discovery/feed` and `/api/discovery/carousel`
- Carousel shows "Recommended for your Bali trip" based on itinerary context

---

## 7. Piece 5: BYOAI-Ready Architecture

### AIProvider Interface

New file: `web/src/lib/intelligence/ai-provider.ts`

```typescript
export interface AIProvider {
  /** Parse user message into a structured intent + function call */
  parseIntent(input: {
    message: string;
    systemPrompt: string;
    conversationHistory: Array<{ role: string; content: string }>;
    functionDeclarations: FunctionDeclaration[];
  }): Promise<{
    functionCall?: { name: string; args: Record<string, string> };
    textResponse?: string;
  }>;

  /** Generate a day-by-day itinerary skeleton */
  plan(input: {
    destination: string;
    startDate: string;
    endDate: string;
    groupSize: number;
    constraints: string;
    tasteContext: string;
    lockedDecisions: string;
  }): Promise<ItinerarySkeleton>;

  /** Synthesize search results into a brief, human response */
  synthesize(input: {
    userMessage: string;
    results: ApifyResult[];
    groundingContext: string;
    recentMessages: string;
  }): Promise<string>;
}
```

### Default Implementation: GeminiProvider

```typescript
export class GeminiProvider implements AIProvider {
  private model: GenerativeModel;

  constructor(apiKey: string, modelName: string = "gemini-2.5-pro") {
    const genAI = new GoogleGenerativeAI(apiKey);
    this.model = genAI.getGenerativeModel({ model: modelName, ... });
  }

  async parseIntent(input) { /* current Gemini function calling logic */ }
  async plan(input) { /* new itinerary generation logic */ }
  async synthesize(input) { /* current synthesis logic */ }
}
```

### Future Providers (not built now, but interface is ready)

```typescript
// Future — when Claude/OpenAI/Perplexity expose OAuth-based API access
export class ClaudeProvider implements AIProvider { ... }
export class OpenAIProvider implements AIProvider { ... }
export class PerplexityProvider implements AIProvider { ... }
```

### Provider Selection

```typescript
// web/src/lib/intelligence/ai-provider-factory.ts
export function getAIProvider(): AIProvider {
  const providerName = process.env.HELLO_AI_PROVIDER || "gemini";
  const apiKey = process.env.GEMINI_API_KEY;
  const model = process.env.GEMINI_MODEL || "gemini-2.5-pro";

  switch (providerName) {
    case "gemini":
      return new GeminiProvider(apiKey, model);
    // Future:
    // case "claude": return new ClaudeProvider(process.env.CLAUDE_API_KEY);
    // case "openai": return new OpenAIProvider(process.env.OPENAI_API_KEY);
    default:
      return new GeminiProvider(apiKey, model);
  }
}
```

### Orchestrator Refactor

Current `orchestrate()` function hardwires Gemini calls. After refactor:
- All `model.generateContent()` calls replaced with `aiProvider.parseIntent()`, `aiProvider.plan()`, `aiProvider.synthesize()`
- Tool layer (fli, SearchAPI, Apify) remains completely independent of AI provider
- System prompt (voice rules, routing rules) passed to `parseIntent()` — provider-agnostic

---

## 8. Piece 6: Gemini Pro Upgrade

### Change

Single env var change on Vercel:
```
GEMINI_MODEL=gemini-2.5-pro
```

Current orchestrator already reads this (line 177):
```typescript
const modelName = process.env.GEMINI_MODEL || "gemini-2.5-flash";
```

### Impact
- All intent parsing: higher accuracy function calls
- All synthesis: better voice, fewer garbage responses
- Itinerary generation: coherent multi-day planning
- Cost increase: Gemini 2.5 Pro is ~10x more expensive than Flash ($1.25/1M input vs $0.15/1M)
- At <1000 users with moderate usage: estimated $50-200/month (acceptable)

### No Code Change Required
This is a Vercel env var change only. Deploy-time, not code-time.

---

## 9. Files Changed Summary

| File | Action | Description |
|------|--------|-------------|
| `web/api/fli/route.py` | NEW | Vercel Python function — fli flight search |
| `web/api/fli/dates/route.py` | NEW | Vercel Python function — fli cheapest dates |
| `web/requirements.txt` | NEW | `flights>=0.8.0` |
| `web/src/lib/intelligence/fli-client.ts` | NEW | TypeScript HTTP client for /api/fli/* |
| `web/src/lib/intelligence/ai-provider.ts` | NEW | AIProvider interface + GeminiProvider |
| `web/src/lib/intelligence/ai-provider-factory.ts` | NEW | Provider factory with env-based selection |
| `web/src/lib/intelligence/itinerary-generator.ts` | NEW | Three-pass itinerary generation (skeleton → geospatial validate → fill slots) |
| `web/src/lib/intelligence/geospatial.ts` | NEW | Google Maps Distance Matrix validation between itinerary slots |
| `web/src/lib/intelligence/flight-cache.ts` | NEW | Vercel KV read/write for flight intelligence cache (4h TTL) |
| `web/src/lib/intelligence/deep-links.ts` | NEW | Google Flights/Hotels/restaurant URL construction from search data |
| `web/src/lib/intelligence/orchestrator.ts` | MODIFY | Refactor to use AIProvider. Add fli tier. Add generate_itinerary + modify_itinerary handlers. |
| `web/src/lib/intelligence/tool-registry.ts` | MODIFY | Flight tool tier → "fli". Add generate_itinerary + modify_itinerary function declarations. Add "fli" to tier type. |
| `web/src/lib/intelligence/searchapi-client.ts` | NO CHANGE | Stays as-is, becomes flight fallback |
| `web/src/lib/intelligence/apify-client.ts` | NO CHANGE | Stays as-is, last resort fallback |
| `web/src/lib/suggestions.ts` | MODIFY | Add "itinerary_ready" + "consensus_split" whisper types. Batched notifications. Throttle 2/hr/group. |
| `web/src/lib/intelligence/dream-mode.ts` | NEW | Date-less itinerary generation + re-hydration when dates arrive |
| `web/src/lib/intelligence/conflict-resolver.ts` | NEW | Split-vote detection + Gemini Pro compromise search |
| `web/src/lib/discovery/providers/gemini-enrichment.ts` | MODIFY | Wire to real Gemini Pro calls via AIProvider |
| `web/src/components/os/ItineraryView.tsx` | MODIFY | Becomes Timeline View — day/slot grouping with collapsed overflow |
| `web/src/components/os/PlansModeToggle.tsx` | NEW | Category View / Timeline View toggle for Plans tab |
| `web/src/components/os/TimelineDay.tsx` | NEW | Collapsible day section with morning/afternoon/evening slots |
| `web/src/components/os/TravelBlock.tsx` | NEW | Thin connector card between slots (duration, mode, maps link) |
| `web/src/components/os/SlotAlternatives.tsx` | NEW | Collapsed "+N alternatives" chip with expandable mini-list |
| `web/src/components/os/DecisionBoard.tsx` | MODIFY | Add "itinerary" category swim lane at top when plan items exist |
| `web/src/components/os/DecisionCard.tsx` | MODIFY | Add "Book" button, airline logo, "Verified Recent" badge, "Compromise" badge, price staleness label, review snippet. |
| `web/src/app/api/local-action/route.ts` | MODIFY | After set_dates success, auto-trigger itinerary generation |
| `web/src/app/api/cron/warm/route.ts` | NEW | Keep-warm cron for fli Python function |
| `web/public/airline-logos/*.png` | NEW | 727 pre-cached airline logo PNGs (7.5 MB) |
| Vercel env: `GEMINI_MODEL` | CHANGE | `gemini-2.5-flash` → `gemini-2.5-pro` |
| Vercel env: `HELLO_AI_PROVIDER` | NEW | `gemini` (default, extensible later) |
| Vercel env: `GOOGLE_MAPS_API_KEY` | NEW | Distance Matrix API for geospatial validation |

---

## 10. What Is NOT In Scope (V2+)

- **Vibe profiles via image upload** — Pinterest/Instagram screenshot analysis for aesthetic-driven itineraries (Gemini multimodal). V2 when user base >1000.
- **NDC flight aggregators** — Official airline distribution APIs (Amadeus, Travelport). Requires business contracts, $10K+/year. V3.
- **Real-time flight tracking/alerts** — Price drop notifications, gate changes, delays. V2.
- **Interactive itinerary editing** — Drag-to-reorder, time slot adjustment UI. V2.
- **Multi-city itinerary support** — Current scope is single-destination. V2.
- **BYOAI user-facing UI** — Settings page to connect AI provider. Future, when providers open OAuth.
- **Offline itinerary** — Downloadable PDF/calendar export. V2.
- **Hotel/restaurant direct booking** — In-app checkout without leaving hello. V3 (requires affiliate/partner agreements).

---

## 11. Risk Assessment

| Risk | Mitigation |
|------|-----------|
| fli breaks (Google changes internal API) | Flight cache serves recent searches instantly. SearchAPI fallback activates for cache misses. fli is MIT-licensed, actively maintained (1.4k stars). |
| Vercel Python cold start slow (2-3s) | Cron keep-warm every 5 min. Worst case: first user waits 3s extra, subsequent calls are warm. |
| Gemini Pro cost spike at scale | Monitor via Vercel Analytics. BYOAI architecture means we can shift to user-provided models later. Budget threshold: $500/month triggers model-routing (Pro for planning, Flash for intent parsing). |
| `curl_cffi` C extension fails on Vercel build | Vercel Python runtime supports C extensions. If build fails, fall back to Railway deployment with `/api/fli/` proxied. |
| Itinerary generation takes too long (>30s) | Three-pass is parallelizable: all slot fills run concurrently via `Promise.all`. Geospatial calls batched. Target: <15s total. |
| Google Maps API costs | Distance Matrix: $5/1000 elements. 5-day trip = ~10 calls = $0.05/itinerary. At 1000 users generating 3 itineraries each: $150 total. |
| SearchAPI key expires | Logged at `[searchapi] 401:`. Falls through to Apify. Monitoring via Vercel function logs. |

---

## 12. Success Criteria

1. "@hello find flights from SFO to Bali" returns 20+ real flights with airline logos, prices, multi-leg data, and booking deep-links in <5 seconds
2. Repeat flight search on same route returns from cache in <200ms
3. Setting trip dates for "Bali, June 10-15" auto-generates a day-by-day itinerary with real restaurants, activities, and hotels in <15 seconds
4. No itinerary has consecutive slots >60 minutes apart without a travel block (geospatial validation)
5. "@hello swap Tuesday morning for something chill" modifies one slot without regenerating the full itinerary
6. Recommendations section shows 3-5 options per slot per day, each with image, price, rating, and booking link
7. All synthesis responses use Gemini 2.5 Pro quality (no degraded Flash responses)
8. Swapping `HELLO_AI_PROVIDER=claude` in env vars (future) works without code changes to the tool layer
9. "@hello what would 5 days in Bali look like?" generates a dream plan without dates — places with images but no prices
10. Setting dates on an existing dream plan re-hydrates it with real prices and flight data in <10 seconds
11. A split-vote item (≥25% NotForMe) triggers a mediator whisper with a compromise alternative within 60 seconds
12. Every recommendation card with a recent review shows a "Verified Recent" badge and review snippet
13. Auto-generated itinerary sends exactly 1 chat message ("your blueprint is ready"), not 15 individual notifications
