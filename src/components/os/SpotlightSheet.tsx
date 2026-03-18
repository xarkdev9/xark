"use client";

// XARK OS v2.0 — Spotlight Sheet
// Half-sheet overlay: GhostInput + space chips + 800ms morph animation.
// Constitution: no bold, no borders, theme tokens only, Zero-Box for feed items.
// Sheet overlay gets 20px top border-radius (system overlay exception).

import { useEffect, useState, useCallback, useRef } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  colors,
  text as textTokens,
  ink,
  surface,
  opacity as opacityTokens,
} from "@/lib/theme";
import { GhostInput } from "@/components/os/GhostInput";
import { fetchSpaceList, type SpaceListItem } from "@/lib/space-data";

// ── Props ──────────────────────────────────────────────────────────────────

interface SpotlightSheetProps {
  isOpen: boolean;
  morphText: string | null;
  targetSpaceId: string | null;
  isInsideSpace: boolean;
  ghostText: string | null;
  ghostSpaceId: string | null;
  getToken: () => string | null;
  onClose: () => void;
  onSend: (text: string, spaceId: string, spaceTitle?: string) => void;
  onSetTargetSpace: (spaceId: string) => void;
  onGhostAccepted: () => void;
  onGhostDismissed: () => void;
}

// ── Constants ──────────────────────────────────────────────────────────────

const SPRING = { damping: 30, stiffness: 300 };
const MAX_CHIPS = 8;
const BRAND_ORANGE = "#FF6B35";

// ── Component ──────────────────────────────────────────────────────────────

