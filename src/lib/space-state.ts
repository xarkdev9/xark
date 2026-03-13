// XARK OS v2.0 — Emergent Space State
export type SpaceState = "empty" | "exploring" | "converging" | "ready" | "active" | "settled";

export interface SpaceStateItem {
  state: string;
  is_locked: boolean;
  metadata?: { date?: string; check_in?: string; check_out?: string };
}

export function computeSpaceState(items: SpaceStateItem[]): SpaceState {
  if (items.length === 0) return "empty";
  const locked = items.filter((i) => i.is_locked || ["purchased","chosen","decided","locked","claimed"].includes(i.state));
  const allSettled = items.every((i) => ["purchased","chosen","decided"].includes(i.state));
  if (allSettled && items.length > 0) return "settled";
  if (locked.length > 0 && locked.length < items.length) return "converging";
  if (locked.length === items.length) return "ready";
  return "exploring";
}
