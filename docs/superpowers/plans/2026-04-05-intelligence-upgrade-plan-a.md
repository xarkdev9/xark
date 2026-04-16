# Plan A: fli Flights + Flight Cache + Deep-Links + Airline Logos

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace SearchAPI as the primary flight search with fli (Google Flights reverse-engineered API) via a Vercel Python function. Add flight caching, booking deep-links, and pre-cached airline logos.

**Architecture:** New Vercel Python function at `web/api/fli/route.py` wraps the `flights` PyPI package. TypeScript client `fli-client.ts` calls it. Upstash Redis caches results (4h TTL). Orchestrator dispatches to fli first, falls back to SearchAPI. Every flight card gets a Google Flights booking deep-link and a local airline logo.

**Tech Stack:** Python 3.13 (Vercel runtime), `flights` 0.8.x (fli), TypeScript, Upstash Redis (`@upstash/redis` already installed), Next.js API routes

**Spec:** `docs/superpowers/specs/2026-04-05-intelligence-upgrade-design.md`

---

### Task 1: Airline Logos — Copy Pre-Cached PNGs

**Files:**
- Create: `web/public/airline-logos/` (727 PNG files, 7.5 MB)

- [ ] **Step 1: Create directory and copy logos**

```bash
mkdir -p /Users/ramchitturi/hello/web/public/airline-logos
cp /tmp/airline-logos/*.png /Users/ramchitturi/hello/web/public/airline-logos/
```

- [ ] **Step 2: Verify logos are accessible**

```bash
ls /Users/ramchitturi/hello/web/public/airline-logos/ | wc -l
# Expected: 727

# Verify major airlines
for code in AA DL UA B6 QR NH EK SQ LH BA; do
  test -f /Users/ramchitturi/hello/web/public/airline-logos/${code}.png && echo "OK: ${code}" || echo "MISSING: ${code}"
done
# Expected: all OK
```

- [ ] **Step 3: Commit**

```bash
cd /Users/ramchitturi/hello/web
git add public/airline-logos/
git commit -m "feat: add 727 pre-cached airline logo PNGs (7.5 MB)"
```

---

### Task 2: Deep-Links Module

**Files:**
- Create: `web/src/lib/intelligence/deep-links.ts`

- [ ] **Step 1: Create the deep-links module**

```typescript
// web/src/lib/intelligence/deep-links.ts
// Constructs booking URLs for flights, hotels, and restaurants from search data.

/**
 * Build a Google Flights search URL pre-filled with origin, destination, and date.
 * Opens the Google Flights results page — user can book from there.
 */
export function buildFlightBookingUrl(params: {
  origin: string;
  destination: string;
  date: string;
  returnDate?: string;
}): string {
  const base = "https://www.google.com/travel/flights";
  const q = `flights from ${params.origin} to ${params.destination} on ${params.date}`;
  const url = new URL(base);
  url.searchParams.set("q", q);
  if (params.returnDate) {
    url.searchParams.set("tfs", `r:${params.returnDate}`);
  }
  return url.toString();
}

/**
 * Build a Google Hotels search URL pre-filled with location and dates.
 */
export function buildHotelBookingUrl(params: {
  location: string;
  checkIn?: string;
  checkOut?: string;
}): string {
  const base = "https://www.google.com/travel/hotels";
  const url = new URL(base);
  url.searchParams.set("q", params.location);
  if (params.checkIn && params.checkOut) {
    url.searchParams.set("dates", `${params.checkIn}_${params.checkOut}`);
  }
  return url.toString();
}

/**
 * Build a Google Maps URL for a restaurant or activity.
 * Uses the place name as query — Google Maps resolves it.
 */
export function buildMapsUrl(placeName: string): string {
  return `https://www.google.com/maps/search/${encodeURIComponent(placeName)}`;
}

/**
 * Get the local airline logo path. Falls back to undefined if logo doesn't exist.
 * Logos are pre-cached at /airline-logos/{IATA_CODE}.png (727 airlines).
 */
