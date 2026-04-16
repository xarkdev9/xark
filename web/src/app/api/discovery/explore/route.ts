import { NextRequest, NextResponse } from 'next/server';
import { registry } from '@/lib/discovery/registry-instance';
import type { DiscoveryCategory } from '@/lib/discovery/types';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const {
      query,
      category,
      location,
      priceRange,
      limit = 20,
      offset = 0,
    } = body as {
      query?: string;
      category?: DiscoveryCategory;
      location?: string;
      priceRange?: { min?: number; max?: number };
      limit?: number;
      offset?: number;
    };

    if (limit < 1 || limit > 100) {
      return NextResponse.json(
        { error: 'limit must be between 1 and 100' },
        { status: 400 },
      );
    }

    let items = await registry.search({
      query,
      category,
      location,
      limit: limit + offset + 50, // Over-fetch to account for price filtering
    });

    // Filter by price range if provided
    if (priceRange) {
      items = items.filter((item) => {
        if (item.price === undefined || item.price === null) return true;
        if (priceRange.min !== undefined && item.price < priceRange.min)
          return false;
        if (priceRange.max !== undefined && item.price > priceRange.max)
          return false;
        return true;
      });
    }

    const totalCount = items.length;
    const paged = items.slice(offset, offset + limit);

    return NextResponse.json({
      items: paged,
      totalCount,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
