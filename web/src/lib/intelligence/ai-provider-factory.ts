// web/src/lib/intelligence/ai-provider-factory.ts
// Factory for AI provider selection. Reads HELLO_AI_PROVIDER env var.
// Default: "gemini" (GeminiProvider with gemini-2.5-pro).
// Future: "claude", "openai", "perplexity" when providers expose OAuth-based API access.

import { type AIProvider, GeminiProvider } from "./ai-provider";

let cachedProvider: AIProvider | null = null;

/**
 * Get the configured AI provider. Singleton — created once per process lifetime.
 * Returns null if no API key is configured.
 */
export function getAIProvider(): AIProvider | null {
  if (cachedProvider) return cachedProvider;

  const providerName = process.env.HELLO_AI_PROVIDER || "gemini";
  const modelName = process.env.GEMINI_MODEL || "gemini-2.5-pro";

  switch (providerName) {
    case "gemini": {
      const apiKey = process.env.GEMINI_API_KEY;
      if (!apiKey) {
        console.warn("[ai-provider] No GEMINI_API_KEY configured");
        return null;
      }
      cachedProvider = new GeminiProvider(apiKey, modelName);
      console.log(`[ai-provider] Initialized GeminiProvider (model: ${modelName})`);
      return cachedProvider;
    }

    // Future providers:
    // case "claude": {
    //   const apiKey = process.env.CLAUDE_API_KEY;
    //   if (!apiKey) return null;
    //   cachedProvider = new ClaudeProvider(apiKey);
    //   return cachedProvider;
    // }
    // case "openai": {
    //   const apiKey = process.env.OPENAI_API_KEY;
    //   if (!apiKey) return null;
    //   cachedProvider = new OpenAIProvider(apiKey);
    //   return cachedProvider;
    // }

    default:
      console.warn(`[ai-provider] Unknown provider: ${providerName}, falling back to gemini`);
      const fallbackKey = process.env.GEMINI_API_KEY;
      if (!fallbackKey) return null;
      cachedProvider = new GeminiProvider(fallbackKey, modelName);
      return cachedProvider;
  }
}
