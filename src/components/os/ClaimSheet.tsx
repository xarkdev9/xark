"use client";

// XARK OS v2.0 — CLAIM SHEET
// Slide-up sheet for claiming a locked item.
// "i'll handle this" — stamps owner on BOOKING_FLOW locked items.
// Constitutional: no buttons, no boxes, floating text only.

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, text, textColor, opacity as op } from "@/lib/theme";
import { claimItem } from "@/lib/claims";

interface ItemMetadata {
  url?: string;
  shared_url?: string;
  phone?: string;
  siteName?: string;
  [key: string]: unknown;
}

interface ClaimSheetProps {
  isOpen: boolean;
  onClose: () => void;
  itemId: string;
  itemTitle: string;
  userId: string;
  item?: { metadata?: ItemMetadata };
  onClaimed?: (itemId: string) => void;
}

export default function ClaimSheet({
  isOpen,
  onClose,
  itemId,
  itemTitle,
  userId,
  item,
  onClaimed,
}: ClaimSheetProps) {
  const [isClaiming, setIsClaiming] = useState(false);
  const [whisper, setWhisper] = useState<string | null>(null);

  async function handleClaim() {
    setIsClaiming(true);
    const result = await claimItem(itemId, userId);
    setIsClaiming(false);

    if (result.success) {
      setWhisper(`${userId.replace(/^name_/, "")} is on it`);
      onClaimed?.(itemId);
      setTimeout(onClose, 1500);
    }
  }

  return (
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Overlay — #000 at 0.8, no blur */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: op.overlay }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.3 }}
            onClick={onClose}
            style={{
              position: "fixed",
              inset: 0,
              background: colors.overlay,
              zIndex: 90,
            }}
          />

          {/* Sheet — slides from bottom */}
          <motion.div
            initial={{ y: "100%" }}
            animate={{ y: 0 }}
            exit={{ y: "100%" }}
            transition={{ type: "tween", duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
            style={{
              position: "fixed",
              bottom: 0,
              left: 0,
              right: 0,
              maxHeight: "40vh",
              background: colors.void,
              zIndex: 91,
              padding: "32px 24px",
              display: "flex",
              flexDirection: "column",
              gap: "24px",
            }}
          >
            {/* Item title */}
            <span
              style={{
                ...text.listTitle,
                color: textColor(0.9),
              }}
            >
              {itemTitle}
            </span>

            {/* Booking links */}
            {item?.metadata?.url && (
              <p
                role="button"
                tabIndex={0}
                onClick={() => window.open(item.metadata!.url, "_blank", "noopener,noreferrer")}
                onKeyDown={(e) => { if (e.key === "Enter") window.open(item.metadata!.url, "_blank", "noopener,noreferrer"); }}
                className="cursor-pointer outline-none"
                style={{ ...text.label, color: colors.cyan, opacity: 0.7, marginTop: 8 }}
              >
                {item.metadata.siteName || "open booking page"}
              </p>
            )}
            {item?.metadata?.phone && (
              <p
                role="button"
                tabIndex={0}
                onClick={() => window.open(`tel:${item.metadata!.phone}`)}
                onKeyDown={(e) => { if (e.key === "Enter") window.open(`tel:${item.metadata!.phone}`); }}
                className="cursor-pointer outline-none"
                style={{ ...text.label, color: colors.cyan, opacity: 0.7, marginTop: 4 }}
              >
                call {item.metadata.phone}
              </p>
            )}

            {/* Whisper after claim */}
            {whisper ? (
              <span
                style={{
                  ...text.body,
                  color: textColor(0.6),
                }}
              >
                {whisper}
              </span>
            ) : (
              <div style={{ display: "flex", gap: "24px", alignItems: "center" }}>
                {/* "i'll handle this" */}
                <span
                  onClick={!isClaiming ? handleClaim : undefined}
                  style={{
                    ...text.label,
                    color: colors.cyan,
                    opacity: isClaiming ? 0.4 : 0.9,
                    cursor: isClaiming ? "default" : "pointer",
                    transition: "opacity 0.3s ease",
                  }}
                >
                  {isClaiming ? "claiming..." : "i'll handle this"}
                </span>

                {/* "not yet" */}
                <span
                  onClick={onClose}
                  style={{
                    ...text.label,
                    color: textColor(0.4),
                    cursor: "pointer",
                  }}
                >
                  not yet
                </span>
              </div>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
