// XARK OS v2.0 — CLAIM ENGINE
// Manual item claim: lock an item with proof, outside the automated handshake.
// Source of truth: mar10_algo.md Section 7d (Green-Lock Commitment Protocol)
// Two-step BOOKING_FLOW: locked items transition to "claimed" (not terminal).

import { supabase } from "./supabase";
import { resolveTerminalState } from "./state-flows";

// ── Types ──

export interface ClaimProof {
  type: string;
  value: string;
  submittedBy: string;
  submittedAt: string;
}

export interface ClaimResult {
  success: boolean;
  itemId: string;
  lockedAt: string;
  proof: ClaimProof;
  error?: string;
}

// ── claimItem ──
// For items in "locked" state (BOOKING_FLOW): transitions to "claimed", stamps owner.
// No proof required at claim step — proof comes at purchase step.
// For other states: full lock with proof as before.

export async function claimItem(
  itemId: string,
  userId: string,
  proofValue?: string
): Promise<ClaimResult> {
  const now = new Date().toISOString();

  // 1. Fetch current state + version for optimistic concurrency
  const { data: current, error: fetchError } = await supabase
    .from("decision_items")
    .select("id, title, state, is_locked, version")
    .eq("id", itemId)
    .single();

  if (fetchError || !current) {
    return {
      success: false,
      itemId,
      lockedAt: "",
      proof: { type: "", value: "", submittedBy: "", submittedAt: "" },
      error: `Item not found: ${fetchError?.message ?? "no data"}`,
    };
  }

  // 2. BOOKING_FLOW claim: item is in "locked" state (no owner yet)
  if (current.state === "locked" && current.is_locked) {
    const claimedState = resolveTerminalState(current.state); // locked → claimed

    const proof: ClaimProof = {
      type: "verbal",
      value: `claimed by ${userId}`,
      submittedBy: userId,
      submittedAt: now,
    };

    const { error: updateError } = await supabase
      .from("decision_items")
      .update({
        state: claimedState,
        ownership: {
          ownerId: userId,
          assignedAt: now,
          reason: "booker",
        },
        commitment_proof: proof,
        version: (current.version ?? 0) + 1,
      })
      .eq("id", itemId)
      .eq("version", current.version ?? 0);

    if (updateError) {
      return {
        success: false,
        itemId,
        lockedAt: "",
        proof,
        error: `Claim failed (version conflict?): ${updateError.message}`,
      };
    }

    return {
      success: true,
      itemId,
      lockedAt: now,
      proof,
    };
  }

  // 3. Standard claim: guard against already-locked items (not in "locked" waiting state)
  if (current.is_locked) {
    return {
      success: false,
      itemId,
      lockedAt: "",
      proof: { type: "", value: "", submittedBy: "", submittedAt: "" },
      error: "Item is already locked. Cannot claim twice.",
    };
  }

  // 4. Build claim proof for non-BOOKING_FLOW items
  const proofType = proofValue ? "receipt" : "verbal";
  const proof: ClaimProof = {
    type: proofType,
    value: proofValue || `claimed by ${userId}`,
    submittedBy: userId,
    submittedAt: now,
  };

  // 5. Resolve terminal state from current flow
  const lockedState = resolveTerminalState(current.state);

  // 6. Commit with optimistic concurrency
  const { error: updateError } = await supabase
    .from("decision_items")
    .update({
      state: lockedState,
      is_locked: true,
      locked_at: now,
      commitment_proof: proof,
      ownership: {
        ownerId: userId,
        assignedAt: now,
        reason: "booker",
      },
      version: (current.version ?? 0) + 1,
    })
    .eq("id", itemId)
    .eq("version", current.version ?? 0);

  if (updateError) {
    return {
      success: false,
      itemId,
      lockedAt: "",
      proof,
      error: `Claim failed (version conflict?): ${updateError.message}`,
    };
  }

  return {
    success: true,
    itemId,
    lockedAt: now,
    proof,
  };
}
