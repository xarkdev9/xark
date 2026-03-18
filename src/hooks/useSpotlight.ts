"use client";

// XARK OS v2.0 — Spotlight Hook
// State management for SpotlightSheet: open/close, morph animation, routing.
// send() fires @xark query, runs 800ms morph, then auto-navigates if from Galaxy.

import { useState, useCallback, useRef } from "react";
import { useRouter, usePathname } from "next/navigation";

interface SpotlightState {
  isOpen: boolean;
  morphText: string | null;
  targetSpaceId: string | null;
}

export function useSpotlight(getToken: () => string | null) {
  const router = useRouter();
  const pathname = usePathname();

  const [state, setState] = useState<SpotlightState>({
    isOpen: false,
    morphText: null,
    targetSpaceId: null,
  });

  const morphTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Derived: are we inside a space page? e.g. /space/space_san-diego-trip
  const isInsideSpace = /^\/space\//.test(pathname);

  const open = useCallback(() => {
    // If inside a space, extract spaceId from pathname
    const spaceMatch = pathname.match(/^\/space\/([^/]+)/);
    setState({
      isOpen: true,
      morphText: null,
      targetSpaceId: spaceMatch ? spaceMatch[1] : null,
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
      targetSpaceId: null,
    });
  }, []);

  const setTargetSpace = useCallback((spaceId: string) => {
    setState((prev) => ({ ...prev, targetSpaceId: spaceId }));
  }, []);

  const send = useCallback(
    (text: string, spaceId: string, spaceTitle?: string) => {
      const token = getToken();

      // Set morph text immediately
      const label = spaceTitle ?? spaceId.replace(/^space_/, "").replace(/-/g, " ");
      setState((prev) => ({
        ...prev,
        morphText: `scouting ${label}...`,
      }));

      // Fire-and-forget fetch to /api/xark
      if (token) {
        fetch("/api/xark", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            Authorization: `Bearer ${token}`,
          },
          body: JSON.stringify({
            message: "@xark " + text,
            spaceId,
            userId: "",
          }),
        }).catch(console.warn);
      }

      // After 800ms, close sheet + auto-navigate if from Galaxy
      morphTimerRef.current = setTimeout(() => {
        setState({
          isOpen: false,
          morphText: null,
          targetSpaceId: null,
        });

        // Auto-navigate to space if NOT already inside one
        if (!isInsideSpace) {
          router.push(`/space/${spaceId}`);
        }

        morphTimerRef.current = null;
      }, 800);
    },
    [getToken, isInsideSpace, router]
  );

  return {
    isOpen: state.isOpen,
    morphText: state.morphText,
    targetSpaceId: state.targetSpaceId,
    isInsideSpace,
    open,
    close,
    setTargetSpace,
    send,
  };
}
