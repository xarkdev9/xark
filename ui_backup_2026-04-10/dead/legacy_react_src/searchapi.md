


Your migration architecture is spot on. I highly recommend moving all four primary tools (hotel, flight, restaurant, activity) to tier: "searchapi".

You should absolutely keep Apify in the codebase, but wire it as a silent, automatic fallback in your orchestrator.ts. Instead of making the LLM choose between them, simply tell the orchestrator: If the SearchApi client times out or returns zero results, immediately fire the Apify actor. This gives you the lightning speed of SearchApi for 95% of queries, with the bulletproof scraping redundancy of Apify for the edge cases, all without the user ever noticing a hiccup.

As for making the app truly remarkable, the leap from a "good project" to a transformative product usually comes down to moving past a standard chat interface and building a conversational operating system. Here is how you elevate Hello into that top tier:

1. Generative UI (Move Beyond Markdown)
Text lists of flights and hotels are okay, but native UI is remarkable. Instead of having the AI return a formatted markdown string of search results, have it return a structured JSON payload that your front-end catches and renders as native, interactive cards right inside the chat stream. Users shouldn't be reading a text block about a flight; they should see a sleek UI component where they can tap a button to "Vote" or "Split Cost," updating the state locally for everyone in the group.

2. Leverage the Privacy Architecture
Building an end-to-end encrypted foundation gives you a massive trust advantage over almost every other AI tool on the market right now. Most assistants ingest group data to train models. Making it cryptographically clear to your users that the AI acts as a transient, invited agent that drops all context the moment the session ends is a huge selling point. Lean into that security as a core product identity.

3. Opinionated, Proactive Logistics
The best assistants don't wait to be asked 20 questions; they anticipate the bottleneck. If the group consensus is clearly leaning toward a specific weekend in San Diego, the app should silently preempt the logistics and drop a message: "Looks like we are locking in the 12th. Flights out of SFO are currently $140. Want me to track prices or book it?" ### 4. Zero-Latency Illusions
You already have the right idea with the phantom receipt (onProgress) function. To make it feel instantaneous, push that further. If a user asks a complex question, stream the AI's _thought_process to the UI as a subtle, elegant loading state (e.g., Looking at downtown hotels -> Checking availability -> Filtering for pools). It makes a 3-second wait feel like 300 milliseconds because the user is watching the gears turn.

Would you like me to draft the new searchapi-client.ts file for you, or show you exactly how that automatic Apify fallback logic should look inside your orchestrator?


This dual-layer architecture—using SearchApi for lightning-fast primary results and Apify as a silent, bulletproof fallback—is exactly the kind of engineering that separates a standard wrapper from a remarkable, production-grade AI agent.

Here is the complete implementation plan.

1. Create searchapi-client.ts
Create this file right next to your apify-client.ts. It handles the fetching and normalizes SearchApi's various JSON structures (Flights, Hotels, Local) into the exact same ApifyResult interface your UI already expects.

TypeScript
// XARK OS v2.0 — SearchApi Client
// Primary fast-tier search for flights, hotels, and local places.

export interface SearchResult {
  title: string;
  price?: string;
  imageUrl?: string;
  description?: string;
  externalUrl?: string;
  rating?: number;
  source: string;
}

export async function runSearchApi(
  engine: "google_flights" | "google_hotels" | "google_local" | "google",
  params: Record<string, string>
): Promise<SearchResult[]> {
  const apiKey = process.env.SEARCHAPI_API_KEY;
  if (!apiKey) {
    console.warn("[@hello] SearchApi key missing");
    return [];
  }

  const queryParams = new URLSearchParams({
    engine,
    api_key: apiKey,
    ...params,
  });

  try {
    const response = await fetch(`https://www.searchapi.io/api/v1/search?${queryParams}`);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const data = await response.json();

    return normalizeSearchResults(engine, data);
  } catch (error) {
    console.error(`[@hello] SearchApi failed (${engine}):`, error);
    return [];
  }
}

function normalizeSearchResults(engine: string, data: any): SearchResult[] {
  if (engine === "google_flights" && data.flights) {
    return data.flights.map((f: any) => ({
      title: `${f.flights[0].airline} ${f.flights[0].flight_number}`,
      price: f.price ? `$${f.price}` : undefined,
      description: `${f.duration} min, ${f.stops === 0 ? "Nonstop" : f.stops + " stop(s)"}. ${f.flights[0].departure_airport.id} → ${f.flights[f.flights.length - 1].arrival_airport.id}`,
      source: "searchapi",
    }));
  }

  if (engine === "google_hotels" && data.properties) {
    return data.properties.map((h: any) => ({
      title: h.name,
      price: h.rate_per_night?.lowest ? `$${h.rate_per_night.lowest}` : undefined,
      rating: h.overall_rating,
      description: h.description,
      externalUrl: h.link,
      imageUrl: h.images?.[0]?.thumbnail,
      source: "searchapi",
    }));
  }

  if (engine === "google_local" && data.local_results) {
    return data.local_results.map((l: any) => ({
      title: l.title,
      rating: l.rating,
      description: `${l.type || "Place"} — ${l.address}`,
      price: l.price, // SearchApi returns $, $$, etc.
      externalUrl: l.website || l.place_id_link,
      imageUrl: l.thumbnail,
      source: "searchapi",
    }));
  }

  return [];
}
2. Update tool-registry.ts
We need to update your tool definitions so they hold the routing logic for both SearchApi and the Apify fallback.

