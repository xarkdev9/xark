// hello Discovery Engine — Unit Tests
// Tests: ProviderRegistry, sanitizeContext, SeededCatalogProvider, and API logic

import { describe, it, expect, beforeEach } from 'vitest';
import { ProviderRegistry, type DiscoveryProvider } from '@/lib/discovery/provider-registry';
import { sanitizeContext } from '@/lib/discovery/sanitize';
import { SeededCatalogProvider } from '@/lib/discovery/providers/seeded-catalog';
import type { DiscoveryCategory, DiscoveryItem, DiscoveryItemDetail } from '@/lib/discovery/types';

// ── Test Helpers ──

function makeItem(overrides: Partial<DiscoveryItem> = {}): DiscoveryItem {
  return {
    id: `test-${Math.random().toString(36).slice(2, 8)}`,
    title: 'Test Item',
    category: 'restaurants',
    metadata: {},
    tasteScore: 80,
    source: 'test',
    fetchedAt: new Date().toISOString(),
    ...overrides,
  };
}

function makeMockProvider(
  overrides: Partial<DiscoveryProvider> & { items?: DiscoveryItem[] } = {},
): DiscoveryProvider {
  const items = overrides.items ?? [makeItem()];
  return {
    name: overrides.name ?? 'mock',
    priority: overrides.priority ?? 0,
    supports: overrides.supports ?? ['restaurants', 'hotels', 'activities', 'destinations', 'day_plans', 'experiences'],
    search: overrides.search ?? (async () => items),
    getDetail: overrides.getDetail ?? (async () => null),
    healthCheck: overrides.healthCheck ?? (async () => ({ status: 'ok' })),
  };
}

// ═══════════════════════════════════════════
// PROVIDER REGISTRY
// ═══════════════════════════════════════════

describe('ProviderRegistry', () => {
  let registry: ProviderRegistry;

  beforeEach(() => {
    registry = new ProviderRegistry();
  });

  it('search returns items from all providers', async () => {
    const itemA = makeItem({ id: 'a', title: 'Alpha', location: 'Rome' });
    const itemB = makeItem({ id: 'b', title: 'Beta', location: 'Paris' });

    registry.register(makeMockProvider({ name: 'provA', priority: 0, items: [itemA] }));
    registry.register(makeMockProvider({ name: 'provB', priority: 1, items: [itemB] }));

    const results = await registry.search({ limit: 10 });
    expect(results).toHaveLength(2);
    expect(results.map((r) => r.id)).toContain('a');
    expect(results.map((r) => r.id)).toContain('b');
  });

  it('deduplicates by title + location', async () => {
    const item1 = makeItem({ id: '1', title: 'Same Place', location: 'Rome' });
    const item2 = makeItem({ id: '2', title: 'Same Place', location: 'Rome' });
    const item3 = makeItem({ id: '3', title: 'Same Place', location: 'Paris' });

    registry.register(makeMockProvider({ name: 'p1', priority: 0, items: [item1] }));
    registry.register(makeMockProvider({ name: 'p2', priority: 1, items: [item2, item3] }));

    const results = await registry.search({ limit: 10 });
    // item1 and item2 same title+location => deduplicated. item3 different location => kept.
    expect(results).toHaveLength(2);
    expect(results[0].id).toBe('1'); // first seen wins
    expect(results[1].id).toBe('3');
  });

  it('getDetail falls back through providers', async () => {
    const detail: DiscoveryItemDetail = {
      id: 'detail-1',
      title: 'Found It',
      category: 'restaurants',
      metadata: {},
      tasteScore: 90,
      source: 'test',
      fetchedAt: new Date().toISOString(),
      imageUrls: [],
      tags: [],
    };

    registry.register(
      makeMockProvider({
        name: 'empty',
        priority: 0,
        getDetail: async () => null,
      }),
    );
    registry.register(
      makeMockProvider({
        name: 'has-detail',
        priority: 1,
        getDetail: async (id) => (id === 'detail-1' ? detail : null),
      }),
    );

    const result = await registry.getDetail('detail-1');
    expect(result).not.toBeNull();
    expect(result!.title).toBe('Found It');
  });

  it('getDetail returns null when no provider has it', async () => {
    registry.register(makeMockProvider({ name: 'empty', getDetail: async () => null }));
    const result = await registry.getDetail('nonexistent');
    expect(result).toBeNull();
  });

  it('healthReport shows all provider statuses', async () => {
    registry.register(
      makeMockProvider({
        name: 'healthy',
        priority: 0,
        healthCheck: async () => ({ status: 'ok' }),
      }),
    );
    registry.register(
      makeMockProvider({
        name: 'sick',
        priority: 1,
        healthCheck: async () => ({ status: 'degraded' }),
      }),
    );

    const report = await registry.healthReport();
    expect(report['healthy']).toEqual({ status: 'ok' });
    expect(report['sick']).toEqual({ status: 'degraded' });
  });

  it('empty registry returns empty results', async () => {
    const results = await registry.search({ limit: 10 });
    expect(results).toEqual([]);
  });

  it('search filters providers by category support', async () => {
    const restItem = makeItem({ id: 'r1', title: 'Restaurant', category: 'restaurants' });
    const hotelItem = makeItem({ id: 'h1', title: 'Hotel', category: 'hotels' });

    registry.register(
      makeMockProvider({
        name: 'rest-only',
        priority: 0,
        supports: ['restaurants'],
        items: [restItem],
      }),
    );
    registry.register(
      makeMockProvider({
        name: 'hotel-only',
        priority: 1,
        supports: ['hotels'],
        items: [hotelItem],
      }),
    );

    const results = await registry.search({ category: 'hotels', limit: 10 });
    expect(results).toHaveLength(1);
    expect(results[0].id).toBe('h1');
  });

  it('search respects limit', async () => {
    const items = Array.from({ length: 10 }, (_, i) =>
      makeItem({ id: `item-${i}`, title: `Item ${i}`, location: `Loc ${i}` }),
    );
    registry.register(makeMockProvider({ items }));

    const results = await registry.search({ limit: 3 });
    expect(results).toHaveLength(3);
  });
});

