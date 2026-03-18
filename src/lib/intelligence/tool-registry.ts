// XARK OS v2.0 — Apify Tool Registry
// Register Apify actors by category. Orchestrator routes @xark requests here.

export interface ToolDefinition {
  tier: "gemini-search" | "apify";
  actorId: string;
  description: string;
  paramMap: (userParams: Record<string, string>) => Record<string, unknown>;
}

const registry: Record<string, ToolDefinition> = {};

export function registerTool(name: string, tool: ToolDefinition): void {
  registry[name] = tool;
}

export function getTool(name: string): ToolDefinition | null {
  return registry[name] ?? null;
}

export function listTools(): string[] {
  return Object.keys(registry);
}

// Register default tools — real Apify actor IDs

registerTool("hotel", {
  tier: "apify",
  actorId: process.env.APIFY_HOTEL_ACTOR || "voyager/booking-scraper",
  description: "Search hotels by location, dates, and price range",
  paramMap: (p) => ({
    search: p.location,
    checkIn: p.checkIn || undefined,
    checkOut: p.checkOut || undefined,
    currency: "USD",
    language: "en-us",
    maxItems: 10,
    minScore: p.maxPrice ? undefined : "7",
    // "review_score_and_price" requires dates; "bayesian_review_score" works without
    sortBy: p.checkIn && p.checkOut ? "review_score_and_price" : "bayesian_review_score",
  }),
});

registerTool("flight", {
  tier: "apify",
  actorId: process.env.APIFY_FLIGHT_ACTOR || "johnvc/Google-Flights-Data-Scraper-Flight-and-Price-Search",
  description: "Search flights by origin, destination, and dates",
  paramMap: (p) => ({
    departure_id: p.origin,
    arrival_id: p.destination,
    outbound_date: p.date,
    return_date: p.returnDate || undefined,
    currency: p.currency || "USD",
    max_pages: 1,
  }),
});

registerTool("activity", {
  tier: "apify",
  actorId: process.env.APIFY_ACTIVITY_ACTOR || "compass/crawler-google-places",
  description: "Find activities and experiences by location",
  paramMap: (p) => ({
    searchStringsArray: [
      p.category
        ? `${p.category} in ${p.location}`
        : `things to do in ${p.location}`,
    ],
    maxCrawledPlacesPerSearch: 10,
    language: "en",
  }),
});

registerTool("restaurant", {
  tier: "apify",
  actorId: process.env.APIFY_RESTAURANT_ACTOR || "compass/crawler-google-places",
  description: "Search restaurants by location and cuisine",
  paramMap: (p) => ({
    searchStringsArray: [
      p.cuisine
        ? `${p.cuisine} restaurants in ${p.location}`
        : `restaurants in ${p.location}`,
    ],
    maxCrawledPlacesPerSearch: 10,
    language: "en",
  }),
});

registerTool("general", {
  tier: "gemini-search",
  actorId: "",
  description: "General knowledge search — best airports, travel tips, recommendations, planning questions",
  paramMap: (params) => params,
});

registerTool("local_restaurant", {
  tier: "gemini-search",
  actorId: "",
  description: "Local restaurant search via Gemini Search grounding",
  paramMap: (params) => params,
});

registerTool("local_activity", {
  tier: "gemini-search",
  actorId: "",
  description: "Local activity/place search via Gemini Search grounding",
  paramMap: (params) => params,
});

registerTool("local_general", {
  tier: "gemini-search",
  actorId: "",
  description: "General local search via Gemini Search grounding",
  paramMap: (params) => params,
});