export function getAirlineLogoUrl(iataCode: string): string {
  return `/airline-logos/${iataCode.toUpperCase()}.png`;
}

/**
 * Format a cache staleness label for flight prices.
 * Returns undefined if the price is fresh (<15 min).
 */
export function getCacheStalenessLabel(cachedAt: number): string | undefined {
  const ageMs = Date.now() - cachedAt;
  if (ageMs < 15 * 60 * 1000) return undefined; // fresh, no label
  const ageMin = Math.round(ageMs / 60000);
  if (ageMin < 60) return `Price from ${ageMin}m ago. Verify on Google Flights.`;
  const ageHr = Math.round(ageMin / 60);
  return `Price from ${ageHr}h ago. Verify on Google Flights.`;
}
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/intelligence/deep-links.ts
git commit -m "feat: add deep-links module for flight/hotel/maps booking URLs"
```

---

### Task 3: Flight Intelligence Cache

**Files:**
- Create: `web/src/lib/intelligence/flight-cache.ts`

- [ ] **Step 1: Create the flight cache module**

`@upstash/redis` is already in `web/package.json`. The existing `web/src/lib/key-cache.ts` uses the same Redis instance pattern.

```typescript
// web/src/lib/intelligence/flight-cache.ts
// Caches flight search results in Upstash Redis to protect against fli downtime
// and speed up repeat searches on popular routes. TTL: 4 hours.

import { Redis } from "@upstash/redis";

const redis =
  process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN
    ? new Redis({
        url: process.env.UPSTASH_REDIS_REST_URL,
        token: process.env.UPSTASH_REDIS_REST_TOKEN,
      })
    : null;

const CACHE_TTL_SECONDS = 4 * 60 * 60; // 4 hours
const KEY_PREFIX = "flights";

export interface CachedFlightResult {
  results: FlightResultItem[];
  cachedAt: number;
  source: string;
}

export interface FlightResultItem {
  title: string;
  price: string | undefined;
  imageUrl: string | undefined;
  description: string;
  externalUrl: string | undefined;
  bookingUrl: string;
  source: string;
  airlineCode: string;
  legs: Array<{
    airline: string;
    airlineCode: string;
    flightNumber: string;
    departureAirport: string;
    arrivalAirport: string;
    departureTime: string;
    arrivalTime: string;
    duration: number;
  }>;
}

function cacheKey(origin: string, destination: string, date: string): string {
  return `${KEY_PREFIX}:${origin.toUpperCase()}:${destination.toUpperCase()}:${date}`;
}

export async function getCachedFlights(
  origin: string,
  destination: string,
  date: string
): Promise<CachedFlightResult | null> {
  if (!redis) return null;
  try {
    const key = cacheKey(origin, destination, date);
    const cached = await redis.get<CachedFlightResult>(key);
    return cached ?? null;
  } catch (err) {
    console.warn("[flight-cache] Read failed:", err instanceof Error ? err.message : String(err));
    return null;
  }
}

