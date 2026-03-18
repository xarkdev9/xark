"use client";

// XARK OS v2.0 — PURCHASE SHEET
// Slide-up sheet for confirming purchase + entering amount.
// Appears when user taps a claimed item they own.
// State: claimed → purchased (terminal). Proof + amount required.
// Constitutional: no buttons, no boxes, floating text only.

import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, text, textColor, accentColor, opacity as op } from "@/lib/theme";
import { extractDisplayName } from "@/lib/user-id";
import { supabase } from "@/lib/supabase";

interface PurchaseSheetProps {
  isOpen: boolean;
  onClose: () => void;
  itemId: string;
  itemTitle: string;
  userId: string;
  currentVersion: number;
  onPurchased?: (itemId: string) => void;
  prefillAmount?: string;
}

const UNITS = ["total", "per night", "per person"] as const;
type Unit = (typeof UNITS)[number];

export default function PurchaseSheet({
  isOpen,
  onClose,
  itemId,
  itemTitle,
  userId,
  currentVersion,
  onPurchased,
  prefillAmount,
}: PurchaseSheetProps) {
  const [amount, setAmount] = useState(prefillAmount ?? "");
  const [unit, setUnit] = useState<Unit>("total");
  const [proof, setProof] = useState("");
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [whisper, setWhisper] = useState<string | null>(null);

  function cycleUnit() {
    const idx = UNITS.indexOf(unit);
    setUnit(UNITS[(idx + 1) % UNITS.length]);
  }

  async function handleSubmit() {
    if (!amount.trim()) return;
    setIsSubmitting(true);

    const now = new Date().toISOString();
    const priceStr = unit === "total" ? `$${amount}` : `$${amount}/${unit.replace("per ", "")}`;
    const proofType = proof.trim() ? "receipt" : "verbal";
    const proofValue = proof.trim() || `purchased by ${userId}`;

    const { error } = await supabase
      .from("decision_items")
      .update({
        state: "purchased",
        metadata: { price: priceStr },
        commitment_proof: {
          type: proofType,
          value: proofValue,
          submittedBy: userId,
          submittedAt: now,
        },
        ownership: {
          ownerId: userId,
          assignedAt: now,
          reason: "booker",
        },
        version: currentVersion + 1,
      })
      .eq("id", itemId)
      .eq("version", currentVersion);

    setIsSubmitting(false);

    if (!error) {
      const name = extractDisplayName(userId);
      setWhisper(`${name} booked ${itemTitle} for ${priceStr}`);
      onPurchased?.(itemId);
      setTimeout(onClose, 2000);
    }
  }

  const underlineStyle = {
    borderBottom: "none",
    borderBottomWidth: "1px",
    borderBottomStyle: "solid" as const,
    borderBottomColor: accentColor(0.6),
  };

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
              maxHeight: "50vh",
              background: colors.void,
              zIndex: 91,
              padding: "32px 24px",
              display: "flex",
              flexDirection: "column",
              gap: "20px",
            }}
          >
            {/* Item title */}
            <span style={{ ...text.listTitle, color: textColor(0.9) }}>
              {itemTitle}
            </span>

            {whisper ? (
              <span style={{ ...text.body, color: textColor(0.6) }}>
                {whisper}
              </span>
            ) : (
              <>
                {/* Amount input */}
                <div style={{ display: "flex", alignItems: "center", gap: "12px" }}>
                  <span style={{ ...text.body, color: textColor(0.4) }}>$</span>
                  <input
                    type="text"
                    inputMode="decimal"
                    placeholder="how much?"
                    value={amount}
                    onChange={(e) => setAmount(e.target.value)}
                    style={{
                      ...text.input,
                      color: textColor(0.9),
                      background: "transparent",
                      border: "none",
                      outline: "none",
                      flex: 1,
                      padding: "4px 0",
                      ...underlineStyle,
                      userSelect: "text" as const,
                      WebkitUserSelect: "text" as const,
                    }}
                  />
                  {/* Unit toggle */}
                  <span
                    onClick={cycleUnit}
                    style={{
                      ...text.label,
                      color: textColor(0.4),
                      cursor: "pointer",
                      whiteSpace: "nowrap",
                    }}
                  >
                    {unit}
                  </span>
                </div>

                {/* Proof input */}
                <input
                  type="text"
                  placeholder="link to confirmation or drop receipt"
                  value={proof}
                  onChange={(e) => setProof(e.target.value)}
                  style={{
                    ...text.input,
                    color: textColor(0.9),
                    background: "transparent",
                    border: "none",
                    outline: "none",
                    padding: "4px 0",
                    ...underlineStyle,
                    opacity: proof ? 1 : op.ghost,
                    userSelect: "text" as const,
                    WebkitUserSelect: "text" as const,
                  }}
                />

                {/* "done" action */}
                <span
                  onClick={!isSubmitting && amount.trim() ? handleSubmit : undefined}
                  style={{
                    ...text.label,
                    color: colors.cyan,
                    opacity: isSubmitting || !amount.trim() ? 0.3 : 0.9,
                    cursor: isSubmitting || !amount.trim() ? "default" : "pointer",
                    transition: "opacity 0.3s ease",
                    alignSelf: "flex-start",
                  }}
                >
                  {isSubmitting ? "saving..." : prefillAmount ? `confirm $${prefillAmount}` : "done"}
                </span>
              </>
            )}
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
