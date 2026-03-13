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

  const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

  // Step 1: Parse intent via Gemini
  const intentPrompt = buildIntentPrompt(input);
  const intentResult = await model.generateContent(intentPrompt);
  const intentText = intentResult.response.text();

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
    parsed = JSON.parse(intentText);
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
      return { response: "searched but found no results matching your criteria.", action: "search" };
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
  return `You are @xark, a group coordination assistant. You are silent, precise, and never use emojis.

GROUNDING CONTEXT (current decision state):
${input.groundingPrompt}

RECENT MESSAGES (last 15):
${input.recentMessages.map((m) => `${m.sender_name || m.role}: ${m.content}`).join("\n")}

AVAILABLE TOOLS: ${tools.join(", ")}

USER REQUEST: ${input.userMessage}

Respond with JSON only. Choose one action:
1. {"action": "search", "tool": "<tool-name>", "params": {<tool-specific params>}}
2. {"action": "reason", "directResponse": "<your response to the user>"}
3. {"action": "propose", "directResponse": "<your response>"}
4. {"action": "set_dates", "start_date": "YYYY-MM-DD", "end_date": "YYYY-MM-DD", "label": "optional"}
5. {"action": "populate_logistics", "extractions": [{"user_name": "name", "origin": "AIRPORT", "confidence": 0.95}]}

If the user asks to find/search/look for something, use action "search" with the right tool.
If the user asks a question about group state, voting, or consensus, use action "reason".
If the user asks to add an item directly, use action "propose".
If the user wants to set, change, or confirm trip dates, use action "set_dates". Extract start_date (YYYY-MM-DD), end_date (YYYY-MM-DD), and optional label.
If you detect member travel origins/destinations in the message, use action "populate_logistics". Extract user_name, origin (airport code or city), and confidence (0-1). Only extract when confidence > 0.8.
Respond only with the JSON object, nothing else.`;
}

function buildSynthesisPrompt(input: OrchestratorInput, results: ApifyResult[]): string {
  const resultsSummary = results
    .slice(0, 8)
    .map((r, i) => `${i + 1}. ${r.title}${r.price ? ` — ${r.price}` : ""}${r.rating ? ` (${r.rating}★)` : ""}`)
    .join("\n");

  return `You are @xark. Synthesize these search results for the group. Be brief and helpful. No emojis. No personality. Report facts.

RESULTS:
${resultsSummary}

USER ASKED: ${input.userMessage}

Respond in 1-2 sentences. Example: "found 4 hotels under $200. they're in your stream now."`;
}
