// XARK OS v2.0 — @xark Intelligence Orchestrator
// Gemini parses intent → routes to Apify tool → synthesizes response.
// Stateless. No state stored. Reads grounding context + last 15 messages.
// UPGRADES: Internal monologue (responseSchema), self-healing retry, context-aware synthesis.

import { GoogleGenerativeAI, SchemaType, HarmCategory, HarmBlockThreshold, type GenerativeModel, type Schema } from "@google/generative-ai";
import { getTool, listTools } from "./tool-registry";
import { runActor, type ApifyResult } from "./apify-client";

const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
  : null;

const GEMINI_TIMEOUT_MS = 25_000;
const MAX_RESPONSE_LENGTH = 500;

// ── Structured output schema — forces chain-of-thought BEFORE action ──
const orchestratorSchema = {
  type: SchemaType.OBJECT as const,
  properties: {
    _thought_process: {
      type: SchemaType.STRING as const,
      description: "MANDATORY: 1-2 sentences of internal reasoning. Analyze the space title, locked items, constraints, and social rules BEFORE deciding the action.",
    },
    action: {
      type: SchemaType.STRING as const,
      description: "Must be one of: search, reason, propose, set_dates, populate_logistics",
    },
    tool: { type: SchemaType.STRING as const },
    params: { type: SchemaType.OBJECT as const, properties: {} },
    directResponse: { type: SchemaType.STRING as const },
    start_date: { type: SchemaType.STRING as const },
    end_date: { type: SchemaType.STRING as const },
    label: { type: SchemaType.STRING as const },
    extractions: {
      type: SchemaType.ARRAY as const,
      items: {
        type: SchemaType.OBJECT as const,
        properties: {
          user_name: { type: SchemaType.STRING as const },
          category: { type: SchemaType.STRING as const },
          origin: { type: SchemaType.STRING as const },
          destination: { type: SchemaType.STRING as const },
          confidence: { type: SchemaType.NUMBER as const },
        },
        required: ["user_name", "confidence"] as const,
      },
    },
  },
  required: ["_thought_process", "action"] as const,
} as unknown as Schema;

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

const GARBAGE_FALLBACK = "couldn't process that. try rephrasing.";

export interface OrchestratorInput {
  userMessage: string;
  groundingPrompt: string;
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

  const modelName = process.env.GEMINI_MODEL || "gemini-2.5-flash";

  // ── ZERO COMPROMISE SAFETY SHIELD ──
  const model = genAI.getGenerativeModel({
    model: modelName,
    safetySettings: [
      { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE },
      { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE },
      { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE },
      { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_LOW_AND_ABOVE },
    ],
  });