export async function setCachedFlights(
  origin: string,
  destination: string,
  date: string,
  results: FlightResultItem[],
  source: string
): Promise<void> {
  if (!redis) return;
  try {
    const key = cacheKey(origin, destination, date);
    const value: CachedFlightResult = {
      results: results.slice(0, 20), // cache top 20
      cachedAt: Date.now(),
      source,
    };
    await redis.set(key, value, { ex: CACHE_TTL_SECONDS });
  } catch (err) {
    console.warn("[flight-cache] Write failed:", err instanceof Error ? err.message : String(err));
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/intelligence/flight-cache.ts
git commit -m "feat: add flight intelligence cache (Upstash Redis, 4h TTL)"
```

---

### Task 4: Vercel Python Function — fli Flight Search

**Files:**
- Create: `web/api/fli/route.py`
- Create: `web/requirements.txt`

- [ ] **Step 1: Create requirements.txt**

```
flights>=0.8.0
```

- [ ] **Step 2: Create the Python function**

```python
# web/api/fli/route.py
# Vercel Python serverless function wrapping the fli library.
# Exposes flight search as POST /api/fli with JSON body.

from http.server import BaseHTTPRequestHandler
import json

class handler(BaseHTTPRequestHandler):
    def do_POST(self):
        try:
            content_length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(content_length)) if content_length > 0 else {}

            origin = body.get("origin", "").upper()
            destination = body.get("destination", "").upper()
            date = body.get("date", "")
            cabin = body.get("cabin", "economy")
            max_results = body.get("max_results", 20)

            if not origin or not destination or not date:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": "origin, destination, and date are required"}).encode())
                return

            from fli.search import SearchFlights
            from fli.models import (
                FlightSearchFilters, FlightSegment, Airport, SeatType, PassengerInfo, MaxStops
            )

            # Resolve IATA codes to Airport enum
            try:
                origin_airport = Airport[origin]
                dest_airport = Airport[destination]
            except KeyError:
                self.send_response(400)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(json.dumps({"error": f"Invalid airport code: {origin} or {destination}"}).encode())
                return

            # Map cabin class
            seat_map = {
                "economy": SeatType.ECONOMY,
                "premium_economy": SeatType.PREMIUM_ECONOMY,
                "business": SeatType.BUSINESS,
                "first": SeatType.FIRST,
            }
            seat_type = seat_map.get(cabin.lower(), SeatType.ECONOMY)

            # Build filters
            filters = FlightSearchFilters(
                passenger_info=PassengerInfo(),
                flight_segments=[FlightSegment(
                    departure_airport=[[origin_airport, 0]],
                    arrival_airport=[[dest_airport, 0]],
                    travel_date=date,
                )],
                seat_type=seat_type,
            )

            search = SearchFlights()
            results = search.search(filters)

            # Normalize results
            flights = []
            for r in results[:max_results]:
                legs = []
                for leg in r.legs:
                    # Extract IATA code from airline enum name
                    airline_code = ""
                    try:
                        airline_code = leg.airline.name  # enum name IS the IATA code
                    except Exception:
                        pass

                    legs.append({
                        "airline": leg.airline.value,
                        "airline_code": airline_code,
                        "flight_number": leg.flight_number,
                        "departure_airport": leg.departure_airport.name,
                        "arrival_airport": leg.arrival_airport.name,
                        "departure_time": leg.departure_datetime.isoformat(),
                        "arrival_time": leg.arrival_datetime.isoformat(),
                        "duration": leg.duration,
                    })

                first_leg = legs[0] if legs else {}
                flights.append({
                    "price": r.price,
                    "currency": r.currency or "USD",
                    "duration": r.duration,
                    "stops": r.stops,
                    "airline_code": first_leg.get("airline_code", ""),
                    "legs": legs,
                })

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({
                "results": flights,
                "count": len(results),
                "returned": len(flights),
                "source": "fli",
            }).encode())

        except Exception as e:
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e), "source": "fli"}).encode())
```

- [ ] **Step 3: Commit**

```bash
git add web/api/fli/route.py web/requirements.txt
git commit -m "feat: add Vercel Python function for fli flight search"
```

---

### Task 5: TypeScript fli Client

**Files:**
- Create: `web/src/lib/intelligence/fli-client.ts`

- [ ] **Step 1: Create the fli client**

```typescript
// web/src/lib/intelligence/fli-client.ts
// TypeScript client for the Vercel Python fli function at /api/fli.
// Normalizes fli results to ApifyResult[] for the orchestrator.

import { getCachedFlights, setCachedFlights, type FlightResultItem } from "./flight-cache";
import { buildFlightBookingUrl, getAirlineLogoUrl, getCacheStalenessLabel } from "./deep-links";

// Re-export for orchestrator use
export type { FlightResultItem } from "./flight-cache";

interface FliSearchParams {
  origin: string;
  destination: string;
  date: string;
  cabin?: string;
  maxResults?: number;
}

