import { NextResponse } from 'next/server';
import { registry } from '@/lib/discovery/registry-instance';
import type { CarouselCard } from '@/lib/discovery/types';

export async function GET() {
  try {
    // Fetch items for each carousel group in parallel
    const [trendingItems, dayPlanItems, recentItems] = await Promise.all([
      registry.search({ limit: 5 }),
      registry.search({ category: 'day_plans', limit: 4 }),
      registry.search({ limit: 8 }),
    ]);

    // Sort trending by taste score descending
    const trending = [...trendingItems].sort(
      (a, b) => b.tasteScore - a.tasteScore,
    );

    // Recent discoveries: take items not in trending, or tail of the list
    const trendingIds = new Set(trending.map((i) => i.id));
    const recent = recentItems.filter((i) => !trendingIds.has(i.id)).slice(0, 5);

    const carousels: CarouselCard[] = [
      {
        id: 'carousel-trending',
        title: 'Trending Now',
        subtitle: 'Most loved across all categories',
        heroColor: '#FF6B35',
        category: 'activities',
        items: trending.slice(0, 5),
        curationType: 'trending',
      },
      {
        id: 'carousel-day-plans',
        title: 'Day Plans',
        subtitle: 'Full days, zero planning stress',
        heroColor: '#4ECDC4',
        category: 'day_plans',
        items: dayPlanItems.slice(0, 4),
        curationType: 'editorial',
      },
      {
        id: 'carousel-new',
        title: 'New Discoveries',
        subtitle: 'Fresh picks this season',
        heroColor: '#7B68EE',
        category: 'experiences',
        items: recent.slice(0, 5),
        curationType: 'seasonal',
      },
    ];

    return NextResponse.json({ carousels });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
