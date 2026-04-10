import { NextRequest, NextResponse } from 'next/server';
import { TripSummary } from '../../../lib/types';

// TODO: Integrate with database (Supabase Postgres) to fetch real data
// and compute summary using trip-aggregator.

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ tripId: string }> }
) {
  try {
    const { tripId } = await params;

    // TODO: Fetch expenses and members from DB, then run
    // summarizeTrip() to produce real summary.

    const emptySummary: TripSummary = {
      totalSpent: 0,
      byCurrency: {},
      byCategory: {},
      byPhase: {},
      byMember: {},
      topPayer: '',
      topSpender: '',
      avgPerDay: 0,
      avgPerPerson: 0,
      timeline: [],
    };

    return NextResponse.json({
      tripId,
      ...emptySummary,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
