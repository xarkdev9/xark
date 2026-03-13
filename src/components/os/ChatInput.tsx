"use client";

// XARK OS v2.0 — Shared Chat Input
// Lives in Space page, persists across Discuss/Decide view switches.
// Owns: input field, mic, accent underline. Stateless — controlled by parent.

import { useRef, useState, useEffect } from "react";
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
              marginBottom: "12px",
            }}
          />
          <div className="relative flex items-center gap-3">
            <input
              type="text"
              value={input}
              onChange={(e) => onInputChange(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") onSend();
              }}
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
              onFocus={() => setInputFocused(true)}
              onBlur={() => setInputFocused(false)}
              className="w-full bg-transparent outline-none"
              style={{
                ...text.input,
                color: colors.white,
                caretColor: colors.cyan,
                opacity: isThinking ? 0.3 : 1,
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
                ...text.label,
                color: isXarkListening ? colors.cyan : colors.white,
                opacity: isListening || isXarkListening ? 0.9 : 0.3,
                cursor: "pointer",
                transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
                flexShrink: 0,
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
        input::placeholder {
          color: ${colors.white};
          opacity: ${opacity.ghost};
          letter-spacing: 0.12em;
        }
      `}</style>
    </>
  );
}