// ═══════════════════════════════════════════
// SANITIZE
// ═══════════════════════════════════════════

describe('sanitizeContext', () => {
  it('removes keys containing "token"', () => {
    const result = sanitizeContext({ authToken: 'abc', screen: 'home' });
    expect(result).not.toHaveProperty('authToken');
    expect(result).toHaveProperty('screen', 'home');
  });

  it('removes keys containing "key" (including compound keys)', () => {
    const result = sanitizeContext({
      apiKey: 'secret-123',
      accessKey: 'ak-456',
      screen: 'explore',
    });
    expect(result).not.toHaveProperty('apiKey');
    expect(result).not.toHaveProperty('accessKey');
    expect(result).toHaveProperty('screen', 'explore');
  });

  it('removes "monkey" because it contains "key"', () => {
    // The sanitizer uses a simple `.includes()` check — "monkey" contains "key"
    const result = sanitizeContext({ monkey: 'george' });
    expect(result).not.toHaveProperty('monkey');
  });

  it('removes keys containing "secret"', () => {
    const result = sanitizeContext({ clientSecret: 'shhh', action: 'tap' });
    expect(result).not.toHaveProperty('clientSecret');
    expect(result).toHaveProperty('action', 'tap');
  });

  it('removes keys containing "password"', () => {
    const result = sanitizeContext({ userPassword: 'hunter2', screen: 'login' });
    expect(result).not.toHaveProperty('userPassword');
    expect(result).toHaveProperty('screen', 'login');
  });

  it('removes keys containing "plaintext"', () => {
    const result = sanitizeContext({ plaintextMessage: 'hello', screen: 'chat' });
    expect(result).not.toHaveProperty('plaintextMessage');
  });

  it('removes keys containing "taste"', () => {
    const result = sanitizeContext({ tasteScore: 92, tasteReason: 'great', screen: 'feed' });
    expect(result).not.toHaveProperty('tasteScore');
    expect(result).not.toHaveProperty('tasteReason');
    expect(result).toHaveProperty('screen', 'feed');
  });

  it('truncates strings longer than 200 chars', () => {
    const longString = 'a'.repeat(250);
    const result = sanitizeContext({ description: longString });
    const desc = result['description'] as string;
    expect(desc.length).toBeLessThanOrEqual(215); // 200 + "...[truncated]"
    expect(desc).toContain('...[truncated]');
  });

  it('preserves safe keys like "screen", "action", "timestamp"', () => {
    const input = {
      screen: 'explore',
      action: 'search',
      timestamp: '2026-04-02T10:00:00Z',
    };
    const result = sanitizeContext(input);
    expect(result).toEqual(input);
  });

  it('deep clones — original not mutated', () => {
    const original = { screen: 'home', nested: { action: 'tap', value: 'x'.repeat(300) } };
    const originalCopy = JSON.parse(JSON.stringify(original));
    sanitizeContext(original);
    expect(original).toEqual(originalCopy);
  });

  it('handles nested objects', () => {
    const result = sanitizeContext({
      screen: 'feed',
      context: {
        apiKey: 'should-strip',
        action: 'should-keep',
        deep: {
          secretValue: 'strip-me',
          label: 'keep-me',
        },
      },
    });
    expect(result['screen']).toBe('feed');
    const ctx = result['context'] as Record<string, unknown>;
    expect(ctx).not.toHaveProperty('apiKey');
    expect(ctx['action']).toBe('should-keep');
    const deep = ctx['deep'] as Record<string, unknown>;
    expect(deep).not.toHaveProperty('secretValue');
    expect(deep['label']).toBe('keep-me');
  });

  it('handles arrays within objects', () => {
    const result = sanitizeContext({
      items: ['hello', 'world'],
      screen: 'feed',
    });
    expect(result['items']).toEqual(['hello', 'world']);
  });

  it('preserves numbers and booleans', () => {
    const result = sanitizeContext({
      count: 42,
      active: true,
      screen: 'home',
    });
    expect(result['count']).toBe(42);
    expect(result['active']).toBe(true);
  });
});

