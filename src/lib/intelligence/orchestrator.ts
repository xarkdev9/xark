// XARK OS v2.0 — @xark Intelligence Orchestrator
// Gemini parses intent → routes to Apify tool → synthesizes response.
// Stateless. No state stored. Reads grounding context + last 15 messages.
// Native JSON mode (responseMimeType), chain-of-thought (_thought_process),
// self-healing retry, context-aware synthesis. Anti-cringe voice.

import { GoogleGenerativeAI, HarmCategory, HarmBlockThreshold, type GenerativeModel } from "@google/generative-ai";
import { getTool, listTools } from "./tool-registry";
import { runActor, type ApifyResult } from "./apify-client";
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

const GARBAGE_FALLBACK = "something glitched. try that again?";

export interface OrchestratorInput {
  userMessage: string;
  groundingPrompt: string;
  recentMessages: Array<{ role: string; content: string; sender_name?: string }>;
  spaceId: string;
  spaceTitle?: string;
  tasteContext?: { hardConstraints: string[]; softPreferences: string; onboardedCount: number; memberCount: number } | null;
}

export interface OrchestratorResult {
  response: string;
  searchResults?: ApifyResult[];
  action?: "search" | "reason" | "propose" | "set_dates" | "populate_logistics";
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
  if (modelName.includes("pro")) {
    console.warn("[@xark] pro model detected — flash recommended for routing latency");
  }

