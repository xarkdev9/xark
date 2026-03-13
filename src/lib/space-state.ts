// XARK OS v2.0 — Emergent Space State
// Pure function. No DB calls. Computed from items array.

export type SpaceState =
  | "empty"
  | "exploring"
  | "converging"
  | "ready"
  | "active"
  | "settled";

export interface SpaceStateItem {
  state: string;
  is_locked: boolean;
  category?: string;
  metadata?: {
    date?: string;
    check_in?: string;
    check_out?: string;
    price?: string;
  };
}

export function computeSpaceState(
  items: SpaceStateItem[],
  tripDates?: { start_date: string; end_date: string }
): SpaceState {
  if (items.length === 0) return "empty";

  const hasLocked = items.some(
    (i) => i.state === "locked" || i.state === "claimed" || i.state === "purchased"
  );
  const allSettled = items.every(
    (i) => i.state === "purchased" || i.state === "chosen" || i.state === "decided"
  );
  const hasOpenItems = items.some(
    (i) => !i.is_locked && i.state !== "purchased" && i.state !== "chosen" && i.state !== "decided"
  );

  // Check if trip dates have passed (settled)
  if (allSettled) {
    const now = new Date();
    const hasPastDates = items.some((i) => {
      const dateStr = i.metadata?.check_out || i.metadata?.date;
      if (!dateStr) return false;
      return new Date(dateStr) < now;
    });
    // Fallback to tripDates only when NO items have their own dates
    const itemsHaveDates = items.some(
      (i) => i.metadata?.check_out || i.metadata?.date
    );
    const tripPast = !itemsHaveDates && tripDates?.end_date
      ? new Date(tripDates.end_date) < now
      : false;
    if (hasPastDates || tripPast) return "settled";
  }

  // Check if in active trip (dates within range)
  const now = new Date();
  const hasActiveDates = items.some((i) => {
    const checkIn = i.metadata?.check_in || i.metadata?.date;
    const checkOut = i.metadata?.check_out || i.metadata?.date;
    if (!checkIn) return false;
    return new Date(checkIn) <= now && (!checkOut || new Date(checkOut) >= now);
  });
  // Fallback to tripDates only when NO items have their own dates
  const itemsHaveCheckIn = items.some(
    (i) => i.metadata?.check_in || i.metadata?.date
  );
  const tripActive = !itemsHaveCheckIn && tripDates
    ? new Date(tripDates.start_date) <= now && new Date(tripDates.end_date) >= now
    : false;
  if ((hasActiveDates || tripActive) && hasLocked) return "active";

  // v1 heuristic: ready when all items are settled. Full category coverage check is Gemini's job (blueprint Section 2 note).
  if (hasLocked && !hasOpenItems) return "ready";

  // Mixed: some locked, some still voting
  if (hasLocked && hasOpenItems) return "converging";

  // All items are proposed/voting, nothing locked
  return "exploring";
}
