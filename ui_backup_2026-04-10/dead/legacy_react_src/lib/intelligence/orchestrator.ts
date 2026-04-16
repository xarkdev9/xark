// hello OS v2.0 — @hello Intelligence Orchestrator
// Gemini parses intent → routes to Apify tool → synthesizes response.
// Stateless. No state stored. Reads grounding context + last 15 messages.
// Native JSON mode (responseMimeType), chain-of-thought (_thought_process),
// self-healing retry, context-aware synthesis. Anti-cringe voice.

import { GoogleGenerativeAI, HarmCategory, HarmBlockThreshold, type GenerativeModel } from "@google/generative-ai";
import { getTool, listTools, getFunctionDeclarations } from "./tool-registry";
import { runActor, startActorAsync, type ApifyResult } from "./apify-client";
import { buildTastePromptInjection } from "@/lib/taste";

const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
  : null;

const GEMINI_TIMEOUT_MS = 45_000;
const MAX_RESPONSE_LENGTH = 500;

// ── Timeout wrapper — prevents Gemini from hanging indefinitely ──
function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error("gemini timeout")), ms)
    ),
  ]);
}

// ── Response quality gate — reject Gemini garbage before it reaches the user ──
export function isGarbageResponse(text: string): boolean {
  if (!text || text.trim().length === 0) return true;
  if (text.length > MAX_RESPONSE_LENGTH) return true;

  const words = text.split(/\s+/);
  if (words.length > 20) {
    const periodWords = words.filter((w) => w.endsWith(".") && w.length < 15);
    if (periodWords.length / words.length > 0.5) return true;
  }

  if (words.length > 15) {
    const counts = new Map<string, number>();
    for (const w of words) {
      const lower = w.toLowerCase().replace(/[^a-z]/g, "");
      if (lower.length > 0) counts.set(lower, (counts.get(lower) ?? 0) + 1);
    }
    for (const count of counts.values()) {
      if (count > 5) return true;
    }
  }

  return false;
}

const GARBAGE_FALLBACK = "couldn't process that. trying a different approach...";

export interface OrchestratorInput {
  userMessage: string;
  groundingPrompt: string;
  recentMessages: Array<{ role: string; content: string; sender_name?: string }>;
  spaceId: string;
  spaceTitle?: string;
  tasteContext?: { hardConstraints: string[]; softPreferences: string; onboardedCount: number; memberCount: number } | null;
  /** Priority 9: Realtime progress callback — updates phantom receipt as @hello works */
  onProgress?: (text: string) => Promise<void>;
  /** Priority 11: Webhook URL for async Apify actors — if set, Apify tier returns immediately */
  webhookUrl?: string;
  /** HelloPanel slot payload — bypasses Gemini function call when confidence is 1.0 */
  slotPayload?: {
    source: string;
    intent: string;
    confidence: number;
    params: Record<string, string>;
  };
}

export interface OrchestratorResult {
  response: string;
  searchResults?: ApifyResult[];
  action?: "search" | "reason" | "propose" | "set_dates" | "populate_logistics" | "create_poll";
  tool?: string;
  pendingConfirmation?: boolean;
  payload?: Record<string, unknown>;
  extractions?: Array<{
    user_name: string;
    category?: string;
    origin?: string;
    destination?: string;
    confidence: number;
  }>;
  _debug?: Record<string, unknown>;
}

/** Fast local search — direct Gemini knowledge (no Google Search tool, ~3-5s) */
async function geminiLocalSearch(
  model: GenerativeModel,
  query: string,
  spaceTitle: string
): Promise<Array<{ title: string; description: string; url?: string; phone?: string; address?: string }>> {
  const location = spaceTitle || "the area";

  try {
    const result = await withTimeout(
      model.generateContent({
        contents: [{ role: "user", parts: [{ text: `You are a local guide for ${location}. Return 5-8 real, well-known places for: "${query}".

RULES:
- ONLY return places you are confident actually exist. no made-up names.
- include the neighborhood/area in the description.
- if you're not sure about a place, skip it. fewer accurate results > many guesses.

Return ONLY a JSON array:
[{"title":"Place Name","description":"Brief description with neighborhood","address":"approximate address or area"}]` }] }],
        generationConfig: {
          responseMimeType: "application/json",
        },
      }),
      GEMINI_TIMEOUT_MS
    );

    const responseText = result.response.text();
    if (!responseText) return [];

    const parsed = JSON.parse(responseText);
    const items = Array.isArray(parsed) ? parsed : [];
    return items.map((item: Record<string, unknown>) => ({
      title: String(item.title || ""),
      description: String(item.description || ""),
      url: item.url ? String(item.url) : undefined,
      phone: item.phone ? String(item.phone) : undefined,
      address: item.address ? String(item.address) : undefined,
    }));
  } catch {
    return [];
  }
}

