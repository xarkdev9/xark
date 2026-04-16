import { NextRequest, NextResponse } from 'next/server';
import { registry } from '@/lib/discovery/registry-instance';
import type { DiscoveryCategory } from '@/lib/discovery/types';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const {
      categories,
      location,
      limit = 20,
      offset = 0,
      exclude = [],
    } = body as {
      categories?: DiscoveryCategory[];
      location?: string;
      groupId?: string;
      limit?: number;
      offset?: number;
      exclude?: string[];
    };

    if (limit < 1 || limit > 100) {
      return NextResponse.json(
        { error: 'limit must be between 1 and 100' },
        { status: 400 },
      );
    }

    let allItems = await registry.search({
      category: categories?.[0],
      location,
      limit: limit + offset + exclude.length,
    });

    // If multiple categories requested, merge results from each
    if (categories && categories.length > 1) {
      const categoryResults = await Promise.all(
        categories.map((cat) =>
          registry.search({ category: cat, location, limit }),
        ),
      );
      const seen = new Set<string>();
      allItems = [];
      for (const results of categoryResults) {
        for (const item of results) {
          if (!seen.has(item.id)) {
            seen.add(item.id);
            allItems.push(item);
          }
        }
      }
    }

    // Exclude specified item IDs
    if (exclude.length > 0) {
      const excludeSet = new Set(exclude);
      allItems = allItems.filter((item) => !excludeSet.has(item.id));
    }

    // Apply offset and limit
    const paged = allItems.slice(offset, offset + limit);

    const cacheKey = `feed:${categories?.join(',') ?? 'all'}:${location ?? 'global'}:${offset}`;
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000).toISOString();

    return NextResponse.json({
      items: paged,
      source: 'discovery_feed',
      cacheKey,
      expiresAt,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
