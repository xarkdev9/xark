// web/src/lib/intelligence/ai-provider.ts
// BYOAI-ready AI provider abstraction.
// Default: GeminiProvider. Future: ClaudeProvider, OpenAIProvider, etc.

import { GoogleGenerativeAI, HarmCategory, HarmBlockThreshold, type GenerativeModel } from "@google/generative-ai";

const TIMEOUT_MS = 45_000;
const MAX_RESPONSE_LENGTH = 500;

// ── Types ──

export interface ParseIntentResult {
  functionCall?: { name: string; args: Record<string, string> };
  textResponse?: string;
  blocked?: boolean;
}

export interface SynthesisResult {
  text: string;
}

export interface ItinerarySkeleton {
  days: Array<{
    date: string;
    label: string;
    slots: Array<{
      time: string;
      type: string;
      query: string;
      note: string;
    }>;
  }>;
}

export interface FunctionDeclaration {
  name: string;
  description: string;
  parameters: Record<string, unknown>;
}

// ── Interface ──

export interface AIProvider {
  /** Parse user message into a structured intent via function calling */
  parseIntent(input: {
    systemPrompt: string;
    conversationHistory: Array<{ role: "user" | "model"; parts: Array<{ text: string }> }>;
    dynamicPrompt: string;
    functionDeclarations: FunctionDeclaration[];
  }): Promise<ParseIntentResult>;

  /** Synthesize search results into a brief human response */
  synthesize(prompt: string): Promise<SynthesisResult>;

  /** Generate JSON from a structured prompt (for self-healing retry, itinerary, etc.) */
  generateJson(prompt: string): Promise<Record<string, unknown>>;

  /** Run a local knowledge search (Gemini-local tier) */
  localSearch(query: string, location: string): Promise<Array<{
    title: string;
    description: string;
    url?: string;
    phone?: string;
    address?: string;
  }>>;

  /** Run a grounded web search (Gemini-search tier) */
  groundedSearch(query: string, location: string): Promise<Array<{
    title: string;
    description: string;
    url?: string;
    phone?: string;
    address?: string;
  }>>;
}

// ── Timeout helper ──

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return Promise.race([
    promise,
    new Promise<never>((_, reject) =>
      setTimeout(() => reject(new Error("ai provider timeout")), ms)
    ),
  ]);
}

// ── GeminiProvider ──

export class GeminiProvider implements AIProvider {
  private model: GenerativeModel;

  constructor(apiKey: string, modelName: string = "gemini-2.5-pro") {
    const genAI = new GoogleGenerativeAI(apiKey);
    this.model = genAI.getGenerativeModel({
      model: modelName,
      safetySettings: [
        { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
        { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
        { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
        { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
      ],
    });
  }

  async parseIntent(input: {
    systemPrompt: string;
    conversationHistory: Array<{ role: "user" | "model"; parts: Array<{ text: string }> }>;
    dynamicPrompt: string;
    functionDeclarations: FunctionDeclaration[];
  }): Promise<ParseIntentResult> {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY || "");
    const model = genAI.getGenerativeModel({
      model: this.model.model || process.env.GEMINI_MODEL || "gemini-2.5-pro",
      systemInstruction: input.systemPrompt,
      safetySettings: [
        { category: HarmCategory.HARM_CATEGORY_HARASSMENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
        { category: HarmCategory.HARM_CATEGORY_HATE_SPEECH, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
        { category: HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
        { category: HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT, threshold: HarmBlockThreshold.BLOCK_ONLY_HIGH },
      ],
    });

    const result = await withTimeout(
      model.generateContent({
        contents: [
          ...input.conversationHistory,
          { role: "user", parts: [{ text: input.dynamicPrompt }] },
        ],
        tools: [{ functionDeclarations: input.functionDeclarations as any }],
      }),
      TIMEOUT_MS
    );

    const candidate = result.response.candidates?.[0];
    if (candidate?.finishReason === "SAFETY") {
      return { blocked: true };
    }

    const functionCall = result.response.functionCalls()?.[0];
    if (functionCall) {
      return {
        functionCall: {
          name: functionCall.name,
          args: (functionCall.args ?? {}) as Record<string, string>,
        },
      };
    }

    const textResponse = result.response.text();
    if (textResponse && textResponse.trim().length > 0) {
      return { textResponse: textResponse.trim().slice(0, MAX_RESPONSE_LENGTH) };
    }

    return {};
  }

  async synthesize(prompt: string): Promise<SynthesisResult> {
    const result = await withTimeout(
      this.model.generateContent(prompt),
      TIMEOUT_MS
    );
    return { text: result.response.text() };
  }

  async generateJson(prompt: string): Promise<Record<string, unknown>> {
    const result = await withTimeout(
      this.model.generateContent({
        contents: [{ role: "user", parts: [{ text: prompt }] }],
        generationConfig: { responseMimeType: "application/json" },
      }),
      TIMEOUT_MS
    );
    return JSON.parse(result.response.text());
  }

  async localSearch(query: string, location: string): Promise<Array<{
    title: string; description: string; url?: string; phone?: string; address?: string;
  }>> {
    try {
      const result = await withTimeout(
        this.model.generateContent({
          contents: [{ role: "user", parts: [{ text: `You are a local guide for ${location}. Return 5-8 real, well-known places for: "${query}".

RULES:
- ONLY return places you are confident actually exist. no made-up names.
- include the neighborhood/area in the description.
- if you're not sure about a place, skip it. fewer accurate results > many guesses.

Return ONLY a JSON array:
[{"title":"Place Name","description":"Brief description with neighborhood","address":"approximate address or area"}]` }] }],
          generationConfig: { responseMimeType: "application/json" },
        }),
        TIMEOUT_MS
      );

      const parsed = JSON.parse(result.response.text());
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

  async groundedSearch(query: string, location: string): Promise<Array<{
    title: string; description: string; url?: string; phone?: string; address?: string;
  }>> {
    const contextualQuery = location ? `${query} near ${location}` : query;
    try {
      const result = await withTimeout(
        this.model.generateContent({
          contents: [{ role: "user", parts: [{ text: `Find real places for: ${contextualQuery}. Return a JSON array of objects with fields: title, description, url, phone, address. Return ONLY the JSON array, no other text.` }] }],
          tools: [{ googleSearch: {} }] as any,
        }),
        TIMEOUT_MS
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
}
