import { NextRequest, NextResponse } from 'next/server';

// TODO: Integrate with database (Supabase Postgres) for trip storage.

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    const name: string | undefined = body.name;
    const currency: string = body.currency ?? 'USD';
    const members: { id: string; name: string }[] = body.members ?? [];

    if (!name) {
      return NextResponse.json(
        { error: 'name is required' },
        { status: 400 }
      );
    }

    // TODO: Store trip in database and return real tripId.
    const tripId = `trip_${Date.now()}`;

    return NextResponse.json({
      tripId,
      name,
      currency,
      members,
      created: true,
      createdAt: new Date().toISOString(),
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