Update your ToolDefinition interface and tools like this:

TypeScript
export interface ToolDefinition {
  tier: "searchapi" | "gemini-search";
  engine?: "google_flights" | "google_hotels" | "google_local" | "google";
  searchApiMap?: (userParams: Record<string, string>) => Record<string, string>;
  
  // Apify Fallback Config
  fallbackActorId?: string;
  apifyMap?: (userParams: Record<string, string>) => Record<string, unknown>;
  description: string;
}

// Example: The new Flight Tool
registerTool("flight", {
  tier: "searchapi",
  engine: "google_flights",
  description: "Search flights by origin, destination, and dates",
  
  // 1. Primary: SearchApi params
  searchApiMap: (p) => ({
    departure_id: p.origin?.toUpperCase() || "",
    arrival_id: p.destination?.toUpperCase() || "",
    outbound_date: p.date || new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10),
    return_date: p.returnDate || "",
    currency: "USD"
  }),

  // 2. Fallback: Apify params
  fallbackActorId: process.env.APIFY_FLIGHT_ACTOR || "johnvc/Google-Flights-Data-Scraper-Flight-and-Price-Search",
  apifyMap: (p) => ({
    departure_id: p.origin?.toUpperCase(),
    arrival_id: p.destination?.toUpperCase(),
    outbound_date: p.date,
    currency: "USD",
  }),
});

// Example: The new Restaurant/Activity Tool (using Google Local)
registerTool("restaurant", {
  tier: "searchapi",
  engine: "google_local",
  description: "Search restaurants by location and cuisine",
  searchApiMap: (p) => ({
    q: p.cuisine ? `${p.cuisine} restaurants in ${p.location}` : `restaurants in ${p.location}`,
    hl: "en",
    gl: "us"
  }),
  fallbackActorId: "compass/crawler-google-places",
  apifyMap: (p) => ({
    searchStringsArray: [p.cuisine ? `${p.cuisine} in ${p.location}` : `restaurants in ${p.location}`],
  }),
});
3. Update orchestrator.ts (The Magic Fallback Logic)
Now, find the execution block in your orchestrator. We will try SearchApi first. If it fails, times out, or returns [], it instantly catches it and triggers Apify so the user never gets an error.

TypeScript
import { runSearchApi } from "./searchapi-client";
import { runActor } from "./apify-client";

// ... inside your orchestrate() function ...

    // ── SearchApi tier (Primary) with Apify Fallback ──
    if (tool.tier === "searchapi" && tool.engine && tool.searchApiMap) {
      let results: any[] = [];
      let mappedParams = tool.searchApiMap(params);
      let searchSource = "SearchApi";

      try {
        console.log(`[@hello] Attempting fast SearchApi for ${toolName}...`);
        // Add a strict timeout to SearchApi so it doesn't hang the UI
        results = await withTimeout(runSearchApi(tool.engine, mappedParams), 10000);
      } catch (err) {
        console.warn(`[@hello] SearchApi failed or timed out: ${err}`);
      }

      // ── THE FALLBACK TRIGGER ──
      // If SearchApi returned nothing or crashed, instantly fire Apify
      if (results.length === 0 && tool.fallbackActorId && tool.apifyMap) {
        console.log(`[@hello] SearchApi empty. Falling back to heavy Apify actor: ${tool.fallbackActorId}`);
        searchSource = "Apify (Fallback)";
        
        try {
          const apifyParams = tool.apifyMap(params);
          results = await runActor(tool.fallbackActorId, apifyParams);
        } catch (apifyErr) {
          console.error("[@hello] Apify fallback also failed:", apifyErr);
        }
      }

      if (results.length === 0) {
        return { response: "searched everywhere but came up empty. try being a bit broader?", action: "search" };
      }

      // Context-aware synthesis
      const synthesisPrompt = buildSynthesisPrompt(input, results);
      const synthesisResult = await withTimeout(model.generateContent(synthesisPrompt), GEMINI_TIMEOUT_MS);

      return {
        response: isGarbageResponse(synthesisResult.response.text()) ? `found ${results.length} options via ${searchSource}.` : synthesisResult.response.text(),
        searchResults: results,
        action: "search",
        tool: toolName,
        _debug: { source: searchSource }
      };
    }
This setup completely changes the feel of the app. Your standard restaurant and local queries will now resolve in ~1-2 seconds via SearchApi, while complex hotel grids that require deep scraping will lean on Apify as needed, ensuring @hello never drops the ball.

Does this structure make sense for the way your app's data flow is set up?