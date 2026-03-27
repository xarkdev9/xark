// XARK OS v2.0 — HANDSHAKE HOOK
// React hook that listens to the group's heartbeat via Supabase Realtime.
// Silent until agreementScore crosses 80% (ignited) — then triggers a Handshake Proposal.
// Uses the full Green-Lock Commitment Protocol from handshake.ts.

import { useEffect, useState, useCallback, useRef } from "react";
import {
  subscribeToConsensus,
  confirmHandshake as executeHandshake,
  generateHandshakeWhisper,
  unsubscribeFromConsensus,
} from "@/lib/handshake";
import type { HandshakeProposal, HandshakeResult } from "@/lib/handshake";

export interface UseHandshakeReturn {
  /** Active handshake proposal — null when silent */
  proposal: HandshakeProposal | null;
  /** @xark whisper message for the active proposal */
  whisper: string | null;
  /** Post-lock whisper — changes based on flow type */
  postLockWhisper: string | null;
  /** Confirm the handshake — executes Green-Lock Commitment Protocol */
  confirm: (confirmerId: string) => Promise<HandshakeResult | null>;
  /** Dismiss the proposal — group chose to wait */
  dismiss: () => void;
  /** True during the commit operation */
  isCommitting: boolean;
  /** True when Social Gold burst should fire */
  goldBurst: boolean;
}

export function useHandshake(spaceId: string): UseHandshakeReturn {
  const [proposal, setProposal] = useState<HandshakeProposal | null>(null);
  const [isCommitting, setIsCommitting] = useState(false);
  const [goldBurst, setGoldBurst] = useState(false);
  const [postLockWhisper, setPostLockWhisper] = useState<string | null>(null);
  const goldTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // ── Subscribe to consensus detection on mount ──
  useEffect(() => {
    const channel = subscribeToConsensus(spaceId, (incoming) => {
      setProposal(incoming);
    });

    return () => {
      unsubscribeFromConsensus(channel);
    };
  }, [spaceId]);

  // ── Cleanup gold burst timer ──
  useEffect(() => {
    return () => {
      if (goldTimerRef.current) clearTimeout(goldTimerRef.current);
    };
  }, []);

  // ── Confirm: execute Green-Lock via handshake.ts ──
  const confirm = useCallback(
    async (confirmerId: string): Promise<HandshakeResult | null> => {
      if (!proposal) return null;
      setIsCommitting(true);

      const result = await executeHandshake(proposal.itemId, confirmerId);

      setIsCommitting(false);

      if (result.success) {
        // Clear proposal
        setProposal(null);

        // Post-lock whisper: BOOKING_FLOW items have no owner yet
        setPostLockWhisper("locked. waiting for someone to own it.");

        // Trigger Social Gold burst — 3s visual reward
        setGoldBurst(true);
        goldTimerRef.current = setTimeout(() => setGoldBurst(false), 3000);
      }

      return result;
    },
    [proposal]
  );

  // ── Dismiss: group chose to wait ──
  const dismiss = useCallback(() => {
    setProposal(null);
  }, []);

  // ── Generate whisper from active proposal ──
  const whisper = proposal ? generateHandshakeWhisper(proposal) : null;

  return { proposal, whisper, postLockWhisper, confirm, dismiss, isCommitting, goldBurst };
}
