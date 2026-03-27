// XARK OS v2.0 — Shared state flow definitions
// Single source of truth for flow terminal states.
// Imported by handshake.ts, claims.ts, and future commitment modules.

export const FLOW_TERMINAL_STATES: Record<string, string> = {
  // BOOKING_FLOW (extended)
  proposed: "locked",
  // NOTE: "ranked" is intentionally omitted — it appears in both BOOKING_FLOW (→ locked)
  // and SIMPLE_VOTE_FLOW (→ chosen). Use resolveTerminalState(state, flow) to disambiguate.
  locked: "claimed",    // locked is intermediate in BOOKING_FLOW
  claimed: "purchased", // claimed is intermediate
  // PURCHASE_FLOW
  researching: "purchased",
  shortlisted: "purchased",
  negotiating: "purchased",
  // SIMPLE_VOTE_FLOW
  nominated: "chosen",
  // SOLO_DECISION_FLOW
  considering: "decided",
  leaning: "decided",
};

export function resolveTerminalState(currentState: string, flow?: string): string {
  if (currentState === "ranked") {
    return flow === "SIMPLE_VOTE_FLOW" ? "chosen" : "locked";
  }
  return FLOW_TERMINAL_STATES[currentState] ?? "locked";
}

export function isTerminalState(state: string): boolean {
  const terminals = new Set(["purchased", "chosen", "decided"]);
  return terminals.has(state);
}
