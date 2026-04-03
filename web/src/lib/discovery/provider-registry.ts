import type { DiscoveryCategory, DiscoveryItem, DiscoveryItemDetail } from './types';

export interface DiscoveryProvider {
  name: string;
  priority: number;
  supports: DiscoveryCategory[];
  search(params: {
    query?: string;
    category?: DiscoveryCategory;
    location?: string;
    limit: number;
  }): Promise<DiscoveryItem[]>;
  getDetail(externalId: string): Promise<DiscoveryItemDetail | null>;
  healthCheck(): Promise<{ status: 'ok' | 'degraded' | 'down' }>;
}

export class ProviderRegistry {
  private providers: DiscoveryProvider[] = [];

  register(provider: DiscoveryProvider): void {
    this.providers.push(provider);
    this.providers.sort((a, b) => a.priority - b.priority);
  }

  /**
   * Queries all providers that support the category, in priority order.
   * Runs in parallel with Promise.allSettled.
   * Merges results, deduplicates by title+location.
   */
  async search(params: {
    query?: string;
    category?: DiscoveryCategory;
    location?: string;
    limit: number;
  }): Promise<DiscoveryItem[]> {
    const eligible = params.category
      ? this.providers.filter((p) => p.supports.includes(params.category!))
      : this.providers;

    if (eligible.length === 0) return [];

    const results = await Promise.allSettled(
      eligible.map((p) => p.search(params)),
    );

    const merged: DiscoveryItem[] = [];
    const seen = new Set<string>();

    for (const result of results) {
      if (result.status !== 'fulfilled') continue;
      for (const item of result.value) {
        const dedupeKey = `${item.title.toLowerCase()}|${(item.location ?? '').toLowerCase()}`;
        if (!seen.has(dedupeKey)) {
          seen.add(dedupeKey);
          merged.push(item);
        }
      }
    }

    return merged.slice(0, params.limit);
  }

  /**
   * Tries providers in priority order until one returns a result.
   */
  async getDetail(itemId: string): Promise<DiscoveryItemDetail | null> {
    for (const provider of this.providers) {
      try {
        const detail = await provider.getDetail(itemId);
        if (detail) return detail;
      } catch {
        // Try next provider
      }
    }
    return null;
  }

  async healthReport(): Promise<Record<string, { status: string }>> {
    const report: Record<string, { status: string }> = {};

    const checks = await Promise.allSettled(
      this.providers.map(async (p) => ({
        name: p.name,
        result: await p.healthCheck(),
      })),
    );

    for (const check of checks) {
      if (check.status === 'fulfilled') {
        report[check.value.name] = { status: check.value.result.status };
      } else {
        report['unknown'] = { status: 'down' };
      }
    }

    return report;
  }
}
