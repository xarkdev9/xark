import { NextRequest, NextResponse } from 'next/server';
import { calculateSplit } from '../../../lib/split-calculator';
import { Expense } from '../../../lib/types';

// TODO: Integrate with database (Supabase Postgres) for expense storage.

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ tripId: string }> }
) {
  try {
    const { tripId } = await params;
    const { searchParams } = new URL(request.url);

    const category = searchParams.get('category');
    const phase = searchParams.get('phase');
    const from = searchParams.get('from');
    const to = searchParams.get('to');

    // TODO: Fetch expenses from database with filters.
    return NextResponse.json({
      tripId,
      expenses: [],
      filters: {
        ...(category && { category }),
        ...(phase && { phase }),
        ...(from && { from }),
        ...(to && { to }),
      },
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ tripId: string }> }
) {
  try {
    const { tripId } = await params;
    const body = await request.json();

    const expense: Expense = {
      id: `exp_${Date.now()}`,
      title: body.title,
      amount: body.amount,
      currency: body.currency ?? 'USD',
      paidBy: body.paidBy,
      splitAmong: body.splitAmong,
      splitMode: body.splitMode ?? 'equal',
      splitDetails: body.splitDetails,
      category: body.category ?? 'uncategorized',
      phase: body.phase,
      date: body.date ?? new Date().toISOString().split('T')[0],
      notes: body.notes,
      receiptUrl: body.receiptUrl,
      tags: body.tags,
      recurring: body.recurring,
    };

    if (!expense.title) {
      return NextResponse.json(
        { error: 'title is required' },
        { status: 400 }
      );
    }

    if (typeof expense.amount !== 'number' || expense.amount <= 0) {
      return NextResponse.json(
        { error: 'amount is required and must be a positive number' },
        { status: 400 }
      );
    }

    if (!expense.paidBy || !Array.isArray(expense.paidBy) || expense.paidBy.length === 0) {
      return NextResponse.json(
        { error: 'paidBy is required and must be a non-empty array' },
        { status: 400 }
      );
    }

    if (!expense.splitAmong || !Array.isArray(expense.splitAmong) || expense.splitAmong.length === 0) {
      return NextResponse.json(
        { error: 'splitAmong is required and must be a non-empty array' },
        { status: 400 }
      );
    }

    // Calculate splits using the split calculator (this is real logic).
    const splits = calculateSplit(expense);

    // TODO: Store expense in database.

    return NextResponse.json({
      tripId,
      expense,
      splits,
      created: true,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
