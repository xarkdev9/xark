"use client";

// XARK OS v2.0 — Shared Chat Input
// Textarea + mic at inputBottom. Attach/Camera icons flank the dot at caretBottom.

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

// ── Minimal SVG icons — thin stroke, atmospheric ──
function AttachIcon({ color }: { color: string }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48" />
    </svg>
  );
}

function CameraIcon({ color }: { color: string }) {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z" />
      <circle cx="12" cy="13" r="4" />
    </svg>
  );
}

function MicIcon({ color, size = 14 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="9" y="1" width="6" height="11" rx="3" />
      <path d="M19 10v2a7 7 0 01-14 0v-2" />
      <line x1="12" y1="19" x2="12" y2="23" />
      <line x1="8" y1="23" x2="16" y2="23" />
    </svg>
  );
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

  const micColor = isXarkListening
    ? colors.cyan
    : isListening
      ? colors.white
      : textColor(0.3);

  return (
    <>
      {/* Hidden file inputs */}
      <input ref={fileRef} type="file" className="hidden" accept="*/*" />
      <input ref={cameraRef} type="file" className="hidden" accept="image/*" capture="environment" />

      {/* ═══ TEXTAREA ZONE + MIC — at inputBottom ═══ */}
      <div
        className="fixed inset-x-0 z-20 px-6"
        style={{
          bottom: "56px",
          paddingBottom: "12px",
          background: colors.void,
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          <div
            style={{
              height: "1px",
              background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
              opacity: 0.15,
              marginBottom: "10px",
            }}
          />

          <div className="flex items-start gap-3">
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

            {/* ── Mic icon — fixed in text field ── */}
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
              className="outline-none select-none cursor-pointer"
              style={{
                flexShrink: 0,
                marginTop: "1px",
                opacity: isListening || isXarkListening ? 1 : 0.6,
                transition: `opacity ${timing.transition} ease`,
              }}
              onMouseEnter={(e) => { e.currentTarget.style.opacity = "1"; }}
              onMouseLeave={(e) => {
                if (!isListening && !isXarkListening) e.currentTarget.style.opacity = "0.6";
              }}
            >
              {isListening || isXarkListening ? (
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
              ) : (
                <MicIcon color={micColor} />
              )}
            </span>
          </div>

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

      {/* ═══ VOID FILL — reduced gap between textarea and bottom ═══ */}
      <div
        className="fixed inset-x-0 z-[19]"
        style={{
          bottom: 0,
          height: "56px",
          background: colors.void,
        }}
      />

      {/* ═══ ATTACH — left of dot, halfway to left edge ═══ */}
      <div
        className="fixed z-20"
        style={{
          bottom: layout.caretBottom,
          left: "25%",
          transform: "translate(-50%, 50%)",
        }}
      >
        <span
          role="button"
          tabIndex={0}
          onClick={handleAttachClick}
          onKeyDown={(e) => { if (e.key === "Enter") handleAttachClick(); }}
          className="cursor-pointer outline-none"
          style={{
            opacity: 0.5,
            transition: `opacity ${timing.transition} ease`,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.8"; }}
          onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.5"; }}
        >
          <AttachIcon color={colors.white} />
        </span>
      </div>

      {/* ═══ CAMERA — right of dot, halfway to right edge ═══ */}
      <div
        className="fixed z-20"
        style={{
          bottom: layout.caretBottom,
          left: "75%",
          transform: "translate(-50%, 50%)",
        }}
      >
        <span
          role="button"
          tabIndex={0}
          onClick={handleCameraClick}
          onKeyDown={(e) => { if (e.key === "Enter") handleCameraClick(); }}
          className="cursor-pointer outline-none"
          style={{
            opacity: 0.5,
            transition: `opacity ${timing.transition} ease`,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.8"; }}
          onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.5"; }}
        >
          <CameraIcon color={colors.white} />
        </span>
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
