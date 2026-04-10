import { NextRequest, NextResponse } from 'next/server';

// TODO: Integrate with database (Supabase Postgres) for expense CRUD.

export async function PATCH(
  request: NextRequest,
  { params }: { params: Promise<{ tripId: string; expenseId: string }> }
) {
  try {
    const { tripId, expenseId } = await params;
    const body = await request.json();

    // TODO: Update expense in database and recalculate splits.
    return NextResponse.json({
      tripId,
      expenseId,
      updated: true,
      changes: body,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}

export async function DELETE(
  _request: NextRequest,
  { params }: { params: Promise<{ tripId: string; expenseId: string }> }
) {
  try {
    const { tripId, expenseId } = await params;

    // TODO: Delete expense from database.
    return NextResponse.json({
      tripId,
      expenseId,
      deleted: true,
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