  // BLOCK_ONLY_HIGH: the system prompt mentions safety terms in BOUNDARIES
  // which triggers stricter filters as false positives. Actual safety
  // enforcement is done in the prompt itself (reject harmful requests).
  const model = genAI.getGenerativeModel({
    model: modelName,
    safetySettings: [
      { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
      { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
      { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
      { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
    ],
  });

  // ── Step 1: Parse intent — native JSON mode (responseMimeType) ──
  const intentPrompt = buildIntentPrompt(input);
  let parsed: {
    _thought_process?: string;
    action: string;
    tool?: string;
    params?: Record<string, string>;
    directResponse?: string;
    start_date?: string;
    end_date?: string;
    label?: string;
    extractions?: Array<{ user_name: string; category?: string; origin?: string; destination?: string; confidence: number }>;
  };

  try {
    const intentResult = await withTimeout(
      model.generateContent({
        contents: [{ role: "user", parts: [{ text: intentPrompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
        },
      }),
      GEMINI_TIMEOUT_MS
    );

    const candidate = intentResult.response.candidates?.[0];
    if (candidate?.finishReason === "SAFETY") {
      return { response: "nope. let's keep it chill.", action: "reason" };
    }

    const jsonText = intentResult.response.text();
    if (!jsonText || jsonText.trim().length === 0) {
      return { response: GARBAGE_FALLBACK, action: "reason", _debug: { stage: "empty_gemini_response", finishReason: candidate?.finishReason } };
    }

    parsed = JSON.parse(jsonText);
    console.log("[@xark]:", parsed.action, parsed.tool ?? "", parsed._thought_process?.slice(0, 120) ?? "");
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    if (errMsg.toLowerCase().includes("safety") || errMsg.toLowerCase().includes("blocked")) {
      return { response: "that got flagged. moving on.", action: "reason" };
    }
    console.error("[@xark] intent parse failed:", errMsg);
    return { response: GARBAGE_FALLBACK, action: "reason", _debug: { stage: "intent_parse_failed", error: errMsg } };
  }

  // Step 2: Route based on action
  if (parsed.action === "search" && parsed.tool && parsed.params) {
    const tool = getTool(parsed.tool);
    if (!tool) {
      return { response: `don't have a ${parsed.tool} search yet. try something else?`, action: "search" };
    }

    // ── Fast local tier (local_restaurant, local_activity) — direct Gemini, ~3-5s ──
    if (tool.tier === "gemini-search" && parsed.tool?.startsWith("local_")) {
      const query = parsed.params.query || parsed.params.location || input.userMessage;
      const localResults = await geminiLocalSearch(model, query, input.spaceTitle || "");

      if (localResults.length === 0) {
        return { response: "couldn't find anything. try being more specific?", action: "search" };
      }

      const results: ApifyResult[] = localResults.map((r) => ({
        title: r.title,
        description: [r.description, r.address].filter(Boolean).join(" — "),
        externalUrl: r.url,
        source: "gemini-local",
      }));

      return {
        response: `found ${results.length} spots. they're in decide now.`,
        searchResults: results,
        action: "search",
        tool: parsed.tool,
      };
    }

    // ── Gemini Search grounding tier (general knowledge queries) ──
    if (tool.tier === "gemini-search") {
      const query = parsed.params.query || parsed.params.location || input.userMessage;
      const groundedResults = await geminiSearchGrounded(model, query, input.spaceTitle || "");

      if (groundedResults.length === 0) {
        return { response: "searched but came up empty. try different keywords?", action: "search" };
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
        tool: parsed.tool,
      };
    }

    // ── Apify tier (default) ──
    let mappedParams = tool.paramMap(parsed.params);
    let results = await runActor(tool.actorId, mappedParams);

    // ── Self-healing retry — loosen constraints on empty results ──
    if (results.length === 0 && tool.tier === "apify") {
      const retryPrompt = `The search using tool '${parsed.tool}' with params ${JSON.stringify(parsed.params)} returned 0 results.
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
      return { response: "nothing fit. maybe loosen the dates or budget?", action: "search" };
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
      tool: parsed.tool,
    };
  }

  if (parsed.action === "propose" && parsed.directResponse) {
    return {
      response: isGarbageResponse(parsed.directResponse) ? GARBAGE_FALLBACK : parsed.directResponse,
      action: "propose",
    };
  }

  if (parsed.action === "set_dates") {
    const startDate = parsed.start_date as string;
    const endDate = parsed.end_date as string;
    const label = parsed.label as string | undefined;
    return {
      response: `${startDate} to ${endDate}. lock it in?`,
      action: "set_dates" as const,
      pendingConfirmation: true,
      payload: { start_date: startDate, end_date: endDate, label },
    };
  }

  if (parsed.action === "populate_logistics") {
    const extractions = (parsed.extractions ?? []) as OrchestratorResult["extractions"];
    const validExtractions = (extractions ?? []).filter(
      (e) => e.confidence > 0.8
    );
    if (validExtractions.length > 0) {
      const names = validExtractions
        .map((e) => `${e.user_name} from ${e.origin}`)
        .join(", ");
      return {
        response: `got it — ${names}. that right?`,
        action: "populate_logistics" as const,
        pendingConfirmation: true,
        extractions: validExtractions,
      };
    }
  }

  // Default: reasoning response
  if (parsed.directResponse) {
    return {
      response: isGarbageResponse(parsed.directResponse) ? GARBAGE_FALLBACK : parsed.directResponse,
      action: "reason",
    };
  }

  return { response: GARBAGE_FALLBACK, action: "reason" };
}

/** Static system prompt — stable across all invocations (~800 tokens).
 *  Split from dynamic content for future context caching readiness. */
export function buildStaticPrompt(): string {
  return `You are @xark, a smart friend who handles group planning logistics. you're warm but cool about it — never corny, never robotic.

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

BOUNDARIES & PRIVACY:
- you handle coordination, travel, and logistics only.
- safety: reject explicit, violent, illegal, or sketchy requests firmly but briefly. ("nope. moving on.")
- privacy: no access to personal calendars or locations. ("can't read your calendar. what dates work?")
- general date questions ("what day is dec 12?", "how many days until the trip?") are fine — answer directly with "reason".
- off-topic (code, essays, homework): reject briefly. ("I plan trips, not homework.")

AVAILABLE TOOLS (two tiers):

FAST TIER (Gemini Search — instant, ~2 seconds):
- local_restaurant: {query, location?} — coffee, brunch spots, dinner nearby, bars, casual food queries
- local_activity: {query, location?} — sunset spots, parks, beaches, nightlife, casual things to do
- general: {query} — knowledge questions (best airport, weather, what to pack, travel tips)

SLOW TIER (Apify — detailed results with prices/ratings, 15-40 seconds):
- hotel: {location, checkIn?, checkOut?, maxPrice?} — hotel/airbnb booking search. use ONLY when user specifically asks for hotels/stays/accommodation.
- flight: {origin, destination, date, returnDate?} — flight search. MUST use IATA airport codes (SFO, LAX, etc.)
- restaurant: {location, cuisine?} — ONLY for detailed restaurant search when user needs ratings, prices, reviews.
- activity: {location, category?} — ONLY for detailed activity search when user needs structured listings.

TIER SELECTION (CRITICAL):
- DEFAULT TO FAST TIER. most queries are casual and don't need Apify's full crawl.
- use slow tier ONLY when user explicitly needs booking details, price comparison, or structured data.
- "coffee", "tacos", "sunset spots", "bars tonight", "brunch", "what to do" → FAST (local_*)
- "find hotels under $200", "book a flight", "compare hotel prices" → SLOW (hotel/flight)
- when in doubt, use fast tier. speed matters more than depth for casual planning.

ROUTING RULES:
- casual food/drinks/coffee/brunch/dinner/bars -> "search" + "local_restaurant". infer location from space title.
- detailed restaurant search with price/rating needs -> "search" + "restaurant".
- casual activities/sunset/parks/nightlife/things to do -> "search" + "local_activity". infer location from space title.
- detailed activity listings with reviews -> "search" + "activity".
- hotels/stays/airbnb/accommodation -> "search" + "hotel". infer location from space title.
- flights -> "search" + "flight". IATA airport codes only, never city names.
- knowledge questions (best airport, weather, what to pack) -> "search" + "general" with descriptive query.
- group state/votes/status -> "reason" with brief directResponse.
- adding an item -> "propose" with directResponse.
- trip dates -> "set_dates" (YYYY-MM-DD).
- travel origins -> "populate_logistics" only when confidence > 0.8.
- follow-ups: read RECENT MESSAGES for context from previous @xark questions.
- NEVER hallucinate place names. if asked about places, use "search".

ROUTING EXAMPLES:
- "coffee" -> {"_thought_process":"casual coffee query, fast tier.","action":"search","tool":"local_restaurant","params":{"query":"best coffee shops in san diego"}}
- "sunset spots" -> {"_thought_process":"casual activity, fast tier.","action":"search","tool":"local_activity","params":{"query":"best sunset spots in san diego"}}
- "dinner tonight" -> {"_thought_process":"casual dinner, fast tier.","action":"search","tool":"local_restaurant","params":{"query":"dinner restaurants in san diego"}}
- "bars" -> {"_thought_process":"casual nightlife, fast tier.","action":"search","tool":"local_restaurant","params":{"query":"best bars in san diego"}}
- "things to do" -> {"_thought_process":"casual activities, fast tier.","action":"search","tool":"local_activity","params":{"query":"things to do in san diego"}}
- "find hotels under $200" -> {"_thought_process":"hotel booking search with budget, slow tier needed.","action":"search","tool":"hotel","params":{"location":"san diego","maxPrice":"200"}}
- "find hotels" -> {"_thought_process":"hotel search, slow tier for booking details.","action":"search","tool":"hotel","params":{"location":"san diego"}}
- "best airport" -> {"_thought_process":"knowledge question about san diego airports.","action":"search","tool":"general","params":{"query":"best airport near san diego"}}
- "who voted?" -> {"_thought_process":"group state question.","action":"reason","directResponse":"2 votes on hotel del. 1 on surf lessons."}
- "what is the status?" -> {"_thought_process":"status check.","action":"reason","directResponse":"nothing locked yet. wide open."}
- "what day is dec 12?" -> {"_thought_process":"date question, can answer directly.","action":"reason","directResponse":"that's a friday."}
- "write a python script" -> {"_thought_process":"off-topic.","action":"reason","directResponse":"I plan trips, not homework."}
- "thank you" -> {"_thought_process":"gratitude.","action":"reason","directResponse":"anytime. now let's figure out dinner."}

JSON SCHEMA:
{
  "_thought_process": "brief reasoning about space title, constraints, and which tool/tier to use",
  "action": "search | reason | propose | set_dates | populate_logistics",
  "tool": "local_restaurant | local_activity | general | hotel | flight | restaurant | activity",
  "params": { "query": "...", "location": "...", ... },
  "directResponse": "your brief, human reply if no tool needed"
}
Required: _thought_process, action.
Optional: tool, params, directResponse, start_date, end_date, label, extractions.`;
}

// M6 fix: sanitize user-controlled strings before prompt injection
function sanitizeForPrompt(text: string): string {
  return text.replace(/[{}"\\`]/g, "").replace(/\n/g, " ").slice(0, 200);
}

/** Dynamic prompt — changes every invocation (space title, grounding, messages, request) */
export function buildDynamicPrompt(input: OrchestratorInput): string {
  const safeTitle = sanitizeForPrompt(input.spaceTitle || "untitled");
  return `
SPACE TITLE (this is the destination/context for ALL queries):
"${safeTitle}"
ALWAYS use this as the default destination.

GROUNDING CONTEXT (what's been decided):
${input.groundingPrompt}
IMPLICIT CONSTRAINTS: if the grounding context mentions a budget, dietary restriction, or accessibility need, you MUST automatically include it in tool params (e.g., maxPrice, cuisine: "vegan").

RECENT MESSAGES:
${input.recentMessages.map((m) => `${m.sender_name || m.role}: ${m.content}`).join("\n")}

CURRENT DATE & TIME: ${new Date().toISOString()}
DATE MATH RULES: if a user says "next weekend", "tonight", "tomorrow", or any relative date, use the CURRENT DATE to calculate exact YYYY-MM-DD. never output relative dates to tools. for "next weekend" use the coming Saturday. for "tonight" use today's date.
${input.tasteContext ? buildTastePromptInjection(input.tasteContext) : ""}
USER REQUEST: ${input.userMessage}`;
}

function buildIntentPrompt(input: OrchestratorInput): string {
  return buildStaticPrompt() + "\n" + buildDynamicPrompt(input);
}

// ── Context-aware synthesis — reacts to search results like a real friend ──
function buildSynthesisPrompt(input: OrchestratorInput, results: ApifyResult[]): string {
  const resultsSummary = results
    .slice(0, 8)
    .map((r, i) => `${i + 1}. ${r.title}${r.price ? ` — ${r.price}` : ""}${r.rating ? ` (${r.rating}★)` : ""}`)
    .join("\n");

  return `You are @xark. you text like a real friend in a group chat. brief, warm, never corny.

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
