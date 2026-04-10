"use client";

// hello OS v2.0 — Chat Display (Display-Only)
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
  ink,
  opacity,
  timing,
  layout,
  text,
  fovealOpacity,
  textColor,
} from "@/lib/theme";
import { Avatar } from "@/components/os/Avatar";
import { LedgerPill } from "@/components/os/LedgerPill";
import { InlineCardPreview } from "@/components/os/InlineCardPreview";
import { PlaygroundWhisper } from "@/components/os/PlaygroundWhisper";
import { InlinePoll } from "@/components/os/InlinePoll";
import { EncryptedMediaRenderer } from "@/components/os/EncryptedMedia";
import { LinkPreviewCard } from "@/components/os/LinkPreviewCard";
import type { LedgerEvent } from "@/components/os/LedgerPill";
import type { ChatMessage } from "@/app/space/[id]/page";

interface InlineCard {
  title: string;
  imageUrl?: string;
  price?: string;
  score: number;
  onTap?: () => void;
}

interface HelloChatProps {
  groupId: string;
  spaceTitle?: string;
  messages: ChatMessage[];
  isThinking?: boolean;
  e2eeActive?: boolean;
  ledgerEvents?: LedgerEvent[];
  onLedgerUndo?: (ledgerId: string, action: string, previous: Record<string, unknown>) => void;
  typingIndicator?: { name: string; visible: boolean } | null;
  inlineCards?: InlineCard[];
  inlineCardsWhisper?: string;
  onInvite?: () => void;
  memberCount?: number;
  currentUserId?: string;
  currentUserName?: string;
  currentDeviceId?: number;
}

// ── Sanctuary mapping — sender name → private space ID ──
const SANCTUARY_MAP: Record<string, string> = {
  ananya: "space_ananya",
};

