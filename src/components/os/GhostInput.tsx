"use client";

// XARK OS v2.0 — Ghost Input
// Pre-fills with whisper text at opacity 0.4 (ghost layer).
// Type = ghost shatters (AnimatePresence exit). Send = accept ghost as-is.
// Zero borders, zero boxes, zero bold. Pure Xark constitution.

import { useRef, useState, useCallback, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { colors, text as textTokens, ink, surface } from "@/lib/theme";

const EASE = [0.22, 1, 0.36, 1] as const;

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

  // Auto-focus on mount if requested
  useEffect(() => {
    if (autoFocus && textareaRef.current) {
      textareaRef.current.focus();
    }
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

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleSend = () => {
    if (ghostVisible && ghostText) {
      onSend(ghostText, true);
    } else if (value.trim().length > 0) {
      onSend(value.trim(), false);
    }
  };

  const hasContent = ghostVisible ? !!ghostText : value.trim().length > 0;

  return (
    <div
      style={{
        position: "relative",
        width: "100%",
        background: `linear-gradient(to top, ${surface.canvas}, ${surface.canvas} 80%, transparent)`,
        paddingTop: "16px",
        paddingBottom: "12px",
        paddingLeft: "24px",
        paddingRight: "24px",
      }}
    >
      {/* ── Ghost text layer — absolute overlay, shatters on first keystroke ── */}
      <AnimatePresence>
        {ghostVisible && ghostText && (
          <motion.div
            key="ghost-layer"
            initial={{ opacity: 0.4, scale: 1 }}
            animate={{ opacity: 0.4, scale: 1 }}
            exit={{ opacity: 0, scale: 0.95 }}
            transition={{ duration: 0.15, ease: EASE }}
            style={{
              position: "absolute",
              top: "16px",
              left: "24px",
              right: "72px", // leave room for send button
              pointerEvents: "none",
              userSelect: "none",
              zIndex: 1,
              // Match textarea sizing exactly
              fontSize: "18px",
              fontWeight: 400,
              letterSpacing: "0.02em",
              lineHeight: 1.5,
              color: ink.primary,
              wordBreak: "break-word",
              whiteSpace: "pre-wrap",
              paddingTop: 0,
            }}
          >
            {ghostText}
          </motion.div>
        )}
      </AnimatePresence>

      {/* ── Input row ── */}
      <div style={{ display: "flex", alignItems: "flex-end", gap: "12px" }}>
        <textarea
          ref={textareaRef}
          value={value}
          onChange={handleChange}
          onKeyDown={handleKeyDown}
          placeholder={ghostVisible ? undefined : "ask xark anything..."}
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
            fontSize: "18px",
            fontWeight: 400,
            letterSpacing: "0.02em",
            lineHeight: 1.5,
            color: ghostVisible ? "transparent" : ink.primary,
            caretColor: colors.cyan,
            maxHeight: "144px",
            overflow: "hidden",
            background: "transparent",
            // Constitution: no border, no outline
          }}
        />

        {/* ── Send button — "send" text at 14px weight 300 ── */}
        <motion.span
          role="button"
          tabIndex={0}
          onClick={handleSend}
          onKeyDown={(e) => { if (e.key === "Enter") handleSend(); }}
          className="outline-none cursor-pointer select-none"
          animate={{ opacity: hasContent ? 0.9 : 0.3 }}
          transition={{ duration: 0.2, ease: EASE }}
          style={{
            flexShrink: 0,
            marginBottom: "4px",
            color: colors.cyan,
            ...textTokens.hint,
            fontSize: "14px",
            fontWeight: 300,
            letterSpacing: "0.08em",
          }}
        >
          send
        </motion.span>
      </div>

      {/* ── Placeholder styling ── */}
      <style jsx>{`
        textarea::placeholder {
          color: var(--xark-ink-tertiary);
          opacity: 1;
          letter-spacing: 0.04em;
        }
      `}</style>
    </div>
  );
}
