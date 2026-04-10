import { NextRequest, NextResponse } from 'next/server';
import { calculateSplit } from '../lib/split-calculator';
import { Expense, Payer, SplitMode } from '../lib/types';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    const amount: number = body.amount;
    const currency: string = body.currency ?? 'USD';
    const paidBy: Payer[] = body.paidBy;
    const splitAmong: string[] = body.splitAmong;
    const mode: SplitMode = body.mode ?? 'equal';
    const details: Record<string, number> | undefined = body.details;

    if (typeof amount !== 'number' || amount <= 0) {
      return NextResponse.json(
        { error: 'amount is required and must be a positive number' },
        { status: 400 }
      );
    }

    if (!paidBy || !Array.isArray(paidBy) || paidBy.length === 0) {
      return NextResponse.json(
        { error: 'paidBy is required and must be a non-empty array' },
        { status: 400 }
      );
    }

    if (!splitAmong || !Array.isArray(splitAmong) || splitAmong.length === 0) {
      return NextResponse.json(
        { error: 'splitAmong is required and must be a non-empty array' },
        { status: 400 }
      );
    }

    const expense: Expense = {
      title: 'split-calculation',
      amount,
      currency,
      paidBy,
      splitAmong,
      splitMode: mode,
      splitDetails: details,
    };

    const splits = calculateSplit(expense);

    return NextResponse.json({ splits, mode, currency });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
