"use client";

// XARK OS v2.0 — Shared Chat Input
// Lives in Space page, persists across Discuss/Decide view switches.
// Auto-expanding textarea. Owns: input, mic, accent underline. Controlled by parent.

import { useRef, useState, useEffect, useCallback } from "react";
import { useVoiceInput } from "@/hooks/useVoiceInput";
import { colors, text, timing, layout, opacity } from "@/lib/theme";

interface ChatInputProps {
  input: string;
  onInputChange: (value: string) => void;
  onSend: () => void;
  isThinking?: boolean;
}

export function ChatInput({
  input,
  onInputChange,
  onSend,
  isThinking,
}: ChatInputProps) {
  const [inputFocused, setInputFocused] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  // ── Voice Input — tap: on-device, long-press: @xark mode ──
  const {
    isListening,
    isXarkListening,
    transcript,
    startListening,
    startXarkListening,
    stopListening,
  } = useVoiceInput();
  const longPressRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (transcript) onInputChange(transcript);
  }, [transcript, onInputChange]);

  // ── Auto-resize textarea to content (max ~6 lines) ──
  const autoResize = useCallback(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 120)}px`;
  }, []);

  useEffect(() => {
    autoResize();
  }, [input, autoResize]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === "Enter" && !e.shiftKey) {
      e.preventDefault();
      onSend();
    }
  };

  return (
    <>
      <div
        className="fixed inset-x-0 bottom-0 z-20 px-6 pt-4"
        style={{
          paddingBottom: layout.inputBottom,
          background: colors.void,
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          {/* ── Top ambient line — content boundary ── */}
          <div
            style={{
              height: "1px",
              background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
              opacity: 0.15,
              marginBottom: "10px",
            }}
          />
          <div className="relative flex items-start gap-3">
            <textarea
              ref={textareaRef}
              value={input}
              onChange={(e) => onInputChange(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={
                isXarkListening
                  ? "@xark is listening..."
                  : isListening
                    ? "listening..."
                    : "message, or @xark for ideas"
              }
              disabled={isThinking}
              spellCheck={false}
              autoComplete="off"
              rows={1}
              onFocus={() => setInputFocused(true)}
              onBlur={() => setInputFocused(false)}
              className="w-full resize-none bg-transparent outline-none"
              style={{
                ...text.body,
                color: colors.white,
                caretColor: colors.cyan,
                opacity: isThinking ? 0.3 : 1,
                lineHeight: 1.5,
                maxHeight: "120px",
                overflow: "hidden",
              }}
            />
            {/* ── Mic — tap: listen, long-press 500ms: @xark mode ── */}
            <span
              role="button"
              tabIndex={0}
              onPointerDown={() => {
                longPressRef.current = setTimeout(() => {
                  startXarkListening();
                  longPressRef.current = null;
                }, 500);
              }}
              onPointerUp={() => {
                if (longPressRef.current) {
                  clearTimeout(longPressRef.current);
                  longPressRef.current = null;
                  if (isListening || isXarkListening) {
                    stopListening();
                  } else {
                    startListening();
                  }
                }
              }}
              onPointerLeave={() => {
                if (longPressRef.current) {
                  clearTimeout(longPressRef.current);
                  longPressRef.current = null;
                }
              }}
              className="outline-none select-none"
              style={{
                ...text.recency,
                color: isXarkListening ? colors.cyan : colors.white,
                opacity: isListening || isXarkListening ? 0.9 : 0.3,
                cursor: "pointer",
                transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
                flexShrink: 0,
                marginTop: "2px",
              }}
            >
              {isListening || isXarkListening ? (
                <span className="flex items-center gap-2">
                  <span
                    style={{
                      display: "inline-block",
                      width: "6px",
                      height: "6px",
                      borderRadius: "50%",
                      backgroundColor: isXarkListening ? colors.cyan : colors.white,
                      animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                    }}
                  />
                </span>
              ) : (
                "mic"
              )}
            </span>
            <div
              className="absolute -bottom-2 left-0 h-px w-full"
              style={{
                background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
                opacity: inputFocused ? 1 : 0.15,
                animation: inputFocused
                  ? `ambientBreath ${timing.breath} ease-in-out infinite`
                  : "none",
                transition: `opacity ${timing.transition} ease`,
              }}
            />
          </div>
        </div>
      </div>

      <style jsx>{`
        textarea::placeholder {
          color: ${colors.white};
          opacity: ${opacity.ghost};
          letter-spacing: 0.08em;
        }
      `}</style>
    </>
  );
}
