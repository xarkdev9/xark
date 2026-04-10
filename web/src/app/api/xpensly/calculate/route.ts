import { NextRequest, NextResponse } from 'next/server';
import { computeSettlement } from '../lib/settlement-engine';
import { Member, Expense, Refund, SettlementRecord } from '../lib/types';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    const members: Member[] = body.members;
    const expenses: Expense[] = body.expenses;
    const refunds: Refund[] = body.refunds ?? [];
    const priorSettlements: SettlementRecord[] = body.priorSettlements ?? [];
    const baseCurrency: string = body.baseCurrency ?? 'USD';
    const exchangeRates: Record<string, number> = body.exchangeRates ?? {};

    if (!members || !Array.isArray(members) || members.length === 0) {
      return NextResponse.json(
        { error: 'members is required and must be a non-empty array' },
        { status: 400 }
      );
    }

    if (!expenses || !Array.isArray(expenses) || expenses.length === 0) {
      return NextResponse.json(
        { error: 'expenses is required and must be a non-empty array' },
        { status: 400 }
      );
    }

    // Default splitMode to 'equal' for any expense missing it.
    const normalizedExpenses = expenses.map((e) => ({
      ...e,
      splitMode: e.splitMode ?? 'equal',
      category: e.category ?? 'uncategorized',
    })) as Expense[];

    const settlement = computeSettlement({
      members,
      expenses: normalizedExpenses,
      refunds,
      priorSettlements,
      baseCurrency,
      exchangeRates,
    });

    return NextResponse.json(settlement);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
