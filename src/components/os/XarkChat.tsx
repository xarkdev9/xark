"use client";

import { useState, useRef, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  buildGroundingContext,
  generateGroundingPrompt,
  getGreeting,
} from "@/lib/ai-grounding";
import type { GroundingContext } from "@/lib/ai-grounding";
import { useHandshake } from "@/hooks/useHandshake";
import { useAuth } from "@/hooks/useAuth";
import { useVoiceInput } from "@/hooks/useVoiceInput";
import {
  fetchMessages,
  saveMessage,
  subscribeToMessages,
  unsubscribeFromMessages,
} from "@/lib/messages";
import { colors, opacity, timing, layout, text, fovealOpacity } from "@/lib/theme";

interface Message {
  id: string;
  role: "user" | "xark";
  content: string;
  timestamp: number;
  senderName?: string;
}

interface XarkChatProps {
  spaceId: string;
  userId?: string;
  spaceTitle?: string;
}

// ── Sanctuary mapping — sender name → private space ID ──
const SANCTUARY_MAP: Record<string, string> = {
  ananya: "space_ananya",
};

// ── Demo messages — used when Supabase is unreachable ──
const DEMO_GROUP_MESSAGES: Record<string, Message[]> = {
  "space_san-diego": [
    { id: "d1", role: "user", content: "alright who's looking into hotels?", timestamp: Date.now() - 600000, senderName: "ram" },
    { id: "d2", role: "user", content: "i found a few near coronado beach", timestamp: Date.now() - 540000, senderName: "ananya" },
    { id: "d3", role: "xark", content: "hotel del coronado fits the group's vibe — beachfront, historic, within budget range. coronado island marriott is bayfront, lower price.", timestamp: Date.now() - 480000 },
    { id: "d4", role: "user", content: "what about the price though?", timestamp: Date.now() - 420000, senderName: "ram" },
    { id: "d5", role: "user", content: "450 a night but the beach access is worth it", timestamp: Date.now() - 360000, senderName: "ananya" },
    { id: "d6", role: "user", content: "i'm in for hotel del", timestamp: Date.now() - 300000, senderName: "ram" },
    { id: "d7", role: "user", content: "same. let's lock it", timestamp: Date.now() - 240000, senderName: "ananya" },
    { id: "d8", role: "xark", content: "consensus reached on hotel del coronado. locked with confirmation HDC-29441.", timestamp: Date.now() - 180000 },
    { id: "d9", role: "user", content: "locked. what activities are we doing?", timestamp: Date.now() - 120000, senderName: "ram" },
    { id: "d10", role: "user", content: "i proposed surf lessons at la jolla — check it out", timestamp: Date.now() - 60000, senderName: "ananya" },
  ],
};

const DEMO_SANCTUARY_MESSAGES: Record<string, Message[]> = {
  "space_ananya": [
    { id: "s1", role: "user", content: "hey, are you excited about the trip?", timestamp: Date.now() - 1800000, senderName: "ananya" },
    { id: "s2", role: "user", content: "so excited. finally getting the whole group together", timestamp: Date.now() - 1680000 },
    { id: "s3", role: "user", content: "i've been looking at activities near la jolla", timestamp: Date.now() - 1200000, senderName: "ananya" },
    { id: "s4", role: "user", content: "the kayaking looks amazing, those sea caves", timestamp: Date.now() - 900000 },
    { id: "s5", role: "user", content: "did you see the surf lesson proposal?", timestamp: Date.now() - 300000, senderName: "ananya" },
  ],
};

