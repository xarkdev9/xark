import { NextResponse } from 'next/server';
import { registry } from '@/lib/discovery/registry-instance';

export async function GET() {
  try {
    const report = await registry.healthReport();

    // Determine overall status
    const statuses = Object.values(report).map((r) => r.status);
    const overall = statuses.every((s) => s === 'ok')
      ? 'healthy'
      : statuses.some((s) => s === 'down')
        ? 'degraded'
        : 'partial';

    return NextResponse.json({
      overall,
      providers: report,
      checkedAt: new Date().toISOString(),
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : 'Unknown error';
    return NextResponse.json({ error: message }, { status: 500 });
  }
}
