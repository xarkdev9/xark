// XARK OS v2.0 — Apify Tool Registry
// Register Apify actors by category. Orchestrator routes @xark requests here.

export interface ToolDefinition {
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
  actorId: "voyager/booking-scraper",
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
  actorId: "johnvc/Google-Flights-Data-Scraper-Flight-and-Price-Search",
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
  actorId: "compass/crawler-google-places",
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
  actorId: "compass/crawler-google-places",
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
  actorId: "apify/google-search-scraper",
  description: "General web search for any topic",
  paramMap: (p) => ({
    queries: p.query,
    maxPagesPerQuery: 1,
    resultsPerPage: 10,
  }),
});
