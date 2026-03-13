"use client";

// XARK OS v2.0 — Shared Chat Input
// Auto-expanding textarea + fixed action row (attach · camera · mic).
// Textarea grows upward. Actions stay pinned below it, always in same position.

import { useRef, useState, useEffect, useCallback } from "react";
import { useVoiceInput } from "@/hooks/useVoiceInput";
import { colors, text, timing, layout, opacity, textColor } from "@/lib/theme";

interface ChatInputProps {
  input: string;
  onInputChange: (value: string) => void;
  onSend: () => void;
  isThinking?: boolean;
  onAttach?: () => void;
  onCamera?: () => void;
}

export function ChatInput({
  input,
  onInputChange,
  onSend,
  isThinking,
  onAttach,
  onCamera,
}: ChatInputProps) {
  const [inputFocused, setInputFocused] = useState(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const cameraRef = useRef<HTMLInputElement>(null);

  // ── Voice Input ──
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

  // ── Auto-resize textarea (max ~6 lines) ──
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

  const handleAttachClick = () => {
    if (onAttach) {
      onAttach();
    } else {
      fileRef.current?.click();
    }
  };

  const handleCameraClick = () => {
    if (onCamera) {
      onCamera();
    } else {
      cameraRef.current?.click();
    }
  };

  return (
    <>
      {/* Hidden file inputs */}
      <input ref={fileRef} type="file" className="hidden" accept="*/*" />
      <input ref={cameraRef} type="file" className="hidden" accept="image/*" capture="environment" />

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

          {/* ── Textarea — grows upward ── */}
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

          {/* ── Action row — fixed below textarea, never moves ── */}
          <div
            className="flex items-center justify-end gap-5"
            style={{ marginTop: "8px" }}
          >
            <span
              role="button"
              tabIndex={0}
              onClick={handleAttachClick}
              onKeyDown={(e) => { if (e.key === "Enter") handleAttachClick(); }}
              className="cursor-pointer outline-none"
              style={{
                ...text.recency,
                color: textColor(0.3),
                transition: `color ${timing.transition} ease`,
              }}
              onMouseEnter={(e) => { e.currentTarget.style.color = textColor(0.5); }}
              onMouseLeave={(e) => { e.currentTarget.style.color = textColor(0.3); }}
            >
              attach
            </span>

            <span
              role="button"
              tabIndex={0}
              onClick={handleCameraClick}
              onKeyDown={(e) => { if (e.key === "Enter") handleCameraClick(); }}
              className="cursor-pointer outline-none"
              style={{
                ...text.recency,
                color: textColor(0.3),
                transition: `color ${timing.transition} ease`,
              }}
              onMouseEnter={(e) => { e.currentTarget.style.color = textColor(0.5); }}
              onMouseLeave={(e) => { e.currentTarget.style.color = textColor(0.3); }}
            >
              camera
            </span>

            {/* ── Mic — tap: listen, long-press: @xark mode ── */}
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
                  if (isListening || isXarkListening) stopListening();
                  else startListening();
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
                color: isXarkListening ? colors.cyan : textColor(0.3),
                opacity: isListening || isXarkListening ? 0.9 : 1,
                cursor: "pointer",
                transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
              }}
              onMouseEnter={(e) => {
                if (!isListening && !isXarkListening) e.currentTarget.style.color = textColor(0.5);
              }}
              onMouseLeave={(e) => {
                if (!isListening && !isXarkListening) e.currentTarget.style.color = textColor(0.3);
              }}
            >
              {isListening || isXarkListening ? (
                <span className="flex items-center gap-2">
                  <span
                    style={{
                      display: "inline-block",
                      width: "5px",
                      height: "5px",
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
          </div>

          {/* ── Bottom accent underline ── */}
          <div
            style={{
              marginTop: "6px",
              height: "1px",
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