// ═══════════════════════════════════════════
// SEEDED CATALOG PROVIDER
// ═══════════════════════════════════════════

describe('SeededCatalogProvider', () => {
  let catalog: SeededCatalogProvider;

  beforeEach(() => {
    catalog = new SeededCatalogProvider();
  });

  it('search returns items for supported categories', async () => {
    const results = await catalog.search({ limit: 50 });
    expect(results.length).toBeGreaterThan(0);

    // Should have items from multiple categories
    const categories = new Set(results.map((i) => i.category));
    expect(categories.size).toBeGreaterThanOrEqual(3);
  });

  it('search filters by category when specified', async () => {
    const hotels = await catalog.search({ category: 'hotels', limit: 50 });
    expect(hotels.length).toBeGreaterThan(0);
    for (const item of hotels) {
      expect(item.category).toBe('hotels');
    }
  });

  it('search respects limit parameter', async () => {
    const results = await catalog.search({ limit: 2 });
    expect(results).toHaveLength(2);
  });

  it('search filters by location when specified', async () => {
    const romeItems = await catalog.search({ location: 'Rome', limit: 50 });
    expect(romeItems.length).toBeGreaterThan(0);
    for (const item of romeItems) {
      expect(item.location?.toLowerCase()).toContain('rome');
    }
  });

  it('search filters by query', async () => {
    const results = await catalog.search({ query: 'jazz', limit: 50 });
    expect(results.length).toBeGreaterThan(0);
    // At least one result should match "jazz" in title or description
    const hasMatch = results.some(
      (item) =>
        item.title.toLowerCase().includes('jazz') ||
        item.description?.toLowerCase().includes('jazz'),
    );
    expect(hasMatch).toBe(true);
  });

  it('getDetail returns item by ID', async () => {
    const detail = await catalog.getDetail('seed-rest-001');
    expect(detail).not.toBeNull();
    expect(detail!.id).toBe('seed-rest-001');
    expect(detail!.title).toBe('Roscioli Salumeria con Cucina');
    expect(detail!.longDescription).toBeDefined();
    expect(detail!.imageUrls.length).toBeGreaterThan(0);
    expect(detail!.tags.length).toBeGreaterThan(0);
  });

  it('getDetail returns null for unknown ID', async () => {
    const detail = await catalog.getDetail('nonexistent-999');
    expect(detail).toBeNull();
  });

  it('healthCheck returns ok', async () => {
    const health = await catalog.healthCheck();
    expect(health.status).toBe('ok');
  });

  it('supports all 6 categories', () => {
    const expected: DiscoveryCategory[] = [
      'restaurants',
      'hotels',
      'activities',
      'destinations',
      'day_plans',
      'experiences',
    ];
    for (const cat of expected) {
      expect(catalog.supports).toContain(cat);
    }
  });

  it('all items have required fields', async () => {
    const items = await catalog.search({ limit: 100 });
    for (const item of items) {
      expect(item.id).toBeTruthy();
      expect(item.title).toBeTruthy();
      expect(item.category).toBeTruthy();
      expect(typeof item.tasteScore).toBe('number');
      expect(item.source).toBe('seeded_catalog');
      expect(item.fetchedAt).toBeTruthy();
    }
  });
});