interface FliResponse {
  results: Array<{
    price: number;
    currency: string;
    duration: number;
    stops: number;
    airline_code: string;
    legs: Array<{
      airline: string;
      airline_code: string;
      flight_number: string;
      departure_airport: string;
      arrival_airport: string;
      departure_time: string;
      arrival_time: string;
      duration: number;
    }>;
  }>;
  count: number;
  returned: number;
  source: string;
}

// Resolve base URL — same origin in production, localhost in dev
function getFliBaseUrl(): string {
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  if (process.env.NEXT_PUBLIC_APP_URL) return process.env.NEXT_PUBLIC_APP_URL;
  return "http://localhost:3000";
}

/**
 * Search flights via fli Python function.
 * Checks cache first. On cache miss, calls /api/fli.
 * Returns normalized FlightResultItem[] compatible with the orchestrator.
 */
export async function searchFlightsFli(params: FliSearchParams): Promise<FlightResultItem[]> {
  const { origin, destination, date } = params;

  // 1. Check cache
  const cached = await getCachedFlights(origin, destination, date);
  if (cached) {
    console.log(`[fli] Cache hit for ${origin}->${destination} on ${date} (${cached.results.length} results, age: ${Math.round((Date.now() - cached.cachedAt) / 60000)}m)`);
    return cached.results;
  }

  // 2. Call fli Python function
  const baseUrl = getFliBaseUrl();
  const url = `${baseUrl}/api/fli`;

  console.log(`[fli] Fetching ${origin}->${destination} on ${date}`);

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      origin,
      destination,
      date,
      cabin: params.cabin || "economy",
      max_results: params.maxResults || 20,
    }),
    cache: "no-store",
    signal: AbortSignal.timeout(10000), // 10s timeout — fall through to SearchAPI if slow
  });

  if (!res.ok) {
    const errBody = await res.text().catch(() => "");
    console.error(`[fli] ${res.status}: ${errBody}`);
    return [];
  }

  const data: FliResponse = await res.json();
  console.log(`[fli] Got ${data.returned} of ${data.count} flights`);

  // 3. Build booking URL for this route
  const bookingUrl = buildFlightBookingUrl({ origin, destination, date });

  // 4. Normalize to FlightResultItem[]
  const results: FlightResultItem[] = data.results.map((f) => {
    const firstLeg = f.legs[0];
    const airlineCode = firstLeg?.airline_code || f.airline_code || "";
    const depTime = firstLeg?.departure_time ? new Date(firstLeg.departure_time).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false }) : "";
    const arrTime = f.legs[f.legs.length - 1]?.arrival_time ? new Date(f.legs[f.legs.length - 1].arrival_time).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false }) : "";
    const hrs = Math.floor(f.duration / 60);
    const mins = f.duration % 60;
    const stopsLabel = f.stops === 0 ? "nonstop" : `${f.stops} stop${f.stops > 1 ? "s" : ""}`;

    return {
      title: `${firstLeg?.airline || ""} ${firstLeg?.flight_number || ""} ${firstLeg?.departure_airport || ""} → ${f.legs[f.legs.length - 1]?.arrival_airport || ""}`,
      price: f.price > 0 ? `$${f.price}` : undefined,
      imageUrl: airlineCode ? getAirlineLogoUrl(airlineCode) : undefined,
      description: `${stopsLabel}, ${hrs}h${String(mins).padStart(2, "0")}m. ${depTime} → ${arrTime}`,
      externalUrl: bookingUrl,
      bookingUrl,
      source: "fli",
      airlineCode,
      legs: f.legs,
    };
  });

  // 5. Cache the results
  await setCachedFlights(origin, destination, date, results, "fli");

  return results;
}
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/intelligence/fli-client.ts
git commit -m "feat: add fli TypeScript client with cache + deep-links"
```

---

### Task 6: Update Tool Registry — Add fli Tier

**Files:**
- Modify: `web/src/lib/intelligence/tool-registry.ts`

- [ ] **Step 1: Add "fli" to the ToolDefinition tier type**

In `web/src/lib/intelligence/tool-registry.ts`, change the `tier` field:

```typescript
// BEFORE (line 5)
tier: "gemini-search" | "apify" | "searchapi";

