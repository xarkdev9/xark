"use client";

// XARK OS v2.0 — Shared Chat Input
// Textarea + mic/send toggle. 2-step mic: tap=dictation, slide up=@xark.
// Send arrow appears when text present. Mic appears when empty.

import { useRef, useState, useEffect, useCallback } from "react";
import { useVoiceInput } from "@/hooks/useVoiceInput";
import { useKeyboard } from "@/hooks/useKeyboard";
import { colors, text, timing, layout, opacity, textColor } from "@/lib/theme";

const URL_PATTERN = /https?:\/\/[^\s]+/i;

interface ChatInputProps {
  input: string;
  onInputChange: (value: string) => void;
  onSend: () => void;
  isThinking?: boolean;
  onAttach?: () => void;
  onCamera?: () => void;
  onUrlDetected?: (url: string) => void;
}

// ── Minimal SVG icons — thin stroke, atmospheric ──
function AttachIcon({ color }: { color: string }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48" />
    </svg>
  );
}

function CameraIcon({ color }: { color: string }) {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z" />
      <circle cx="12" cy="13" r="4" />
    </svg>
  );
}

function MicIcon({ color, size = 20 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <rect x="9" y="1" width="6" height="11" rx="3" />
      <path d="M19 10v2a7 7 0 01-14 0v-2" />
      <line x1="12" y1="19" x2="12" y2="23" />
      <line x1="8" y1="23" x2="16" y2="23" />
    </svg>
  );
}

