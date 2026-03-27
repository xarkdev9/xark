"use client";

import { Suspense, useState, useEffect, useRef, useCallback } from "react";
import { useSearchParams } from "next/navigation";

// ═══════════════════════════════════════════════
// MOBILE AD — /ad
// Two ads: ?ad=amalfi (default) or ?ad=gift
// Canvas: #FAFAFA, 9:16, ~33s, 2s breathing gaps
// ═══════════════════════════════════════════════

const BG = "#FAFAFA";
const INK = "#1A1A1A";
const INK_SEC = "#8E8E93";
const INK_TER = "#A1A1A6";
const SURFACE_RECESSED = "#F0F0F0";
const ACCENT = "#FF6B35";
const WA_GREEN_IN = "#1e2b31";
const WA_GREEN_OUT = "#005c4b";
const CARD_AMBER = "#e8a855";
const CARD_GREEN = "#047857";
const CARD_TEXT = "#E8E8EC";
const CARD_TEXT_DIM = "rgba(232,232,236,0.5)";

// ── Liquid Fire gradient — matches globals.css .xark-text-led exactly ──
// #8B2500 → #FF6B35 → #FF9F43 → #FF6B35 → #8B2500
const liquidFireCSS = `
  @keyframes xarkLiquidFire {
    0% { background-position: 0% 50%; }
    50% { background-position: 100% 50%; }
    100% { background-position: 0% 50%; }
  }
`;

const liquidFire: React.CSSProperties = {
  background: "linear-gradient(90deg, #8B2500 0%, #FF6B35 25%, #FF9F43 50%, #FF6B35 75%, #8B2500 100%)",
  backgroundSize: "200% auto",
  WebkitBackgroundClip: "text",
  backgroundClip: "text",
  color: "transparent",
  animation: "xarkLiquidFire 3s linear infinite",
};

// ═══════════════════════════════════════════════
// SHARED COMPONENTS
// ═══════════════════════════════════════════════

function WhatsAppBubble({ text, out, visible, delay = 0 }: {
  text: string; out: boolean; visible: boolean; delay?: number;
}) {
  return (
    <div style={{
      display: "flex",
      justifyContent: out ? "flex-end" : "flex-start",
      opacity: visible ? 1 : 0,
      transform: visible ? "translateY(0) scale(1)" : "translateY(15px) scale(0.95)",
      transition: `opacity 0.35s ease ${delay}s, transform 0.45s cubic-bezier(0.34, 1.56, 0.64, 1) ${delay}s`,
    }}>
      <div style={{
        padding: "8px 14px",
        borderRadius: "18px",
        borderBottomRightRadius: out ? "4px" : "18px",
        borderBottomLeftRadius: out ? "18px" : "4px",
        fontSize: "14px",
        fontWeight: 400,
        lineHeight: 1.4,
        letterSpacing: "-0.01em",
        background: out ? WA_GREEN_OUT : WA_GREEN_IN,
        color: "#e9edef",
        maxWidth: "85%",
        width: "fit-content",
      }}>
        {text}
      </div>
    </div>
  );
}

// ── Fake Home Chat List ──
interface ChatRow {
  name: string;
  preview: string;
  time: string;
  unread?: number;
  isGroup?: boolean;
}

