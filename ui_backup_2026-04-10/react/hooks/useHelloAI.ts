"use client";

// hello OS v2.0 — Spotlight Hook
// State management for SpotlightSheet: open/close, morph animation, routing.
// send() fires @hello query, runs 800ms morph, then auto-navigates if from Home.

import { useState, useCallback, useRef } from "react";
import { useRouter, usePathname } from "next/navigation";

interface SpotlightState {
  isOpen: boolean;
  morphText: string | null;
  targetGroupId: string | null;
}

export function useHelloAI(getToken: () => string | null) {
  const router = useRouter();
  const pathname = usePathname();

  const [state, setState] = useState<SpotlightState>({
    isOpen: false,
    morphText: null,
    targetGroupId: null,
  });

  const morphTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Derived: are we inside a space page? e.g. /space/space_san-diego-trip
  const isInsideSpace = /^\/space\//.test(pathname);

  const open = useCallback(() => {
    // If inside a space, extract groupId from pathname
    const spaceMatch = pathname.match(/^\/space\/([^/]+)/);
    setState({
      isOpen: true,
      morphText: null,
      targetGroupId: spaceMatch ? spaceMatch[1] : null,
    });
  }, [pathname]);

  const close = useCallback(() => {
    if (morphTimerRef.current) {
      clearTimeout(morphTimerRef.current);
      morphTimerRef.current = null;
    }
    setState({
      isOpen: false,
      morphText: null,
      targetGroupId: null,
    });
  }, []);

  const setTargetSpace = useCallback((groupId: string) => {
    setState((prev) => ({ ...prev, targetGroupId: groupId }));
  }, []);

  const send = useCallback(
    (text: string, groupId: string, spaceTitle?: string) => {
      const token = getToken();

      // Set morph text immediately
      setState((prev) => ({
        ...prev,
        morphText: spaceTitle ? `scouting ${spaceTitle}...` : "scouting...",
      }));

      // Signal to Space page that @hello is processing — instant feedback
      window.dispatchEvent(new CustomEvent("hello-thinking", { detail: { groupId } }));

      // Fire-and-forget fetch to /api/hello
      if (token) {
        fetch("/api/hello", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({
            message: "@hello " + text,
            groupId,
            userId: "",
          }),
        }).catch(console.warn);
      }

      // After 800ms, close sheet + auto-navigate if from Home
      morphTimerRef.current = setTimeout(() => {
        setState({
          isOpen: false,
          morphText: null,
          targetGroupId: null,
        });

        // Auto-navigate to space if NOT already inside one
        if (!isInsideSpace) {
          router.push(`/space/${groupId}?hello=thinking`);
        }

        morphTimerRef.current = null;
      }, 800);
    },
    [getToken, isInsideSpace, router]
  );

  return {
    isOpen: state.isOpen,
    morphText: state.morphText,
    targetGroupId: state.targetGroupId,
    isInsideSpace,
    open,
    close,
    setTargetSpace,
    send,
  };
}
