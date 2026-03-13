// XARK OS v2.0 — HANDSHAKE PROTOCOL
// Two-step commitment for BOOKING_FLOW:
//   Step 1 (this): consensus lock — sets is_locked=true, state="locked", NO owner.
//   Step 2 (ClaimSheet): someone claims it — stamps owner.

import { supabase } from "./supabase";
import { resolveTerminalState } from "./state-flows";
import type { RealtimeChannel } from "@supabase/supabase-js";

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

export function generateHandshakeWhisper(proposal: HandshakeProposal): string {
  return `consensus reached on ${proposal.title}. shall i lock this in for the group?`;
}

export function subscribeToConsensus(
  spaceId: string,
  onHandshake: (proposal: HandshakeProposal) => void
): RealtimeChannel {
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

        if (item.is_locked) return;
        if (triggered.has(item.id)) return;

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

const BOOKING_FLOW_LOCKED_STATES = new Set(["proposed", "ranked"]);

export async function confirmHandshake(
  itemId: string,
  confirmerId: string
): Promise<HandshakeResult> {
  const now = new Date().toISOString();

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

  if (current.is_locked) {
    return {
      success: false,
      itemId,
      lockedAt: "",
      proof: { type: "", value: "", submittedBy: "", submittedAt: "" },
      error: "Item is already locked. Cannot lock twice.",
    };
  }

  const proof: CommitmentProof = {
    type: "verbal",
    value: "group consensus confirmed via @xark handshake",
    submittedBy: confirmerId,
    submittedAt: now,
  };

  const lockedState = resolveTerminalState(current.state);
  const isBookingFlow = BOOKING_FLOW_LOCKED_STATES.has(current.state) && lockedState === "locked";

  const updatePayload: Record<string, unknown> = {
    state: lockedState,
    is_locked: true,
    locked_at: now,
    commitment_proof: proof,
    version: (current.version ?? 0) + 1,
  };

  if (!isBookingFlow) {
    updatePayload.ownership = {
      ownerId: confirmerId,
      assignedAt: now,
      reason: "booker",
    };
  }

  const { error: updateError } = await supabase
    .from("decision_items")
    .update(updatePayload)
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

export function unsubscribeFromConsensus(channel: RealtimeChannel): void {
  supabase.removeChannel(channel);
}
