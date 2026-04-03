import { ProviderRegistry } from './provider-registry';
import { SeededCatalogProvider } from './providers/seeded-catalog';
import { GeminiEnrichmentProvider } from './providers/gemini-enrichment';
import { ApifyScrapingProvider } from './providers/apify-scraping';

/**
 * Default discovery provider registry.
 * Registers all 3 providers in priority order:
 *   0 — seeded_catalog (mock data, always available)
 *   1 — gemini (AI enrichment, stub)
 *   2 — apify (web scraping, stub)
 */
const registry = new ProviderRegistry();
registry.register(new SeededCatalogProvider());
registry.register(new GeminiEnrichmentProvider());
registry.register(new ApifyScrapingProvider());

export { registry };
