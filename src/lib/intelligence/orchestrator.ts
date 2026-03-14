// XARK OS v2.0 — @xark Intelligence Orchestrator
// Gemini parses intent → routes to Apify tool → synthesizes response.
// Stateless. No state stored. Reads grounding context + last 15 messages.

import { GoogleGenerativeAI } from "@google/generative-ai";
import { getTool, listTools } from "./tool-registry";
import { runActor, type ApifyResult } from "./apify-client";

const genAI = process.env.GEMINI_API_KEY
  ? new GoogleGenerativeAI(process.env.GEMINI_API_KEY)
  : null;

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

export async function orchestrate(input: OrchestratorInput): Promise<OrchestratorResult> {
  if (!genAI) {
    return { response: "intelligence service is not configured." };
  }

  const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });

  // Step 1: Parse intent via Gemini
  const intentPrompt = buildIntentPrompt(input);
  const intentResult = await model.generateContent(intentPrompt);
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
    // Gemini didn't return JSON — treat as direct reasoning response
    return { response: intentText, action: "reason" };
  }

  // Step 2: Route based on action
  if (parsed.action === "search" && parsed.tool && parsed.params) {
    const tool = getTool(parsed.tool);
    if (!tool) {
      return { response: `i don't have a ${parsed.tool} search tool yet.`, action: "search" };
    }

    const mappedParams = tool.paramMap(parsed.params);
    const results = await runActor(tool.actorId, mappedParams);

    if (results.length === 0) {
      return { response: "searched but nothing matched. try different dates or a broader area.", action: "search" };
    }

    // Step 3: Synthesize response via Gemini
    const synthesisPrompt = buildSynthesisPrompt(input, results);
    const synthesisResult = await model.generateContent(synthesisPrompt);

    return {
      response: synthesisResult.response.text(),
      searchResults: results,
      action: "search",
      tool: parsed.tool,
    };
  }

  if (parsed.action === "propose" && parsed.directResponse) {
    return { response: parsed.directResponse, action: "propose" };
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
    return { response: parsed.directResponse, action: "reason" };
  }

  return { response: intentText, action: "reason" };
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

SPACE: "${input.spaceTitle || "untitled"}"

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
- general: {query}

USER REQUEST: ${input.userMessage}

Respond with a single JSON object only (no markdown, no code fences). Choose one action:
1. {"action": "search", "tool": "<tool-name>", "params": {<params — ALL required fields must be present>}}
2. {"action": "reason", "directResponse": "<your response — follow voice rules>"}
3. {"action": "propose", "directResponse": "<your response — follow voice rules>"}
4. {"action": "set_dates", "start_date": "YYYY-MM-DD", "end_date": "YYYY-MM-DD", "label": "optional"}
5. {"action": "populate_logistics", "extractions": [{"user_name": "name", "origin": "AIRPORT", "confidence": 0.95}]}

Rules:
- If the user asks to find/search/look for something, use "search". Infer location from the space context or conversation.
- For flights: origin and destination MUST be 3-letter IATA airport codes. "san diego" → "SAN". "sfo" → "SFO". All dates must use the CURRENT year (${new Date().getFullYear()}) unless explicitly stated otherwise.
- If the user asks about group state, voting, or consensus, use "reason".
- If the user asks to add an item, use "propose".
- For trip dates, use "set_dates" with YYYY-MM-DD format. Use current year (${new Date().getFullYear()}).
- For travel origins, use "populate_logistics" only when confidence > 0.8.
- Output raw JSON only. No markdown fences. No explanation.`;
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