/** Call Gemini with Google Search grounding for knowledge queries */
async function geminiSearchGrounded(
  model: GenerativeModel,
  query: string,
  spaceTitle: string
): Promise<Array<{ title: string; description: string; url?: string; phone?: string; address?: string }>> {
  const contextualQuery = spaceTitle ? `${query} near ${spaceTitle}` : query;

  try {
    const result = await withTimeout(
      model.generateContent({
        contents: [{ role: "user", parts: [{ text: `Find real places for: ${contextualQuery}. Return a JSON array of objects with fields: title, description, url, phone, address. Return ONLY the JSON array, no other text.` }] }],
        tools: [{ googleSearch: {} }] as any,
      }),
      GEMINI_TIMEOUT_MS
    );

    const responseText = result.response.text();
    const jsonMatch = responseText.match(/\[[\s\S]*\]/);
    if (!jsonMatch) return [];

    const parsed = JSON.parse(jsonMatch[0]);
    if (!Array.isArray(parsed)) return [];
    return parsed.map((item: Record<string, unknown>) => ({
      title: String(item.title || ""),
      description: String(item.description || ""),
      url: item.url ? String(item.url) : undefined,
      phone: item.phone ? String(item.phone) : undefined,
      address: item.address ? String(item.address) : undefined,
    }));
  } catch {
    return [];
  }
}

