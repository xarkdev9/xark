"use client";

// XARK OS v2.0 — Playground Choreography Engine
// Timer-based sequencing for diegetic whispers, queued messages, typing indicators.
// Each space has its own choreography timeline triggered on mount + user interactions.
// All timers cleaned up on unmount.

import { useState, useEffect, useRef, useCallback } from "react";
import { PLAYGROUND_SPACE_IDS, PLAYGROUND_FRIENDS } from "@/lib/playground";
import type { PlaygroundMessage } from "@/lib/playground";

interface WhisperState {
  text: string;
  visible: boolean;
}

interface ChoreographyState {
  whispers: Record<string, WhisperState>;
  queuedMessages: PlaygroundMessage[];
  typingIndicator: { name: string; visible: boolean } | null;
  tabBadge: { tab: string; text: string } | null;
  placeholderOverride: string | null;
}

interface ChoreographyActions {
  dismissWhisper: (key: string) => void;
  triggerPostVote: () => void;
  triggerPostXark: () => void;
  triggerPostClaim: () => void;
  triggerPostPurchase: () => void;
}

function ago(minutes: number): number {
  return Date.now() - minutes * 60 * 1000;
}

export function usePlaygroundChoreography(
  spaceId: string,
  isPlayground: boolean
): ChoreographyState & ChoreographyActions {
  const [whispers, setWhispers] = useState<Record<string, WhisperState>>({});
  const [queuedMessages, setQueuedMessages] = useState<PlaygroundMessage[]>([]);
  const [typingIndicator, setTypingIndicator] = useState<{ name: string; visible: boolean } | null>(null);
  const [tabBadge, setTabBadge] = useState<{ tab: string; text: string } | null>(null);
  const [placeholderOverride, setPlaceholderOverride] = useState<string | null>(null);
  const timers = useRef<ReturnType<typeof setTimeout>[]>([]);

  const schedule = useCallback((fn: () => void, ms: number) => {
    const t = setTimeout(fn, ms);
    timers.current.push(t);
    return t;
  }, []);

  // Cleanup all timers on unmount
  useEffect(() => {
    return () => {
      timers.current.forEach(clearTimeout);
      timers.current = [];
    };
  }, []);

  // ── Mount choreography — initial whispers per space ──
  useEffect(() => {
    if (!isPlayground) return;

    // Space 1: tokyo — "waiting on your vote..."
    if (spaceId === PLAYGROUND_SPACE_IDS.tokyo) {
      schedule(() => {
        setWhispers((w) => ({ ...w, vote: { text: "waiting on your vote...", visible: true } }));
      }, 1500);
    }

    // Space 2: dinner — "try @xark for ideas..."
    if (spaceId === PLAYGROUND_SPACE_IDS.dinner) {
      schedule(() => {
        setWhispers((w) => ({ ...w, xark_hint: { text: "try @xark for ideas...", visible: true } }));
      }, 2000);
    }

    // Space 3: maya — "tap to claim this task"
    if (spaceId === PLAYGROUND_SPACE_IDS.maya) {
      schedule(() => {
        setWhispers((w) => ({ ...w, claim: { text: "tap to claim this task", visible: true } }));
      }, 1500);
    }

    // Space 4: hike — "your adventures, always here"
    if (spaceId === PLAYGROUND_SPACE_IDS.hike) {
      schedule(() => {
        setWhispers((w) => ({ ...w, memories: { text: "your adventures, always here", visible: true } }));
      }, 1500);
    }
  }, [spaceId, isPlayground, schedule]);

  const dismissWhisper = useCallback((key: string) => {
    setWhispers((w) => {
      if (!w[key]) return w;
      return { ...w, [key]: { ...w[key], visible: false } };
    });
  }, []);

  // ── Space 1: Post-vote choreography ──
  const triggerPostVote = useCallback(() => {
    if (spaceId !== PLAYGROUND_SPACE_IDS.tokyo) return;

    // Dismiss the vote whisper
    dismissWhisper("vote");

    // +3s: @xark system message
    schedule(() => {
      setQueuedMessages((prev) => [
        ...prev,
        {
          id: "pg_choreo_xark_lock",
          role: "xark",
          content: "everyone agreed. park hyatt is locked.",
          timestamp: Date.now(),
          senderName: "@xark",
        },
      ]);
    }, 3000);

    // +5s: tab badge if on decide
    schedule(() => {
      setTabBadge({ tab: "discuss", text: "new message from kai" });
    }, 5000);

    // +5s: typing indicator
    schedule(() => {
      setTypingIndicator({ name: "kai", visible: true });
    }, 5000);

    // +6.5s: kai message, clear typing
    schedule(() => {
      setTypingIndicator(null);
      setQueuedMessages((prev) => [
        ...prev,
        {
          id: "pg_choreo_kai_dinner",
          role: "user",
          content: "what about dinner?",
          timestamp: Date.now(),
          senderName: "kai",
        },
      ]);
    }, 6500);

    // +7s: morph placeholder
    schedule(() => {
      setPlaceholderOverride("suggest a place, or ask @xark...");
    }, 7000);
  }, [spaceId, dismissWhisper, schedule]);

  // ── Space 1 & 2: Post-@xark choreography ──
  const triggerPostXark = useCallback(() => {
    dismissWhisper("xark_hint");

    // Show "swipe to decide to vote" whisper
    schedule(() => {
      setWhispers((w) => ({
        ...w,
        decide_hint: { text: "swipe to decide to vote", visible: true },
      }));
    }, 500);
  }, [dismissWhisper, schedule]);

  // ── Space 3: Post-claim choreography ──
  const triggerPostClaim = useCallback(() => {
    dismissWhisper("claim");

    schedule(() => {
      setWhispers((w) => ({
        ...w,
        purchase: { text: "tap to add your share", visible: true },
      }));
    }, 500);
  }, [dismissWhisper, schedule]);

  // ── Space 3: Post-purchase choreography ──
  const triggerPostPurchase = useCallback(() => {
    dismissWhisper("purchase");

    schedule(() => {
      setWhispers((w) => ({
        ...w,
        settlement: { text: "you owe leo $40", visible: true },
      }));
    }, 300);
  }, [dismissWhisper, schedule]);

  return {
    whispers,
    queuedMessages,
    typingIndicator,
    tabBadge,
    placeholderOverride,
    dismissWhisper,
    triggerPostVote,
    triggerPostXark,
    triggerPostClaim,
    triggerPostPurchase,
  };
}
