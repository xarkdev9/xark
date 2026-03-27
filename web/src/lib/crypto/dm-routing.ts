// XARK OS v2.0 — Deterministic 1:1 Routing
// Both peers compute the identical space ID without network calls.
// Used for sanctuary (1:1) message routing.

const DM_PREFIX = 'dm_';

/**
 * Generate deterministic space ID for 1:1 chat between two users.
 * Both users compute the same ID regardless of who initiates.
 *
 * @example getDMSpaceId('name_ram', 'name_kai') === getDMSpaceId('name_kai', 'name_ram')
 * // Both return 'dm_name_kai_name_ram'
 */
export function getDMSpaceId(myId: string, peerId: string): string {
  if (!myId || !peerId) throw new Error('DM routing: both user IDs required');
  if (myId === peerId) throw new Error('DM routing: cannot create DM with self');
  const sorted = [myId, peerId].sort();
  return `${DM_PREFIX}${sorted[0]}_${sorted[1]}`;
}

/**
 * Check if a space ID represents a 1:1 DM (sanctuary) space.
 */
export function isDMSpace(spaceId: string): boolean {
  return spaceId.startsWith(DM_PREFIX);
}

/**
 * Extract the two participant user IDs from a DM space ID.
 * Returns null if not a valid DM space ID.
 */
export function parseDMSpaceId(spaceId: string): { userA: string; userB: string } | null {
  if (!isDMSpace(spaceId)) return null;
  const rest = spaceId.slice(DM_PREFIX.length);
  // Find the split point — user IDs contain underscores, so we need to be smart
  // DM IDs are always sorted, so we look for the pattern
  const parts = rest.split('_');
  if (parts.length < 4) return null; // minimum: prefix_type_name1_prefix_type_name2
  // Reconstruct: since user IDs are "type_name" format, find the midpoint
  // Try all possible split points
  for (let i = 1; i < parts.length; i++) {
    const userA = parts.slice(0, i).join('_');
    const userB = parts.slice(i).join('_');
    if (userA && userB && [userA, userB].sort()[0] === userA) {
      return { userA, userB };
    }
  }
  return null;
}
