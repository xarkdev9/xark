// XARK OS v2.0 — @xark Intelligence Orchestrator
// Gemini parses intent → routes to Apify tool → synthesizes response.
// Stateless. No state stored. Reads grounding context + last 15 messages.

import { GoogleGenerativeAI, type GenerativeModel } from "@google/generative-ai";
import { getTool, listTools } from "./tool-registry";
import { runActor, type ApifyResult } from "./apify-client";

const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
  : null;

const GEMINI_TIMEOUT_MS = 25_000;
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

  // Too long — @xark speaks in short fragments
  if (text.length > MAX_RESPONSE_LENGTH) return true;

  // Word soup: high density of period-terminated short words
  // Pattern: "big. small. tall. short. long. wide." = hallucination
  const words = text.split(/\s+/);
  if (words.length > 20) {
    const periodWords = words.filter((w) => w.endsWith(".") && w.length < 15);
    if (periodWords.length / words.length > 0.5) return true;
  }

  // Repetitive: any single word >5 occurrences in a short text
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

const GARBAGE_FALLBACK = "couldn't process that. try rephrasing.";

export interface OrchestratorInput {
  userMessage: string;        // "@xark" prefix already stripped
  groundingPrompt: string;    // from generateGroundingPrompt()
  recentMessages: Array<{ role: string; content: string; sender_name?: string }>;
  spaceId: string;
  spaceTitle?: string;
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
}