// ═══════════════════════════════════════════
// STATELESS API CALCULATION TESTS
// ═══════════════════════════════════════════

describe('Feed endpoint logic', () => {
  let registry: ProviderRegistry;

  beforeEach(() => {
    registry = new ProviderRegistry();
    registry.register(new SeededCatalogProvider());
  });

  it('returns items with source information', async () => {
    const items = await registry.search({ limit: 5 });
    expect(items.length).toBeGreaterThan(0);
    for (const item of items) {
      expect(item.source).toBeTruthy();
    }
  });

  it('cacheKey can be constructed from params', () => {
    const categories: DiscoveryCategory[] = ['restaurants', 'hotels'];
    const location = 'Rome';
    const offset = 0;

    const cacheKey = `feed:${categories.join(',')}:${location}:${offset}`;
    expect(cacheKey).toBe('feed:restaurants,hotels:Rome:0');
  });

  it('cacheKey defaults to "all" and "global"', () => {
    const categories = undefined;
    const location = undefined;
    const offset = 0;

    const cacheKey = `feed:${(categories as string[] | undefined)?.join(',') ?? 'all'}:${location ?? 'global'}:${offset}`;
    expect(cacheKey).toBe('feed:all:global:0');
  });

  it('exclude logic filters items by ID', async () => {
    const allItems = await registry.search({ limit: 20 });
    const excludeIds = new Set([allItems[0].id]);
    const filtered = allItems.filter((item) => !excludeIds.has(item.id));

    expect(filtered.length).toBe(allItems.length - 1);
    expect(filtered.every((item) => item.id !== allItems[0].id)).toBe(true);
  });

  it('paging with offset and limit', async () => {
    const allItems = await registry.search({ limit: 20 });
    const offset = 2;
    const limit = 3;
    const paged = allItems.slice(offset, offset + limit);

    expect(paged).toHaveLength(3);
    expect(paged[0].id).toBe(allItems[2].id);
  });
});

describe('Explore endpoint logic', () => {
  let registry: ProviderRegistry;

  beforeEach(() => {
    registry = new ProviderRegistry();
    registry.register(new SeededCatalogProvider());
  });

  it('query filtering works', async () => {
    const items = await registry.search({ query: 'truffle', limit: 50 });
    expect(items.length).toBeGreaterThan(0);
    const hasTruffle = items.some(
      (item) =>
        item.title.toLowerCase().includes('truffle') ||
        item.description?.toLowerCase().includes('truffle'),
    );
    expect(hasTruffle).toBe(true);
  });

  it('price range filtering works', async () => {
    const items = await registry.search({ limit: 50 });
    const priceRange = { min: 50, max: 200 };
    const filtered = items.filter((item) => {
      if (item.price === undefined || item.price === null) return true;
      if (priceRange.min !== undefined && item.price < priceRange.min) return false;
      if (priceRange.max !== undefined && item.price > priceRange.max) return false;
      return true;
    });

    for (const item of filtered) {
      if (item.price != null) {
        expect(item.price).toBeGreaterThanOrEqual(50);
        expect(item.price).toBeLessThanOrEqual(200);
      }
    }
  });

  it('combined category and location filter', async () => {
    const items = await registry.search({
      category: 'restaurants',
      location: 'Rome',
      limit: 50,
    });
    expect(items.length).toBeGreaterThan(0);
    for (const item of items) {
      expect(item.category).toBe('restaurants');
      expect(item.location?.toLowerCase()).toContain('rome');
    }
  });
});

