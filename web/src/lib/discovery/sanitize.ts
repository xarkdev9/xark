const FORBIDDEN_KEY_PATTERNS = [
  'key',
  'token',
  'secret',
  'password',
  'plaintext',
  'taste',
  'message_content',
];

const MAX_STRING_LENGTH = 200;

/**
 * Privacy sanitization for feedback context.
 * Removes keys containing sensitive patterns, truncates long strings.
 * Deep clones to avoid mutation.
 */
export function sanitizeContext(
  context: Record<string, unknown>,
): Record<string, unknown> {
  return sanitizeValue(structuredClone(context)) as Record<string, unknown>;
}

function isForbiddenKey(key: string): boolean {
  const lower = key.toLowerCase();
  return FORBIDDEN_KEY_PATTERNS.some((pattern) => lower.includes(pattern));
}

function sanitizeValue(value: unknown): unknown {
  if (value === null || value === undefined) return value;

  if (typeof value === 'string') {
    return value.length > MAX_STRING_LENGTH
      ? value.slice(0, MAX_STRING_LENGTH) + '...[truncated]'
      : value;
  }

  if (Array.isArray(value)) {
    return value.map(sanitizeValue);
  }

  if (typeof value === 'object') {
    const sanitized: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (isForbiddenKey(k)) continue;
      sanitized[k] = sanitizeValue(v);
    }
    return sanitized;
  }

  return value;
}
