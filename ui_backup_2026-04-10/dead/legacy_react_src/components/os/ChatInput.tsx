"use client";

// hello OS v2.0 — The Input Pill
// iMessage "+" menu. "hello" invoke surface at trailing edge.
// @hello chip + Liquid Fire gradient border = AI mode consent boundary.
// Pure E2EE messaging. Privacy-first.

import { useRef, useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { useVoiceInput } from "@/hooks/useVoiceInput";
import { useKeyboard } from "@/hooks/useKeyboard";
import { colors, text, timing, layout, opacity, textColor, surface, ink } from "@/lib/theme";

const URL_PATTERN = /https?:\/\/[^\s]+/i;
const EASE = [0.22, 1, 0.36, 1] as const;

export interface ScrapeResult {
  title: string | null;
  description: string | null;
  imageBase64: string | null;
  url: string;
}

interface ChatInputProps {
  input: string;
  onInputChange: (value: string) => void;
  onSend: () => void;
  isThinking?: boolean;
  onAttach?: () => void;
  onCamera?: () => void;
  onUrlDetected?: (url: string) => void;
  onMediaSelected?: (file: File) => void;
  /** Current pending link preview (scraped OG data), managed by parent */
  pendingLinkPreview?: ScrapeResult | null;
  /** Called when a URL is detected and scraped */
  onLinkPreviewReady?: (preview: ScrapeResult | null) => void;
  /** Called when user taps the "hello" brand button — opens HelloPanel */
  onHelloTap?: () => void;
}

// ── Minimal SVG icons ──
function AttachIcon({ color }: { color: string }) {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66l-9.2 9.19a2 2 0 01-2.83-2.83l8.49-8.48" />
    </svg>
  );
}
function CameraIcon({ color }: { color: string }) {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z" />
      <circle cx="12" cy="13" r="4" />
    </svg>
  );
}
function MicIcon({ color }: { color: string }) {
  return (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z" />
      <path d="M19 10v2a7 7 0 01-14 0v-2" />
      <line x1="12" y1="19" x2="12" y2="23" />
      <line x1="8" y1="23" x2="16" y2="23" />
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
  onMediaSelected,
  pendingLinkPreview,
  onLinkPreviewReady,
  onHelloTap,
}: ChatInputProps) {
  const [inputFocused, setInputFocused] = useState(false);
  const [detectedUrl, setDetectedUrl] = useState<string | null>(null);
  const [showUrlPrompt, setShowUrlPrompt] = useState(false);
  const [urlPromptDismissed, setUrlPromptDismissed] = useState(false);
  const [plusMenuOpen, setPlusMenuOpen] = useState(false);
  const [isScraping, setIsScraping] = useState(false);
  const { keyboardHeight, isKeyboardOpen } = useKeyboard();
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const cameraRef = useRef<HTMLInputElement>(null);
  const scrapeTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const lastScrapedUrl = useRef<string | null>(null);

  // ── Voice Input ──
  const {
    isListening,
    mode: voiceMode,
    transcript,
    toggleDictation,
    stop: stopVoice,
  } = useVoiceInput();
  const isRecording = voiceMode !== "off";

  useEffect(() => {
    if (transcript) onInputChange(transcript);
  }, [transcript, onInputChange]);

  // Auto-resize textarea
  useEffect(() => {
    const ta = textareaRef.current;
    if (!ta) return;
    ta.style.height = "auto";
    ta.style.height = `${Math.min(ta.scrollHeight, 144)}px`;
  }, [input]);

  // URL detection + debounced OG scrape
  useEffect(() => {
    if (urlPromptDismissed || !input) {
      setShowUrlPrompt(false);
      if (scrapeTimerRef.current) clearTimeout(scrapeTimerRef.current);
      return;
    }
    const match = input.match(URL_PATTERN);
    if (match && match[0] !== detectedUrl) {
      setDetectedUrl(match[0]);
      setShowUrlPrompt(true);

      // Debounced scrape — 500ms after URL detected (and not already scraped)
      if (onLinkPreviewReady && match[0] !== lastScrapedUrl.current) {
        if (scrapeTimerRef.current) clearTimeout(scrapeTimerRef.current);
        scrapeTimerRef.current = setTimeout(async () => {
          const url = match![0];
          lastScrapedUrl.current = url;
          setIsScraping(true);
          try {
            const res = await fetch('/api/proxy-scrape', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ url }),
            });
            if (res.ok) {
              const data = await res.json();
              if (data.title || data.description || data.imageBase64) {
                onLinkPreviewReady({ ...data, url });
              }
            }
          } catch { /* silent — link preview is best-effort */ }
          setIsScraping(false);
        }, 500);
      }
    } else if (!match) {
      setShowUrlPrompt(false);
      if (scrapeTimerRef.current) clearTimeout(scrapeTimerRef.current);
    }
  }, [input, detectedUrl, urlPromptDismissed, onLinkPreviewReady]);

  useEffect(() => {
    if (input.trim().length === 0) {
      setUrlPromptDismissed(false);
      lastScrapedUrl.current = null;
      if (onLinkPreviewReady) onLinkPreviewReady(null);
    }
  }, [input, onLinkPreviewReady]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    // Backspace at position 0 with @hello chip → remove chip
    if (e.key === "Backspace" && ishelloMode && textareaRef.current?.selectionStart === 0) {
      e.preventDefault();
      onInputChange(input.replace(/^@hello\s*/i, ""));
      return;
    }
    if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); onSend(); }
  };

  const handleAttachClick = () => { if (onAttach) onAttach(); else fileRef.current?.click(); };
  const handleCameraClick = () => { if (onCamera) onCamera(); else cameraRef.current?.click(); };
  const handleMicTap = () => {
    if (isRecording) { stopVoice(); return; }
    toggleDictation();
  };

  // Close plus menu when typing starts
  useEffect(() => {
    if (input.trim().length > 0) setPlusMenuOpen(false);
  }, [input]);

  const hasText = input.trim().length > 0;
  const ishelloMode = input.toLowerCase().startsWith("@hello");
  // For display: strip the @hello prefix from the textarea when chip is shown
  const displayInput = ishelloMode ? input.replace(/^@hello\s*/i, "") : input;
  const hasQuery = ishelloMode ? displayInput.trim().length > 0 : hasText;

  return (
    <>
      <input ref={fileRef} type="file" className="hidden" accept="image/*,video/*" onChange={(e) => {
        const file = e.target.files?.[0];
        if (file && onMediaSelected) onMediaSelected(file);
        e.target.value = "";
      }} />
      <input ref={cameraRef} type="file" className="hidden" accept="image/*" capture="environment" onChange={(e) => {
        const file = e.target.files?.[0];
        if (file && onMediaSelected) onMediaSelected(file);
        e.target.value = "";
      }} />

      <div
        className="fixed inset-x-0"
        style={{
          zIndex: 20,
          bottom: isKeyboardOpen ? `${keyboardHeight}px` : "max(env(safe-area-inset-bottom), 12px)",
          paddingTop: "8px",
          paddingBottom: "8px",
          transition: "bottom 0.2s ease",
          transform: "translateZ(0)",
          WebkitTransform: "translateZ(0)",
        }}
      >
        <div className="mx-auto px-4" style={{ maxWidth: "640px" }}>

          {/* ── Recording Banner ── */}
          {isRecording && (
            <div className="flex items-center justify-between mb-3" style={{ opacity: 0.9 }}>
              <div className="flex items-center gap-3">
                <div style={{
                  width: "8px", height: "8px", borderRadius: "50%",
                  backgroundColor: colors.orange,
                  animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                }} />
                <span style={{ ...text.subtitle, color: colors.white, letterSpacing: "0.08em" }}>
                  listening...
                </span>
              </div>
              <span
                role="button" tabIndex={0}
                onClick={stopVoice}
                className="cursor-pointer outline-none flex items-center gap-2"
                style={{ ...text.subtitle, color: colors.orange, opacity: 0.8 }}
              >
                <StopIcon color={colors.orange} />
                stop
              </span>
            </div>
          )}

          {/* ── Link Preview Mini Card (above input pill) ── */}
          {(pendingLinkPreview || isScraping) && (
            <div
              style={{
                marginBottom: "8px",
                borderRadius: "12px",
                background: surface.recessed,
                padding: "8px 10px",
                display: "flex",
                alignItems: "center",
                gap: "8px",
                position: "relative",
              }}
            >
              {isScraping && !pendingLinkPreview && (
                <span style={{ fontSize: "12px", fontWeight: 300, color: ink.tertiary }}>
                  fetching preview...
                </span>
              )}
              {pendingLinkPreview && (
                <>
                  {pendingLinkPreview.imageBase64 && (
                    <img
                      src={pendingLinkPreview.imageBase64}
                      alt=""
                      style={{
                        width: "40px",
                        height: "40px",
                        borderRadius: "6px",
                        objectFit: "cover",
                        flexShrink: 0,
                      }}
                    />
                  )}
                  <div style={{ flex: 1, minWidth: 0 }}>
                    {pendingLinkPreview.title && (
                      <div style={{
                        fontSize: "12px",
                        fontWeight: 400,
                        color: ink.primary,
                        overflow: "hidden",
                        textOverflow: "ellipsis",
                        whiteSpace: "nowrap",
                      }}>
                        {pendingLinkPreview.title}
                      </div>
                    )}
                    <div style={{
                      fontSize: "10px",
                      fontWeight: 300,
                      color: ink.tertiary,
                      overflow: "hidden",
                      textOverflow: "ellipsis",
                      whiteSpace: "nowrap",
                    }}>
                      {(() => { try { return new URL(pendingLinkPreview.url).hostname; } catch { return pendingLinkPreview.url; } })()}
                    </div>
                  </div>
                  <button
                    onClick={() => onLinkPreviewReady?.(null)}
                    style={{
                      background: "none",
                      border: "none",
                      padding: "4px",
                      cursor: "pointer",
                      color: ink.tertiary,
                      fontSize: "16px",
                      lineHeight: 1,
                      flexShrink: 0,
                    }}
                  >
                    &times;
                  </button>
                </>
              )}
            </div>
          )}

          {/* ═══ THE INPUT PILL — with Liquid Fire gradient border in @hello mode ═══ */}
          <div style={{ position: "relative" }}>
            {/* Gradient border layer — only visible in @hello mode */}
            {ishelloMode && (
              <div
                className="hello-bg-led"
                style={{
                  position: "absolute",
                  inset: "-2px",
                  borderRadius: "26px",
                  zIndex: 0,
                  opacity: 0.8,
                }}
              />
            )}

            <div
              className="flex items-center gap-2 relative"
              style={{
                zIndex: 1,
                backgroundColor: surface.recessed,
                borderRadius: "24px",
                padding: "8px 14px",
                transform: "translateZ(0)",
                WebkitTransform: "translateZ(0)",
              }}
            >
              {/* ── "+" button (no text entered, not in hello mode) ── */}
              {!hasText && !ishelloMode && (
                <div style={{ flexShrink: 0, position: "relative" }}>
                  <span
                    role="button" tabIndex={0}
                    onClick={() => setPlusMenuOpen((p) => !p)}
                    className="cursor-pointer outline-none flex items-center justify-center"
                    style={{
                      width: "30px", height: "30px", borderRadius: "50%",
                      backgroundColor: "rgba(0,0,0,0.12)",
                      color: ink.primary,
                      fontSize: "20px", fontWeight: 300, lineHeight: 1,
                    }}
                  >
                    +
                  </span>
                </div>
              )}

              {/* ── @hello chip (visible when in AI mode) ── */}
              {ishelloMode && (
                <motion.div
                  initial={{ opacity: 0, scale: 0.85 }}
                  animate={{ opacity: 1, scale: 1 }}
                  exit={{ opacity: 0, scale: 0.85 }}
                  transition={{ duration: 0.15 }}
                  style={{
                    flexShrink: 0,
                    display: "flex",
                    alignItems: "center",
                    gap: "4px",
                    backgroundColor: "#FDF0EE",
                    borderRadius: "8px",
                    padding: "4px 10px",
                    marginBottom: "1px",
                  }}
                >
                  <span className="liquid-brand-text" style={{
                    fontSize: "13px",
                    fontWeight: 400,
                    letterSpacing: "0.02em",
                  }}>
                    @hello
                  </span>
                  <span
                    role="button" tabIndex={0}
                    onClick={() => onInputChange(input.replace(/^@hello\s*/i, ""))}
                    style={{
                      fontSize: "12px",
                      color: "#FF6B35",
                      cursor: "pointer",
                      opacity: 0.6,
                      lineHeight: 1,
                    }}
                  >
                    ×
                  </span>
                </motion.div>
              )}

              {/* ── Textarea ── */}
              <textarea
                ref={textareaRef}
                value={ishelloMode ? input.replace(/^@hello\s*/i, "") : input}
                onChange={(e) => {
                  const val = e.target.value;
                  onInputChange(ishelloMode ? "@hello " + val : val);
                }}
                onKeyDown={handleKeyDown}
                placeholder={ishelloMode ? "ask hello anything..." : isListening ? "listening..." : "message..."}
                disabled={isThinking}
                enterKeyHint="send"
                spellCheck={false}
                autoComplete="off"
                autoCapitalize="sentences"
                autoCorrect="on"
                rows={1}
                onFocus={() => { setInputFocused(true); setPlusMenuOpen(false); }}
                onBlur={() => setInputFocused(false)}
                className="resize-none bg-transparent outline-none"
                style={{
                  flex: 1,
                  minWidth: 0,
                  fontSize: "16px",
                  fontWeight: 400,
                  letterSpacing: "0.02em",
                  color: ishelloMode ? "#FF6B35" : colors.white,
                  caretColor: ishelloMode ? "#FF6B35" : colors.accent,
                  opacity: isThinking ? 0.3 : 1,
                  lineHeight: 1.5,
                  maxHeight: "144px",
                  overflow: "hidden",
                }}
              />

              {/* ── Right element: hello (idle) → send (typing) ── */}
              <AnimatePresence mode="wait">
                {hasText || ishelloMode ? (
                  <motion.span
                    key="send"
                    role="button" tabIndex={0}
                    onClick={onSend}
                    onKeyDown={(e) => { if (e.key === "Enter") onSend(); }}
                    className="outline-none cursor-pointer select-none"
                    style={{
                      flexShrink: 0,
                      fontSize: "14px",
                      fontWeight: 400,
                      letterSpacing: "0.06em",
                      color: colors.accent,
                    }}
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 0.9, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.8 }}
                    transition={{ duration: 0.15, ease: EASE }}
                  >
                    send
                  </motion.span>
                ) : (
                  <motion.span
                    key="hello"
                    role="button" tabIndex={0}
                    onClick={() => {
                      if (onHelloTap) {
                        onHelloTap();
                      } else {
                        onInputChange("@hello ");
                        textareaRef.current?.focus();
                      }
                    }}
                    className="hello-text-led outline-none select-none cursor-pointer"
                    style={{
                      flexShrink: 0,
                      fontSize: "18px",
                      fontWeight: 400,
                      letterSpacing: "-0.02em",
                      padding: "4px 2px",
                      WebkitTapHighlightColor: "transparent",
                    }}
                    initial={{ opacity: 0, scale: 0.8 }}
                    animate={{ opacity: 1, scale: 1 }}
                    exit={{ opacity: 0, scale: 0.8 }}
                    transition={{ duration: 0.15, ease: EASE }}
                    whileTap={{ scale: 0.9 }}
                  >
                    hello
                  </motion.span>
                )}
              </AnimatePresence>
            </div>
          </div>

          {/* ── Horizontal "+" Tray — slides up from pill ── */}
          <AnimatePresence>
            {plusMenuOpen && (
              <motion.div
                initial={{ opacity: 0, y: 12 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: 12 }}
                transition={{ duration: 0.2 }}
                className="flex items-center justify-center gap-6"
                style={{
                  marginTop: "10px",
                  padding: "12px 0",
                }}
              >
                {[
                  { icon: <AttachIcon color={ink.secondary} />, label: "file", action: () => { handleAttachClick(); setPlusMenuOpen(false); } },
                  { icon: <CameraIcon color={ink.secondary} />, label: "photo", action: () => { handleCameraClick(); setPlusMenuOpen(false); } },
                  { icon: <MicIcon color={ink.secondary} />, label: "voice", action: () => { handleMicTap(); setPlusMenuOpen(false); } },
                ].map((item) => (
                  <span
                    key={item.label}
                    role="button" tabIndex={0}
                    onClick={item.action}
                    className="cursor-pointer outline-none flex flex-col items-center gap-1"
                    style={{ minWidth: "56px" }}
                  >
                    <div style={{
                      width: "48px", height: "48px", borderRadius: "50%",
                      backgroundColor: surface.recessed,
                      display: "flex", alignItems: "center", justifyContent: "center",
                    }}>
                      {item.icon}
                    </div>
                    <span style={{ fontSize: "10px", fontWeight: 400, color: ink.tertiary, letterSpacing: "0.04em" }}>
                      {item.label}
                    </span>
                  </span>
                ))}
              </motion.div>
            )}
          </AnimatePresence>

          {/* ── URL detection prompt ── */}
          {showUrlPrompt && detectedUrl && (
            <div style={{ display: "flex", alignItems: "center", gap: 12, marginTop: 6 }}>
              <span style={{ ...text.timestamp, color: ink.secondary }}>add to decisions?</span>
              <span
                role="button" tabIndex={0}
                onClick={() => { onUrlDetected?.(detectedUrl); setShowUrlPrompt(false); setUrlPromptDismissed(true); }}
                style={{ ...text.timestamp, color: colors.accent, cursor: "pointer", opacity: 0.7 }}
              >yes</span>
              <span
                role="button" tabIndex={0}
                onClick={() => { setShowUrlPrompt(false); setUrlPromptDismissed(true); }}
                style={{ ...text.timestamp, color: ink.tertiary, cursor: "pointer" }}
              >no</span>
            </div>
          )}
        </div>
      </div>

      {/* ═══ AMBIENT FLOOR ═══ */}
      <div
        className="fixed inset-x-0 pointer-events-none"
        style={{
          zIndex: 19,
          bottom: "-100px",
          height: isKeyboardOpen ? "0px" : "200px",
          background: `linear-gradient(to top, ${surface.canvas} 0%, ${surface.canvas} 50%, transparent)`,
          transition: "height 0.2s ease",
          transform: "translateZ(0)",
          WebkitTransform: "translateZ(0)",
        }}
      />

      <style jsx>{`
        textarea::placeholder {
          color: var(--hello-ink-tertiary);
          opacity: 1;
          letter-spacing: 0.04em;
        }
      `}</style>
    </>
  );
}