export function SpotlightSheet({
  isOpen,
  morphText,
  targetSpaceId,
  isInsideSpace,
  ghostText,
  ghostSpaceId,
  getToken,
  onClose,
  onSend,
  onSetTargetSpace,
  onGhostAccepted,
  onGhostDismissed,
}: SpotlightSheetProps) {
  const [spaces, setSpaces] = useState<SpaceListItem[]>([]);
  const [spacesLoaded, setSpacesLoaded] = useState(false);
  const chipsRef = useRef<HTMLDivElement>(null);

  // Fetch space list when sheet opens on Galaxy (not inside a space)
  useEffect(() => {
    if (!isOpen || isInsideSpace) return;
    if (spacesLoaded) return;

    let cancelled = false;
    fetchSpaceList().then((list) => {
      if (!cancelled) {
        setSpaces(list.slice(0, MAX_CHIPS));
        setSpacesLoaded(true);
        // Auto-select first space if none selected
        if (!targetSpaceId && list.length > 0) {
          onSetTargetSpace(list[0].id);
        }
      }
    });

    return () => {
      cancelled = true;
    };
  }, [isOpen, isInsideSpace, spacesLoaded, targetSpaceId, onSetTargetSpace]);

  // Reset spaces cache when sheet closes
  useEffect(() => {
    if (!isOpen) {
      setSpacesLoaded(false);
    }
  }, [isOpen]);

  // Find title for the active space
  const activeSpaceTitle = (() => {
    if (!targetSpaceId) return null;
    const found = spaces.find((s) => s.id === targetSpaceId);
    if (found) return found.title;
    // Fallback: derive from id
    return targetSpaceId.replace(/^space_/, "").replace(/-/g, " ");
  })();

  // Handle send from GhostInput
  const handleSend = useCallback(
    (text: string, wasGhost: boolean) => {
      // Onboarding whisper: ghostSpaceId === "" means taste onboarding
      if (wasGhost && ghostSpaceId === "") {
        const token = getToken();
        if (token) {
          fetch("/api/taste", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${token}`,
            },
            body: JSON.stringify({ text }),
          }).catch(console.warn);
        }
        onGhostAccepted();
        onClose();
        return;
      }

      // Normal send: must have a target space
      if (!targetSpaceId) return;
      onSend(text, targetSpaceId, activeSpaceTitle ?? undefined);
    },
    [
      ghostSpaceId,
      targetSpaceId,
      activeSpaceTitle,
      getToken,
      onSend,
      onGhostAccepted,
      onClose,
    ]
  );

  const isMorphing = !!morphText;
  const showChips = !isInsideSpace && !isMorphing && spaces.length > 0;

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* ── Overlay scrim ── */}
          <motion.div
            key="spotlight-overlay"
            initial={{ opacity: 0 }}
            animate={{ opacity: opacityTokens.overlay }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.2 }}
            onClick={onClose}
            style={{
              position: "fixed",
              inset: 0,
              backgroundColor: colors.overlay,
              zIndex: 9998,
            }}
          />

          {/* ── Sheet ── */}
          <motion.div
            key="spotlight-sheet"
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "spring", ...SPRING }}
            style={{
              position: "fixed",
              bottom: 0,
              left: 0,
              right: 0,
              zIndex: 9999,
              backgroundColor: surface.chrome,
              borderRadius: "20px 20px 0 0",
              paddingBottom: "env(safe-area-inset-bottom, 0px)",
              maxHeight: "70dvh",
              overflow: "hidden",
            }}
          >
            {/* ── Handle bar ── */}
            <div
              style={{
                display: "flex",
                justifyContent: "center",
                paddingTop: "12px",
                paddingBottom: "8px",
              }}
            >
              <div
                style={{
                  width: "36px",
                  height: "4px",
                  borderRadius: "2px",
                  backgroundColor: ink.tertiary,
                  opacity: 0.3,
                }}
              />
            </div>

            {/* ── Context pill (inside space) ── */}
            {isInsideSpace && targetSpaceId && activeSpaceTitle && !isMorphing && (
              <div
                style={{
                  paddingLeft: "24px",
                  paddingRight: "24px",
                  paddingBottom: "8px",
                }}
              >
                <span
                  style={{
                    ...textTokens.label,
                    color: colors.cyan,
                    opacity: 0.7,
                    letterSpacing: "0.06em",
                  }}
                >
                  {activeSpaceTitle}
                </span>
              </div>
            )}

            {/* ── Space chips (on Galaxy, not morphing) ── */}
            {showChips && (
              <div
                style={{
                  paddingLeft: "24px",
                  paddingRight: "24px",
                  paddingBottom: "12px",
                }}
              >
                <div
                  style={{
                    ...textTokens.label,
                    color: ink.tertiary,
                    marginBottom: "8px",
                    fontSize: "0.6875rem",
                    letterSpacing: "0.1em",
                  }}
                >
                  send to
                </div>
                <div
                  ref={chipsRef}
                  style={{
                    display: "flex",
                    gap: "8px",
                    overflowX: "auto",
                    scrollbarWidth: "none",
                    WebkitOverflowScrolling: "touch",
                    // Hide scrollbar
                    msOverflowStyle: "none",
                  }}
                >
                  {spaces.map((space) => {
                    const isActive = space.id === targetSpaceId;
                    return (
                      <button
                        key={space.id}
                        onClick={() => onSetTargetSpace(space.id)}
                        style={{
                          flexShrink: 0,
                          padding: "6px 14px",
                          borderRadius: "16px",
                          backgroundColor: isActive
                            ? colors.cyan
                            : surface.recessed,
                          color: isActive ? colors.void : ink.secondary,
                          ...textTokens.label,
                          fontSize: "0.75rem",
                          letterSpacing: "0.06em",
                          cursor: "pointer",
                          // Constitution: no border, no outline
                          border: "none",
                          outline: "none",
                          WebkitTapHighlightColor: "transparent",
                          transition: "background-color 0.2s, color 0.2s",
                          whiteSpace: "nowrap",
                        }}
                      >
                        {space.title}
                      </button>
                    );
                  })}
                </div>
              </div>
            )}

            {/* ── Morph state: breathing dot + status text ── */}
            {isMorphing && (
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  gap: "12px",
                  padding: "24px",
                  justifyContent: "center",
                }}
              >
                <motion.div
                  animate={{ opacity: [0.5, 1, 0.5] }}
                  transition={{
                    duration: 1.5,
                    repeat: Infinity,
                    ease: "easeInOut",
                  }}
                  style={{
                    width: "8px",
                    height: "8px",
                    borderRadius: "50%",
                    backgroundColor: BRAND_ORANGE,
                    flexShrink: 0,
                  }}
                />
                <span
                  style={{
                    ...textTokens.subtitle,
                    color: ink.secondary,
                    fontWeight: 300,
                  }}
                >
                  {morphText}
                </span>
              </div>
            )}

            {/* ── Ghost Input (when not morphing) ── */}
            {!isMorphing && (
              <GhostInput
                ghostText={ghostText}
                onSend={handleSend}
                onGhostDismissed={onGhostDismissed}
                autoFocus
              />
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
