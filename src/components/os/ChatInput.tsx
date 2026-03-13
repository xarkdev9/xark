"use client";

// XARK OS v2.0 — Shared Chat Input
// Textarea zone at inputBottom. Actions (attach · camera · mic) flanking the
// ControlCaret dot at caretBottom — always visible, always in thumb range.

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
    if (onAttach) onAttach();
    else fileRef.current?.click();
  };

  const handleCameraClick = () => {
    if (onCamera) onCamera();
    else cameraRef.current?.click();
  };

  // Shared action label style
  const actionStyle = {
    ...text.subtitle,
    color: textColor(0.35),
    cursor: "pointer" as const,
    transition: `color ${timing.transition} ease`,
  };

  return (
    <>
      {/* Hidden file inputs */}
      <input ref={fileRef} type="file" className="hidden" accept="*/*" />
      <input ref={cameraRef} type="file" className="hidden" accept="image/*" capture="environment" />

      {/* ═══ TEXTAREA ZONE — at inputBottom level ═══ */}
      <div
        className="fixed inset-x-0 z-20 px-6"
        style={{
          bottom: layout.inputBottom,
          paddingBottom: "12px",
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

          {/* ── Bottom accent underline ── */}
          <div
            style={{
              marginTop: "4px",
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

      {/* ═══ ACTION BAR — flanks the ControlCaret dot at caretBottom ═══ */}
      <div
        className="fixed inset-x-0 z-20 px-6"
        style={{
          bottom: layout.caretBottom,
          transform: "translateY(50%)",
          pointerEvents: "none",
          background: colors.void,
          paddingTop: "8px",
          paddingBottom: "8px",
        }}
      >
        <div
          className="mx-auto flex items-center justify-center gap-8"
          style={{ maxWidth: "640px", pointerEvents: "auto" }}
        >
          {/* ── Left of dot: attach · camera ── */}
          <span
            role="button"
            tabIndex={0}
            onClick={handleAttachClick}
            onKeyDown={(e) => { if (e.key === "Enter") handleAttachClick(); }}
            className="cursor-pointer outline-none"
            style={actionStyle}
            onMouseEnter={(e) => { e.currentTarget.style.color = textColor(0.6); }}
            onMouseLeave={(e) => { e.currentTarget.style.color = textColor(0.35); }}
          >
            attach
          </span>

          <span
            role="button"
            tabIndex={0}
            onClick={handleCameraClick}
            onKeyDown={(e) => { if (e.key === "Enter") handleCameraClick(); }}
            className="cursor-pointer outline-none"
            style={actionStyle}
            onMouseEnter={(e) => { e.currentTarget.style.color = textColor(0.6); }}
            onMouseLeave={(e) => { e.currentTarget.style.color = textColor(0.35); }}
          >
            camera
          </span>

          {/* ── Gap for the breathing dot (ControlCaret renders it independently) ── */}
          <div style={{ width: layout.caretSize }} />

          {/* ── Right of dot: mic ── */}
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
              ...text.subtitle,
              color: isXarkListening ? colors.cyan : isListening ? colors.white : textColor(0.35),
              cursor: "pointer",
              transition: `color ${timing.transition} ease`,
            }}
            onMouseEnter={(e) => {
              if (!isListening && !isXarkListening) e.currentTarget.style.color = textColor(0.6);
            }}
            onMouseLeave={(e) => {
              if (!isListening && !isXarkListening) e.currentTarget.style.color = textColor(0.35);
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
