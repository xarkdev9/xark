import { NextRequest, NextResponse } from 'next/server';

// TODO: Integrate with database (Supabase Postgres) for settlement recording.

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ tripId: string }> }
) {
  try {
    const { tripId } = await params;
    const body = await request.json();

    const fromUser: string = body.fromUser;
    const toUser: string = body.toUser;
    const amount: number = body.amount;
    const currency: string = body.currency ?? 'USD';
    const provider: string | undefined = body.provider;
    const proof: string | undefined = body.proof;
    const note: string | undefined = body.note;

    if (!fromUser || !toUser) {
      return NextResponse.json(
        { error: 'fromUser and toUser are required' },
        { status: 400 }
      );
    }

    if (typeof amount !== 'number' || amount <= 0) {
      return NextResponse.json(
        { error: 'amount is required and must be a positive number' },
        { status: 400 }
      );
    }

    // TODO: Store settlement record in database.
    const settlementId = `stl_${Date.now()}`;

    return NextResponse.json({
      tripId,
      settlement: {
        id: settlementId,
        tripId,
        fromUser,
        toUser,
        amount,
        currency,
        provider,
        proof,
        note,
        settledAt: new Date().toISOString(),
      },
      created: true,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
