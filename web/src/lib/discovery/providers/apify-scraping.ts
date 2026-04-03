import type { DiscoveryProvider } from '../provider-registry';
import type {
  DiscoveryCategory,
  DiscoveryItem,
  DiscoveryItemDetail,
} from '../types';

/**
 * ApifyScrapingProvider — web scraping via Apify actors.
 * Stub: returns empty for now.
 * TODO: integrate with existing algo/src/apify-fetch.ts
 */
export class ApifyScrapingProvider implements DiscoveryProvider {
  name = 'apify';
  priority = 2;
  supports: DiscoveryCategory[] = ['restaurants', 'hotels', 'activities'];

  async search(_params: {
    query?: string;
    category?: DiscoveryCategory;
    location?: string;
    limit: number;
  }): Promise<DiscoveryItem[]> {
    // Stub: no results until Apify integration is wired up.
    return [];
  }

  async getDetail(_externalId: string): Promise<DiscoveryItemDetail | null> {
    // Stub: no detail until Apify integration is wired up.
    return null;
  }

  async healthCheck(): Promise<{ status: 'ok' | 'degraded' | 'down' }> {
    // Stub: report degraded until properly connected.
    return { status: 'degraded' };
  }
}
