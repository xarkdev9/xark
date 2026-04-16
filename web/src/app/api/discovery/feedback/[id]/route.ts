import { NextRequest, NextResponse } from 'next/server';
import type { FeedbackRecord } from '@/lib/discovery/types';

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ id: string }> },
) {
  try {
    const { id } = await params;

    if (!id || id.trim().length === 0) {
      return NextResponse.json(
        { error: 'Feedback ID is required' },
        { status: 400 },
      );
    }

    // TODO: fetch from Supabase feedback table
    // For now, return a mock record
    const record: FeedbackRecord = {
      id,
      userId: 'anonymous',
      type: 'bug',
      errorType: 'ui_rendering',
      errorMessage: 'Mock feedback record',
      userDescription: 'This is a placeholder feedback entry.',
      context: {
        screen: 'discovery_feed',
        action: 'scroll',
        timestamp: new Date().toISOString(),
      },
      status: 'received',
      createdAt: new Date().toISOString(),
    };

    return NextResponse.json(record);
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
