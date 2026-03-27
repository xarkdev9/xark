/// Client-side E2EE observability via Sentry (or equivalent).
/// Server HTTP 200s are blind to E2EE failures — only the client
/// knows when decryption fails, ratchets desync, or keys are missing.

export interface E2EEMetric {
  event: string;
  groupId?: string;
  sessionId?: string;
  error?: string;
  duration?: number;
  metadata?: Record<string, any>;
}

const metrics: E2EEMetric[] = [];
const MAX_BUFFER = 100;

/**
 * Track an E2EE event for observability.
 * Events are buffered and flushed periodically.
 */
export function trackE2EEEvent(metric: E2EEMetric): void {
  metrics.push({ ...metric, timestamp: Date.now() } as any);
  if (metrics.length > MAX_BUFFER) metrics.shift();

  // Critical events get reported immediately
  if (metric.event === 'decryption_failed' ||
      metric.event === 'ratchet_desync' ||
      metric.event === 'session_not_found') {
    reportCritical(metric);
  }
}

function reportCritical(metric: E2EEMetric): void {
  // Sentry integration point
  // NEVER include plaintext, keys, or user content
  console.error('[E2EE]', metric.event, {
    groupId: metric.groupId,
    sessionId: metric.sessionId,
    error: metric.error,
  });

  // TODO: Sentry.captureEvent({
  //   message: `E2EE: ${metric.event}`,
  //   level: 'error',
  //   tags: { component: 'e2ee' },
  //   extra: { groupId: metric.groupId, sessionId: metric.sessionId },
  // });
}

/**
 * Track encryption timing.
 */
export function trackEncryptTime(groupId: string, durationMs: number): void {
  trackE2EEEvent({ event: 'encrypt_complete', groupId, duration: durationMs });
}

/**
 * Track decryption timing.
 */
export function trackDecryptTime(groupId: string, durationMs: number): void {
  trackE2EEEvent({ event: 'decrypt_complete', groupId, duration: durationMs });
}

/**
 * Track decryption failure.
 */
export function trackDecryptFailure(groupId: string, sessionId: string, error: string): void {
  trackE2EEEvent({ event: 'decryption_failed', groupId, sessionId, error });
}

/**
 * Get recent E2EE metrics for debugging.
 */
export function getRecentMetrics(): E2EEMetric[] {
  return [...metrics];
}
