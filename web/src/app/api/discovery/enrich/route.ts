import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { itemIds, context } = body as {
      itemIds: string[];
      context?: Record<string, unknown>;
    };

    if (!Array.isArray(itemIds) || itemIds.length === 0) {
      return NextResponse.json(
        { error: 'itemIds must be a non-empty array' },
        { status: 400 },
      );
    }

    if (itemIds.length > 50) {
      return NextResponse.json(
        { error: 'Maximum 50 items per enrichment request' },
        { status: 400 },
      );
    }

    const contextHint = context?.intent
      ? String(context.intent)
      : 'general exploration';

    // Generate mock AI summaries for each item
    const enriched = itemIds.map((id) => ({
      id,
      aiSummary: generateMockSummary(id, contextHint),
      tags: generateMockTags(id),
    }));

    return NextResponse.json({ enriched });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}

function generateMockSummary(itemId: string, contextHint: string): string {
  const summaries: Record<string, string> = {
    rest: 'solid pick for the group. the food quality is consistent and the vibe works for both casual and celebratory meals.',
    hotel: 'great location-to-price ratio. rooms are clean, staff is responsive, and the neighborhood has plenty to explore on foot.',
    act: 'worth the time investment. this is the kind of experience that ends up being the highlight of the trip.',
    day: 'well-paced itinerary that balances must-sees with downtime. flexible enough to swap stops without losing the thread.',
    dest: 'the kind of place that rewards slow travel. skip the top-10 lists and wander.',
    exp: 'genuinely unique. hard to replicate this anywhere else, and the local guides make it personal.',
  };

  const prefix = itemId.split('-')[1] ?? 'act';
  const base = summaries[prefix] ?? summaries['act'];
  return `${base} (context: ${contextHint})`;
}

function generateMockTags(itemId: string): string[] {
  const tagSets: Record<string, string[]> = {
    rest: ['dining', 'group-friendly', 'local-favorite'],
    hotel: ['accommodation', 'walkable', 'good-value'],
    act: ['experience', 'memorable', 'active'],
    day: ['itinerary', 'full-day', 'curated'],
    dest: ['destination', 'multi-day', 'scenic'],
    exp: ['unique', 'immersive', 'local'],
  };

  const prefix = itemId.split('-')[1] ?? 'act';
  return tagSets[prefix] ?? ['discovery', 'recommended'];
}