function FakeChatList({ rows, visible }: { rows: ChatRow[]; visible: boolean }) {
  return (
    <div style={{
      opacity: visible ? 1 : 0,
      transform: visible ? "translateY(0)" : "translateY(12px)",
      transition: "opacity 0.5s ease, transform 0.5s cubic-bezier(0.22,1,0.36,1)",
      width: "100%",
    }}>
      {/* Header */}
      <div style={{
        padding: "0 24px",
        paddingTop: "calc(env(safe-area-inset-top, 0px) + 16px)",
        paddingBottom: "12px",
      }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", paddingBottom: "12px" }}>
          <span style={{ ...liquidFire, fontSize: "28px", fontWeight: 400, fontStyle: "italic", letterSpacing: "-0.03em" }}>
            hello
          </span>
          <div style={{
            width: "32px", height: "32px", borderRadius: "50%",
            background: SURFACE_RECESSED,
            display: "flex", alignItems: "center", justifyContent: "center",
            fontSize: "14px", fontWeight: 400, color: INK_SEC,
          }}>
            R
          </div>
        </div>
        {/* Tabs */}
        <div style={{ display: "flex", gap: "24px", paddingBottom: "8px" }}>
          {["people", "plans", "memories"].map((tab, i) => (
            <span key={tab} style={{
              position: "relative",
              color: i === 1 ? INK : INK_TER,
              opacity: i === 1 ? 1 : 0.6,
              fontWeight: 400,
              fontSize: "15px",
              letterSpacing: "0.06em",
              paddingBottom: "10px",
              textTransform: "capitalize" as const,
            }}>
              {tab}
              {i === 1 && (
                <span style={{
                  position: "absolute",
                  bottom: 0,
                  left: "5%",
                  width: "90%",
                  height: "2.5px",
                  borderRadius: "2px",
                  background: "linear-gradient(90deg, #8B2500 0%, #FF6B35 25%, #FF9F43 50%, #FF6B35 75%, #8B2500 100%)",
                  backgroundSize: "200% auto",
                  animation: "xarkLiquidFire 3s linear infinite",
                }} />
              )}
            </span>
          ))}
        </div>
      </div>

      {/* Chat rows */}
      <div style={{ padding: "0 24px" }}>
        {rows.map((row, i) => (
          <div key={i} style={{
            display: "flex", alignItems: "center", gap: "12px",
            paddingBottom: "20px",
            opacity: visible ? 1 : 0,
            transform: visible ? "translateY(0)" : "translateY(8px)",
            transition: `opacity 0.4s ease ${0.1 + i * 0.06}s, transform 0.5s cubic-bezier(0.22,1,0.36,1) ${0.1 + i * 0.06}s`,
          }}>
            {/* Avatar */}
            <div style={{
              width: "36px", height: "36px", borderRadius: "50%",
              background: SURFACE_RECESSED, flexShrink: 0,
              display: "flex", alignItems: "center", justifyContent: "center",
              fontSize: "14px", fontWeight: 400, color: INK_SEC,
            }}>
              {row.name[0].toUpperCase()}
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline" }}>
                <span style={{ fontSize: "1.125rem", fontWeight: 400, lineHeight: 1.4, letterSpacing: "-0.01em", color: INK }}>
                  {row.name}
                </span>
                <div style={{ display: "flex", alignItems: "center", gap: "8px" }}>
                  <span style={{ fontSize: "0.75rem", fontWeight: 300, lineHeight: 1.4, color: INK_TER }}>
                    {row.time}
                  </span>
                  {row.unread && row.unread > 0 && (
                    <span style={{
                      display: "inline-flex", alignItems: "center", justifyContent: "center",
                      minWidth: "18px", height: "18px", borderRadius: "9px",
                      padding: "0 5px", fontSize: "11px", fontWeight: 400,
                      color: "#fff", backgroundColor: ACCENT,
                    }}>
                      {row.unread}
                    </span>
                  )}
                </div>
              </div>
              <span style={{
                fontSize: "0.75rem", fontWeight: 300, lineHeight: 1.4, letterSpacing: "0.08em",
                color: INK_SEC,
                overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" as const,
                display: "block",
              }}>
                {row.preview}
              </span>
            </div>
          </div>
        ))}
      </div>

      {/* Bottom bar */}
      <div style={{
        position: "absolute", bottom: 0, left: 0, right: 0,
        padding: "8px 16px",
        paddingBottom: "max(env(safe-area-inset-bottom, 0px), 8px)",
        background: `linear-gradient(to top, ${BG} 70%, transparent)`,
        display: "flex", alignItems: "center", gap: "12px",
      }}>
        <div style={{
          flex: 1, display: "flex", alignItems: "center", gap: "8px",
          backgroundColor: SURFACE_RECESSED, borderRadius: "20px", padding: "10px 14px",
        }}>
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke={INK_TER} strokeWidth="2" strokeLinecap="round">
            <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <span style={{ fontSize: "15px", fontWeight: 400, color: INK_TER, letterSpacing: "0.02em" }}>search...</span>
        </div>
        <div style={{
          width: "44px", height: "44px", borderRadius: "50%",
          background: "linear-gradient(90deg, #8B2500 0%, #FF6B35 25%, #FF9F43 50%, #FF6B35 75%, #8B2500 100%)",
          backgroundSize: "200% auto",
          animation: "xarkLiquidFire 3s linear infinite",
          color: "#fff", display: "flex", alignItems: "center", justifyContent: "center",
          fontSize: "24px", fontWeight: 300,
          boxShadow: "0 2px 12px rgba(255, 107, 53, 0.3)",
        }}>
          +
        </div>
      </div>
    </div>
  );
}

// ── Fake Spotlight Sheet ──
function FakeSpotlight({
  visible,
  typedText,
  responseText,
  responseLink,
}: {
  visible: boolean;
  typedText: string;
  responseText: string | null;
  responseLink: string | null;
}) {
  return (
    <>
      {/* Overlay */}
      <div style={{
        position: "absolute", inset: 0,
        background: "#000",
        opacity: visible ? 0.8 : 0,
        transition: "opacity 0.3s ease",
        pointerEvents: visible ? "auto" : "none",
        zIndex: 30,
      }} />
      {/* Sheet */}
      <div style={{
        position: "absolute", bottom: 0, left: 0, right: 0,
        background: BG,
        borderRadius: "20px 20px 0 0",
        padding: "20px 24px 32px",
        transform: visible ? "translateY(0)" : "translateY(100%)",
        transition: "transform 0.4s cubic-bezier(0.22,1,0.36,1)",
        zIndex: 31,
      }}>
        {/* Drag handle */}
        <div style={{
          width: "36px", height: "4px", borderRadius: "2px",
          background: INK_TER, opacity: 0.3, margin: "0 auto 16px",
        }} />
        {/* Input */}
        <div style={{
          display: "flex", alignItems: "center", gap: "8px",
          backgroundColor: SURFACE_RECESSED, borderRadius: "16px",
          padding: "12px 16px", marginBottom: responseText ? "16px" : "0",
        }}>
          <span style={{
            display: "inline-flex", alignItems: "center",
            padding: "2px 8px", borderRadius: "8px",
            fontSize: "12px", fontWeight: 400, letterSpacing: "0.04em",
            background: `linear-gradient(135deg, ${ACCENT}20, ${ACCENT}10)`,
            color: ACCENT,
          }}>
            @hello
          </span>
          <span style={{ fontSize: "17px", fontWeight: 400, color: INK, letterSpacing: "0.01em" }}>
            {typedText}
            <span style={{ opacity: 0.4, animation: "blink 1s step-end infinite" }}>|</span>
          </span>
        </div>
        {/* Response */}
        {responseText && (
          <div style={{
            padding: "12px 16px",
            borderRadius: "16px",
            borderBottomLeftRadius: "4px",
            background: SURFACE_RECESSED,
            opacity: responseText ? 1 : 0,
            transform: responseText ? "translateY(0)" : "translateY(8px)",
            transition: "opacity 0.3s ease, transform 0.3s ease",
          }}>
            {/* @hello label with Liquid Fire corner */}
            <div style={{ display: "flex", alignItems: "center", gap: "6px", marginBottom: "6px" }}>
              <span style={{ ...liquidFire, fontSize: "12px", fontWeight: 400, letterSpacing: "0.04em" }}>@hello</span>
            </div>
            <span style={{ fontSize: "15px", fontWeight: 400, color: INK, lineHeight: 1.5 }}>
              {responseText}
            </span>
            {responseLink && (
              <div style={{
                marginTop: "10px",
                display: "inline-flex", alignItems: "center", gap: "4px",
                padding: "6px 12px", borderRadius: "12px",
                background: `${ACCENT}15`,
                color: ACCENT,
                fontSize: "13px", fontWeight: 400, letterSpacing: "0.02em",
              }}>
                decide →
              </div>
            )}
          </div>
        )}
      </div>
    </>
  );
}

// ── Mini Decision Card (for runner-ups in gift ad) ──
function MiniCard({ title, score, delay = 0, visible }: {
  title: string; score: number; delay?: number; visible: boolean;
}) {
  return (
    <div style={{
      flexShrink: 0,
      width: "140px", height: "180px",
      borderRadius: "18px", overflow: "hidden",
      position: "relative",
      opacity: visible ? 1 : 0,
      transform: visible ? "translateY(0) scale(1)" : "translateY(12px) scale(0.92)",
      transition: `opacity 0.35s ease ${delay}s, transform 0.45s cubic-bezier(0.22,1,0.36,1) ${delay}s`,
      border: "1px solid rgba(255,255,255,0.08)",
    }}>
      {/* Gradient background */}
      <div style={{
        position: "absolute", inset: 0,
        background: "linear-gradient(160deg, #2a2a3a 0%, #0a0a14 100%)",
      }} />
      {/* Content */}
      <div style={{
        position: "absolute", bottom: 0, left: 0, right: 0,
        padding: "12px",
      }}>
        <span style={{
          fontSize: "28px", fontWeight: 300, lineHeight: 1,
          letterSpacing: "-0.04em", color: CARD_AMBER,
          textShadow: "0 1px 4px rgba(0,0,0,0.5)",
        }}>
          {score}
        </span>
        <p style={{
          fontSize: "13px", fontWeight: 300, color: CARD_TEXT,
          lineHeight: 1.3, marginTop: "6px",
          textShadow: "0 1px 3px rgba(0,0,0,0.4)",
        }}>
          {title}
        </p>
      </div>
    </div>
  );
}

// ── Hero Decision Card ──
function HeroCard({
  title, subtitle, score, badge, badgeColor, progress, visible, fullFocus,
}: {
  title: string;
  subtitle: string;
  score: number;
  badge?: string;
  badgeColor?: string;
  progress?: { current: number; total: number };
  visible: boolean;
  fullFocus?: boolean;
}) {
  return (
    <div style={{
      width: fullFocus ? "100%" : "100%",
      maxWidth: fullFocus ? "none" : "320px",
      height: fullFocus ? "100%" : "clamp(340px, 50dvh, 420px)",
      borderRadius: fullFocus ? "20px" : "26px", overflow: "hidden",
      position: "relative",
      opacity: visible ? 1 : 0,
      transform: visible ? "scale(1)" : "scale(0.97)",
      transition: "opacity 0.5s ease, transform 0.6s cubic-bezier(0.22,1,0.36,1)",
      border: "1px solid rgba(255,255,255,0.08)",
      boxShadow: "0 10px 40px rgba(0,0,0,0.2)",
    }}>
      {/* Background */}
      <div style={{
        position: "absolute", inset: 0,
        background: "linear-gradient(160deg, #8a6a4a 0%, #3a2818 100%)",
      }} />
      {/* Cinematic gradient */}
      <div style={{
        position: "absolute", inset: 0,
        background: "linear-gradient(to top, rgba(0,0,0,0.95) 0%, rgba(0,0,0,0.5) 40%, transparent 70%)",
      }} />
      {/* Content */}
      <div style={{
        position: "absolute", inset: "0 0 0 0", bottom: 0,
        display: "flex", flexDirection: "column", justifyContent: "flex-end",
        padding: "16px", paddingBottom: "52px",
      }}>
        {/* Badge */}
        {badge && (
          <div style={{
            display: "inline-flex", alignSelf: "flex-start",
            padding: "4px 10px", borderRadius: "8px",
            background: `${badgeColor || CARD_GREEN}22`,
            marginBottom: "12px",
          }}>
            <span style={{
              fontSize: "11px", fontWeight: 400, letterSpacing: "0.08em",
              textTransform: "uppercase" as const,
              color: badgeColor || CARD_GREEN,
            }}>
              {badge}
            </span>
          </div>
        )}
        {/* Score + title */}
        <div style={{ display: "flex", alignItems: "flex-start", gap: "12px" }}>
          <div style={{ flexShrink: 0 }}>
            <span style={{
              fontSize: "48px", fontWeight: 300, lineHeight: 1,
              letterSpacing: "-0.04em", color: CARD_AMBER,
              textShadow: "0 1px 4px rgba(0,0,0,0.5)",
            }}>
              {score}
            </span>
            <div style={{
              height: "2px", background: CARD_AMBER,
              borderRadius: "1px", marginTop: "6px",
              opacity: 0.5, width: `${Math.min(score, 100)}%`,
              maxWidth: "56px",
            }} />
          </div>
          <div style={{ paddingTop: "4px", flex: 1, minWidth: 0 }}>
            <p style={{
              fontSize: "18px", fontWeight: 300, color: CARD_TEXT,
              lineHeight: 1.3, textShadow: "0 1px 3px rgba(0,0,0,0.4)",
            }}>
              {title}
            </p>
            <span style={{
              fontSize: "13px", fontWeight: 300, color: CARD_TEXT_DIM,
              display: "inline-block", marginTop: "4px",
            }}>
              {subtitle}
            </span>
          </div>
        </div>
        {/* Progress bar (for gift ad) */}
        {progress && (
          <div style={{ marginTop: "14px" }}>
            <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "6px" }}>
              <span style={{ fontSize: "12px", fontWeight: 300, color: CARD_TEXT_DIM }}>
                {progress.current} of {progress.total} paid
              </span>
              <span style={{ fontSize: "12px", fontWeight: 300, color: CARD_GREEN }}>
                ${Math.round(280 / progress.total)}/person
              </span>
            </div>
            <div style={{
              height: "4px", borderRadius: "2px",
              background: "rgba(255,255,255,0.1)",
              overflow: "hidden",
            }}>
              <div style={{
                height: "100%", borderRadius: "2px",
                background: CARD_GREEN,
                width: `${(progress.current / progress.total) * 100}%`,
                transition: "width 0.8s cubic-bezier(0.22,1,0.36,1)",
              }} />
            </div>
          </div>
        )}
      </div>
      {/* Reaction bar */}
      <div style={{
        position: "absolute", bottom: 0, left: 0, right: 0,
        height: "44px", display: "flex", alignItems: "center",
        justifyContent: "center", gap: "8px", padding: "0 12px",
      }}>
        {[
          { label: "love", color: ACCENT, active: true },
          { label: "okay", color: "#A8B4C0", active: false },
          { label: "pass", color: "#6B7280", active: false },
        ].map((s) => (
          <span key={s.label} style={{
            fontSize: "13px", fontWeight: s.active ? 400 : 300,
            letterSpacing: "0.12em",
            color: s.active ? s.color : "rgba(255,255,255,0.45)",
            padding: "6px 14px", borderRadius: "20px",
            background: s.active ? `radial-gradient(ellipse at center, ${s.color}22 0%, ${s.color}08 70%, transparent 100%)` : "transparent",
            boxShadow: s.active ? `0 0 20px ${s.color}30, 0 0 8px ${s.color}18` : "none",
            textShadow: s.active ? `0 0 12px ${s.color}, 0 0 4px ${s.color}80` : "none",
          }}>
            {s.label}
          </span>
        ))}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════
// AD DATA
// ═══════════════════════════════════════════════

const AMALFI_BUBBLES = [
  { text: "wait did anyone book the amalfi airbnb?", out: false },
  { text: "i thought dave was handling it", out: true },
  { text: "what dates did we even agree on?", out: false },
];

const AMALFI_CHATS: ChatRow[] = [
  { name: "Amalfi Trip", preview: "dave: checking the villa now", time: "2m", unread: 3, isGroup: true },
  { name: "Sarah", preview: "are you coming tonight?", time: "15m" },
  { name: "NYC Friends", preview: "lol who sent that", time: "1h", unread: 12, isGroup: true },
  { name: "Mom", preview: "call me when you can", time: "3h" },
  { name: "Jake", preview: "happy birthday! 🎂", time: "5h" },
  { name: "Work Team", preview: "meeting at 3pm tomorrow", time: "1d", isGroup: true },
];

const GIFT_BUBBLES = [
  { text: "what are we getting jake?", out: false },
  { text: "someone said a speaker?", out: true },
  { text: "how much is everyone putting in", out: false },
];

const GIFT_CHATS: ChatRow[] = [
  { name: "Jake's Birthday", preview: "speaker looks good", time: "5m", unread: 4, isGroup: true },
  { name: "Sarah", preview: "did you venmo?", time: "20m" },
  { name: "Amalfi Trip", preview: "dave booked the villa!", time: "1h", isGroup: true },
  { name: "Mom", preview: "dinner sunday?", time: "2h" },
  { name: "Alex", preview: "sent you the link", time: "4h" },
  { name: "Book Club", preview: "next meeting is thursday", time: "1d", isGroup: true },
];

// ═══════════════════════════════════════════════
// MAIN AD COMPONENT
// ═══════════════════════════════════════════════

type Stage = "hook" | "punchline" | "solution" | "decide" | "bridge" | "close";

function Ad({ variant }: { variant: "amalfi" | "gift" }) {
  const [stage, setStage] = useState<Stage>("hook");
  const stageRef = useRef(stage);
  stageRef.current = stage;

  // Hook state
  const [bubblesVisible, setBubblesVisible] = useState<boolean[]>([false, false, false]);

  // Punchline state
  const [punchSetupVisible, setPunchSetupVisible] = useState(false);
  const [punchHelloVisible, setPunchHelloVisible] = useState(false);
  const [punchWordIdx, setPunchWordIdx] = useState(0);
  const [punchWordVisible, setPunchWordVisible] = useState(false);

  // Solution state
  const [chatListVisible, setChatListVisible] = useState(false);
  const [spotlightVisible, setSpotlightVisible] = useState(false);
  const [typedText, setTypedText] = useState("");
  const [responseText, setResponseText] = useState<string | null>(null);
  const [responseLink, setResponseLink] = useState<string | null>(null);

  // Decide state
  const [heroVisible, setHeroVisible] = useState(false);
  const [miniCardsVisible, setMiniCardsVisible] = useState(false);

  // Bridge state
  const [bridgeLine1, setBridgeLine1] = useState(false);
  const [bridgeLine2, setBridgeLine2] = useState(false);

  // Close state
  const [helloVisible, setHelloVisible] = useState(false);
  const [messengerVisible, setMessengerVisible] = useState(false);
  const [comingSoonVisible, setComingSoonVisible] = useState(false);

  const bubbles = variant === "amalfi" ? AMALFI_BUBBLES : GIFT_BUBBLES;
  const chats = variant === "amalfi" ? AMALFI_CHATS : GIFT_CHATS;
  const queryText = variant === "amalfi" ? "airbnb status" : "jake's birthday gift status";
  const respText = variant === "amalfi"
    ? "dave booked villa margherita. 4 guests, jun 12–18."
    : "bluetooth speaker. $35 each. 6 of 8 paid.";
  const bridgeTagline = variant === "amalfi"
    ? "from 47 links to one tap."
    : "from 47 opinions to one gift. split and done.";

  // Reset all state
  const reset = useCallback(() => {
    setBubblesVisible([false, false, false]);
    setPunchSetupVisible(false);
    setPunchHelloVisible(false);
    setPunchWordIdx(0);
    setPunchWordVisible(false);
    setChatListVisible(false);
    setSpotlightVisible(false);
    setTypedText("");
    setResponseText(null);
    setResponseLink(null);
    setHeroVisible(false);
    setMiniCardsVisible(false);
    setBridgeLine1(false);
    setBridgeLine2(false);
    setHelloVisible(false);
    setMessengerVisible(false);
    setComingSoonVisible(false);
  }, []);

  // ── HOOK STAGE ──
  useEffect(() => {
    if (stage !== "hook") return;
    reset();
    const timers: ReturnType<typeof setTimeout>[] = [];

    // Bubble 1 at 0.5s, bubble 2 at 2.5s, bubble 3 at 4.5s
    timers.push(setTimeout(() => setBubblesVisible([true, false, false]), 500));
    timers.push(setTimeout(() => setBubblesVisible([true, true, false]), 2500));
    timers.push(setTimeout(() => setBubblesVisible([true, true, true]), 4500));
    // 2s pause after last bubble, then punchline
    timers.push(setTimeout(() => setStage("punchline"), 8500));

    return () => timers.forEach(clearTimeout);
  }, [stage, reset]);

  // ── PUNCHLINE STAGE — "there's a new way to say hello [word flip]" ──
  const PUNCH_WORDS = ["clarity.", "consensus.", "plans.", "memories."];
  useEffect(() => {
    if (stage !== "punchline") return;
    const timers: ReturnType<typeof setTimeout>[] = [];

    // "there's a new way to say hello" fades in
    timers.push(setTimeout(() => setPunchSetupVisible(true), 300));
    // First emotion word appears
    timers.push(setTimeout(() => setPunchWordVisible(true), 1200));

    // Flip through words: show 1.2s, fade 0.15s, next
    let wordT = 2400; // start cycling after first word shows for 1.2s
    for (let i = 1; i < PUNCH_WORDS.length; i++) {
      const idx = i;
      timers.push(setTimeout(() => setPunchWordVisible(false), wordT));
      timers.push(setTimeout(() => { setPunchWordIdx(idx); setPunchWordVisible(true); }, wordT + 150));
      wordT += 1350;
    }

    // Hold last word, then move to solution
    timers.push(setTimeout(() => setStage("solution"), wordT + 1200));

    return () => timers.forEach(clearTimeout);
  }, [stage]);

  // ── SOLUTION STAGE ──
  useEffect(() => {
    if (stage !== "solution") return;
    const timers: ReturnType<typeof setTimeout>[] = [];

    // Show chat list
    timers.push(setTimeout(() => setChatListVisible(true), 200));

    // After 1.5s, open spotlight
    timers.push(setTimeout(() => setSpotlightVisible(true), 1700));

    // After 2.5s, start typing
    const typeDelay = 2700;
    const chars = queryText.split("");
    chars.forEach((_, i) => {
      timers.push(setTimeout(() => {
        setTypedText(queryText.slice(0, i + 1));
      }, typeDelay + i * 55));
    });

    // After typing done + 0.5s, show response
    const typeDone = typeDelay + chars.length * 55 + 500;
    timers.push(setTimeout(() => setResponseText(respText), typeDone));
    timers.push(setTimeout(() => setResponseLink("decide"), typeDone + 300));

    // After response + 1.5s, transition to decide
    timers.push(setTimeout(() => setStage("decide"), typeDone + 2000));

    return () => timers.forEach(clearTimeout);
  }, [stage, queryText, respText]);

  // ── DECIDE STAGE ──
  useEffect(() => {
    if (stage !== "decide") return;
    const timers: ReturnType<typeof setTimeout>[] = [];

    timers.push(setTimeout(() => setHeroVisible(true), 300));
    if (variant === "gift") {
      timers.push(setTimeout(() => setMiniCardsVisible(true), 800));
    }
    // Hold for 3s, then bridge
    timers.push(setTimeout(() => setStage("bridge"), 4000));

    return () => timers.forEach(clearTimeout);
  }, [stage, variant]);

  // ── BRIDGE STAGE ──
  useEffect(() => {
    if (stage !== "bridge") return;
    const timers: ReturnType<typeof setTimeout>[] = [];

    timers.push(setTimeout(() => setBridgeLine1(true), 300));
    timers.push(setTimeout(() => setBridgeLine2(true), 3000));
    timers.push(setTimeout(() => setStage("close"), 6000));

    return () => timers.forEach(clearTimeout);
  }, [stage]);

  // ── CLOSE STAGE ──
  useEffect(() => {
    if (stage !== "close") return;
    const timers: ReturnType<typeof setTimeout>[] = [];

    timers.push(setTimeout(() => setHelloVisible(true), 300));
    timers.push(setTimeout(() => setMessengerVisible(true), 1800));
    timers.push(setTimeout(() => setComingSoonVisible(true), 2800));

    return () => timers.forEach(clearTimeout);
  }, [stage]);

  return (
    <div style={{
      position: "fixed", inset: 0, background: BG,
      display: "flex", alignItems: "center", justifyContent: "center",
      overflow: "hidden",
      fontFamily: "'Inter', -apple-system, system-ui, sans-serif",
      color: INK, fontWeight: 400, WebkitFontSmoothing: "antialiased",
    }}>

      {/* ═══ ACT 1: HOOK — WhatsApp bubbles ═══ */}
      {stage === "hook" && (
        <div style={{
          padding: "0 24px", width: "100%", maxWidth: "380px",
          display: "flex", flexDirection: "column", gap: "10px",
        }}>
          {bubbles.map((b, i) => (
            <WhatsAppBubble
              key={i}
              text={b.text}
              out={b.out}
              visible={bubblesVisible[i]}
            />
          ))}
        </div>
      )}

      {/* ═══ PUNCHLINE — "there's a new way to say hello [word]" ═══ */}
      {stage === "punchline" && (
        <div style={{
          display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center",
          gap: "clamp(4px, 1vh, 10px)",
          padding: "0 28px", width: "100%",
        }}>
          <div style={{
            fontSize: "clamp(16px, 4vw, 20px)",
            fontWeight: 400, color: INK, opacity: punchSetupVisible ? 0.35 : 0,
            letterSpacing: "0.02em", textAlign: "center",
            lineHeight: 1.4,
            transform: punchSetupVisible ? "translateY(0)" : "translateY(8px)",
            transition: "opacity 0.5s ease, transform 0.5s ease",
          }}>
            there&apos;s a new way to say<br />hello
          </div>
          {/* Word flip — positive human emotions — HERO element */}
          <div style={{
            ...liquidFire,
            fontSize: "clamp(44px, 12vw, 80px)",
            fontWeight: 400,
            fontStyle: "italic",
            letterSpacing: "-0.03em", lineHeight: 1.1,
            minHeight: "1.2em",
            textAlign: "center",
            opacity: punchWordVisible ? 1 : 0,
            transform: punchWordVisible ? "translateY(0) scale(1)" : "translateY(-6px) scale(0.95)",
            transition: "opacity 0.15s ease, transform 0.2s ease",
          }}>
            {PUNCH_WORDS[punchWordIdx]}
          </div>
        </div>
      )}

      {/* ═══ ACT 2: SOLUTION — Chat list + Spotlight ═══ */}
      {stage === "solution" && (
        <div style={{ position: "absolute", inset: 0 }}>
          <FakeChatList rows={chats} visible={chatListVisible} />
          <FakeSpotlight
            visible={spotlightVisible}
            typedText={typedText}
            responseText={responseText}
            responseLink={responseLink}
          />
        </div>
      )}

      {/* ═══ ACT 2.5: DECIDE — v4 full-focus card + mini strip + category tags ═══ */}
      {stage === "decide" && (
        <div style={{
          position: "absolute", inset: 0,
          display: "flex", flexDirection: "column",
          background: BG,
        }}>
          {/* Vital label */}
          <div style={{
            padding: "calc(env(safe-area-inset-top, 0px) + 12px) 20px 4px",
            fontSize: "11px", fontWeight: 300, letterSpacing: "0.06em",
            color: CARD_AMBER, opacity: heroVisible ? 0.7 : 0,
            transition: "opacity 0.4s ease",
          }}>
            90% on #1 · {variant === "gift" ? "4 of 4 rated" : "3 of 4 rated"}
          </div>

          {/* Full-focus hero card */}
          <div style={{ flex: 1, padding: "4px 12px 8px", minHeight: 0 }}>
            {variant === "amalfi" ? (
              <HeroCard
                title="Villa Margherita, Amalfi Coast"
                subtitle="Jun 12–18 · 4 guests"
                score={90}
                badge="booking confirmed"
                badgeColor={CARD_GREEN}
                visible={heroVisible}
                fullFocus
              />
            ) : (
              <HeroCard
                title="Bluetooth Speaker"
                subtitle="$280 · $35/person"
                score={90}
                badge="6 of 8 paid"
                badgeColor={CARD_GREEN}
                progress={{ current: 6, total: 8 }}
                visible={heroVisible}
                fullFocus
              />
            )}
          </div>

          {/* Mini thumbnail strip — v4 pattern */}
          <div style={{
            flexShrink: 0,
            opacity: miniCardsVisible ? 1 : 0,
            transform: miniCardsVisible ? "translateY(0)" : "translateY(8px)",
            transition: "opacity 0.3s ease 0.1s, transform 0.3s ease 0.1s",
          }}>
            <div style={{
              display: "flex", gap: "6px", padding: "6px 12px",
              justifyContent: "center",
            }}>
              {(variant === "gift"
                ? [
                    { title: "Speaker", active: true },
                    { title: "Headphones", active: false },
                    { title: "Watch", active: false },
                    { title: "Coffee Machine", active: false },
                  ]
                : [
                    { title: "Villa Margherita", active: true },
                    { title: "Casa Bianca", active: false },
                    { title: "Hotel Positano", active: false },
                  ]
              ).map((thumb, i) => (
                <div key={i} style={{
                  width: "52px", height: "52px", borderRadius: "10px",
                  overflow: "hidden",
                  background: "linear-gradient(160deg, #2a2a3a 0%, #0a0a14 100%)",
                  border: thumb.active ? `2px solid ${ACCENT}` : "2px solid transparent",
                  opacity: thumb.active ? 1 : 0.4,
                  transform: thumb.active ? "scale(1.1)" : "scale(1)",
                  transition: "all 0.2s ease",
                }} />
              ))}
            </div>

            {/* Category tags */}
            <div style={{
              display: "flex", alignItems: "center", justifyContent: "center",
              padding: "6px 12px 8px", gap: "4px",
            }}>
              {(variant === "gift"
                ? ["all", "gifts", "ideas"]
                : ["all", "hotels", "activities"]
              ).map((cat, i) => (
                <span key={cat} style={{
                  padding: "8px 14px",
                  fontSize: "14px", fontWeight: 400,
                  letterSpacing: "0.01em",
                  color: i === 1 ? ACCENT : INK_TER,
                  textTransform: "capitalize" as const,
                  whiteSpace: "nowrap" as const,
                }}>
                  {cat}
                </span>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* ═══ BRIDGE — taglines ═══ */}
      {stage === "bridge" && (
        <div style={{
          textAlign: "center", padding: "0 28px", maxWidth: "500px",
          display: "flex", flexDirection: "column", gap: "16px",
          alignItems: "center",
        }}>
          <p style={{
            fontSize: "clamp(22px, 5.5vw, 32px)",
            fontWeight: 400, letterSpacing: "-0.02em", lineHeight: 1.3,
            color: INK,
            opacity: bridgeLine1 ? 1 : 0,
            transform: bridgeLine1 ? "translateY(0)" : "translateY(8px)",
            transition: "opacity 0.5s ease, transform 0.5s ease",
          }}>
            <span style={{ ...liquidFire, fontStyle: "italic" }}>messaging</span>{" "}just evolved.
          </p>
          <p style={{
            fontSize: "clamp(16px, 4vw, 22px)",
            fontWeight: 400, letterSpacing: "-0.01em", lineHeight: 1.4,
            color: `${INK}88`,
            opacity: bridgeLine2 ? 1 : 0,
            transform: bridgeLine2 ? "translateY(0)" : "translateY(8px)",
            transition: "opacity 0.5s ease, transform 0.5s ease",
          }}>
            {bridgeTagline}
          </p>
        </div>
      )}

      {/* ═══ ACT 3: CLOSE — hello + messenger + coming soon ═══ */}
      {stage === "close" && (
        <div style={{
          display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center",
          gap: "clamp(12px, 2vh, 20px)",
          padding: "0 24px", width: "100%", textAlign: "center",
        }}>
          <div style={{
            ...liquidFire,
            fontSize: "clamp(56px, 15vw, 120px)",
            fontWeight: 400,
            fontStyle: "italic",
            letterSpacing: "-0.04em", lineHeight: 1,
            padding: "0 16px",
            opacity: helloVisible ? 1 : 0,
            transform: helloVisible ? "scale(1)" : "scale(1.4)",
            transition: "opacity 0.4s ease, transform 0.6s cubic-bezier(0.22, 1, 0.36, 1)",
          }}>
            hello
          </div>
          <div style={{
            ...liquidFire,
            fontSize: "clamp(16px, 4vw, 22px)",
            fontWeight: 300,
            fontStyle: "italic",
            letterSpacing: "0.2em",
            opacity: messengerVisible ? 1 : 0,
            transform: messengerVisible ? "scale(1)" : "scale(0.9)",
            transition: "opacity 0.5s ease, transform 0.5s ease",
          }}>
            messenger
          </div>
          <div style={{
            opacity: comingSoonVisible ? 1 : 0,
            transform: comingSoonVisible ? "translateY(0)" : "translateY(6px)",
            transition: "opacity 0.6s ease, transform 0.6s ease",
            marginTop: "8px",
          }}>
            <p style={{
              fontSize: "clamp(10px, 2.5vw, 13px)",
              fontWeight: 300, color: INK, opacity: 0.25,
              letterSpacing: "0.5em", textTransform: "uppercase" as const,
            }}>
              coming soon
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════
// PAGE — ?ad=amalfi | ?ad=gift
// Suspense boundary required for useSearchParams
// ═══════════════════════════════════════════════

const AD_STYLES = `${liquidFireCSS}
@keyframes blink { 50% { opacity: 0; } }
`;

function AdContent() {
  const searchParams = useSearchParams();
  const paramAd = searchParams.get("ad");
  const initialVariant = (paramAd === "amalfi" || paramAd === "gift") ? paramAd : "gift";

  const [variant, setVariant] = useState<"amalfi" | "gift">(initialVariant);
  const [key, setKey] = useState(0);

  return (
    <>
      <style dangerouslySetInnerHTML={{ __html: AD_STYLES }} />
      <Ad key={key} variant={variant} />
      {/* Controls removed for clean screen recording */}
    </>
  );
}

export default function AdPage() {
  return (
    <Suspense>
      <AdContent />
    </Suspense>
  );
}
