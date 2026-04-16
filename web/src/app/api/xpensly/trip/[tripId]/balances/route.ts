import { NextRequest, NextResponse } from 'next/server';
import { Settlement } from '../../../lib/types';

// TODO: Integrate with database (Supabase Postgres) to fetch real data
// and compute balances using settlement-engine.

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ tripId: string }> }
) {
  try {
    const { tripId } = await params;
    const { searchParams } = new URL(request.url);
    const asOf = searchParams.get('asOf');

    // TODO: Fetch members, expenses, refunds, and settlements from DB,
    // then run computeSettlement() to produce real balances.
    // If asOf is provided, filter data to that date.

    const emptySettlement: Settlement = {
      entries: [],
      deltas: [],
      simplified: [],
      totalSpent: 0,
      perPerson: 0,
      byCurrency: {},
      byCategory: {},
      memberCount: 0,
    };

    return NextResponse.json({
      tripId,
      ...(asOf && { asOf }),
      ...emptySettlement,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
