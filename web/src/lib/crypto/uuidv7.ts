// hello OS v2.0 — UUIDv7 Generator
// Client-generated, millisecond-precision, monotonically sortable UUIDs.
// Clock delta from ClockSync compensates for device clock skew.
// Used as idempotency key for send_e2ee_message RPC.

let clockDeltaMs = 0;

export function setClockDelta(delta: number): void {
  clockDeltaMs = delta;
}

export function generateUUIDv7(): string {
  const now = Date.now() + clockDeltaMs;
  const timestamp = now.toString(16).padStart(12, '0');
  const random = new Uint8Array(10);
  crypto.getRandomValues(random);
  const hex = Array.from(random, (b) => b.toString(16).padStart(2, '0')).join('');

  return [
    timestamp.slice(0, 8),
    timestamp.slice(8, 12),
    '7' + hex.slice(0, 3),
    ((parseInt(hex.slice(3, 4), 16) & 0x3) | 0x8).toString(16) + hex.slice(4, 7),
    hex.slice(7, 19),
  ].join('-');
}
