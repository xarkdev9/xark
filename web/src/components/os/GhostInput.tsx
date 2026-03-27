"use client";

// XARK OS v2.0 — Ghost Input
// Pre-fills with whisper text at opacity 0.4 (ghost layer).
// Type = ghost shatters (AnimatePresence exit). Send = accept ghost as-is.
// No ghost = clean input with placeholder "ask xark anything..."
// Zero borders, zero boxes, zero bold. Pure Xark constitution.

import { useRef, useState, useCallback, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, text as textTokens, ink, surface } from "@/lib/theme";
import { spring, exit, tap } from "@/lib/motion";

interface GhostInputProps {
  ghostText: string | null;
  onSend: (text: string, wasGhost: boolean) => void;
  onGhostDismissed?: () => void;
  autoFocus?: boolean;
}

export function GhostInput({
  ghostText,
  onSend,
  onGhostDismissed,
  autoFocus = false,
}: GhostInputProps) {
  const [value, setValue] = useState("");
  const [ghostVisible, setGhostVisible] = useState<boolean>(!!ghostText);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // Re-show ghost when ghostText prop changes
  useEffect(() => {
    setGhostVisible(!!ghostText);
    setValue("");
  }, [ghostText]);

  // Auto-focus logic disabled for mobile integrity (prevents layout thrash)
  useEffect(() => {
    // Native mobile browsers handle autoFocus better natively, or user can tap.
    // SetTimeout focus causes severe jumps during Framer Motion slide-up.
  }, [autoFocus]);

  // Auto-resize textarea to content
  const autoResize = useCallback(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 144)}px`;
  }, []);

  useEffect(() => {
    autoResize();
  }, [value, autoResize]);

  // First keystroke shatters the ghost
  const handleChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const newValue = e.target.value;
    if (ghostVisible && newValue.length > 0) {
      setGhostVisible(false);
      onGhostDismissed?.();
    }
    setValue(newValue);
  };

  const handleSend = () => {
    if (ghostVisible && ghostText) {
      onSend(ghostText, true);
      setValue("");
      setGhostVisible(false);
    } else if (value.trim().length > 0) {
      onSend(value.trim(), false);
      setValue("");
    }
  };

  const hasContent = ghostVisible ? !!ghostText : value.trim().length > 0;

  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        paddingTop: "16px",
        paddingBottom: "max(env(safe-area-inset-bottom, 12px), 12px)",
        paddingLeft: "24px",
        paddingRight: "24px",
      }}
    >
      {/* ── Ghost text layer — absolute overlay, shatters on first keystroke ── */}
      <AnimatePresence>
        {ghostVisible && ghostText && (
          <motion.div
            key="ghost-layer"
            initial={{ opacity: 0, y: 4 }}
            animate={{ opacity: 0.35 }}
            exit={exit.shatter}
            transition={exit.shatterTiming}
            style={{
              position: "absolute",
              top: "16px",
              left: "24px",
              right: "72px",
              pointerEvents: "none",
              userSelect: "none",
              zIndex: 1,
              fontSize: "16px",
              fontWeight: 400,
              letterSpacing: "0.01em",
              lineHeight: 1.5,
              color: ink.secondary,
              wordBreak: "break-word",
              whiteSpace: "pre-wrap",
            }}
          >
            {ghostText}
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Input row ── */}
      <form
        onSubmit={(e) => { e.preventDefault(); handleSend(); }}
        style={{ display: "flex", alignItems: "flex-end", gap: "12px" }}
      >
        <textarea
          ref={textareaRef}
          value={value}
          onChange={handleChange}
          placeholder="ask hello anything..."
          rows={1}
          spellCheck={false}
          autoComplete="off"
          autoCapitalize="sentences"
          autoCorrect="on"
          enterKeyHint="send"
          className="w-full resize-none bg-transparent outline-none"
          style={{
            position: "relative",
            zIndex: 2,
            fontSize: "16px",
            fontWeight: 400,
            letterSpacing: "0.01em",
            lineHeight: 1.5,
            color: ghostVisible ? "transparent" : ink.primary,
            caretColor: colors.accent,
            maxHeight: "144px",
            overflow: "hidden",
            background: "transparent",
          }}
        />

        {/* ── Send button ── */}
        <motion.button
          type="submit"
          className="outline-none cursor-pointer select-none"
          animate={{ opacity: hasContent ? 0.9 : 0.25 }}
          transition={spring.snappy}
          whileTap={tap.micro}
          style={{
            flexShrink: 0,
            marginBottom: "2px",
            color: colors.accent,
            fontSize: "14px",
            fontWeight: 300,
            letterSpacing: "0.08em",
            background: "none",
            border: "none",
            padding: 0,
          }}
        >
          send
        </motion.button>
      </form>

      <style jsx>{`
        textarea::placeholder {
          color: var(--xark-ink-tertiary);
          opacity: 0.6;
          letter-spacing: 0.04em;
        }
      `}</style>
    </div>
  );
}
