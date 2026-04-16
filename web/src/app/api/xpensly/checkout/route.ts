import { NextRequest, NextResponse } from 'next/server';
import { generatePaymentLink } from '../lib/payment-links';

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url);
    const provider = searchParams.get('provider') || 'stripe';
    const from = searchParams.get('from');
    const to = searchParams.get('to');
    const amountStr = searchParams.get('amount');
    const currency = searchParams.get('currency') || 'USD';
    const note = searchParams.get('note') || undefined;

    if (!from || !to || !amountStr) {
      return NextResponse.json(
        { error: 'from, to, and amount query parameters are required' },
        { status: 400 }
      );
    }

    const amount = parseFloat(amountStr);
    if (isNaN(amount) || amount <= 0) {
      return NextResponse.json(
        { error: 'amount must be a positive number' },
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

    if (result.url) {
      return NextResponse.redirect(result.url, 302);
    }

    return NextResponse.json({ error: 'No URL generated' }, { status: 400 });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
