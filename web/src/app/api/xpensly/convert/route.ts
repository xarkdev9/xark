import { NextRequest, NextResponse } from 'next/server';
import { convert } from '../lib/currency-converter';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    const amount: number = body.amount;
    const from: string = body.from;
    const to: string = body.to;
    const rate: number | undefined = body.rate;

    if (typeof amount !== 'number') {
      return NextResponse.json(
        { error: 'amount is required and must be a number' },
        { status: 400 }
      );
    }

    if (!from || !to) {
      return NextResponse.json(
        { error: 'from and to currency codes are required' },
        { status: 400 }
      );
    }

    // If a direct rate is provided, use it as a simple multiplier.
    // Otherwise, require a rates map in the body.
    if (rate !== undefined) {
      const converted = Math.round(amount * rate * 100) / 100;
      return NextResponse.json({
        converted,
        rate,
        from,
        to,
        source: 'provided',
      });
    }

    const rates: Record<string, number> | undefined = body.rates;
    if (!rates || typeof rates !== 'object') {
      return NextResponse.json(
        { error: 'Either rate (direct multiplier) or rates (rate map) must be provided' },
        { status: 400 }
      );
    }

    const converted = convert(amount, from, to, rates);
    return NextResponse.json({
      converted,
      rate: rates[to] / rates[from],
      from,
      to,
      source: 'rates-map',
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