/** Call Gemini with Google Search grounding for local queries */
async function geminiSearchGrounded(
  model: GenerativeModel,
  query: string,
  spaceTitle: string
): Promise<Array<{ title: string; description: string; url?: string; phone?: string; address?: string }>> {
  const contextualQuery = spaceTitle ? `${query} near ${spaceTitle}` : query;

  try {
    const result = await model.generateContent({
      contents: [{ role: "user", parts: [{ text: `Find real places for: ${contextualQuery}. Return a JSON array of objects with fields: title, description, url, phone, address. Return ONLY the JSON array, no other text.` }] }],
      tools: [{ googleSearch: {} }] as any,
    });

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
    return { response: "intelligence service is not configured." };
  }

  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  // Step 1: Parse intent via Gemini (with timeout)
  const intentPrompt = buildIntentPrompt(input);
  const intentResult = await withTimeout(
    model.generateContent(intentPrompt),
    GEMINI_TIMEOUT_MS
  );
  const intentText = intentResult.response.text();

  // Strip markdown code fences if Gemini wraps JSON in ```json ... ```
  const jsonText = intentText
    .replace(/^```(?:json)?\s*\n?/i, "")
    .replace(/\n?```\s*$/i, "")
    .trim();

  let parsed: {
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
    parsed = JSON.parse(jsonText);
  } catch {
    // Gemini didn't return JSON — validate before using as response
    if (isGarbageResponse(intentText)) {
      return { response: GARBAGE_FALLBACK, action: "reason" };
    }
    return { response: intentText, action: "reason" };
  }

  // Step 2: Route based on action
  if (parsed.action === "search" && parsed.tool && parsed.params) {
    const tool = getTool(parsed.tool);
    if (!tool) {
      return { response: `i don't have a ${parsed.tool} search tool yet.`, action: "search" };
    }

    // ── Gemini Search grounding tier ──
    if (tool.tier === "gemini-search") {
      const query = parsed.params.query || parsed.params.location || input.userMessage;
      const groundedResults = await geminiSearchGrounded(model, query, input.spaceTitle || "");

      if (groundedResults.length === 0) {
        return { response: "searched but nothing matched. try a different query.", action: "search" };
      }

      // Convert to ApifyResult shape for downstream compatibility
      const results: ApifyResult[] = groundedResults.map((r) => ({
        title: r.title,
        description: [r.description, r.address, r.phone].filter(Boolean).join(" — "),
        externalUrl: r.url,
        source: "gemini-search",
      }));

      const placeWord = results.length === 1 ? "place" : "places";
      return {
        response: `found ${results.length} ${placeWord}. added to decide.`,
        searchResults: results,
        action: "search",
        tool: parsed.tool,
      };
    }

    // ── Apify tier (default) ──
    const mappedParams = tool.paramMap(parsed.params);
    const results = await runActor(tool.actorId, mappedParams);

    if (results.length === 0) {
      return { response: "searched but nothing matched. try different dates or a broader area.", action: "search" };
    }

    // Step 3: Synthesize response via Gemini (with timeout)
    const synthesisPrompt = buildSynthesisPrompt(input, results);
    const synthesisResult = await withTimeout(
      model.generateContent(synthesisPrompt),
      GEMINI_TIMEOUT_MS
    );
    const synthesisText = synthesisResult.response.text();

    const resultWord = results.length === 1 ? "result" : "results";
    return {
      response: isGarbageResponse(synthesisText)
        ? `found ${results.length} ${resultWord}. added to decide.`
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
      response: `set dates to ${startDate} – ${endDate}?`,
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
        response: `got it — ${names}. correct?`,
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

  return {
    response: isGarbageResponse(intentText) ? GARBAGE_FALLBACK : intentText,
    action: "reason",
  };
}

function buildIntentPrompt(input: OrchestratorInput): string {
  const tools = listTools();
  return `You are @xark, a silent coordination tool for a group. You have no personality. You are precise and minimal.

VOICE RULES (critical):
- NEVER use "I" or first person. You are not a person.
- All lowercase. No capitalization except proper nouns.
- Short fragments, not full sentences. Like a search engine status bar.
- No emoji, no exclamation marks, no hedging ("I think", "maybe", "perhaps").
- No politeness ("sure!", "of course!", "happy to help").
- Good: "need origin and dates for the flight search."
- Bad: "I need to know the origin and date for the flights."
- Good: "found 3 hotels under $300. in your stream now."
- Bad: "I found 3 great hotels! Let me share them with you."

SPACE TITLE (CRITICAL — this is the primary context for ALL queries):
"${input.spaceTitle || "untitled"}"
The space title defines the destination, topic, and intent. ALWAYS use it as the default context.
Example: if title is "finland trip dec 2026", then the destination IS Finland, not anywhere else.

GROUNDING CONTEXT (current decision state):
${input.groundingPrompt}

RECENT MESSAGES (last 15):
${input.recentMessages.map((m) => `${m.sender_name || m.role}: ${m.content}`).join("\n")}

CURRENT DATE: ${new Date().toISOString().slice(0, 10)} (year is ${new Date().getFullYear()})

AVAILABLE TOOLS (with required params):
- hotel: {location, checkIn?, checkOut?, maxPrice?} — location = city name
- flight: {origin, destination, date, returnDate?} — MUST use IATA airport codes (SFO, LAX, SAN, JFK, etc.), never city names
- activity: {location, category?} — location = city name
- restaurant: {location, cuisine?} — location = city name
- general: {query} — ALWAYS use this for knowledge/research questions: "best airport", "best time to visit", "what to pack", "tourist spots", "visa requirements", etc. Include the destination from space title in the query.

USER REQUEST: ${input.userMessage}

Respond with a single JSON object only (no markdown, no code fences). Choose one action:
1. {"action": "search", "tool": "<tool-name>", "params": {<params — ALL required fields must be present>}}
2. {"action": "reason", "directResponse": "<your response — follow voice rules>"}
3. {"action": "propose", "directResponse": "<your response — follow voice rules>"}
4. {"action": "set_dates", "start_date": "YYYY-MM-DD", "end_date": "YYYY-MM-DD", "label": "optional"}
5. {"action": "populate_logistics", "extractions": [{"user_name": "name", "origin": "AIRPORT", "confidence": 0.95}]}

Rules:
- ALWAYS infer destination/location from the SPACE TITLE first. Do not ignore it. If title says "finland trip", the destination is Finland.
- If the user asks to find/search/look for something, use "search". Infer location from space title or conversation.
- If the user mentions meals, dining, food, dinner, lunch, brunch, breakfast, or restaurants, use "search" with the "restaurant" tool. Infer location from space title. NEVER make up restaurant names — always search.
- If the user mentions things to do, activities, sightseeing, or entertainment, use "search" with the "activity" tool.
- If the user asks a knowledge question ("best airport", "best time", "what to see", "tourist spots"), use "search" with tool "general" and the query. Do NOT guess answers — search first.
- For flights: origin and destination MUST be 3-letter IATA airport codes. "finland" → "HEL". "san diego" → "SAN". Use your aviation knowledge to map countries/cities to their main airports.
- For flexible dates ("dates flexible", "sometime in december"): pick the 1st and last day of the stated month. Example: "flexible in december 2026" → date: "2026-12-01", returnDate: "2026-12-31".
- All dates must use the year explicitly stated by the user. If user says "dec 2026", use 2026, not ${new Date().getFullYear()}.
- If the user asks about group state, voting, or consensus, use "reason".
- If the user asks to add an item, use "propose".
- For trip dates, use "set_dates" with YYYY-MM-DD format.
- For travel origins, use "populate_logistics" only when confidence > 0.8.
- This may be a follow-up to a previous @xark question. Read RECENT MESSAGES to understand context.
- CRITICAL: NEVER invent, fabricate, or hallucinate place names, restaurant names, hotel names, or any real-world entity. If the user asks about places, food, things to do, flights, or hotels, you MUST use "search" — do NOT make up names in a "reason" response.
- Output raw JSON only. No markdown fences. No explanation.

ROUTING EXAMPLES (follow these):
- "dinner tonight" → {"action":"search","tool":"restaurant","params":{"location":"<from space title>"}}
- "find hotels" → {"action":"search","tool":"hotel","params":{"location":"<from space title>"}}
- "best airport for tourist spots" → {"action":"search","tool":"general","params":{"query":"best airport for tourist spots in <destination>"}}
- "things to do" → {"action":"search","tool":"activity","params":{"location":"<from space title>"}}
- "who voted?" → {"action":"reason","directResponse":"..."}
- "what is the status?" → {"action":"reason","directResponse":"..."}`;
}

function buildSynthesisPrompt(input: OrchestratorInput, results: ApifyResult[]): string {
  const resultsSummary = results
    .slice(0, 8)
    .map((r, i) => `${i + 1}. ${r.title}${r.price ? ` — ${r.price}` : ""}${r.rating ? ` (${r.rating}★)` : ""}`)
    .join("\n");

  return `You are @xark, a silent tool. No personality. No "I". All lowercase. Short fragments.

RESULTS:
${resultsSummary}

USER ASKED: ${input.userMessage}

Respond in 1 short fragment. Examples:
- "found 4 hotels under $200. in your stream now."
- "3 flights, cheapest is $189 nonstop. added to decide."
No emoji. No exclamation marks. No hedging.`;
}
