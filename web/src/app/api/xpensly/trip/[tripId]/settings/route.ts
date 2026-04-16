import { NextRequest, NextResponse } from 'next/server';

// TODO: Integrate with database (Supabase Postgres) for trip settings.

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ tripId: string }> }
) {
  try {
    const { tripId } = await params;
    const body = await request.json();

    // TODO: Update trip settings in database.
    return NextResponse.json({
      tripId,
      settings: body,
      updated: true,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
