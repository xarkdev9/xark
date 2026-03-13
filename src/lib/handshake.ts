// XARK OS v2.0 — HANDSHAKE PROTOCOL
// The bridge between Consensus and Commitment.
// When agreementScore crosses 80% (ignited), @xark proposes a lock.
// On confirmation, the item enters the Green-Lock Commitment Protocol.
// Source of truth: /Users/ramchitturi/algo/mar10_algo.md (Section 7d)

import { supabase } from "./supabase";
import { resolveTerminalState } from "./state-flows";
import type { RealtimeChannel } from "@supabase/supabase-js";

// ── Types ──

export interface HandshakeProposal {
  itemId: string;
  title: string;
  category: string;
  agreementScore: number;
  spaceId: string;
  timestamp: number;
}

export interface CommitmentProof {
  type: string;
  value: string;
  submittedBy: string;
  submittedAt: string;
}

export interface HandshakeResult {
  success: boolean;
  itemId: string;
  lockedAt: string;
  proof: CommitmentProof;
  error?: string;
}

// ── @xark Handshake Message ──
// The whisper that bridges consensus to commitment.

export function generateHandshakeWhisper(proposal: HandshakeProposal): string {
  return `consensus reached on ${proposal.title}. shall i lock this in for the group?`;
}

// ── Consensus Detection via Supabase Realtime ──
// Subscribes to decision_items changes and fires when an item crosses
// the ignited threshold (agreementScore > 0.80, strictly greater than).

export function subscribeToConsensus(
  spaceId: string,
  onHandshake: (proposal: HandshakeProposal) => void
): RealtimeChannel {
  // Track items that have already triggered a handshake to prevent duplicates
  const triggered = new Set<string>();

  const channel = supabase
    .channel(`handshake:${spaceId}`)
    .on(
      "postgres_changes",
      {
        event: "UPDATE",
        schema: "public",
        table: "decision_items",
        filter: `space_id=eq.${spaceId}`,
      },
      (payload) => {
        const item = payload.new as {
          id: string;
          title: string;
          category: string;
          agreement_score: number;
          space_id: string;
          is_locked: boolean;
          state: string;
        };

        // Guard: already locked or already triggered
        if (item.is_locked) return;
        if (triggered.has(item.id)) return;

        // Ignited threshold: strictly > 0.80 per mar10_algo.md
        if (item.agreement_score > 0.8) {
          triggered.add(item.id);

          onHandshake({
            itemId: item.id,
            title: item.title,
            category: item.category,
            agreementScore: item.agreement_score,
            spaceId: item.space_id,
            timestamp: Date.now(),
          });
        }
      }
    )
    .subscribe();

  return channel;
}

// ── Confirm Handshake — Green-Lock Commitment ──
// Locks the item with "verbal" proof type per mar10_algo.md Section 7d.
// On lock: committer stamped as owner { ownerId, assignedAt, reason: "booker" }.

export async function confirmHandshake(
  itemId: string,
  confirmerId: string
): Promise<HandshakeResult> {
  const now = new Date().toISOString();

  // 1. Fetch current item state + version for optimistic concurrency
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

  // 2. Guard: cannot lock already-locked item (GreenLockError)
  if (current.is_locked) {
    return {
      success: false,
      itemId,
      lockedAt: "",
      proof: { type: "", value: "", submittedBy: "", submittedAt: "" },
      error: "Item is already locked. Cannot lock twice.",
    };
  }

  // 3. Build commitment proof
  const proof: CommitmentProof = {
    type: "verbal",
    value: "group consensus confirmed via @xark handshake",
    submittedBy: confirmerId,
    submittedAt: now,
  };

  // 4. Resolve the terminal state based on current flow
  const lockedState = resolveTerminalState(current.state);

  // 5. Commit — optimistic concurrency via version check
  const { error: updateError } = await supabase
    .from("decision_items")
    .update({
      state: lockedState,
      is_locked: true,
      locked_at: now,
      commitment_proof: proof,
      ownership: {
        ownerId: confirmerId,
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
      error: `Commit failed (version conflict?): ${updateError.message}`,
    };
  }

  return {
    success: true,
    itemId,
    lockedAt: now,
    proof,
  };
}

// ── Unsubscribe ──

export function unsubscribeFromConsensus(channel: RealtimeChannel): void {
  supabase.removeChannel(channel);
}
