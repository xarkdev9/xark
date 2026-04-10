import { NextRequest, NextResponse } from 'next/server';
import { generatePaymentLink } from '../lib/payment-links';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    const provider: string = body.provider;
    const from: string = body.from;
    const to: string = body.to;
    const amount: number = body.amount;
    const currency: string = body.currency ?? 'USD';
    const note: string | undefined = body.note;

    if (!provider) {
      return NextResponse.json(
        { error: 'provider is required' },
        { status: 400 }
      );
    }

    if (!from || !to) {
      return NextResponse.json(
        { error: 'from and to are required' },
        { status: 400 }
      );
    }

    if (typeof amount !== 'number' || amount <= 0) {
      return NextResponse.json(
        { error: 'amount is required and must be a positive number' },
        { status: 400 }
      );
    }

    const result = await generatePaymentLink(provider, {
      from,
      to,
      amount,
      currency,
      note,
    });

    return NextResponse.json(result);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