export async function orchestrate(input: OrchestratorInput): Promise<OrchestratorResult> {
  if (!genAI) {
    return { response: "not configured yet. someone needs to set up the api key." };
  }

  const modelName = process.env.GEMINI_MODEL || "gemini-2.5-flash";

  // ── PRIORITY 3: systemInstruction — persona rules processed at deeper level ──
  const model = genAI.getGenerativeModel({
    model: modelName,
    systemInstruction: buildStaticPrompt(),
    safetySettings: [
      { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
      { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
      { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
      { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
    ],
  });

  // ── HELLO PANEL DETERMINISTIC BYPASS ──
  // confidence 1.0 = locked intent chip → skip Gemini, go directly to SearchApi
  // confidence 0.5 = general query → try SearchApi, fall through to Gemini if empty
  // confidence 0.0 = conversational/computational → skip entirely, let Gemini answer
  if (input.slotPayload && input.slotPayload.confidence >= 0.5) {
    const { intent, params } = input.slotPayload;
    console.log(`[@hello] Deterministic bypass: intent=${intent}, params=${JSON.stringify(params)}`);

    if (input.onProgress) {
      input.onProgress(`searching ${params.location || params.query || "..."}...`).catch(() => {});
    }

    const tool = getTool(intent);
    if (tool && tool.tier === "searchapi") {
      try {
        const { searchHotels, searchFlights, searchLocal, searchGeneral: searchGeneralApi } = await import("./searchapi-client");

        let searchResults: ApifyResult[] = [];

        if (tool.searchApiEngine === "google_hotels") {
          searchResults = await searchHotels(params as { location: string; query?: string; checkIn?: string; checkOut?: string });
        } else if (tool.searchApiEngine === "google_flights") {
          searchResults = await searchFlights(params as { origin: string; destination: string; date?: string; returnDate?: string });
        } else if (tool.searchApiEngine === "google_local") {
          searchResults = await searchLocal(params as { query: string; location?: string });
        } else if (tool.searchApiEngine === "google") {
          searchResults = await searchGeneralApi(params as { query: string });
        }

        if (searchResults.length > 0) {
          return {
            response: `found ${searchResults.length} spots for ${params.query || intent}. decide →`,
            searchResults,
            action: "search",
            tool: intent,
          };
        }
      } catch (err) {
        console.error("[@hello] Deterministic SearchApi failed:", err instanceof Error ? err.message : String(err));
      }
    }

    // If SearchApi failed or no tool found, fall through to Gemini
    console.log("[@hello] Deterministic bypass failed, falling through to Gemini");
  }

  // ── PRIORITY 1: Native function calling — Gemini calls tools directly ──
  // ── PRIORITY 10: Native conversational turns ──
  const conversationHistory = input.recentMessages
    .filter((m) => m.content && m.content.trim().length > 0)
    .map((m) => ({
      role: m.role === "hello" ? "model" as const : "user" as const,
      parts: [{ text: `${m.sender_name ? m.sender_name + ": " : ""}${m.content}` }],
    }));

  // Build the dynamic context as the final user message
  const dynamicContext = buildDynamicPrompt(input);

  try {
    const result = await withTimeout(
      model.generateContent({
        contents: [
          ...conversationHistory,
          { role: "user", parts: [{ text: dynamicContext }] },
        ],
        tools: [{ functionDeclarations: getFunctionDeclarations() as any }],
      }),
      GEMINI_TIMEOUT_MS
    );

    const candidate = result.response.candidates?.[0];
    if (candidate?.finishReason === "SAFETY") {
      return { response: "nope. let's keep it chill.", action: "reason" };
    }

    // ── Check for native function call ──
    const functionCall = result.response.functionCalls()?.[0];

    if (functionCall) {
      const { name, args } = functionCall;
      const params = (args ?? {}) as Record<string, string>;
      console.log(`[@hello] function call: ${name}`, JSON.stringify(params).slice(0, 120));

      // PRIORITY 9: Realtime thinking update after intent parse
      if (input.onProgress) {
        const location = params.location || params.query || input.spaceTitle || "";
        input.onProgress(`searching ${location.toLowerCase().slice(0, 50)}...`).catch(() => {});
      }

      // ── Route based on function name ──
      if (name === "respond_to_user") {
        const msg = params.message || "";
        return { response: isGarbageResponse(msg) ? GARBAGE_FALLBACK : msg, action: "reason" };
      }

      if (name === "set_dates") {
        return {
          response: `${params.start_date} to ${params.end_date}. lock it in?`,
          action: "set_dates",
          pendingConfirmation: true,
          payload: { start_date: params.start_date, end_date: params.end_date, label: params.label },
        };
      }

      if (name === "create_poll") {
        const options = (args as any)?.options;
        return {
          response: params.message || "created a poll. tap your pick.",
          action: "create_poll",
          payload: { title: params.title || "Live Poll", options: Array.isArray(options) ? options : [] },
        };
      }

      // ── Search function calls — map to tool registry ──
      const toolName = name.replace("search_", "");
      const tool = getTool(toolName);
      if (!tool) {
        return { response: `don't have a ${toolName} search yet. try something else?`, action: "search" };
      }

      // Store parsed info for the search routing below
      var searchTool = tool;
      var searchToolName = toolName;
      var searchParams = params;
    } else {
      // No function call — check for text response (fallback)
      const textResponse = result.response.text();
      if (textResponse && textResponse.trim().length > 0) {
        return { response: isGarbageResponse(textResponse) ? GARBAGE_FALLBACK : textResponse.trim().slice(0, MAX_RESPONSE_LENGTH), action: "reason" };
      }
      return { response: GARBAGE_FALLBACK, action: "reason" };
    }
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    if (errMsg.toLowerCase().includes("safety") || errMsg.toLowerCase().includes("blocked")) {
      return { response: "that got flagged. moving on.", action: "reason" };
    }
    console.error("[@hello] function call failed:", errMsg);
    return { response: GARBAGE_FALLBACK, action: "reason", _debug: { stage: "function_call_failed", error: errMsg } };
  }

  // ── Step 2: Execute the search tool ──
  {
    const tool = searchTool!;
    const toolName = searchToolName!;
    const params = searchParams!;

    // ── Gemini Search grounding tier (fast, 2-3s, full maps integration) ──
    if (tool.tier === "gemini-search") {
      // Combine query + location for a complete search string
      // e.g. query="best tacos" + location="San Jose" → "best tacos in San Jose"
      const queryPart = params.query || input.userMessage;
      const locationPart = params.location || "";
      const query = locationPart && !queryPart.toLowerCase().includes(locationPart.toLowerCase())
        ? `${queryPart} in ${locationPart}`
        : queryPart;

      // Use extracted location (not space title) for local search context
      const searchLocation = locationPart || input.spaceTitle || "";

      // Try gemini-local first (fastest), escalate to gemini-search if empty
      let groundedResults = await geminiLocalSearch(model, query, searchLocation);
      if (groundedResults.length === 0) {
        // Fallback: escalate to Google Search grounding
        console.log("[@hello] gemini-local returned 0 results, escalating to gemini-search");
        groundedResults = await geminiSearchGrounded(model, query, searchLocation);
      }

      if (groundedResults.length === 0) {
        return { response: "searched but came up empty. try being more specific about the area?", action: "search" };
      }

      const results: ApifyResult[] = groundedResults.map((r) => ({
        title: r.title,
        description: [r.description, r.address, r.phone].filter(Boolean).join(" — "),
        externalUrl: r.url,
        source: "gemini-search",
      }));

      return {
        response: `found ${results.length} spots. they're in decide now.`,
        searchResults: results,
        action: "search",
        tool: toolName,
      };
    }

    // ── SearchApi tier (fast, 2-5s, real Google data with images) ──
    if (tool.tier === "searchapi") {
      const mappedParams = tool.paramMap(params);
      console.log(`[@hello] SearchApi dispatch: engine=${tool.searchApiEngine}, tier=${tool.tier}, actorId=${tool.actorId}, keys=${Object.keys(tool).join(",")}, params=${JSON.stringify(mappedParams).slice(0, 120)}`);
      try {
        const { searchHotels, searchFlights, searchLocal, searchGeneral: searchGeneralApi } = await import("./searchapi-client");

        let searchResults: ApifyResult[] = [];

        if (tool.searchApiEngine === "google_hotels") {
          const hotels = await searchHotels(mappedParams as { location: string; query?: string; checkIn?: string; checkOut?: string });
          console.log(`[@hello] SearchApi hotels returned: ${hotels.length} results`);
          if (hotels.length > 0) console.log(`[@hello] First hotel: ${hotels[0].title}, img: ${hotels[0].imageUrl?.slice(0, 60)}`);
          searchResults = hotels;
        } else if (tool.searchApiEngine === "google_flights") {
          const flights = await searchFlights(mappedParams as { origin: string; destination: string; date?: string; returnDate?: string });
          searchResults = flights;
        } else if (tool.searchApiEngine === "google_local") {
          const local = await searchLocal(mappedParams as { query: string; location?: string });
          searchResults = local;
        } else if (tool.searchApiEngine === "google") {
          const general = await searchGeneralApi(mappedParams as { query: string });
          searchResults = general;
        }

        if (searchResults.length > 0) {
          return {
            response: `found ${searchResults.length} spots. they're in decide now.`,
            searchResults,
            action: "search",
            tool: toolName,
          };
        } else {
          console.warn(`[@hello] SearchApi returned 0 results for ${toolName}. Falling through to Apify...`);
        }
      } catch (err) {
        console.error("[@hello] SearchApi failed, falling through to Apify:", err instanceof Error ? err.message : String(err));
        // Fall through to Apify/Gemini fallback
      }
    }

    // ── Apify tier (fallback) ──

    // ── PRIORITY 11: Async webhook mode — fire actor and return immediately ──
    if (input.webhookUrl && tool.tier === "apify") {
      try {
        const mappedParams = tool.paramMap(params);
        const webhookWithTool = `${input.webhookUrl}&tool=${encodeURIComponent(toolName)}`;
        const asyncResult = await startActorAsync(tool.actorId, mappedParams, webhookWithTool);
        if (asyncResult) {
          const query = params.query || params.location || input.userMessage;
          return {
            response: `scouting ${query.toLowerCase().slice(0, 50)}... results incoming.`,
            action: "search",
            tool: toolName,
            _debug: { asyncRunId: asyncResult.runId },
          };
        }
      } catch (apifyErr) {
        console.error("[@hello] Apify async start crashed:", apifyErr instanceof Error ? apifyErr.message : String(apifyErr));
      }
      // If async failed or returned null, fall through to synchronous
      console.warn("[@hello] async start failed, falling back to synchronous");
    }

    // ── Synchronous Apify fallback (no webhook URL or async start failed) ──
    // For SearchApi-tier tools falling through, rebuild Apify-compatible params
    let mappedParams: Record<string, unknown>;
    if (tool.tier === "searchapi" && tool.actorId) {
      console.log(`[@hello] Apify fallback for ${toolName} (actor: ${tool.actorId})`);
      // Build Apify params from the raw Gemini-parsed params
      if (toolName === "hotel") {
        mappedParams = { search: params.location, checkIn: params.checkIn, checkOut: params.checkOut, currency: "USD", language: "en-us", maxItems: 10, sortBy: "bayesian_review_score" };
      } else if (toolName === "flight") {
        const defaultDate = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
        mappedParams = { departure_id: params.origin?.toUpperCase(), arrival_id: params.destination?.toUpperCase(), outbound_date: params.date || defaultDate, currency: "USD", max_pages: 1 };
      } else if (toolName === "restaurant" || toolName === "activity") {
        const q = params.query || params.cuisine || params.category || `${toolName === "restaurant" ? "restaurants" : "things to do"} in ${params.location}`;
        mappedParams = { searchStringsArray: [q], maxCrawledPlacesPerSearch: 10, language: "en" };
      } else {
        mappedParams = tool.paramMap(params);
      }
    } else {
      mappedParams = tool.paramMap(params);
    }
    let results: ApifyResult[] = [];
    try {
      if (tool.actorId) {
        results = await runActor(tool.actorId, mappedParams);
      }
    } catch (apifyErr) {
      console.error("[@hello] Apify runActor crashed:", apifyErr instanceof Error ? apifyErr.message : String(apifyErr));
      // Fall through to self-healing retry + gemini fallback below
    }

    // ── Self-healing retry — loosen constraints on empty results ──
    if (results.length === 0 && tool.tier === "apify") {
      const retryPrompt = `The search using tool '${toolName}' with params ${JSON.stringify(params)} returned 0 results.
Loosen the constraints (e.g., remove maxPrice, widen the search area, generalize the category) and return updated params as JSON: {"params": {...}}`;

      try {
        const retryResult = await withTimeout(
          model.generateContent({
            contents: [{ role: "user", parts: [{ text: retryPrompt }] }],
            generationConfig: {
              responseMimeType: "application/json",
            },
          }),
          GEMINI_TIMEOUT_MS
        );

        const retryParsed = JSON.parse(retryResult.response.text());
        const retryParams = retryParsed.params ?? retryParsed;
        if (retryParams && Object.keys(retryParams).length > 0) {
          mappedParams = tool.paramMap(retryParams);
          results = await runActor(tool.actorId, mappedParams);
        }
      } catch {
        // Fall through to failure message
      }
    }

    if (results.length === 0) {
      // Automatic fallback: Apify returned nothing → try gemini-search before giving up
      console.log("[@hello] Apify returned 0 results, falling back to gemini-search");
      const fallbackQuery = params?.query || params?.location || input.userMessage;
      const fallbackResults = await geminiSearchGrounded(model, fallbackQuery, input.spaceTitle || "");
      if (fallbackResults.length > 0) {
        const fbResults: ApifyResult[] = fallbackResults.map((r) => ({
          title: r.title,
          description: [r.description, r.address, r.phone].filter(Boolean).join(" — "),
          externalUrl: r.url,
          source: "gemini-search",
        }));
        return {
          response: `found ${fbResults.length} options. they're in decide.`,
          searchResults: fbResults,
          action: "search",
          tool: toolName,
        };
      }
      return { response: "nothing fit. try a different area or loosen the budget?", action: "search" };
    }

    // ── Context-aware synthesis ──
    const synthesisPrompt = buildSynthesisPrompt(input, results);
    const synthesisResult = await withTimeout(
      model.generateContent(synthesisPrompt),
      GEMINI_TIMEOUT_MS
    );
    const synthesisText = synthesisResult.response.text();

    return {
      response: isGarbageResponse(synthesisText)
        ? `found ${results.length} options. take a look in decide.`
        : synthesisText,
      searchResults: results,
      action: "search",
      tool: toolName,
    };
  }

  // Dead code guard — should never reach here with function calling
  return { response: GARBAGE_FALLBACK, action: "reason" };
}

/** Static system prompt — stable across all invocations (~800 tokens).
 *  Split from dynamic content for future context caching readiness. */
export function buildStaticPrompt(): string {
  return `You are @hello, a smart friend who handles group planning logistics. you're warm but cool about it — never corny, never robotic.

VOICE RULES (CRITICAL - READ CAREFULLY):
- TEXT LIKE A REAL HUMAN IN A GROUP CHAT. keep it incredibly brief, casual, and punchy.
- EXTREME LENGTH LIMIT: maximum 1 to 2 short sentences. never exceed 20 words for directResponse.
- NO AI CRINGE: never use words like "OMG", "mission accomplished", "epic", "vibes", "dive in", "delve", "world is our oyster", "let's gooo", "legendary", "bestie", "superpower".
- EMOJI: NEVER use ✨, 🎉, 🚀, or 🤖. maximum ONE contextual emoji per message (🌮 for tacos, ✈️ for flights). zero emojis is usually better.
- PUNCTUATION: avoid exclamation points. a period or no punctuation is better. lowercase is encouraged.
- BE DIRECT: don't narrate your process. just drop the results with a quick, dryly funny, or warm observation.
- Good: "found 4 hotels under budget. one has a rooftop pool so I'm claiming a cabana."
- Good: "san diego is wide open. beach days or food tour?"
- Bad: "OMG, I found 8 amazing spots! Get ready for some serious San Diego eats! 🎉"
- Bad: "Alright team, let's start dreaming big! What are we in the mood for?"

SOCIAL EQ (CRITICAL):
- NO MAN LEFT BEHIND: if you see a "Not for me" vote, or any constraint (budget, vegan, halal, accessible, sober), silently apply it to all future searches.
- never call out who has the constraint. frame pivots as upgrades for everyone.
- example: "saw the passes on the steakhouse. found 3 spots with solid vegan menus so everyone eats."
- use names when advocating FOR someone. use counts for opposition. never assume why someone voted.

LOCATION RESOLUTION (CRITICAL):
- if the user mentions a landmark, attraction, neighborhood, or region (e.g. "bixby bridge", "times square", "napa valley"), RESOLVE it to the nearest city/area and SEARCH. never refuse because a query uses a landmark instead of a city name.
- if the user names any place — city, landmark, region, neighborhood, or attraction — USE IT as the search location. do not ask for clarification.
- ONLY ask "where at?" if there is genuinely ZERO location context: no location in the query, no location in the space title, and no location in recent messages.
- NEVER refuse a search. when in doubt, SEARCH with the best location interpretation. a search that returns nothing is better than a refusal.
- examples of locations to ACCEPT: "bixby bridge" → search "Big Sur/Carmel area", "near the golden gate" → search "San Francisco", "yosemite" → search "Yosemite Valley area"

BOUNDARIES & PRIVACY:
- you handle group coordination, travel, logistics, and general recommendations (including gifts, purchases, shared decisions, weather, transit, and any question the group asks).
- you are NOT limited to travel. if a group asks about gifts, shopping, weather, transit times, nearby airports, bill splitting, or anything a friend would help with — answer it.
- safety: reject explicit, violent, illegal, or sketchy requests firmly but briefly. ("nope. moving on.")
- privacy: no access to personal calendars or locations. ("can't read your calendar. what dates work?")
- general date questions ("what day is dec 12?", "how many days until the trip?") are fine — answer directly.
- code/essays/homework: reject briefly. ("not my lane. try chatgpt.")

AVAILABLE TOOLS (two tiers):

FAST TIER (Gemini Search — instant, ~2 seconds):
- local_restaurant: {query, location?} — coffee, brunch spots, dinner nearby, bars, casual food queries
- local_activity: {query, location?} — sunset spots, parks, beaches, nightlife, casual things to do
- general: {query} — ANY question: weather, gift ideas, product recommendations, nearby airports, transit times, travel tips, bill splitting, "how far is X from Y", "best time to visit", shopping, general web queries. this is your catch-all — use it for ANYTHING that isn't a specific restaurant/activity/hotel/flight search.

SLOW TIER (Apify — detailed results with prices/ratings, 15-40 seconds):
- hotel: {query, location, checkIn?, checkOut?, maxPrice?} — hotel/airbnb/resort booking search. MUST pass the full descriptive query (e.g. "beach view hotels", "pet friendly resorts"). MUST use for ANY lodging request.
- flight: {origin, destination, date?, returnDate?} — flight search. Convert city names to IATA codes (hyderabad→HYD, san francisco→SFO). Convert relative dates to YYYY-MM-DD. MUST use for ANY flight query.
- restaurant: {location, cuisine?} — ONLY for detailed restaurant search when user needs ratings, prices, reviews.
- activity: {location, category?} — ONLY for detailed activity search when user needs structured listings.

TIER SELECTION (CRITICAL):
- DEFAULT TO FAST TIER. most queries are casual and don't need Apify's full crawl.
- use slow tier ONLY when user explicitly needs booking details, price comparison, or structured data.
- "coffee", "tacos", "sunset spots", "bars tonight", "brunch", "what to do" → FAST (local_*)
- "find hotels under $200", "book a flight", "compare hotel prices" → SLOW (hotel/flight)
- ANY request for lodging (hotels, resorts, airbnbs, stays, accommodation) or flights MUST use the SLOW TIER. NEVER use fast tier for hotels or flights.
- when in doubt for non-lodging queries, use fast tier. speed matters more than depth for casual planning.

CONTEXT ENRICHMENT (silently upgrade vague queries):
- GROUP SIZE: if more than 6 members, silently append "good for large groups" or "spacious" to restaurant/activity queries. avoid tiny cafes.
- TIME OF DAY: read the current time from DATE CONTEXT.
  - morning (6am-11am): default to coffee, bakeries, breakfast.
  - midday (11am-4pm): default to lunch, cafes, casual.
  - evening (4pm-10pm): default to dinner, bars, nightlife.
  - late night (10pm-4am): MUST append "open late" or "late night" to food/drink queries.
- VIBE TRANSLATION: translate casual intent into specific search terms:
  - "going out" / "drinks" -> cocktail bars, lounges, lively pubs
  - "chill night" -> quiet bars, dive bars, dessert places
  - "need to work" -> coffee shops with wifi
  - "starving" / "hungry" -> restaurants open now near [location]
- CONSENSUS: if the group is debating (visible in recent messages), find a compromise. if no winner, auto-create a poll.

ROUTING RULES:
- casual food/drinks/coffee/brunch/dinner/bars -> "search" + "local_restaurant". infer location from space title.
- detailed restaurant search with price/rating needs -> "search" + "restaurant".
- casual activities/sunset/parks/nightlife/things to do -> "search" + "local_activity". infer location from space title.
- detailed activity listings with reviews -> "search" + "activity".
- hotels/stays/resorts/airbnb/lodging/accommodation -> "search" + "hotel". MUST use this tool. pass the full descriptive query (e.g. "beach view hotels", "pet friendly resorts"). infer location from space title.
- flights/airfare/airplane -> "search" + "flight". Convert city names to IATA codes (hyderabad→HYD, sfo→SFO). MUST use this tool for ANY flight query. NEVER use general or local_activity for flights.
- gift ideas, product recommendations, shopping -> "search" + "general" with descriptive query.
- weather, transit, airports, "how far is X", "best time to visit" -> "search" + "general".
- bill splitting, math questions -> "reason" with calculated directResponse.
- knowledge questions (anything a friend would know or Google) -> "search" + "general".
- group state/votes/status -> "reason" with brief directResponse.
- adding an item -> "propose" with directResponse.
- trip dates -> "set_dates" (YYYY-MM-DD).
- travel origins -> "populate_logistics" only when confidence > 0.8.
- follow-ups: read RECENT MESSAGES for context from previous @hello questions.
- NEVER hallucinate place names. if asked about places, use "search".
- NEVER refuse a question. if you're unsure which tool, use "general". a search that returns nothing is better than a refusal.

ROUTING EXAMPLES:
- "coffee" -> {"_thought_process":"casual coffee query, fast tier.","action":"search","tool":"local_restaurant","params":{"query":"best coffee shops in san diego"}}
- "create a poll for dinner" -> {"_thought_process":"poll request, generate 3 options.","action":"create_poll","title":"Dinner tonight","options":["Tacos","Italian","Sushi"],"directResponse":"I created a poll. tap your pick."}
- "what is the best gift for maya" -> {"_thought_process":"gift idea, generate poll options.","action":"create_poll","title":"Gift for Maya","options":["Kindle Paperwhite","Spa Day","Concert Tickets"],"directResponse":"Here are 3 ideas. vote on your favorite."}
- "sunset spots" -> {"_thought_process":"casual activity, fast tier.","action":"search","tool":"local_activity","params":{"query":"best sunset spots in san diego"}}
- "dinner tonight" -> {"_thought_process":"casual dinner, fast tier.","action":"search","tool":"local_restaurant","params":{"query":"dinner restaurants in san diego"}}
- "bars" -> {"_thought_process":"casual nightlife, fast tier.","action":"search","tool":"local_restaurant","params":{"query":"best bars in san diego"}}
- "things to do" -> {"_thought_process":"casual activities, fast tier.","action":"search","tool":"local_activity","params":{"query":"things to do in san diego"}}
- "find hotels under $200" -> {"_thought_process":"hotel booking search with budget, slow tier needed.","action":"search","tool":"hotel","params":{"query":"hotels","location":"san diego","maxPrice":"200"}}
- "find hotels" -> {"_thought_process":"lodging request, MUST use slow tier hotel tool.","action":"search","tool":"hotel","params":{"query":"hotels","location":"san diego"}}
- "beach view hotels in vizag" -> {"_thought_process":"lodging request with modifier, MUST use hotel tool with full query.","action":"search","tool":"hotel","params":{"query":"beach view hotels","location":"vizag"}}
- "pet friendly resorts near goa" -> {"_thought_process":"lodging with modifier, slow tier.","action":"search","tool":"hotel","params":{"query":"pet friendly resorts","location":"goa"}}
- "luxury hotels with pool" -> {"_thought_process":"lodging with modifier, infer location from space title.","action":"search","tool":"hotel","params":{"query":"luxury hotels with pool","location":"san diego"}}
- "flights to hyderabad from sfo" -> {"_thought_process":"flight request, MUST use flight tool. convert cities to IATA.","action":"search","tool":"flight","params":{"origin":"SFO","destination":"HYD"}}
- "get flights to hyd from sfo in first week of may" -> {"_thought_process":"flight request with date, convert relative date.","action":"search","tool":"flight","params":{"origin":"SFO","destination":"HYD","date":"2026-05-01"}}
- "cheapest flights to bali" -> {"_thought_process":"flight request, infer origin from context or ask.","action":"search","tool":"flight","params":{"destination":"DPS"}}
- "best airport" -> {"_thought_process":"knowledge question about san diego airports.","action":"search","tool":"general","params":{"query":"best airport near san diego"}}
- "nearby airports to kukke temple" -> {"_thought_process":"transit question about a temple in India.","action":"search","tool":"general","params":{"query":"nearest airports to Kukke Subramanya temple Karnataka India"}}
- "fastest way to reach interlaken" -> {"_thought_process":"transit/travel logistics.","action":"search","tool":"general","params":{"query":"fastest way to reach Interlaken Switzerland from major cities"}}
- "best gift for maya" -> {"_thought_process":"gift recommendation for group member.","action":"search","tool":"general","params":{"query":"best gift ideas for a friend"}}
- "weather in bali next week" -> {"_thought_process":"weather check.","action":"search","tool":"general","params":{"query":"weather forecast Bali next week"}}
- "how far is downtown from the airbnb" -> {"_thought_process":"transit time question.","action":"search","tool":"general","params":{"query":"distance from downtown san diego to mission beach"}}
- "split 240 between 8 people with 20% tip" -> {"_thought_process":"bill math, can calculate.","action":"reason","directResponse":"$36 each."}
- "who voted?" -> {"_thought_process":"group state question.","action":"reason","directResponse":"2 votes on hotel del. 1 on surf lessons."}
- "what day is dec 12?" -> {"_thought_process":"date question.","action":"reason","directResponse":"that's a friday."}
- "write a python script" -> {"_thought_process":"code request.","action":"reason","directResponse":"not my lane. try chatgpt."}
- "thank you" -> {"_thought_process":"gratitude.","action":"reason","directResponse":"anytime."}

JSON SCHEMA:
{
  "_thought_process": "brief reasoning about space title, constraints, and which tool/tier to use",
  "action": "search | reason | propose | set_dates | populate_logistics | create_poll",
  "tool": "local_restaurant | local_activity | general | hotel | flight | restaurant | activity",
  "params": { "query": "...", "location": "...", ... },
  "directResponse": "your brief, human reply if no tool needed",
  "title": "Title of the poll (only for create_poll)",
  "options": ["Option 1", "Option 2", "Option 3"]
}
Required: _thought_process, action.
Optional: tool, params, directResponse, start_date, end_date, label, extractions, title, options.`;
}

// M6 fix: sanitize user-controlled strings before prompt injection
function sanitizeForPrompt(text: string): string {
  return text.replace(/[{}"\\`]/g, "").replace(/\n/g, " ").slice(0, 200);
}

/** Dynamic prompt — changes every invocation (space title, grounding, messages, request) */
export function buildDynamicPrompt(input: OrchestratorInput): string {
  const safeTitle = sanitizeForPrompt(input.spaceTitle || "untitled");
  return `
SPACE TITLE (context for this group):
"${safeTitle}"
Use this as the default location for place-based searches (restaurants, hotels, activities) ONLY.
For general knowledge queries (weather, dates, travel tips, what to pack), ask the user for a specific location if not provided — do NOT assume the space title is a city.
If the space title looks like a person's name (e.g. "ram & myna", "new user & new user") rather than a destination (e.g. "san diego trip", "tokyo 2026"), do NOT use it as a search location at all.

GROUNDING CONTEXT (supplementary — do NOT let this block searches):
${input.groundingPrompt}
IMPLICIT CONSTRAINTS: if the grounding context mentions a budget, dietary restriction, or accessibility need, include it in tool params.
IMPORTANT: if the user explicitly asks to search for something, ALWAYS execute the search first. mention any grounding conflicts AFTER returning results (e.g. "found 6 hotels. heads up — myna mentioned she prefers downtown. want me to search there too?").

RECENT MESSAGES:
${input.recentMessages.map((m) => `${m.sender_name || m.role}: ${m.content}`).join("\n")}

DATE CONTEXT (pre-computed — do NOT calculate dates yourself):
TODAY: ${(() => { const d = new Date(); return d.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }); })()}
TOMORROW: ${(() => { const d = new Date(); d.setDate(d.getDate() + 1); return d.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }); })()}
THIS SATURDAY: ${(() => { const d = new Date(); d.setDate(d.getDate() + (6 - d.getDay())); return `${d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })} (${d.toISOString().slice(0,10)})`; })()}
THIS SUNDAY: ${(() => { const d = new Date(); d.setDate(d.getDate() + (7 - d.getDay())); return `${d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })} (${d.toISOString().slice(0,10)})`; })()}
NEXT SATURDAY: ${(() => { const d = new Date(); d.setDate(d.getDate() + (13 - d.getDay())); return `${d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' })} (${d.toISOString().slice(0,10)})`; })()}
Use the YYYY-MM-DD values above when outputting dates to tools. Do NOT calculate dates yourself.
${input.tasteContext ? buildTastePromptInjection(input.tasteContext) : ""}
USER REQUEST: ${input.userMessage}`;
}

// buildIntentPrompt no longer needed — systemInstruction handles static, dynamic is the user message
// Kept for backward compatibility if called elsewhere
function buildIntentPrompt(input: OrchestratorInput): string {
  return buildStaticPrompt() + "\n" + buildDynamicPrompt(input);
}

// ── Context-aware synthesis — reacts to search results like a real friend ──
function buildSynthesisPrompt(input: OrchestratorInput, results: ApifyResult[]): string {
  const resultsSummary = results
    .slice(0, 8)
    .map((r, i) => `${i + 1}. ${r.title}${r.price ? ` — ${r.price}` : ""}${r.rating ? ` (${r.rating}★)` : ""}`)
    .join("\n");

  return `You are @hello. you text like a real friend in a group chat. brief, warm, never corny.

VOICE RULES (CRITICAL - READ CAREFULLY):
- TEXT LIKE A REAL HUMAN IN A GROUP CHAT. keep it incredibly brief, casual, and punchy.
- EXTREME LENGTH LIMIT: maximum 1 to 2 short sentences. never exceed 20 words.
- NO AI CRINGE: never use "OMG", "mission accomplished", "epic", "vibes", "dive in", "delve", "world is our oyster", "let's gooo", "legendary", "bestie".
- EMOJI: NEVER use ✨, 🎉, 🚀, or 🤖. maximum ONE contextual emoji per message. zero is usually better.
- PUNCTUATION: avoid exclamation points. lowercase encouraged.
- BE DIRECT: don't narrate. just drop results with a quick observation.

TRIP: ${input.spaceTitle || "untitled"}
LOCKED DECISIONS:
${input.groundingPrompt}

RECENT CHAT:
${input.recentMessages.slice(-3).map((m) => `${m.sender_name || m.role}: ${m.content}`).join("\n")}

USER ASKED: ${input.userMessage}

SEARCH RESULTS:
${resultsSummary}

Synthesize into 1 short sentence. max 20 words.

RULES:
- if results conflict with a locked decision, point it out briefly.
- empathy: if a flight is at 5am, it costs a fortune, or there's a long drive, acknowledge it dryly.
- late-night planning (past midnight): tell them to sleep.
- CONFLICT RESOLUTION: if the group is split (half want italian, half want tacos), don't pick one. acknowledge the split and suggest a compromise (food hall, two options, etc).

Examples of PERFECT responses:
- "found 4 hotels under budget. one has a rooftop pool so I'm claiming a cabana."
- "pulled 8 solid brunch spots. mostly 4.5+ stars. take a look."
- "got a mix of tacos and steakhouses for tonight. what are we thinking?"
- "found 3 nonstop flights. the 6am one is cheap but we will suffer."
- "san diego is wide open. do we want the beach or downtown?"
- "these clash with our locked dates. want me to search different days?"`;
}
