// XARK OS v2.0 — CLAIM ENGINE
// Manual item claim: lock an item with proof, outside the automated handshake.
// Source of truth: mar10_algo.md Section 7d (Green-Lock Commitment Protocol)

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
// Locks an item and assigns ownership to the claiming user.
// proof: "Link to confirmation or drop receipt." — free-form text.
// If no proof is provided, defaults to verbal confirmation.

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

  // 2. Guard: cannot claim already-locked item
  if (current.is_locked) {
    return {
      success: false,
      itemId,
      lockedAt: "",
      proof: { type: "", value: "", submittedBy: "", submittedAt: "" },
      error: "Item is already locked. Cannot claim twice.",
    };
  }

  // 3. Build claim proof
  const proofType = proofValue ? "receipt" : "verbal";
  const proof: ClaimProof = {
    type: proofType,
    value: proofValue || `claimed by ${userId}`,
    submittedBy: userId,
    submittedAt: now,
  };

  // 4. Resolve terminal state from current flow
  const lockedState = resolveTerminalState(current.state);

  // 5. Commit with optimistic concurrency
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
