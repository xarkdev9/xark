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

// Register default tools
registerTool("hotel", {
  actorId: "apify/hotel-scraper",
  description: "Search hotels by location, dates, and price range",
  paramMap: (p) => ({
    location: p.location,
    checkIn: p.checkIn,
    checkOut: p.checkOut,
    maxPrice: p.maxPrice ? Number(p.maxPrice) : undefined,
  }),
});

registerTool("flight", {
  actorId: "apify/flight-scraper",
  description: "Search flights by origin, destination, and dates",
  paramMap: (p) => ({
    origin: p.origin,
    destination: p.destination,
    date: p.date,
    returnDate: p.returnDate,
  }),
});

registerTool("activity", {
  actorId: "apify/activity-finder",
  description: "Find activities and experiences by location",
  paramMap: (p) => ({
    location: p.location,
    category: p.category,
  }),
});

registerTool("restaurant", {
  actorId: "apify/restaurant-search",
  description: "Search restaurants by location and cuisine",
  paramMap: (p) => ({
    location: p.location,
    cuisine: p.cuisine,
    maxPrice: p.maxPrice ? Number(p.maxPrice) : undefined,
  }),
});

registerTool("general", {
  actorId: "apify/web-scraper",
  description: "General web search for any topic",
  paramMap: (p) => ({ query: p.query }),
});