// AFTER
tier: "gemini-search" | "apify" | "searchapi" | "fli";
```

- [ ] **Step 2: Update the flight tool registration**

```typescript
// BEFORE (lines 176-187)
registerTool("flight", {
  tier: "searchapi",
  actorId: process.env.APIFY_FLIGHT_ACTOR || "johnvc/Google-Flights-Data-Scraper-Flight-and-Price-Search",
  searchApiEngine: "google_flights",
  description: "Search flights via Google Flights API",
  paramMap: (p) => ({
    origin: p.origin?.toUpperCase(),
    destination: p.destination?.toUpperCase(),
    date: p.date || undefined,
    returnDate: p.returnDate || undefined,
  }),
});

// AFTER
registerTool("flight", {
  tier: "fli",
  actorId: process.env.APIFY_FLIGHT_ACTOR || "johnvc/Google-Flights-Data-Scraper-Flight-and-Price-Search",
  searchApiEngine: "google_flights", // kept for SearchAPI fallback
  description: "Search flights via fli (primary) with SearchAPI fallback",
  paramMap: (p) => ({
    origin: p.origin?.toUpperCase(),
    destination: p.destination?.toUpperCase(),
    date: p.date || undefined,
    returnDate: p.returnDate || undefined,
  }),
});
```

- [ ] **Step 3: Commit**

```bash
git add web/src/lib/intelligence/tool-registry.ts
git commit -m "feat: add fli tier to tool registry, set flight tool to tier fli"
```

---

### Task 7: Update Orchestrator — Add fli Dispatch

**Files:**
- Modify: `web/src/lib/intelligence/orchestrator.ts`

- [ ] **Step 1: Add fli dispatch block before the SearchAPI block**

Insert this block BEFORE the existing `if (tool.tier === "searchapi")` block at line 378. The fli tier runs first; if it fails or returns 0 results, execution falls through to the SearchAPI block.

Add this import at the top of the file (after the existing imports around line 9):

```typescript
import { searchFlightsFli } from "./fli-client";
```

Then insert this new block before line 378 (`// ── SearchApi tier`):

```typescript
    // ── fli tier (fastest for flights, 2-5s, 30-150 results, free) ──
    if (tool.tier === "fli") {
      const mappedParams = tool.paramMap(params);
      const origin = String(mappedParams.origin || "");
      const destination = String(mappedParams.destination || "");
      const date = String(mappedParams.date || "");

      if (origin && destination) {
        console.log(`[@hello] fli dispatch: ${origin}->${destination} on ${date || "default"}`);
        try {
          const fliResults = await searchFlightsFli({
            origin,
            destination,
            date: date || new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10),
          });

          if (fliResults.length > 0) {
            // Convert FlightResultItem[] to ApifyResult[] for the standard pipeline
            const searchResults: ApifyResult[] = fliResults.map((f) => ({
              title: f.title,
              price: f.price,
              imageUrl: f.imageUrl,
              description: f.description,
              externalUrl: f.bookingUrl,
              rating: undefined,
              source: "fli",
            }));

            return {
              response: `found ${searchResults.length} flights. they're in decide now.`,
              searchResults,
              action: "search",
              tool: toolName,
            };
          }

          console.warn("[@hello] fli returned 0 results, falling through to SearchAPI...");
        } catch (err) {
          console.error("[@hello] fli failed, falling through to SearchAPI:", err instanceof Error ? err.message : String(err));
        }
      }

      // Fall through: fli failed or no origin/destination → try SearchAPI with google_flights engine
    }
```

- [ ] **Step 2: Commit**

```bash
git add web/src/lib/intelligence/orchestrator.ts
git commit -m "feat: add fli dispatch to orchestrator (primary flight tier, SearchAPI fallback)"
```

---

### Task 8: Keep-Warm Cron for fli Python Function

**Files:**
- Create: `web/src/app/api/cron/warm/route.ts`
- Modify: `web/vercel.json`

- [ ] **Step 1: Create the warm endpoint**

```typescript
// web/src/app/api/cron/warm/route.ts
// Pings the fli Python function every 5 minutes to prevent cold starts.