function SendIcon({ color, size = 24 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="11" stroke={color} strokeWidth="1.5" />
      <path d="M12 16V8M12 8l-4 4M12 8l4 4" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function StopIcon({ color, size = 16 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={color}>
      <rect x="4" y="4" width="16" height="16" rx="2" />
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
  onUrlDetected,
}: ChatInputProps) {
  const [inputFocused, setInputFocused] = useState(false);
  const [detectedUrl, setDetectedUrl] = useState<string | null>(null);
  const [showUrlPrompt, setShowUrlPrompt] = useState(false);
  const [urlPromptDismissed, setUrlPromptDismissed] = useState(false);
  const { keyboardHeight, isKeyboardOpen } = useKeyboard();
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const cameraRef = useRef<HTMLInputElement>(null);
  const micAreaRef = useRef<HTMLDivElement>(null);
  const dragStartY = useRef<number | null>(null);

  // ── Voice Input — 2-step ──
  const {
    isListening,
    isXarkListening,
    mode: voiceMode,
    transcript,
    toggleDictation,
    startXarkMode,
    stop: stopVoice,
  } = useVoiceInput();

  const isRecording = voiceMode !== "off";

  useEffect(() => {
    if (transcript) onInputChange(transcript);
  }, [transcript, onInputChange]);

  // ── Auto-resize textarea (max ~6 lines) ──
  const autoResize = useCallback(() => {
    const el = textareaRef.current;
    if (!el) return;
    el.style.height = "auto";
    el.style.height = `${Math.min(el.scrollHeight, 144)}px`;
  }, []);

  useEffect(() => {
    autoResize();
  }, [input, autoResize]);

  // ── URL detection ──
  useEffect(() => {
    if (urlPromptDismissed) return;
    const match = input.match(URL_PATTERN);
    if (match) {
      setDetectedUrl(match[0]);
      setShowUrlPrompt(true);
    } else {
      setDetectedUrl(null);
      setShowUrlPrompt(false);
    }
  }, [input, urlPromptDismissed]);

  // ── Reset URL prompt dismissed when input clears ──
  useEffect(() => {
    if (input.trim().length === 0) {
      setUrlPromptDismissed(false);
    }
  }, [input]);

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

  // ── Mic slide-up gesture for @xark mode ──
  const handleMicPointerDown = (e: React.PointerEvent) => {
    if (isRecording) {
      // Already recording — stop on any tap
      stopVoice();
      return;
    }
    dragStartY.current = e.clientY;
  };

  const handleMicPointerUp = (e: React.PointerEvent) => {
    if (dragStartY.current === null) return;
    const deltaY = dragStartY.current - e.clientY;
    dragStartY.current = null;

    if (deltaY > 40) {
      // Slide up detected — @xark mode
      startXarkMode();
    } else {
      // Regular tap — dictation
      toggleDictation();
    }
  };

  const hasText = input.trim().length > 0;

  // Recording state colors
  const recordingBorderColor = isXarkListening ? colors.cyan : colors.orange;

  return (
    <>
      {/* Hidden file inputs */}
      <input ref={fileRef} type="file" className="hidden" accept="*/*" />
      <input ref={cameraRef} type="file" className="hidden" accept="image/*" capture="environment" />

      {/* ═══ TEXTAREA ZONE — at inputBottom ═══ */}
      <div
        className="fixed inset-x-0 z-20 px-6"
        style={{
          bottom: isKeyboardOpen ? `${keyboardHeight}px` : "56px",
          paddingBottom: "12px",
          background: colors.void,
          transition: "bottom 0.2s ease",
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          {/* ── Top line ── */}
          <div
            style={{
              height: "1px",
              background: isRecording
                ? `linear-gradient(90deg, transparent, ${recordingBorderColor}, transparent)`
                : `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
              opacity: isRecording ? 0.5 : 0.15,
              marginBottom: "10px",
              transition: "opacity 0.3s ease",
            }}
          />

          {/* ── Recording Banner — unmissable ── */}
          {isRecording && (
            <div
              className="flex items-center justify-between mb-2"
              style={{ opacity: 0.9 }}
            >
              <div className="flex items-center gap-3">
                <div
                  style={{
                    width: "8px",
                    height: "8px",
                    borderRadius: "50%",
                    backgroundColor: isXarkListening ? colors.cyan : colors.orange,
                    animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                  }}
                />
                <span
                  style={{
                    ...text.subtitle,
                    color: isXarkListening ? colors.cyan : colors.white,
                    letterSpacing: "0.08em",
                  }}
                >
                  {isXarkListening ? "@xark listening..." : "listening..."}
                </span>
              </div>
              <span
                role="button"
                tabIndex={0}
                onClick={stopVoice}
                onKeyDown={(e) => { if (e.key === "Enter") stopVoice(); }}
                className="cursor-pointer outline-none flex items-center gap-2"
                style={{
                  ...text.subtitle,
                  color: isXarkListening ? colors.cyan : colors.orange,
                  opacity: 0.8,
                }}
              >
                <StopIcon color={isXarkListening ? colors.cyan : colors.orange} />
                stop
              </span>
            </div>
          )}

          <div className="flex items-end gap-3">
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
              enterKeyHint="send"
              spellCheck={false}
              autoComplete="off"
              autoCapitalize="sentences"
              autoCorrect="on"
              rows={1}
              onFocus={() => setInputFocused(true)}
              onBlur={() => setInputFocused(false)}
              className="w-full resize-none bg-transparent outline-none"
              style={{
                ...text.input,
                color: colors.white,
                caretColor: colors.cyan,
                backgroundColor: "var(--xark-void)",
                opacity: isThinking ? 0.3 : 1,
                lineHeight: 1.5,
                maxHeight: "144px",
                overflow: "hidden",
                colorScheme: "light",
              }}
            />

            {/* ── Right icon: Send arrow OR Mic ── */}
            {hasText ? (
              <span
                role="button"
                tabIndex={0}
                onClick={onSend}
                onKeyDown={(e) => { if (e.key === "Enter") onSend(); }}
                className="outline-none cursor-pointer select-none"
                style={{
                  flexShrink: 0,
                  marginBottom: "2px",
                  opacity: 0.8,
                  transition: `opacity ${timing.transition} ease`,
                }}
                onMouseEnter={(e) => { e.currentTarget.style.opacity = "1"; }}
                onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.8"; }}
              >
                <SendIcon color={colors.cyan} />
              </span>
            ) : (
              <div
                ref={micAreaRef}
                role="button"
                tabIndex={0}
                onPointerDown={handleMicPointerDown}
                onPointerUp={handleMicPointerUp}
                className="outline-none select-none cursor-pointer"
                style={{
                  flexShrink: 0,
                  marginBottom: "2px",
                  opacity: isRecording ? 1 : 0.5,
                  transition: `opacity ${timing.transition} ease`,
                  touchAction: "none",
                }}
                onMouseEnter={(e) => { if (!isRecording) e.currentTarget.style.opacity = "0.8"; }}
                onMouseLeave={(e) => { if (!isRecording) e.currentTarget.style.opacity = "0.5"; }}
              >
                {isRecording ? (
                  <div
                    style={{
                      width: "20px",
                      height: "20px",
                      borderRadius: "50%",
                      backgroundColor: isXarkListening ? colors.cyan : colors.orange,
                      animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                    }}
                  />
                ) : (
                  <MicIcon color={textColor(0.5)} />
                )}
              </div>
            )}
          </div>

          {/* ── Mic hint — slide up for @xark ── */}
          {!isRecording && !hasText && (
            <p
              style={{
                ...text.timestamp,
                color: textColor(0.15),
                marginTop: "6px",
                textAlign: "right",
              }}
            >
              slide mic up for @xark
            </p>
          )}

          {/* ── Ambient line — lives below text only, breathes when focused ── */}
          <div
            style={{
              marginTop: "4px",
              height: "1px",
              width: input.length > 0
                ? `min(${Math.max(input.length * 6, 40)}px, 100%)`
                : inputFocused ? "60px" : "0px",
              background: isRecording
                ? `linear-gradient(90deg, ${recordingBorderColor}, transparent)`
                : `linear-gradient(90deg, ${colors.cyan}, transparent)`,
              opacity: isRecording ? 0.5 : input.length > 0 ? 0.4 : 0.2,
              animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
              transition: `width 0.3s ease, opacity ${timing.transition} ease`,
            }}
          />

          {/* ── URL detection prompt ── */}
          {showUrlPrompt && detectedUrl && (
            <div style={{ display: "flex", alignItems: "center", gap: 12, marginTop: 6 }}>
              <span style={{ ...text.timestamp, color: textColor(0.4) }}>
                add to decisions?
              </span>
              <span
                role="button"
                tabIndex={0}
                onClick={() => {
                  onUrlDetected?.(detectedUrl);
                  setShowUrlPrompt(false);
                  setUrlPromptDismissed(true);
                }}
                style={{ ...text.timestamp, color: colors.cyan, cursor: "pointer", opacity: 0.7 }}
              >
                yes
              </span>
              <span
                role="button"
                tabIndex={0}
                onClick={() => {
                  setShowUrlPrompt(false);
                  setUrlPromptDismissed(true);
                }}
                style={{ ...text.timestamp, color: textColor(0.3), cursor: "pointer" }}
              >
                no
              </span>
            </div>
          )}
        </div>
      </div>

      {/* ═══ VOID FILL ═══ */}
      <div
        className="fixed inset-x-0 z-[19]"
        style={{
          bottom: 0,
          height: isKeyboardOpen ? "0px" : "56px",
          background: colors.void,
          transition: "height 0.2s ease",
        }}
      />

      {/* ═══ ATTACH — left of dot ═══ */}
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
            opacity: 0.4,
            transition: `opacity ${timing.transition} ease`,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.7"; }}
          onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.4"; }}
        >
          <AttachIcon color={colors.white} />
        </span>
      </div>

      {/* ═══ CAMERA — right of dot ═══ */}
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
            opacity: 0.4,
            transition: `opacity ${timing.transition} ease`,
          }}
          onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.7"; }}
          onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.4"; }}
        >
          <CameraIcon color={colors.white} />
        </span>
      </div>

      <style jsx>{`
        textarea::placeholder {
          color: ${colors.white};
          opacity: ${opacity.ghost};
          letter-spacing: 0.04em;
        }
      `}</style>
    </>
  );
}
