import { NextRequest, NextResponse } from 'next/server';
import { sanitizeContext } from '@/lib/discovery/sanitize';
import type { ErrorReportPayload } from '@/lib/discovery/types';
import { randomBytes } from 'crypto';

export async function POST(request: NextRequest) {
  try {
    const body = (await request.json()) as ErrorReportPayload;

    // Validate required fields
    if (!body.type || !['error', 'bug', 'suggestion'].includes(body.type)) {
      return NextResponse.json(
        { error: 'type must be one of: error, bug, suggestion' },
        { status: 400 },
      );
    }

    if (!body.context?.screen || !body.context?.action) {
      return NextResponse.json(
        { error: 'context.screen and context.action are required' },
        { status: 400 },
      );
    }

    if (!body.context?.deviceInfo?.os || !body.context?.deviceInfo?.appVersion) {
      return NextResponse.json(
        { error: 'context.deviceInfo.os and context.deviceInfo.appVersion are required' },
        { status: 400 },
      );
    }

    // Sanitize context to strip sensitive data
    const sanitizedContext = sanitizeContext(
      body.context as unknown as Record<string, unknown>,
    );

    // Generate a report ID (in production, this would be a DB insert)
    const reportId = `fb-${randomBytes(12).toString('hex')}`;

    // TODO: persist to Supabase feedback table
    // For now, log and return mock confirmation
    console.log('[discovery/feedback]', {
      reportId,
      type: body.type,
      errorType: body.errorType,
      context: sanitizedContext,
    });

    return NextResponse.json({
      reportId,
      status: 'received',
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 400 });
  }
}