export function HelloChat({
  groupId,
  spaceTitle,
  messages,
  isThinking,
  e2eeActive,
  ledgerEvents,
  onLedgerUndo,
  typingIndicator,
  inlineCards,
  inlineCardsWhisper,
  onInvite,
  memberCount,
  currentUserId,
  currentUserName,
  currentDeviceId,
}: HelloChatProps) {
  const [groundingContext, setGroundingContext] =
    useState<GroundingContext | null>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  // ── Sanctuary Bridge state ──
  const [dmOpen, setDmOpen] = useState(false);
  const [dmName, setDmName] = useState("");
  const [dmMessages, setDmMessages] = useState<ChatMessage[]>([]);

  // ── Handshake Protocol — silent until consensus ignites ──
  const { proposal, whisper, confirm, dismiss, isCommitting, goldBurst } =
    useHandshake(groupId);

  // Load grounding context
  useEffect(() => {
    buildGroundingContext(groupId)
      .then(setGroundingContext)
      .catch(() => {});
  }, [groupId]);

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
        role: "hello",
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
      const dmGroupId =
        SANCTUARY_MAP[name.toLowerCase()];
      if (!dmGroupId) return;
      setDmName(name);
      setDmOpen(true);
      try {
        const msgs = await fetchMessages(dmGroupId, { limit: 30 });
        if (msgs.length > 0) {
          setDmMessages(
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
    if (msg.role === "hello") return "@hello";
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
          background: "none",
        }}
      />

      {/* ── Social Gold Burst ── */}
      {goldBurst && (
        <div
          className="pointer-events-none fixed inset-0"
          style={{
            background: `radial-gradient(circle at 50% 50%, rgba(var(--hello-gold-rgb), 0.15) 0%, rgba(var(--hello-gold-rgb), 0.05) 40%, transparent 70%)`,
            animation: "goldBurstPulse 3s ease-out forwards",
          }}
        />
      )}

      {/* E2EE indicator removed — trust signal is the hello anchor + Liquid Fire */}

      {/* ── Message Stream ── */}
      <div
        className="flex-1 overflow-y-auto px-6"
        style={{
          paddingTop: "200px",
          paddingBottom: "110px",
          display: "flex",
          flexDirection: "column",
          scrollPaddingTop: "200px",
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
                0.35,
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
              msg.role as "user" | "hello"
            );
            const label = senderLabel(msg);
            const isOtherUser = msg.role === "user" && !!msg.senderName;
            const canOpenSanctuary =
              isOtherUser && hasSanctuary(msg.senderName!);

            const prevMsg = index > 0 ? msgOnlyList[index - 1] : null;
            const sameSender = prevMsg && senderLabel(prevMsg) === label;

            // Avatar: show only on first message of a group, and only in 3+ member rooms or for hello
            const isGroupChat = (memberCount ?? 0) > 2;
            const showAvatar = !sameSender && (isGroupChat || msg.role === "hello");
            const avatarName = msg.role === "hello" ? "hello" : (msg.senderName ?? "you");

            const isSentByMe = Boolean(
              msg.role === "user" &&
                ((currentUserId && msg.userId === currentUserId) ||
                 (currentDeviceId && msg.senderDeviceId === currentDeviceId))
            );

            const isHello = msg.role === "hello" || msg.messageType === "helloReceipt";
            const isHelloQuery = msg.messageType === "helloQuery" ||
              (msg.role === "user" && msg.content?.toLowerCase().startsWith("@hello"));

            // ── User's @hello query: centered compact rose text (no bubble) ──
            if (isHelloQuery) {
              return (
                <motion.div
                  key={msg.id}
                  id={`msg-${msg.id}`}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ opacity: { duration: 0.15 } }}
                  style={{
                    marginTop: sameSender ? "2px" : index === 0 ? "0px" : "4px",
                    textAlign: "center",
                  }}
                >
                  <span style={{
                    fontSize: "11px",
                    fontWeight: 300,
                    color: "rgba(255,107,53,0.5)",
                    letterSpacing: "0.01em",
                    lineHeight: "1.3",
                  }}>
                    {msg.content || "..."}
                  </span>
                  <span style={{
                    fontSize: "9px",
                    fontWeight: 300,
                    color: "rgba(26,26,26,0.15)",
                    marginLeft: "5px",
                  }}>
                    {formatTime(msg.timestamp)}
                  </span>
                </motion.div>
              );
            }

            // ── @hello responses: left-aligned rose whisper (no bubble, timestamp size) ──
            if (isHello) {
              const msgType = msg.messageType ?? 'legacy';
              // Polls still get full treatment
              if (msgType === "hello_poll") {
                let pollPayload: { text?: string; poll_id?: string; title?: string } = {};
                try { pollPayload = JSON.parse(msg.content || "{}"); } catch { /* */ }
                return (
                  <motion.div
                    key={msg.id}
                    id={`msg-${msg.id}`}
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ opacity: { duration: 0.2 } }}
                    style={{ marginTop: index === 0 ? "0px" : "8px", maxWidth: "80%" }}
                  >
                    <div style={{
                      backgroundColor: "var(--hello-bubble-received)",
                      borderRadius: "16px",
                      padding: "8px 12px 6px 12px",
                    }}>
                      <div style={{ fontSize: "10px", fontWeight: 400, letterSpacing: "0.06em", color: "#FF6B35", marginBottom: "2px" }}>@hello</div>
                      <div style={{ fontSize: "15px", fontWeight: 400, color: "var(--hello-bubble-text-received)", lineHeight: "20px" }}>
                        <span>{pollPayload.text || "Created a live poll."}</span>
                        {pollPayload.poll_id && (
                          <div className="mt-2 w-full" onClick={(e) => e.stopPropagation()}>
                            <InlinePoll groupId={groupId} pollId={pollPayload.poll_id} title={pollPayload.title || "Live Poll"} />
                          </div>
                        )}
                      </div>
                    </div>
                  </motion.div>
                );
              }
              // Standard @hello messages: centered compact system line
              return (
                <motion.div
                  key={msg.id}
                  id={`msg-${msg.id}`}
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ opacity: { duration: 0.15 } }}
                  style={{
                    marginTop: sameSender ? "2px" : index === 0 ? "0px" : "4px",
                    textAlign: "center",
                  }}
                >
                  <span style={{
                    fontSize: "11px",
                    fontWeight: 300,
                    color: "#FF6B35",
                    letterSpacing: "0.01em",
                    lineHeight: "1.3",
                  }}>
                    {msg.content || "..."}
                  </span>
                  <span style={{
                    fontSize: "9px",
                    fontWeight: 300,
                    color: "rgba(26,26,26,0.2)",
                    marginLeft: "5px",
                  }}>
                    {formatTime(msg.timestamp)}
                  </span>
                </motion.div>
              );
            }

            return (
              <motion.div
                key={msg.id}
                id={`msg-${msg.id}`}
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                transition={{ opacity: { duration: 0.2 } }}
                style={{
                  maxWidth: "80%",
                  marginLeft: isSentByMe ? "auto" : "0",
                  marginRight: isSentByMe ? "0" : "auto",
                  marginTop: sameSender ? "2px" : index === 0 ? "0px" : "12px",
                  display: "flex",
                  flexDirection: "column",
                  alignItems: isSentByMe ? "flex-end" : "flex-start",
                }}
              >
                {/* ── Avatar + Name row (Only for groups/received if needed) ── */}
                {showAvatar && !isSentByMe && (
                  <div className="flex items-center gap-2" style={{ marginBottom: "2px", paddingLeft: "4px" }}>
                    <span
                      style={{
                        fontSize: "13px",
                        fontWeight: 400,
                        color: "var(--hello-accent)",
                        cursor: canOpenSanctuary ? "pointer" : "default",
                      }}
                      onClick={canOpenSanctuary ? () => openSanctuary(msg.senderName!) : undefined}
                    >
                      {label}
                    </span>
                  </div>
                )}

                {/* ── Directional bubble tails — shape tells you who sent it ── */}
                <div
                  style={{
                    backgroundColor: isSentByMe ? "var(--hello-bubble-sent)" : "var(--hello-bubble-received)",
                    opacity: isSentByMe ? Math.max(0.75, msgOpacity) : 1,
                    borderRadius: isSentByMe ? "18px 18px 4px 18px" : "18px 18px 18px 4px",
                    border: "0.5px solid rgba(0,0,0,0.08)",
                    padding: "8px 12px 6px 12px",
                    position: "relative",
                  }}
                >
                  <div
                    style={{
                      fontSize: "15px",
                      fontWeight: 400,
                      color: isSentByMe ? "var(--hello-bubble-text-sent)" : "var(--hello-bubble-text-received)",
                      lineHeight: "20px",
                      margin: 0,
                      wordBreak: "break-word",
                    }}
                  >
                    {(() => {
                      const msgType = msg.messageType ?? 'legacy';
                      const isE2EE = msgType === 'e2ee' || msgType === 'e2ee_hello';
                      if (isE2EE && (!msg.content || msg.content === '[decryption pending]')) {
                        return <span style={{ color: "var(--hello-ink-tertiary)", fontStyle: "italic" }}>decrypting...</span>;
                      }
                      if (isE2EE && msg.content === '[Error: Decryption Failed]') {
                        return (
                          <span style={{ display: "inline-flex", alignItems: "center", gap: "4px", color: "var(--hello-ink-tertiary)" }}>
                            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" style={{ flexShrink: 0, opacity: 0.5 }}>
                              <rect x="1" y="5" width="10" height="6.5" rx="1.5" stroke="currentColor" strokeWidth="1" />
                              <path d="M3.5 5V3.5C3.5 2.12 4.4 1 5.9 1C7.4 1 8.5 2.12 8.5 3.5V5" stroke="currentColor" strokeWidth="1" strokeLinecap="round" />
                            </svg>
                            <span style={{ fontSize: "13px", fontWeight: 300, letterSpacing: "0.02em" }}>waiting for this message...</span>
                          </span>
                        );
                      }
                      // E2EE media message — render encrypted media + optional text caption
                      if (msg.mediaUrl && msg.aesKeyBase64 && msg.ivBase64 && msg.mimeType) {
                        return (
                          <>
                            <EncryptedMediaRenderer
                              mediaUrl={msg.mediaUrl}
                              aesKeyBase64={msg.aesKeyBase64}
                              ivBase64={msg.ivBase64}
                              mimeType={msg.mimeType}
                              inlineThumbnail={msg.inlineThumbnail}
                            />
                            {msg.content && msg.content !== "sent a photo" && (
                              <span style={{ display: "block", marginTop: "4px" }}>{msg.content}</span>
                            )}
                          </>
                        );
                      }
                      return msg.content || null;
                    })()}
                    {/* E2EE Link Preview Card — rendered below message text */}
                    {msg.linkPreview && (
                      <LinkPreviewCard
                        url={msg.linkPreview.url}
                        title={msg.linkPreview.title}
                        description={msg.linkPreview.description}
                        mediaUrl={msg.linkPreview.mediaUrl}
                        aesKeyBase64={msg.linkPreview.aesKeyBase64}
                        ivBase64={msg.linkPreview.ivBase64}
                        mimeType={msg.linkPreview.mimeType}
                        inlineThumbnail={msg.linkPreview.inlineThumbnail}
                      />
                    )}
                    <span
                      style={{
                        fontSize: "9px",
                        fontWeight: 300,
                        color: "var(--hello-ink-tertiary)",
                        marginLeft: "8px",
                        float: "right",
                        marginTop: "4px",
                        lineHeight: "12px",
                      }}
                    >
                      {formatTime(msg.timestamp)}
                      {isSentByMe && msg.deliveryStatus && (
                        <span style={{ marginLeft: "3px", display: "inline-flex", verticalAlign: "middle" }}>
                          {msg.deliveryStatus === 'queued' && (
                            <svg width="10" height="10" viewBox="0 0 16 16" fill="none" style={{ opacity: 0.4 }}>
                              <circle cx="8" cy="8" r="7" stroke="currentColor" strokeWidth="1.5" />
                              <path d="M8 4v4l2.5 1.5" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" />
                            </svg>
                          )}
                          {msg.deliveryStatus === 'sent' && (
                            <svg width="12" height="10" viewBox="0 0 16 12" fill="none" style={{ opacity: 0.5 }}>
                              <path d="M2 6l4 4L14 2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                            </svg>
                          )}
                          {msg.deliveryStatus === 'delivered' && (
                            <svg width="16" height="10" viewBox="0 0 20 12" fill="none" style={{ opacity: 0.5 }}>
                              <path d="M2 6l4 4L14 2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                              <path d="M6 6l4 4L18 2" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                            </svg>
                          )}
                          {msg.deliveryStatus === 'read' && (
                            <svg width="16" height="10" viewBox="0 0 20 12" fill="none">
                              <path d="M2 6l4 4L14 2" stroke="#FFFFFF" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                              <path d="M6 6l4 4L18 2" stroke="#FFFFFF" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
                            </svg>
                          )}
                        </span>
                      )}
                    </span>
                  </div>
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

        {/* ── Inline Card Previews (playground @hello results) ── */}
        {inlineCards && inlineCards.length > 0 && (
          <div style={{ maxWidth: "640px", marginTop: "14px", paddingLeft: "32px" }}>
            {inlineCards.map((card, i) => (
              <InlineCardPreview
                key={`inline-${i}`}
                title={card.title}
                imageUrl={card.imageUrl}
                price={card.price}
                score={card.score}
                onTap={card.onTap}
              />
            ))}
            {inlineCardsWhisper && (
              <div style={{ marginTop: "4px" }}>
                <PlaygroundWhisper text={inlineCardsWhisper} visible={true} />
              </div>
            )}
          </div>
        )}

        {/* ── Typing Indicator (playground presence) ── */}
        {typingIndicator?.visible && (
          <div style={{ maxWidth: "640px", marginTop: "14px", paddingLeft: "32px" }}>
            <span
              style={{
                ...text.subtitle,
                color: ink.tertiary,
                animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
              }}
            >
              {typingIndicator.name} is typing...
            </span>
          </div>
        )}

        {/* ── Typing state extracted — no fake hello block ── */}
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
                  backgroundColor: "rgba(var(--hello-accent-rgb), 0.08)",
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
                @hello
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
                : `try "@hello find a few options" or "@hello add an idea"`}
            </p>

            {/* ── Invite prompt — in thumb arc, appears when solo ── */}
            {onInvite && (memberCount ?? 0) <= 1 && (
              <p
                role="button"
                tabIndex={0}
                onClick={onInvite}
                onKeyDown={(e) => { if (e.key === "Enter") onInvite(); }}
                className="cursor-pointer outline-none"
                style={{
                  ...text.subtitle,
                  color: "#FF6B35",
                  opacity: 0.7,
                  paddingLeft: "32px",
                  marginTop: "12px",
                  transition: "opacity 0.3s ease",
                }}
                onMouseEnter={(e) => { e.currentTarget.style.opacity = "1"; }}
                onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.7"; }}
              >
                invite someone to this space →
              </p>
            )}
          </div>
        )}

        {/* ── Inline invite — after messages, when still solo ── */}
        {onInvite && (memberCount ?? 0) <= 1 && allMessages.length > 0 && (
          <p
            role="button"
            tabIndex={0}
            onClick={onInvite}
            onKeyDown={(e) => { if (e.key === "Enter") onInvite(); }}
            className="cursor-pointer outline-none"
            style={{
              ...text.subtitle,
              color: "#FF6B35",
              opacity: 0.6,
              marginTop: "20px",
              paddingLeft: "32px",
              transition: "opacity 0.3s ease",
            }}
            onMouseEnter={(e) => { e.currentTarget.style.opacity = "0.9"; }}
            onMouseLeave={(e) => { e.currentTarget.style.opacity = "0.6"; }}
          >
            invite someone →
          </p>
        )}

        {/* ── @hello Thinking Indicator — appears immediately after SpotlightSheet send ── */}
        {isThinking && (
          <motion.div
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -4 }}
            transition={{ duration: 0.25 }}
            style={{
              display: "flex",
              alignItems: "flex-start",
              gap: "8px",
              maxWidth: "640px",
              marginTop: "12px",
            }}
          >
            {/* @hello avatar */}
            <div style={{
              width: 24,
              height: 24,
              borderRadius: "50%",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              backgroundColor: "rgba(var(--hello-accent-rgb), 0.08)",
              flexShrink: 0,
              marginTop: "2px",
            }}>
              <div style={{ width: 6, height: 6, borderRadius: "50%", backgroundColor: colors.accent }} />
            </div>
            {/* Thinking bubble */}
            <div style={{
              backgroundColor: "var(--hello-bubble-received)",
              borderRadius: "16px 16px 16px 4px",
              padding: "10px 16px",
              display: "flex",
              alignItems: "center",
              gap: "10px",
            }}>
              {/* Breathing dots */}
              <div style={{ display: "flex", gap: "4px", alignItems: "center" }}>
                {[0, 1, 2].map((i) => (
                  <div
                    key={i}
                    style={{
                      width: 6,
                      height: 6,
                      borderRadius: "50%",
                      backgroundColor: "#FF6B35",
                      opacity: 0.6,
                      animation: `helloThinkingDot 1.4s ease-in-out ${i * 0.2}s infinite`,
                    }}
                  />
                ))}
              </div>
              <span style={{
                ...text.subtitle,
                color: "rgba(26,26,26,0.5)",
                fontWeight: 300,
                fontSize: "0.8125rem",
              }}>
                thinking...
              </span>
            </div>
          </motion.div>
        )}

        <div ref={bottomRef} />
      </div>

      {/* ═══════════════════════════════════════════
          SANCTUARY BRIDGE — 1:1 Slide-Up Sheet
          ═══════════════════════════════════════════ */}
      <AnimatePresence>
        {dmOpen && (
          <>
            <motion.div
              className="fixed inset-0 z-40"
              style={{ background: "#000000" }}
              initial={{ opacity: 0 }}
              animate={{ opacity: 0.8 }}
              exit={{ opacity: 0 }}
              onClick={() => setDmOpen(false)}
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
                  {dmName}
                </span>

                <div className="mt-4">
                  {dmMessages.map((msg, i) => {
                    const label =
                      msg.role === "hello"
                        ? "@hello"
                        : msg.senderName ?? "you";
                    const prev = i > 0 ? dmMessages[i - 1] : null;
                    const prevLabel = prev
                      ? prev.role === "hello"
                        ? "@hello"
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
                                  msg.role === "hello"
                                    ? colors.cyan
                                    : colors.amber,
                                opacity: msg.role === "hello" ? 0.7 : 0.85,
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
                              opacity: Math.max(0.55, fovealOpacity(i, dmMessages.length, "user")),
                              margin: 0,
                            }}
                          >
                            {msg.content}
                            <span
                              style={{
                                ...text.timestamp,
                                color: colors.white,
                                opacity: 0.38,
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
        @keyframes helloFloat {
          0%, 100% { transform: translateY(0); }
          50% { transform: translateY(-3px); }
        }
        @keyframes helloShimmer {
          0% { background-position: -200% center; }
          100% { background-position: 200% center; }
        }
        .hello-shimmer-text {
          animation: helloShimmer 2s ease-in-out infinite;
        }
        @keyframes goldBurstPulse {
          0% { opacity: 0; }
          20% { opacity: 1; }
          100% { opacity: 0; }
        }
      `}</style>
    </div>
  );
}