import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const baseUrl = process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}`
    : "http://localhost:3000";

  try {
    const res = await fetch(`${baseUrl}/api/fli`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        origin: "JFK",
        destination: "LAX",
        date: new Date(Date.now() + 30 * 86400000).toISOString().slice(0, 10),
        max_results: 1,
      }),
      signal: AbortSignal.timeout(15000),
    });

    const ok = res.ok;
    console.log(`[warm] fli ping: ${ok ? "OK" : res.status}`);
    return NextResponse.json({ fli: ok ? "warm" : "cold", status: res.status });
  } catch (err) {
    console.warn("[warm] fli ping failed:", err instanceof Error ? err.message : String(err));
    return NextResponse.json({ fli: "error" }, { status: 200 }); // 200 so Vercel cron doesn't retry
  }
}
```

- [ ] **Step 2: Add cron to vercel.json**

Add the warm cron to the existing `crons` array:

```json
{
  "path": "/api/cron/warm",
  "schedule": "*/5 * * * *"
}
```

The full `crons` array becomes:
```json
"crons": [
  { "path": "/api/cron/purge", "schedule": "0 3 * * *" },
  { "path": "/api/cron/consensus", "schedule": "0 6 * * *" },
  { "path": "/api/cron/warm", "schedule": "*/5 * * * *" }
]
```

- [ ] **Step 3: Commit**

```bash
git add web/src/app/api/cron/warm/route.ts web/vercel.json
git commit -m "feat: add keep-warm cron for fli Python function (every 5min)"
```

---

### Task 9: Update DecisionCard — Booking Button + Airline Logo + Staleness

**Files:**
- Modify: `web/src/components/os/DecisionCard.tsx`

- [ ] **Step 1: Add booking button and airline logo rendering**

Find the section in `DecisionCard.tsx` where `metadata` is read and the card footer/actions are rendered. Add these enhancements:

1. **Airline logo**: If `metadata.image_url` starts with `/airline-logos/`, render it as a small 32x32 logo next to the title (instead of as the card background image).

2. **Book button**: If `metadata.external_url` or `metadata.booking_url` exists, render a "Book" pill button that opens the URL in a new tab.

3. **Price staleness**: If `metadata.cached_at` exists and is >15 minutes old, show a muted label below the price.

The exact implementation depends on the full DecisionCard component structure. The key additions to the card's metadata rendering section:

```tsx
{/* Airline logo — small inline logo for flight cards */}
{metadata?.image_url && String(metadata.image_url).startsWith("/airline-logos/") && (
  <img
    src={String(metadata.image_url)}
    alt=""
    width={32}
    height={32}
    style={{ borderRadius: 6, objectFit: "contain", background: "rgba(255,255,255,0.06)" }}
  />
)}

{/* Book button — opens deep-link to Google Flights/Hotels */}
{(metadata?.booking_url || metadata?.external_url) && (
  <a
    href={String(metadata.booking_url || metadata.external_url)}
    target="_blank"
    rel="noopener noreferrer"
    onClick={(e) => e.stopPropagation()}
    style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 4,
      padding: "4px 12px",
      borderRadius: 14,
      background: "var(--hello-accent)",
      color: "white",
      fontSize: 11,
      fontWeight: 400,
      textDecoration: "none",
      cursor: "pointer",
    }}
  >
    Book
  </a>
)}

{/* Price staleness label for cached flights */}
{metadata?.cached_at && typeof metadata.cached_at === "number" && (
  (() => {
    const ageMs = Date.now() - Number(metadata.cached_at);
    if (ageMs < 15 * 60 * 1000) return null;
    const ageMin = Math.round(ageMs / 60000);
    const label = ageMin < 60
      ? `Price from ${ageMin}m ago`
      : `Price from ${Math.round(ageMin / 60)}h ago`;
    return (
      <span style={{ fontSize: 10, color: "var(--hello-ink-tertiary)", fontWeight: 300 }}>
        {label}. Verify on Google Flights.
      </span>
    );
  })()
)}
```