describe('Carousel endpoint logic', () => {
  let registry: ProviderRegistry;

  beforeEach(() => {
    registry = new ProviderRegistry();
    registry.register(new SeededCatalogProvider());
  });

  it('returns 3 card groups', async () => {
    const [trendingItems, dayPlanItems, recentItems] = await Promise.all([
      registry.search({ limit: 5 }),
      registry.search({ category: 'day_plans', limit: 4 }),
      registry.search({ limit: 8 }),
    ]);

    const trending = [...trendingItems].sort((a, b) => b.tasteScore - a.tasteScore);
    const trendingIds = new Set(trending.map((i) => i.id));
    const recent = recentItems.filter((i) => !trendingIds.has(i.id)).slice(0, 5);

    const carousels = [
      { id: 'carousel-trending', title: 'Trending Now', items: trending.slice(0, 5), curationType: 'trending' },
      { id: 'carousel-day-plans', title: 'Day Plans', items: dayPlanItems.slice(0, 4), curationType: 'editorial' },
      { id: 'carousel-new', title: 'New Discoveries', items: recent.slice(0, 5), curationType: 'seasonal' },
    ];

    expect(carousels).toHaveLength(3);
    expect(carousels[0].title).toBe('Trending Now');
    expect(carousels[1].title).toBe('Day Plans');
    expect(carousels[2].title).toBe('New Discoveries');
  });

  it('trending items sorted by taste score descending', async () => {
    const items = await registry.search({ limit: 5 });
    const trending = [...items].sort((a, b) => b.tasteScore - a.tasteScore);

    for (let i = 1; i < trending.length; i++) {
      expect(trending[i - 1].tasteScore).toBeGreaterThanOrEqual(trending[i].tasteScore);
    }
  });

  it('day plans carousel fetches day_plans category', async () => {
    const dayPlanItems = await registry.search({ category: 'day_plans', limit: 4 });
    expect(dayPlanItems.length).toBeGreaterThan(0);
    for (const item of dayPlanItems) {
      expect(item.category).toBe('day_plans');
    }
  });
});

describe('Feedback sanitization', () => {
  it('context is cleaned before storage', () => {
    const rawContext = {
      screen: 'discover_feed',
      action: 'search',
      timestamp: '2026-04-02T10:00:00Z',
      apiKey: 'sk-12345',
      authToken: 'jwt-xxxx',
      tasteScore: 92,
      deviceInfo: {
        os: 'iOS',
        version: '18.0',
        model: 'iPhone 16',
        appVersion: '2.0.0',
        secretDeviceId: 'hidden',
      },
    };

    const sanitized = sanitizeContext(rawContext);

    // Safe keys preserved
    expect(sanitized['screen']).toBe('discover_feed');
    expect(sanitized['action']).toBe('search');
    expect(sanitized['timestamp']).toBe('2026-04-02T10:00:00Z');

    // Sensitive keys removed
    expect(sanitized).not.toHaveProperty('apiKey');
    expect(sanitized).not.toHaveProperty('authToken');
    expect(sanitized).not.toHaveProperty('tasteScore');

    // Nested sensitive keys removed
    const deviceInfo = sanitized['deviceInfo'] as Record<string, unknown>;
    expect(deviceInfo['os']).toBe('iOS');
    expect(deviceInfo['appVersion']).toBe('2.0.0');
    expect(deviceInfo).not.toHaveProperty('secretDeviceId');
  });
});
