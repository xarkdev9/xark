"use client";

// XARK OS v2.0 — Chat Display (Display-Only)
// Message stream with avatars + visual hierarchy (name vs message).
// No input, no fetch, no send — state lives in Space page.

import { useRef, useState, useEffect, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import {
  buildGroundingContext,
  getGreeting,
} from "@/lib/ai-grounding";
import type { GroundingContext } from "@/lib/ai-grounding";
import { useHandshake } from "@/hooks/useHandshake";
import { fetchMessages } from "@/lib/messages";
import {
  colors,
  opacity,
  timing,
  layout,
  text,
  fovealOpacity,
  textColor,
} from "@/lib/theme";
import { Avatar } from "@/components/os/Avatar";
import { LedgerPill } from "@/components/os/LedgerPill";
import type { LedgerEvent } from "@/components/os/LedgerPill";
import type { ChatMessage } from "@/app/space/[id]/page";

interface XarkChatProps {
  spaceId: string;
  spaceTitle?: string;
  messages: ChatMessage[];
  isThinking?: boolean;
  e2eeActive?: boolean;
  ledgerEvents?: LedgerEvent[];
  onLedgerUndo?: (ledgerId: string, action: string, previous: Record<string, unknown>) => void;
}

// ── Sanctuary mapping — sender name → private space ID ──
const SANCTUARY_MAP: Record<string, string> = {
  ananya: "space_ananya",
};

export function XarkChat({
  spaceId,
  spaceTitle,
  messages,
  isThinking,
  e2eeActive,
  ledgerEvents,
  onLedgerUndo,
}: XarkChatProps) {
  const [groundingContext, setGroundingContext] =
    useState<GroundingContext | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  // ── Sanctuary Bridge state ──
  const [sanctuaryOpen, setSanctuaryOpen] = useState(false);
  const [sanctuaryName, setSanctuaryName] = useState("");
  const [sanctuaryMessages, setSanctuaryMessages] = useState<ChatMessage[]>([]);

  // ── Handshake Protocol — silent until consensus ignites ──
  const { proposal, whisper, confirm, dismiss, isCommitting, goldBurst } =
    useHandshake(spaceId);

  // Load grounding context
  useEffect(() => {
    buildGroundingContext(spaceId)
      .then(setGroundingContext)
      .catch(() => {});
  }, [spaceId]);

  // Auto-scroll
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages, isThinking, proposal]);

  // ── Inject handshake whisper into display ──
  const allMessages = [...messages];
  if (whisper && proposal) {
    const handshakeId = `handshake-${proposal.itemId}`;
    if (!allMessages.some((m) => m.id === handshakeId)) {
      allMessages.push({
        id: handshakeId,
        role: "xark",
        content: whisper,
        timestamp: proposal.timestamp,
      });
    }
  }

  const handleConfirm = useCallback(async () => {
    const result = await confirm("");
    if (result?.success) {
      // Gold burst handled by useHandshake
    }
  }, [confirm]);

  const handleDismiss = useCallback(() => {
    dismiss();
  }, [dismiss]);

  // ── Sanctuary Bridge ──
  const openSanctuary = useCallback(
    async (name: string) => {
      const sanctuarySpaceId =
        SANCTUARY_MAP[name.toLowerCase()];
      if (!sanctuarySpaceId) return;
      setSanctuaryName(name);
      setSanctuaryOpen(true);
      try {
        const msgs = await fetchMessages(sanctuarySpaceId, { limit: 30 });
        if (msgs.length > 0) {
          setSanctuaryMessages(
            msgs.map((m) => ({
              id: m.id,
              role: m.role,
              content: m.content,
              timestamp: new Date(m.created_at).getTime(),
              senderName: m.sender_name ?? undefined,
            }))
          );
        }
      } catch {
        // Silent
      }
    },
    []
  );

  function formatTime(ts: number): string {
    return new Date(ts).toLocaleTimeString([], {
      hour: "2-digit",
      minute: "2-digit",
    });
  }

  function senderLabel(msg: ChatMessage): string {
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

      {/* ── E2EE indicator ── */}
      {e2eeActive && (
        <div
          className="fixed z-20 flex items-center gap-1.5"
          style={{
            top: "120px",
            right: "24px",
            opacity: 0.35,
          }}
        >
          <svg width="10" height="12" viewBox="0 0 10 12" fill="none">
            <rect x="0.5" y="5.5" width="9" height="6" rx="1" stroke={colors.green} strokeWidth="1" />
            <path d="M3 5.5V3.5C3 2.12 3.9 1 5 1C6.1 1 7 2.12 7 3.5V5.5" stroke={colors.green} strokeWidth="1" strokeLinecap="round" />
          </svg>
          <span style={{ ...text.timestamp, color: colors.green }}>
            encrypted
          </span>
        </div>
      )}

      {/* ── Message Stream ── */}
      <div
        className="flex-1 overflow-y-auto px-6"
        style={{
          paddingTop: "140px",
          paddingBottom: "160px",
          display: "flex",
          flexDirection: "column",
        }}
      >
        {/* ── Spacer pushes greeting toward bottom when stream is empty ── */}
        {allMessages.length === 0 && <div style={{ flex: 1 }} />}

        {/* ── Messages — Grouped by sender, WhatsApp-dense, with avatars ── */}
        <AnimatePresence initial={false}>
          {(() => {
            // Build unified timeline: messages + ledger events sorted by timestamp
            type TimelineItem =
              | { kind: "message"; msg: ChatMessage }
              | { kind: "ledger"; event: LedgerEvent };

            const timeline: (TimelineItem & { ts: number })[] = [
              ...allMessages.map((msg) => ({ kind: "message" as const, msg, ts: msg.timestamp })),
              ...(ledgerEvents ?? []).map((e) => ({ kind: "ledger" as const, event: e, ts: e.timestamp })),
            ].sort((a, b) => a.ts - b.ts);

            // For foveal opacity + grouping, we need message-only index
            const msgOnlyList = timeline.filter((t): t is typeof t & { kind: "message" } => t.kind === "message").map(t => t.msg);

            return timeline.map((item) => {
              if (item.kind === "ledger") {
                return (
                  <motion.div
                    key={`ledger-${item.event.id}`}
                    initial={{ opacity: 0, y: 4 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ opacity: { duration: 0.3 } }}
                    style={{ maxWidth: "640px", margin: "0 auto" }}
                  >
                    <LedgerPill event={item.event} onUndo={onLedgerUndo} />
                  </motion.div>
                );
              }

              const msg = item.msg;
              const index = msgOnlyList.indexOf(msg);

            // ── System messages ──
            if (msg.role === "system") {
              const sysOpacity = Math.max(
                0.15,
                fovealOpacity(index, msgOnlyList.length, "user") * 0.6
              );
              return (
                <motion.div
                  key={msg.id}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ opacity: { duration: 0.2 } }}
                  style={{
                    maxWidth: "640px",
                    margin: "0 auto",
                    marginTop: "14px",
                    textAlign: "center",
                  }}
                >
                  <p
                    style={{
                      ...text.subtitle,
                      color: textColor(sysOpacity),
                      transition: "opacity 0.6s ease",
                    }}
                  >
                    {msg.content}
                  </p>
                </motion.div>
              );
            }

            const msgOpacity = fovealOpacity(
              index,
              msgOnlyList.length,
              msg.role as "user" | "xark"
            );
            const label = senderLabel(msg);
            const isOtherUser = msg.role === "user" && !!msg.senderName;
            const canOpenSanctuary =
              isOtherUser && hasSanctuary(msg.senderName!);

            const prevMsg = index > 0 ? msgOnlyList[index - 1] : null;
            const sameSender = prevMsg && senderLabel(prevMsg) === label;

            // Avatar: show only on first message of a group
            const showAvatar = !sameSender;
            const avatarName = msg.role === "xark" ? "xark" : (msg.senderName ?? "you");

            return (
              <motion.div
                key={msg.id}
                id={`msg-${msg.id}`}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ opacity: { duration: 0.2 } }}
                style={{
                  maxWidth: "640px",
                  marginLeft:
                    isOtherUser || msg.role === "xark" ? "0" : "auto",
                  marginRight:
                    isOtherUser || msg.role === "xark" ? "auto" : "0",
                  marginTop: sameSender ? "3px" : index === 0 ? "0px" : "14px",
                }}
              >
                {/* ── Avatar + Name row ── */}
                {showAvatar && (
                  <div className="flex items-center gap-2" style={{ marginBottom: "2px" }}>
                    {msg.role === "xark" ? (
                      <div
                        style={{
                          width: 24,
                          height: 24,
                          borderRadius: "50%",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "center",
                          backgroundColor: "rgba(var(--xark-accent-rgb), 0.12)",
                          flexShrink: 0,
                        }}
                      >
                        <div
                          style={{
                            width: 6,
                            height: 6,
                            borderRadius: "50%",
                            backgroundColor: colors.cyan,
                          }}
                        />
                      </div>
                    ) : (
                      <Avatar name={avatarName} size={24} />
                    )}

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
                              if (e.key === "Enter")
                                openSanctuary(msg.senderName!);
                            }
                          : undefined
                      }
                      className="outline-none"
                      style={{
                        fontSize: "0.8125rem",
                        fontWeight: 400,
                        lineHeight: 1.4,
                        color:
                          msg.role === "xark" ? colors.cyan : colors.amber,
                        opacity: msg.role === "xark" ? 0.7 : 0.85,
                        cursor: canOpenSanctuary ? "pointer" : "default",
                      }}
                    >
                      {label}
                    </span>
                  </div>
                )}

                {/* ── Content + inline timestamp ── */}
                <div
                  style={{
                    paddingLeft: "32px",
                  }}
                >
                  <p
                    style={{
                      ...text.subtitle,
                      color: colors.white,
                      opacity: Math.max(0.55, msgOpacity),
                      margin: 0,
                    }}
                  >
                    {(() => {
                      const msgType = msg.messageType ?? 'legacy';
                      const isE2EE = msgType === 'e2ee' || msgType === 'e2ee_xark';
                      if (isE2EE && (!msg.content || msg.content === '[decryption pending]')) {
                        return (
                          <span style={{ color: colors.green, opacity: 0.5, fontStyle: "italic" }}>
                            decrypting...
                          </span>
                        );
                      }
                      if (isE2EE && msg.content?.startsWith('[encrypted message')) {
                        return (
                          <span style={{ color: colors.green, opacity: 0.5, fontStyle: "italic" }}>
                            {msg.content}
                          </span>
                        );
                      }
                      return msg.content || null;
                    })()}
                    <span
                      style={{
                        ...text.timestamp,
                        color: colors.white,
                        opacity: 0.2,
                        marginLeft: "8px",
                      }}
                    >
                      {formatTime(msg.timestamp)}
                    </span>
                  </p>
                </div>
              </motion.div>
            );
            });
          })()}
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
                onMouseEnter={(e) => {
                  e.currentTarget.style.opacity = "1";
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.opacity = "0.9";
                }}
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
                onMouseEnter={(e) => {
                  e.currentTarget.style.opacity = "0.7";
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.opacity = "0.4";
                }}
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
            <div className="flex items-center gap-2 mb-1">
              <div
                style={{
                  width: 24,
                  height: 24,
                  borderRadius: "50%",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  backgroundColor: "rgba(var(--xark-accent-rgb), 0.12)",
                  flexShrink: 0,
                }}
              >
                <div
                  style={{
                    width: 6,
                    height: 6,
                    borderRadius: "50%",
                    backgroundColor: colors.cyan,
                    animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                  }}
                />
              </div>
              <span
                style={{
                  ...text.body,
                  color: colors.cyan,
                  opacity: 0.8,
                }}
              >
                @xark
              </span>
            </div>
            <div className="flex items-center gap-3" style={{ paddingLeft: "32px" }}>
              <span
                style={{
                  ...text.subtitle,
                  color: colors.cyan,
                  opacity: 0.4,
                  animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
                }}
              >
                thinking...
              </span>
            </div>
          </div>
        )}

        {/* ── Greeting — near input, guiding first action ── */}
        {allMessages.length === 0 && (
          <div style={{ maxWidth: "640px", marginBottom: "16px" }}>
            <div className="flex items-center gap-2 mb-1">
              <div
                style={{
                  width: 24,
                  height: 24,
                  borderRadius: "50%",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  backgroundColor: "rgba(var(--xark-accent-rgb), 0.08)",
                  flexShrink: 0,
                }}
              >
                <div
                  style={{
                    width: 6,
                    height: 6,
                    borderRadius: "50%",
                    backgroundColor: colors.cyan,
                  }}
                />
              </div>
              <span
                style={{
                  ...text.body,
                  color: colors.cyan,
                  opacity: 0.5,
                }}
              >
                @xark
              </span>
            </div>
            <p
              style={{
                ...text.subtitle,
                color: colors.white,
                opacity: 0.35,
                paddingLeft: "32px",
              }}
            >
              {groundingContext
                ? getGreeting(groundingContext, spaceTitle)
                : `try "@xark find a few options" or "@xark add an idea"`}
            </p>
          </div>
        )}

        <div ref={bottomRef} />
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
              onClick={() => setSanctuaryOpen(false)}
            />
            <motion.div
              className="fixed inset-x-0 bottom-0 z-50 overflow-y-auto px-6 pb-12 pt-8"
              style={{
                background: colors.void,
                maxHeight: "80vh",
                borderTopLeftRadius: "0px",
                borderTopRightRadius: "0px",
              }}
              initial={{ y: "100%" }}
              animate={{ y: 0 }}
              exit={{ y: "100%" }}
              transition={{ type: "tween", duration: 0.3, ease: [0.22, 1, 0.36, 1] }}
            >
              <div className="mx-auto" style={{ maxWidth: "640px" }}>
                <span
                  style={{
                    ...text.body,
                    color: colors.cyan,
                    opacity: 0.6,
                  }}
                >
                  {sanctuaryName}
                </span>

                <div className="mt-4">
                  {sanctuaryMessages.map((msg, i) => {
                    const label =
                      msg.role === "xark"
                        ? "@xark"
                        : msg.senderName ?? "you";
                    const prev = i > 0 ? sanctuaryMessages[i - 1] : null;
                    const prevLabel = prev
                      ? prev.role === "xark"
                        ? "@xark"
                        : prev.senderName ?? "you"
                      : null;
                    const sameSender = prevLabel === label;

                    return (
                      <div
                        key={msg.id}
                        style={{ marginTop: sameSender ? "3px" : i === 0 ? "0px" : "14px" }}
                      >
                        {!sameSender && (
                          <div className="flex items-center gap-2" style={{ marginBottom: "2px" }}>
                            <Avatar name={label} size={24} />
                            <span
                              style={{
                                fontSize: "0.8125rem",
                                fontWeight: 400,
                                lineHeight: 1.4,
                                color:
                                  msg.role === "xark"
                                    ? colors.cyan
                                    : colors.amber,
                                opacity: msg.role === "xark" ? 0.7 : 0.85,
                              }}
                            >
                              {label}
                            </span>
                          </div>
                        )}
                        <div style={{ paddingLeft: "32px" }}>
                          <p
                            style={{
                              ...text.subtitle,
                              color: colors.white,
                              opacity: Math.max(0.55, fovealOpacity(i, sanctuaryMessages.length, "user")),
                              margin: 0,
                            }}
                          >
                            {msg.content}
                            <span
                              style={{
                                ...text.timestamp,
                                color: colors.white,
                                opacity: 0.2,
                                marginLeft: "8px",
                              }}
                            >
                              {formatTime(msg.timestamp)}
                            </span>
                          </p>
                        </div>
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
        @keyframes goldBurstPulse {
          0% { opacity: 0; }
          20% { opacity: 1; }
          100% { opacity: 0; }
        }
      `}</style>
    </div>
  );
}