export function XarkChat({ spaceId, userId, spaceTitle }: XarkChatProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState("");
  const [isThinking, setIsThinking] = useState(false);
  const [inputFocused, setInputFocused] = useState(false);
  const [groundingContext, setGroundingContext] =
    useState<GroundingContext | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  // ── Sanctuary Bridge state ──
  const [sanctuaryOpen, setSanctuaryOpen] = useState(false);
  const [sanctuaryName, setSanctuaryName] = useState("");
  const [sanctuaryMessages, setSanctuaryMessages] = useState<Message[]>([]);

  // ── Firebase Auth — falls back to URL name param ──
  const { user } = useAuth(userId);
  const resolvedUserId = user?.uid ?? userId ?? "anonymous";

  // ── Handshake Protocol — silent until consensus ignites ──
  const { proposal, whisper, confirm, dismiss, isCommitting, goldBurst } =
    useHandshake(spaceId);

  // ── Voice Input — tap: on-device, long-press: @xark mode ──
  const { isListening, isXarkListening, transcript, startListening, startXarkListening, stopListening } =
    useVoiceInput();
  const longPressRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  // Populate input when voice transcript arrives
  useEffect(() => {
    if (transcript) {
      setInput(transcript);
    }
  }, [transcript]);

  // ── Load persisted messages from Supabase Postgres on mount ──
  useEffect(() => {
    fetchMessages(spaceId)
      .then((persisted) => {
        if (persisted.length > 0) {
          setMessages(
            persisted.map((m) => ({
              id: m.id,
              role: m.role,
              content: m.content,
              timestamp: new Date(m.created_at).getTime(),
              senderName: m.sender_name ?? undefined,
            }))
          );
        } else {
          setMessages(DEMO_GROUP_MESSAGES[spaceId] ?? []);
        }
      })
      .catch(() => {
        setMessages(DEMO_GROUP_MESSAGES[spaceId] ?? []);
      });
  }, [spaceId]);

  // ── Supabase Realtime — live message sync across devices ──
  useEffect(() => {
    const channel = subscribeToMessages(spaceId, (incoming) => {
      setMessages((prev) => {
        if (prev.some((m) => m.id === incoming.id)) return prev;
        return [
          ...prev,
          {
            id: incoming.id,
            role: incoming.role,
            content: incoming.content,
            timestamp: new Date(incoming.created_at).getTime(),
            senderName: incoming.sender_name ?? undefined,
          },
        ];
      });
    });

    return () => unsubscribeFromMessages(channel);
  }, [spaceId]);

  // Load grounding context on mount
  useEffect(() => {
    buildGroundingContext(spaceId)
      .then(setGroundingContext)
      .catch(() => {});
  }, [spaceId]);

  // Auto-scroll
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, isThinking, proposal]);

  // ── Inject handshake whisper into message stream ──
  useEffect(() => {
    if (whisper && proposal) {
      const handshakeMsg: Message = {
        id: `handshake-${proposal.itemId}`,
        role: "xark",
        content: whisper,
        timestamp: proposal.timestamp,
      };
      setMessages((prev) => {
        if (prev.some((m) => m.id === handshakeMsg.id)) return prev;
        return [...prev, handshakeMsg];
      });
    }
  }, [whisper, proposal]);

  // ── Sanctuary Bridge — open 1:1 private stream ──
  const openSanctuary = useCallback(
    async (name: string) => {
      const sanctuarySpaceId = SANCTUARY_MAP[name.toLowerCase()];
      if (!sanctuarySpaceId) return;

      setSanctuaryName(name);
      setSanctuaryOpen(true);

      try {
        const persisted = await fetchMessages(sanctuarySpaceId);
        if (persisted.length > 0) {
          setSanctuaryMessages(
            persisted.map((m) => ({
              id: m.id,
              role: m.role,
              content: m.content,
              timestamp: new Date(m.created_at).getTime(),
              senderName: m.sender_name ?? undefined,
            }))
          );
        } else {
          setSanctuaryMessages(DEMO_SANCTUARY_MESSAGES[sanctuarySpaceId] ?? []);
        }
      } catch {
        setSanctuaryMessages(DEMO_SANCTUARY_MESSAGES[sanctuarySpaceId] ?? []);
      }
    },
    []
  );

  const handleConfirm = useCallback(async () => {
    const result = await confirm(resolvedUserId);
    if (result?.success) {
      const lockMsg: Message = {
        id: crypto.randomUUID(),
        role: "xark",
        content: `locked. ${proposal?.title ?? "this decision"} is now committed.`,
        timestamp: Date.now(),
      };
      setMessages((prev) => [...prev, lockMsg]);
    }
  }, [confirm, resolvedUserId, proposal]);

  const handleDismiss = useCallback(() => {
    dismiss();
    const waitMsg: Message = {
      id: crypto.randomUUID(),
      role: "xark",
      content: "understood. keeping this open for now.",
      timestamp: Date.now(),
    };
    setMessages((prev) => [...prev, waitMsg]);
  }, [dismiss]);

  const sendMessage = useCallback(async () => {
    const txt = input.trim();
    if (!txt || isThinking) return;

    const userMsg: Message = {
      id: crypto.randomUUID(),
      role: "user",
      content: txt,
      timestamp: Date.now(),
    };

    setMessages((prev) => [...prev, userMsg]);
    setInput("");
    setIsThinking(true);

    saveMessage({
      id: userMsg.id,
      spaceId,
      role: "user",
      content: userMsg.content,
      userId: resolvedUserId,
    }).catch(() => {});

    try {
      const response = await fetch("/api/xark", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          message: txt,
          spaceId,
        }),
      });

      const data = await response.json();

      // Silent mode: @xark returns null when not invoked
      if (data.response === null) {
        setIsThinking(false);
        return;
      }

      const xarkMsg: Message = {
        id: crypto.randomUUID(),
        role: "xark",
        content: data.response ?? "i could not generate a response.",
        timestamp: Date.now(),
      };

      setMessages((prev) => [...prev, xarkMsg]);

      saveMessage({
        id: xarkMsg.id,
        spaceId,
        role: "xark",
        content: xarkMsg.content,
      }).catch(() => {});
    } catch {
      const errorMsg: Message = {
        id: crypto.randomUUID(),
        role: "xark",
        content: "connection interrupted. try again.",
        timestamp: Date.now(),
      };
      setMessages((prev) => [...prev, errorMsg]);
    } finally {
      setIsThinking(false);
    }
  }, [input, isThinking, messages, spaceId, resolvedUserId]);

  function formatTime(ts: number): string {
    return new Date(ts).toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  function senderLabel(msg: Message): string {
    if (msg.role === "xark") return "@xark";
    if (msg.senderName) return msg.senderName;
    return "you";
  }

  function hasSanctuary(name: string): boolean {
    return name.toLowerCase() in SANCTUARY_MAP;
  }

  return (
    <div className="relative flex min-h-svh flex-col">
      {/* ── Atmospheric Mesh ── */}
      <div
        className="pointer-events-none fixed inset-0"
        style={{
          background:
            "radial-gradient(ellipse 80% 60% at 50% 40%, rgba(var(--xark-accent-rgb), 0.02) 0%, transparent 60%)",
        }}
      />

      {/* ── Social Gold Burst ── */}
      {goldBurst && (
        <div
          className="pointer-events-none fixed inset-0"
          style={{
            background: `radial-gradient(circle at 50% 50%, rgba(var(--xark-gold-rgb), 0.15) 0%, rgba(var(--xark-gold-rgb), 0.05) 40%, transparent 70%)`,
            animation: "goldBurstPulse 3s ease-out forwards",
          }}
        />
      )}

      {/* ── Message Stream ── */}
      <div className="flex-1 overflow-y-auto px-6 pt-24" style={{ paddingBottom: "30vh" }}>
        {/* ── Data-driven greeting ── */}
        {messages.length === 0 && (
          <div className="mb-6" style={{ maxWidth: "640px" }}>
            <span
              style={{
                ...text.label,
                color: colors.cyan,
                opacity: 0.4,
              }}
            >
              @xark
            </span>
            <p
              className="mt-1"
              style={{
                ...text.body,
                color: colors.white,
                opacity: 0.9,
              }}
            >
              {groundingContext
                ? getGreeting(groundingContext, spaceTitle)
                : `what are we thinking for ${spaceTitle ?? "this"}? just type what's on your mind — something like "look into a few options for us" or "add an idea to the list"`}
            </p>
          </div>
        )}

        {/* ── Messages — Grouped by sender, WhatsApp-dense ── */}
        <AnimatePresence initial={false}>
          {messages.map((msg, index) => {
            const msgOpacity = fovealOpacity(index, messages.length, msg.role);
            const label = senderLabel(msg);
            const isOtherUser = msg.role === "user" && !!msg.senderName;
            const canOpenSanctuary = isOtherUser && hasSanctuary(msg.senderName!);

            const prevMsg = index > 0 ? messages[index - 1] : null;
            const sameSender = prevMsg && senderLabel(prevMsg) === label;
            const topGap = sameSender ? "mt-0.5" : index === 0 ? "" : "mt-3";

            return (
              <motion.div
                key={msg.id}
                layout
                initial={{ opacity: 0, y: 8 }}
                animate={{ opacity: 1, y: 0 }}
                transition={{
                  layout: { duration: 0.2, ease: [0.22, 1, 0.36, 1] },
                  opacity: { duration: 0.3 },
                  y: { duration: 0.3, ease: [0.22, 1, 0.36, 1] },
                }}
                className={topGap}
                style={{
                  maxWidth: "640px",
                  marginLeft: isOtherUser || msg.role === "xark" ? "0" : "auto",
                  marginRight: isOtherUser || msg.role === "xark" ? "auto" : "0",
                }}
              >
                {/* ── Role / Sender label — only on first message in a group ── */}
                {!sameSender && (
                  <span
                    role={canOpenSanctuary ? "button" : undefined}
                    tabIndex={canOpenSanctuary ? 0 : undefined}
                    onClick={
                      canOpenSanctuary
                        ? () => openSanctuary(msg.senderName!)
                        : undefined
                    }
                    onKeyDown={
                      canOpenSanctuary
                        ? (e) => {
                            if (e.key === "Enter") openSanctuary(msg.senderName!);
                          }
                        : undefined
                    }
                    className="outline-none"
                    style={{
                      ...text.label,
                      color: msg.role === "xark" ? colors.cyan : colors.white,
                      opacity: Math.min(0.35, msgOpacity),
                      cursor: canOpenSanctuary ? "pointer" : "default",
                      transition: "opacity 0.3s ease",
                    }}
                  >
                    {label}
                  </span>
                )}

                {/* ── Content + inline timestamp ── */}
                <p
                  style={{
                    ...text.body,
                    color: colors.white,
                    opacity: msgOpacity,
                    transition: "opacity 0.6s ease",
                    marginTop: sameSender ? 0 : "2px",
                  }}
                >
                  {msg.content}
                  <span
                    style={{
                      ...text.timestamp,
                      color: colors.white,
                      opacity: Math.min(0.25, msgOpacity * 0.3),
                      marginLeft: "8px",
                    }}
                  >
                    {formatTime(msg.timestamp)}
                  </span>
                </p>
              </motion.div>
            );
          })}
        </AnimatePresence>

        {/* ── Handshake Proposal ── */}
        {proposal && !isCommitting && (
          <div className="mb-4" style={{ maxWidth: "640px" }}>
            <div className="mt-2 flex items-center gap-8">
              <span
                role="button"
                tabIndex={0}
                onClick={handleConfirm}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleConfirm();
                }}
                className="outline-none"
                style={{
                  ...text.label,
                  color: colors.gold,
                  opacity: 0.9,
                  cursor: "pointer",
                  transition: `opacity ${timing.transition} ease`,
                }}
                onMouseEnter={(e) => { e.currentTarget.style.opacity = "1"; }}
                onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.9"; }}
              >
                confirm
              </span>
              <span
                role="button"
                tabIndex={0}
                onClick={handleDismiss}
                onKeyDown={(e) => {
                  if (e.key === "Enter") handleDismiss();
                }}
                className="outline-none"
                style={{
                  ...text.label,
                  color: colors.white,
                  opacity: 0.4,
                  cursor: "pointer",
                  transition: `opacity ${timing.transition} ease`,
                }}
                onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.7"; }}
                onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.4"; }}
              >
                wait
              </span>
            </div>
          </div>
        )}

        {/* ── Committing state ── */}
        {isCommitting && (
          <div className="mb-4" style={{ maxWidth: "640px" }}>
            <div className="mt-1 flex items-center gap-3">
              <div
                style={{
                  width: "6px",
                  height: "6px",
                  borderRadius: "50%",
                  backgroundColor: colors.gold,
                  animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                }}
              />
              <span
                style={{
                  ...text.hint,
                  color: colors.gold,
                  opacity: 0.4,
                  animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                }}
              >
                locking
              </span>
            </div>
          </div>
        )}

        {/* ── Thinking state ── */}
        {isThinking && (
          <div className="mb-4">
            <span
              style={{
                ...text.label,
                color: colors.cyan,
                opacity: 0.4,
              }}
            >
              @xark
            </span>
            <div className="mt-1 flex items-center gap-3">
              <div
                style={{
                  width: "6px",
                  height: "6px",
                  borderRadius: "50%",
                  backgroundColor: colors.cyan,
                  animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                }}
              />
              <span
                style={{
                  ...text.hint,
                  color: colors.cyan,
                  opacity: 0.4,
                  animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                }}
              >
                thinking
              </span>
            </div>
          </div>
        )}

        <div ref={bottomRef} />
      </div>

      {/* ── Thumb-Arc Action Zone — 96px from bottom edge (above ControlCaret zone) ── */}
      <div
        className="fixed inset-x-0 bottom-0 px-6 pt-12"
        style={{
          paddingBottom: layout.inputBottom,
          background:
            "linear-gradient(to top, rgba(var(--xark-void-rgb), 0.98) 0%, rgba(var(--xark-void-rgb), 0.7) 50%, transparent 100%)",
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          {/* ── Input + Mic ── */}
          <div className="relative flex items-center gap-3">
            <input
              type="text"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") sendMessage();
              }}
              placeholder={isXarkListening ? "@xark is listening..." : isListening ? "listening..." : "message, or @xark for ideas"}
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
            {/* ── Mic — floating text, tap: listen, long-press 500ms: @xark mode ── */}
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
                animation: inputFocused ? `ambientBreath ${timing.breath} ease-in-out infinite` : "none",
                transition: `opacity ${timing.transition} ease`,
              }}
            />
          </div>

          {groundingContext && groundingContext.forbiddenCategories.length > 0 && (
            <div
              className="mt-4"
              style={{
                ...text.recency,
                color: colors.white,
                opacity: 0.2,
              }}
            >
              grounded: {groundingContext.forbiddenCategories.join(", ")} locked
            </div>
          )}
        </div>
      </div>

      {/* ═══════════════════════════════════════════
          SANCTUARY BRIDGE — 1:1 Slide-Up Sheet
          ═══════════════════════════════════════════ */}
      <AnimatePresence>
        {sanctuaryOpen && (
          <>
            <motion.div
              className="fixed inset-0 z-40"
              style={{ background: "#000000" }}
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.8 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.3 }}
              onClick={() => setSanctuaryOpen(false)}
            />

            <motion.div
              className="fixed inset-x-0 bottom-0 z-50 overflow-y-auto px-6 pt-8 pb-12"
              style={{ maxHeight: "80vh", background: colors.void }}
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              transition={{ duration: 0.4, ease: [0.22, 1, 0.36, 1] }}
            >
              <div className="mx-auto" style={{ maxWidth: "640px" }}>
                <div className="flex items-center justify-between">
                  <span style={{ ...text.label, color: colors.cyan, opacity: 0.5 }}>
                    {sanctuaryName}
                  </span>
                  <span
                    role="button"
                    tabIndex={0}
                    onClick={() => setSanctuaryOpen(false)}
                    onKeyDown={(e) => {
                      if (e.key === "Enter") setSanctuaryOpen(false);
                    }}
                    className="cursor-pointer outline-none"
                    style={{
                      ...text.label,
                      color: colors.white,
                      opacity: 0.4,
                      transition: "opacity 0.3s ease",
                    }}
                    onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.7"; }}
                    onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.4"; }}
                  >
                    close
                  </span>
                </div>

                <div className="mt-10">
                  {sanctuaryMessages.map((msg, index) => {
                    const msgOpacity = fovealOpacity(
                      index,
                      sanctuaryMessages.length,
                      msg.role
                    );
                    const isOther = !!msg.senderName;
                    return (
                      <div
                        key={msg.id}
                        className="mb-10"
                        style={{
                          maxWidth: "540px",
                          marginLeft: isOther ? "0" : "auto",
                          marginRight: isOther ? "auto" : "0",
                        }}
                      >
                        <span
                          style={{
                            ...text.label,
                            color: colors.white,
                            opacity: Math.min(0.4, msgOpacity),
                          }}
                        >
                          {isOther ? msg.senderName : "you"}
                        </span>
                        <p
                          className="mt-2"
                          style={{
                            ...text.body,
                            color: colors.white,
                            opacity: msgOpacity,
                          }}
                        >
                          {msg.content}
                        </p>
                        <span
                          className="mt-2 inline-block"
                          style={{
                            ...text.recency,
                            color: colors.white,
                            opacity: Math.min(0.2, msgOpacity * 0.25),
                          }}
                        >
                          {formatTime(msg.timestamp)}
                        </span>
                      </div>
                    );
                  })}
                </div>
              </div>
            </motion.div>
          </>
        )}
      </AnimatePresence>

      <style jsx>{`
        input::placeholder {
          color: ${colors.white};
          opacity: ${opacity.ghost};
          letter-spacing: 0.12em;
        }
        input:focus::placeholder {
          opacity: 0;
          transition: opacity 0.8s ease;
        }
        @keyframes goldBurstPulse {
          0% { opacity: 0; transform: scale(0.8); }
          20% { opacity: 1; transform: scale(1.05); }
          100% { opacity: 0; transform: scale(1.2); }
        }
      `}</style>
    </div>
  );
}
