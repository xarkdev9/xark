import { NextRequest, NextResponse } from 'next/server';
import { simplifyDebts, pairwiseDebts } from '../lib/debt-simplifier';
import { DebtDelta } from '../lib/types';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    const deltas: DebtDelta[] = body.deltas;
    const mode: string = body.mode ?? 'simplify';
    const currency: string = body.currency ?? 'USD';

    if (!deltas || !Array.isArray(deltas)) {
      return NextResponse.json(
        { error: 'deltas is required and must be an array' },
        { status: 400 }
      );
    }

    let result: DebtDelta[];
    if (mode === 'pairwise') {
      result = pairwiseDebts(deltas);
    } else {
      result = simplifyDebts(deltas, currency);
    }

    return NextResponse.json({ deltas: result, mode });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
