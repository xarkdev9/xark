import { NextRequest, NextResponse } from 'next/server';

// TODO: Integrate with database (Supabase Postgres) to fetch settlement records.

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ tripId: string }> }
) {
  try {
    const { tripId } = await params;

    // TODO: Fetch settlement records from database.
    return NextResponse.json({
      tripId,
      settlements: [],
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