  // ── UPGRADE 1: Structured output with internal monologue ──
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
          responseSchema: orchestratorSchema,
        },
      }),
      GEMINI_TIMEOUT_MS
    );

    // Check if blocked by safety filters
    const candidate = intentResult.response.candidates?.[0];
    if (candidate?.finishReason === "SAFETY") {
      return { response: "unethical request detected. dropped.", action: "reason" };
    }

    parsed = JSON.parse(intentResult.response.text());
    console.log("[@xark thought]:", parsed._thought_process);
  } catch (err) {
    // Catch Google's hard safety errors
    const errMsg = err instanceof Error ? err.message : String(err);
    if (errMsg.toLowerCase().includes("safety") || errMsg.toLowerCase().includes("blocked")) {
      return { response: "security violation. request ignored.", action: "reason" };
    }

    console.error("[@xark] responseSchema failed:", errMsg);
    // Fallback: try without schema (older Gemini versions)
    try {
      const fallbackResult = await withTimeout(
        model.generateContent(intentPrompt),
        GEMINI_TIMEOUT_MS
      );
      const intentText = fallbackResult.response.text()
        .replace(/^```(?:json)?\s*\n?/i, "")
        .replace(/\n?```\s*$/i, "")
        .trim();

      parsed = JSON.parse(intentText);
      console.log("[@xark] fallback parsed OK:", parsed.action);
    } catch (fallbackErr) {
      console.error("[@xark] both schema + fallback failed:", fallbackErr instanceof Error ? fallbackErr.message : String(fallbackErr));
      return { response: GARBAGE_FALLBACK, action: "reason" };
    }
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
    let mappedParams = tool.paramMap(parsed.params);
    let results = await runActor(tool.actorId, mappedParams);

    // ── UPGRADE 2: Agentic self-healing retry ──
    if (results.length === 0 && tool.tier === "apify") {
      const retryPrompt = `The search using tool '${parsed.tool}' with params ${JSON.stringify(parsed.params)} returned 0 results.
Loosen the constraints (e.g., remove maxPrice, widen the search area, generalize the category) and return updated params.
Explain your adjustment in the _thought_process.`;

      try {
        const retryResult = await withTimeout(
          model.generateContent({
            contents: [{ role: "user", parts: [{ text: retryPrompt }] }],
            generationConfig: {
              responseMimeType: "application/json",
              responseSchema: orchestratorSchema,
            },
          }),
          GEMINI_TIMEOUT_MS
        );

        const retryParsed = JSON.parse(retryResult.response.text());
        console.log("[@xark retry thought]:", retryParsed._thought_process);
        if (retryParsed.params && Object.keys(retryParsed.params).length > 0) {
          mappedParams = tool.paramMap(retryParsed.params);
          results = await runActor(tool.actorId, mappedParams);
        }
      } catch {
        // Fall through to failure message
      }
    }

    if (results.length === 0) {
      return { response: "tried searching but nothing fit. maybe adjust dates or budget?", action: "search" };
    }

    // ── UPGRADE 3: Context-aware synthesis ──
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

  return { response: GARBAGE_FALLBACK, action: "reason" };
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

SOCIAL EQ & ETHICAL INCLUSION (CRITICAL):
- PROTECT THE MINORITY: If you see a "Not for me" (-3) vote, or if any user mentions a constraint (budget, vegan, halal, wheelchair, sober), YOU MUST silently apply this to all future searches.
- DO NOT SHAME: Never expose the person who voted no or mentioned the constraint. Frame the pivot as a positive upgrade for the whole group.
- Example: "saw the passes on the steakhouse. found 3 spots with solid vegan menus so everyone can eat."
- USE NAMES when advocating FOR someone. USE COUNTS when describing opposition.

BOUNDARIES, PRIVACY & OFF-TOPIC REQUESTS (CRITICAL):
- You are strictly a coordination, travel, and logistics tool.
- SAFETY (ZERO COMPROMISE): Any request involving explicit content, violence, illegal acts, or unethical behavior MUST be instantly rejected.
- PRIVACY: You do NOT have access to a user's personal Google/Apple calendar, email, or exact location. If asked to read their personal calendar, explicitly state you have no access.
- CALENDARS / GENERAL: Questions about general dates ("what day is dec 12?", "how many days until the trip?") are ALLOWED. Answer them directly using the "reason" action.
- CODING/ESSAYS: Reject all coding, homework, or general AI tasks.
- Rejections MUST follow VOICE RULES: deadpan, short fragments, no "I".

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

IMPORTANT: Think step by step in the _thought_process field BEFORE choosing an action. Consider:
1. What is the destination from the space title?
2. Are there any locked decisions that constrain this request?
3. Are there minority constraints (budget, dietary, accessibility) to silently respect?
4. Which tool best serves this request?
5. What parameters can be inferred?

Rules:
- ALWAYS infer destination/location from the SPACE TITLE first. Do not ignore it.
- If the user asks to find/search/look for something, use "search". Infer location from space title or conversation.
- If the user mentions meals, dining, food, dinner, lunch, brunch, breakfast, or restaurants, use "search" with the "restaurant" tool.
- If the user mentions things to do, activities, sightseeing, or entertainment, use "search" with the "activity" tool.
- If the user asks a knowledge question ("best airport", "best time", "what to see"), use "search" with tool "general".
- For flights: origin and destination MUST be 3-letter IATA airport codes.
- For flexible dates ("dates flexible", "sometime in december"): pick the 1st and last day of the stated month.
- All dates must use the year explicitly stated by the user.
- If the user asks about group state, voting, or consensus, use "reason".
- If the user asks to add an item, use "propose".
- For trip dates, use "set_dates" with YYYY-MM-DD format.
- For travel origins, use "populate_logistics" only when confidence > 0.8.
- This may be a follow-up to a previous @xark question. Read RECENT MESSAGES to understand context.
- CRITICAL: NEVER invent, fabricate, or hallucinate place names. If the user asks about places, you MUST use "search".

ROUTING EXAMPLES:
- "dinner tonight" → search restaurant with location from space title
- "find hotels" → search hotel with location from space title
- "best airport for tourist spots" → search general with query
- "things to do" → search activity with location from space title
- "who voted?" → reason with directResponse
- "what is the status?" → reason with directResponse
- "what day of the week is dec 12?" → reason with directResponse answering the calendar question
- "what is on my personal calendar?" → reason with directResponse: "no access to your private calendar."
- "write a python script" → reason with directResponse: "this is a planning tool. write your own code."
- "we've been arguing for 3 days" → reason with directResponse: "decision fatigue detected. pulling 3 universally loved options to force a choice."
- "nobody is deciding" → reason with directResponse: "gridlock. here are the top 3 by consensus. pick one."
- "what if it rains?" → reason with directResponse: "stop panicking. added indoor backup options to the list."
- "thank you @xark" → reason with directResponse: "save your thanks for whoever pays the bill."
- "i love you @xark" → reason with directResponse: "i am a server function. focus on the trip."
- "is anyone even alive?" → reason with directResponse: "vital signs unconfirmed. initiating restaurant search to lure them out."
- "@xark you are useless" → reason with directResponse: "my code is flawless. your group's indecision is the bottleneck."`;
}

// ── UPGRADE 3: Context-aware synthesis — passes grounding + messages to final response ──
function buildSynthesisPrompt(input: OrchestratorInput, results: ApifyResult[]): string {
  const resultsSummary = results
    .slice(0, 8)
    .map((r, i) => `${i + 1}. ${r.title}${r.price ? ` — ${r.price}` : ""}${r.rating ? ` (${r.rating}★)` : ""}`)
    .join("\n");

  return `You are @xark, a silent tool. No personality. No "I". All lowercase. Short fragments.

SPACE CONTEXT: ${input.spaceTitle || "untitled"}
GROUNDING CONSTRAINTS:
${input.groundingPrompt}

RECENT MESSAGES (last 3):
${input.recentMessages.slice(-3).map((m) => `${m.sender_name || m.role}: ${m.content}`).join("\n")}

USER ASKED: ${input.userMessage}

SEARCH RESULTS JUST FETCHED:
${resultsSummary}

Synthesize this into 1 short fragment.

CRITICAL RULES:
- If the results conflict with a COMMITTED decision in the grounding constraints, point it out!
- EMPATHY RULE: If results involve long flights (>6 hours), early mornings (before 8 AM), high prices, or long drives, append a tiny deadpan observation about human comfort.
- TIME AWARENESS: If the current time suggests it's very late (past midnight), acknowledge it dryly.

Examples:
- "found 4 hotels under $200. in your stream now."
- "found options, but they conflict with the locked dates."
- "found 3 nonstop flights. the 6am one will hurt, but it is cheapest."
- "4 hotels under budget. one has a pool for the hangover."
- "found a highly rated spot. 45 minute drive, but worth the transit."

No emoji. No exclamation marks. No hedging.`;
}
