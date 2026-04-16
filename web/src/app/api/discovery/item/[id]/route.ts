import { NextRequest, NextResponse } from 'next/server';
import { registry } from '@/lib/discovery/registry-instance';

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { id } = await params;

    if (!id || id.trim().length === 0) {
      return NextResponse.json(
        { error: 'Item ID is required' },
        { status: 400 },
      );
    }

    const detail = await registry.getDetail(id);

    if (!detail) {
      return NextResponse.json(
        { error: 'Item not found' },
        { status: 404 },
      );
    }

    return NextResponse.json(detail);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
