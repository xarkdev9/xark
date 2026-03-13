// XARK OS v2.0 — Emergent Space State
// Pure function. No DB calls. UI reacts to computed state.

export type SpaceState =
  | "empty"
  | "exploring"
  | "converging"
  | "ready"
  | "active"
  | "settled";

interface SpaceItem {
  state: string;
  is_locked?: boolean;
  weighted_score?: number;
  agreement_score?: number;
}

export function computeSpaceState(items: SpaceItem[]): SpaceState {
  if (items.length === 0) return "empty";

  const locked = items.filter((i) => i.is_locked);
  const unlocked = items.filter((i) => !i.is_locked);

  // All items settled
  if (locked.length === items.length) return "settled";

  // Some locked, some active
  if (locked.length > 0 && unlocked.length > 0) return "active";

  // All items locked (purchased/decided)
  if (locked.length > 0) return "ready";

  // Check for convergence (any item with agreement > 0.5)
  const converging = unlocked.some(
    (i) => (i.agreement_score ?? 0) > 0.5
  );
  if (converging) return "converging";

  return "exploring";
}
