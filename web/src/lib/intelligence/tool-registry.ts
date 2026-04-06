// hello OS v2.0 — Apify Tool Registry
// Register Apify actors by category. Orchestrator routes @hello requests here.

export interface ToolDefinition {
  tier: "gemini-search" | "apify" | "searchapi" | "fli";
  actorId: string;
  description: string;
  paramMap: (userParams: Record<string, string>) => Record<string, unknown>;
  /** SearchApi engine type — used when tier is "searchapi" */
  searchApiEngine?: "google_hotels" | "google_flights" | "google_local" | "google";
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

/**
 * Gemini native function declarations for tool calling.
 * Passed to tools: [{ functionDeclarations }] in generateContent().
 */
export function getFunctionDeclarations() {
  return [
    {
      name: "search_local_restaurant",
      description: "Search for restaurants, coffee shops, bars, brunch spots, dinner places. Use for casual food queries.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          query: { type: "STRING" as const, description: "Search query e.g. 'best tacos in san jose'" },
          location: { type: "STRING" as const, description: "City, neighborhood, or landmark. Resolve landmarks to nearest city." },
        },
        required: ["query"],
      },
    },
    {
      name: "search_local_activity",
      description: "Search for activities, sunset spots, parks, beaches, nightlife, things to do. Use for casual activity queries.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          query: { type: "STRING" as const, description: "Search query e.g. 'sunset spots in big sur'" },
          location: { type: "STRING" as const, description: "City, neighborhood, or landmark." },
        },
        required: ["query"],
      },
    },
    {
      name: "search_general",
      description: "General knowledge search — use for gift ideas, product recommendations, weather, nearby airports, transit times, best time to visit, travel tips, shopping, bill splitting, and any general web queries. This is the catch-all for anything that isn't a specific restaurant/activity/hotel/flight search.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          query: { type: "STRING" as const, description: "Knowledge query" },
        },
        required: ["query"],
      },
    },
    {
      name: "search_hotel",
      description: "Search for hotels, stays, resorts, airbnb, lodging, accommodation. MUST use this tool for ANY query mentioning hotels, stays, resorts, airbnb, or accommodation. NEVER use search_local_activity or search_general for hotel queries.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          location: { type: "STRING" as const, description: "City or area. REQUIRED. Resolve landmarks to nearest city (e.g. 'bixby bridge' → 'Big Sur, CA')." },
          query: { type: "STRING" as const, description: "Optional modifiers (e.g. 'beach view', 'pet friendly', 'luxury with pool'). Omit if no specific preference." },
          checkIn: { type: "STRING" as const, description: "Check-in date YYYY-MM-DD" },
          checkOut: { type: "STRING" as const, description: "Check-out date YYYY-MM-DD" },
          maxPrice: { type: "STRING" as const, description: "Max price per night in USD" },
        },
        required: ["location"],
      },
    },
    {
      name: "search_flight",
      description: "Search for flights. MUST use this tool for ANY query mentioning flights, airfare, or airplane travel. NEVER use search_local_activity or search_general for flight queries. Convert city names to IATA codes. If origin is missing, ask the user.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          origin: { type: "STRING" as const, description: "Origin IATA airport code. Convert city names: 'san francisco'→'SFO', 'new york'→'JFK', 'hyderabad'→'HYD', 'mumbai'→'BOM', 'delhi'→'DEL', 'bangalore'→'BLR', 'chennai'→'MAA', 'london'→'LHR', 'dubai'→'DXB'" },
          destination: { type: "STRING" as const, description: "Destination IATA airport code. Same conversion rules as origin." },
          date: { type: "STRING" as const, description: "Departure date YYYY-MM-DD. Convert relative dates: 'first week of may' → '2026-05-01', 'next friday' → actual date, 'christmas' → '2026-12-25'" },
          returnDate: { type: "STRING" as const, description: "Return date YYYY-MM-DD (optional)" },
        },
        required: ["destination"],
      },
    },
    {
      name: "search_restaurant",
      description: "Detailed restaurant search with ratings, prices, reviews. Use when user needs structured listings.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          location: { type: "STRING" as const, description: "City or area" },
          cuisine: { type: "STRING" as const, description: "Cuisine type (e.g. 'indian', 'italian')" },
        },
        required: ["location"],
      },
    },
    {
      name: "search_activity",
      description: "Detailed activity search with structured listings, reviews. Use when user needs specific event/attraction data.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          location: { type: "STRING" as const, description: "City or area" },
          category: { type: "STRING" as const, description: "Activity category" },
        },
        required: ["location"],
      },
    },
    {
      name: "respond_to_user",
      description: "Send a direct text response. Use for: status questions, weather (ask where if no location), date questions, greetings, off-topic rejection, clarification.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          message: { type: "STRING" as const, description: "Your brief, casual response (max 20 words, no AI cringe)" },
        },
        required: ["message"],
      },
    },
    {
      name: "set_dates",
      description: "Set trip dates for the space. Use when user specifies travel dates.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          start_date: { type: "STRING" as const, description: "Start date YYYY-MM-DD" },
          end_date: { type: "STRING" as const, description: "End date YYYY-MM-DD" },
          label: { type: "STRING" as const, description: "Optional label e.g. 'spring break'" },
        },
        required: ["start_date", "end_date"],
      },
    },
    {
      name: "create_poll",
      description: "Create a live poll for group decision. Use when user asks to vote or decide between options.",
      parameters: {
        type: "OBJECT" as const,
        properties: {
          title: { type: "STRING" as const, description: "Poll title" },
          options: { type: "ARRAY" as const, items: { type: "STRING" as const }, description: "2-5 poll options" },
          message: { type: "STRING" as const, description: "Brief message about the poll" },
        },
        required: ["title", "options"],
      },
    },
  ];
}

// Register default tools — real Apify actor IDs

registerTool("hotel", {
  tier: "searchapi",
  actorId: process.env.APIFY_HOTEL_ACTOR || "voyager/booking-scraper",
  searchApiEngine: "google_hotels",
  description: "Search hotels via Google Hotels API",
  paramMap: (p) => ({
    location: p.location,
    query: p.query,
    checkIn: p.checkIn || undefined,
    checkOut: p.checkOut || undefined,
  }),
});

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

registerTool("activity", {
  tier: "searchapi",
  actorId: process.env.APIFY_ACTIVITY_ACTOR || "compass/crawler-google-places",
  searchApiEngine: "google_local",
  description: "Find activities via Google Local API",
  paramMap: (p) => ({
    query: p.category ? `${p.category} in ${p.location}` : `things to do in ${p.location}`,
    location: p.location,
  }),
});

registerTool("restaurant", {
  tier: "searchapi",
  actorId: process.env.APIFY_RESTAURANT_ACTOR || "compass/crawler-google-places",
  searchApiEngine: "google_local",
  description: "Search restaurants via Google Local API",
  paramMap: (p) => ({
    query: p.cuisine ? `${p.cuisine} restaurants in ${p.location}` : `restaurants in ${p.location}`,
    location: p.location,
  }),
});

registerTool("general", {
  tier: "searchapi",
  actorId: "",
  searchApiEngine: "google",
  description: "General knowledge search via Google Search API",
  paramMap: (params) => ({ query: params.query }),
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
