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
  action?: "search" | "reason" | "propose";
  tool?: string;
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

  let parsed: { action: string; tool?: string; params?: Record<string, string>; directResponse?: string };
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

If the user asks to find/search/look for something, use action "search" with the right tool.
If the user asks a question about group state, voting, or consensus, use action "reason".
If the user asks to add an item directly, use action "propose".
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