- [ ] **Step 2: Commit**

```bash
git add web/src/components/os/DecisionCard.tsx
git commit -m "feat: add Book button, airline logo, and price staleness to DecisionCard"
```

---

### Task 10: Update route.ts — Pass booking_url + cached_at to decision_items

**Files:**
- Modify: `web/src/app/api/hello/route.ts`

- [ ] **Step 1: Add booking_url and cached_at to item metadata**

In the `after()` block where decision items are created (around line 368-390), add `booking_url` and `cached_at` to the metadata object:

```typescript
// In the items.map() inside the after() block, update the metadata:
metadata: {
  price: r.price,
  image_url: photoUrls[idx] ?? fallbackImg,
  external_url: r.externalUrl,
  booking_url: r.externalUrl, // deep-link to Google Flights/Hotels/Maps
  cached_at: Date.now(), // for price staleness label on flight cards
  source: r.source ?? "searchapi",
  search_tier: r.source === "fli" ? "fli" : r.source?.startsWith("google-") ? "searchapi" : r.source === "gemini-local" ? "gemini-local" : r.source === "gemini-search" ? "gemini-search" : "apify",
  rating: r.rating,
  search_batch: searchBatch,
  search_label: searchLabel,
},
```

- [ ] **Step 2: Commit**

```bash
git add web/src/app/api/hello/route.ts
git commit -m "feat: add booking_url and cached_at to decision_item metadata"
```

---

### Task 11: Smoke Test

- [ ] **Step 1: Verify fli Python function locally**

```bash
cd /Users/ramchitturi/hello/web
npm run dev &
sleep 5

# Test fli endpoint
curl -s -X POST http://localhost:3000/api/fli \
  -H "Content-Type: application/json" \
  -d '{"origin":"JFK","destination":"LAX","date":"2026-06-15","max_results":3}' | jq '.results[:2]'
```

Expected: JSON with flight results including `airline_code`, `legs`, `price`.

Note: If the Python function doesn't work locally (Vercel Python runtime is Vercel-only), test after deploying to preview:

```bash
vercel deploy --no-wait
# Use the preview URL to test
curl -s -X POST https://<preview-url>/api/fli \
  -H "Content-Type: application/json" \
  -d '{"origin":"JFK","destination":"LAX","date":"2026-06-15","max_results":3}' | jq '.results[:2]'
```

- [ ] **Step 2: Verify full orchestrator flow**

With the dev server running, test via the @hello API:

```bash
# This requires auth — use the dev-auth endpoint first if needed
curl -s -X POST http://localhost:3000/api/hello \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <your-dev-token>" \
  -d '{"message":"@hello find flights from JFK to Bali","groupId":"test_group"}' | jq '{response, action, tool}'
```

Expected: `{ response: "found X flights...", action: "search", tool: "flight" }`

- [ ] **Step 3: Verify airline logos served**

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/airline-logos/QR.png
# Expected: 200

curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/airline-logos/AA.png
# Expected: 200
```

---

## Execution Order

```
Task 1 (logos)  ─┐
Task 2 (links)  ─┤─── independent, parallel
Task 3 (cache)  ─┤
Task 4 (python) ─┘
                  │
Task 5 (client) ──┤─── depends on 2, 3, 4
                  │
Task 6 (registry) ┤─── depends on 5
Task 7 (orch)    ─┘─── depends on 5, 6
                  │
Task 8 (cron)   ──┤─── depends on 4
Task 9 (card)   ──┤─── depends on 2
Task 10 (route) ──┘─── depends on 2
                  │
Task 11 (test)  ──── depends on all
```

Tasks 1-4 can run in parallel. Tasks 5-7 are sequential. Tasks 8-10 can run in parallel. Task 11 is last.
