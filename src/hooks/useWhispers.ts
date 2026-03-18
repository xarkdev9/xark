// XARK OS v2.0 — WHISPER HOOK
// Fetches proactive whispers on mount and every 60 seconds.
// Manages a priority queue: consumeWhisper pops the top,
// dismissWhisper moves current to the back.

import { useEffect, useState, useCallback, useRef } from "react";
import { generateWhispers, type Whisper } from "@/lib/whispers";

const POLL_INTERVAL_MS = 60_000;

export interface UseWhispersReturn {
  /** The highest-priority whisper to display right now */
  currentWhisper: Whisper | null;
  /** True when there is at least one whisper in queue */
  hasWhispers: boolean;
  /** Remove the current whisper and advance to the next */
  consumeWhisper: () => void;
  /** Move the current whisper to the back of the queue and advance to the next */
  dismissWhisper: () => void;
}

export function useWhispers(userId: string | null): UseWhispersReturn {
  const [queue, setQueue] = useState<Whisper[]>([]);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const isFetchingRef = useRef(false);

  // ── Fetch and merge into queue ──
  const fetchAndMerge = useCallback(async () => {
    if (!userId || isFetchingRef.current) return;
    isFetchingRef.current = true;

    try {
      const fresh = await generateWhispers(userId);

      setQueue((prev) => {
        if (fresh.length === 0) return prev;

        // Build a set of existing IDs to avoid duplicating whispers already in queue
        const existingIds = new Set(prev.map((w) => w.id));
        const incoming = fresh.filter((w) => !existingIds.has(w.id));

        if (incoming.length === 0) return prev;

        // Merge and re-sort by priority — keeps the queue ordered
        const merged = [...prev, ...incoming].sort(
          (a, b) => a.priority - b.priority
        );
        return merged;
      });
    } catch {
      // Silent — best effort
    } finally {
      isFetchingRef.current = false;
    }
  }, [userId]);

  // ── Mount: initial fetch + poll ──
  useEffect(() => {
    if (!userId) return;

    fetchAndMerge();

    intervalRef.current = setInterval(fetchAndMerge, POLL_INTERVAL_MS);

    return () => {
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
        intervalRef.current = null;
      }
    };
  }, [userId, fetchAndMerge]);

  // ── consumeWhisper: remove top, advance to next ──
  const consumeWhisper = useCallback(() => {
    setQueue((prev) => {
      if (prev.length === 0) return prev;
      return prev.slice(1);
    });
  }, []);

  // ── dismissWhisper: move current to back, advance to next ──
  const dismissWhisper = useCallback(() => {
    setQueue((prev) => {
      if (prev.length === 0) return prev;
      const [current, ...rest] = prev;
      return [...rest, current];
    });
  }, []);

  const currentWhisper = queue[0] ?? null;
  const hasWhispers = queue.length > 0;

  return { currentWhisper, hasWhispers, consumeWhisper, dismissWhisper };
}
