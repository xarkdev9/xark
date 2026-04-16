import { NextRequest, NextResponse } from 'next/server';

// TODO: Integrate with database (Supabase Postgres) for refund storage.

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ tripId: string }> }
) {
  try {
    const { tripId } = await params;
    const body = await request.json();

    const refundId = `ref_${Date.now()}`;
    const amount: number = body.amount;
    const currency: string = body.currency ?? 'USD';
    const refundedTo: string = body.refundedTo;
    const reason: string = body.reason ?? '';
    const originalExpenseId: string | undefined = body.originalExpenseId;

    if (typeof amount !== 'number' || amount <= 0) {
      return NextResponse.json(
        { error: 'amount is required and must be a positive number' },
        { status: 400 }
      );
    }

    if (!refundedTo) {
      return NextResponse.json(
        { error: 'refundedTo is required' },
        { status: 400 }
      );
    }

    // TODO: Store refund in database.

    return NextResponse.json({
      tripId,
      refund: {
        id: refundId,
        originalExpenseId,
        amount,
        currency,
        refundedTo,
        reason,
        date: new Date().toISOString().split('T')[0],
      },
      created: true,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
