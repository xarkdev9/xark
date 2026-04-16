"use client";

import { useState, useEffect, useCallback, useRef } from "react";

// ═══════════════════════════════════════════════
// HELLO LANDING — land_plan.md implementation
// Canvas: #F9F8F6 (warm paper), Ink: #2D2D2A (charcoal)
// Liquid Fire: #C43D08 → #FF6B35 → #FF9F1C
// 5 scenes, 18 seconds, Inter only
// ═══════════════════════════════════════════════

const PAPER = "#F9F8F6";
const INK = "#2D2D2A";

const liquidFire: React.CSSProperties = {
  background: "linear-gradient(90deg, #C43D08, #FF6B35, #FF9F1C, #FF6B35, #C43D08)",
  backgroundSize: "200% auto",
  WebkitBackgroundClip: "text",
  backgroundClip: "text",
  color: "transparent",
  animation: "liquidShift 3s linear infinite",
};

// ── Chat scenarios ──
const CHATS: { app: "wa" | "im"; msgs: string[]; pos: [number, number] }[] = [
  { app: "wa", pos: [6, 4],   msgs: ["where are we eating?", "i'm good with whatever", "someone just pick"] },
  { app: "im", pos: [4, 58],  msgs: ["wait, who booked the airbnb?", "i thought you did...", "it's gone."] },
  { app: "wa", pos: [28, 2],  msgs: ["what weekend works?", "can't do the 14th", "next year then?"] },
  { app: "im", pos: [25, 55], msgs: ["who owes who for the flights?", "..."] },
  { app: "wa", pos: [48, 8],  msgs: ["tacos or sushi?", "yes"] },
  { app: "im", pos: [45, 60], msgs: ["found a rooftop bar", "they don't take groups over 6"] },
  { app: "wa", pos: [62, 3],  msgs: ["here are 14 links to hotels", "nobody is clicking all those"] },
  { app: "im", pos: [65, 55], msgs: ["did we ever decide on dates?", "idk"] },
];

// ── Reel phrases ──
const REEL_PHRASES = [
  "actual plans.",
  "booked weekends.",
  "a table for six.",
  "zero arguments.",
  "packed bags.",
  "the 80% consensus.",
  "clarity.",
];

// ── The Pact beats ──
const PACT_BEATS = [
  { lines: ["the banter stays.", "the chaos ends."], hold: 1800 },
  { lines: ["more memes.", "less \"wait, who's booking what?\""], hold: 1800 },
  { lines: ["keep the roasts.", "burn the shared spreadsheet."], hold: 2200 },
];

type Stage = "chaos" | "reel" | "pact" | "preslam" | "final";

// ═══ BUBBLE ═══
function Bubble({ msg, app, out }: { msg: string; app: "wa" | "im"; out: boolean }) {
  const bg = app === "wa"
    ? (out ? "#005c4b" : "#1e2b31")
    : (out ? "#2563eb" : "#333333");
  const color = app === "wa" ? "#e9edef" : "#ffffff";

  return (
    <div style={{ display: "flex", justifyContent: out ? "flex-end" : "flex-start" }}>
      <div style={{
        padding: "7px 13px",
        borderRadius: "16px",
        borderBottomRightRadius: out ? "4px" : "16px",
        borderBottomLeftRadius: out ? "16px" : "4px",
        fontSize: "12.5px",
        fontWeight: 400,
        lineHeight: 1.4,
        letterSpacing: "-0.01em",
        background: bg,
        color,
        maxWidth: "90%",
        width: "fit-content",
      }}>
        {msg}
      </div>
    </div>
  );
}

// ═══ SLOT REEL — continuous vertical spin, no stops until last phrase ═══
function SlotReel({ phrases, onDone }: { phrases: string[]; onDone: () => void }) {
  const ITEM_H = 56;
  const containerRef = useRef<HTMLDivElement>(null);
  const raf = useRef(0);
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;

    const el = containerRef.current;
    if (!el) return;

    // Total distance: just scroll through all phrases once, land on last
    const totalDist = (phrases.length - 1) * ITEM_H;

    const startTime = performance.now();
    const DURATION = 10000; // 10 seconds total — ~1.4s per phrase

    // Mostly linear, gentle decelerate at end, tiny overshoot on landing
    function easeOut(t: number) {
      // Linear for 80%, then smooth decelerate for final 20%
      if (t < 0.8) return t * 1.1; // slightly ahead of linear
      const tail = (t - 0.8) / 0.2; // 0→1 in final 20%
      return 0.88 + 0.12 * (1 - Math.pow(1 - tail, 3)); // cubic ease-out for last stretch
    }

    function tick(now: number) {
      const elapsed = now - startTime;
      const p = Math.min(elapsed / DURATION, 1);
      const eased = Math.min(easeOut(p), 1);
      const currentOffset = eased * totalDist;

      const inner = el?.firstElementChild as HTMLElement | null;
      if (inner) {
        inner.style.transform = `translateY(-${currentOffset % (phrases.length * ITEM_H)}px)`;
      }

      if (p < 1) {
        raf.current = requestAnimationFrame(tick);
      } else {
        // Landed on last phrase — hold then done
        setTimeout(onDone, 1200);
      }
    }

    // Start after brief pause
    setTimeout(() => {
      raf.current = requestAnimationFrame(tick);
    }, 400);

    return () => cancelAnimationFrame(raf.current);
  }, [phrases, onDone]);

  // Build reel: multiple copies for continuous scroll
  const reel: string[] = [];
  for (let s = 0; s < 4; s++) {
    for (const p of phrases) reel.push(p);
  }

  return (
    <div
      ref={containerRef}
      style={{
        height: `${ITEM_H}px`,
        overflow: "hidden",
        position: "relative",
        width: "100%",
      }}
    >
      <div>
        {reel.map((p, i) => (
          <div key={`${i}`} style={{
            height: `${ITEM_H}px`,
            display: "flex", alignItems: "center", justifyContent: "center",
          }}>
            <span style={{ opacity: 0.6 }}>{p}</span>
          </div>
        ))}
      </div>

      {/* Edge blur — always visible */}
      <div style={{ position: "absolute", top: 0, left: 0, right: 0, height: "30%", background: `linear-gradient(to bottom, ${PAPER}, transparent)`, pointerEvents: "none", zIndex: 2 }} />
      <div style={{ position: "absolute", bottom: 0, left: 0, right: 0, height: "30%", background: `linear-gradient(to top, ${PAPER}, transparent)`, pointerEvents: "none", zIndex: 2 }} />
    </div>
  );
}

// ═══ MAIN ═══
export default function LandingPage() {
  const [stage, setStage] = useState<Stage>("chaos");
  const [visible, setVisible] = useState<boolean[]>(new Array(CHATS.length).fill(false));
  const [climax, setClimax] = useState(false);
  const [shatter, setShatter] = useState(false);
  const [pactBeat, setPactBeat] = useState(0);
  const [pactIn, setPactIn] = useState(false);
  const [finalIn, setFinalIn] = useState(false);
  const [slamThud, setSlamThud] = useState(false);
  const chaosRef = useRef<HTMLDivElement>(null);
  const isDesktop = useRef(false);

  useEffect(() => {
    isDesktop.current = window.innerWidth >= 768;
  }, []);

  // Random shatter directions for each cluster
  const shatterDirs = useRef(
    CHATS.map(() => ({
      x: (Math.random() - 0.5) * 600,
      y: (Math.random() - 0.5) * 400,
      r: (Math.random() - 0.5) * 90,
      s: 0.3 + Math.random() * 0.4,
    }))
  );

  // ── CHAOS ──
  useEffect(() => {
    if (stage !== "chaos") return;
    setVisible(new Array(CHATS.length).fill(false));
    setClimax(false);
    setShatter(false);

    const timers: ReturnType<typeof setTimeout>[] = [];

    // Stagger clusters: start slow, accelerate
    const delays = [300, 1100, 1800, 2400, 2900, 3300, 3600, 3850];
    CHATS.forEach((_, i) => {
      timers.push(setTimeout(() => {
        setVisible(prev => { const n = [...prev]; n[i] = true; return n; });
      }, delays[i] || i * 400 + 300));
    });

    // Climax: "so... what's the plan?" at 5.5s
    timers.push(setTimeout(() => setClimax(true), 5500));

    // Shatter at 7.5s
    timers.push(setTimeout(() => setShatter(true), 7500));

    // Transition at 8.3s
    timers.push(setTimeout(() => setStage("reel"), 8500));

    return () => timers.forEach(clearTimeout);
  }, [stage]);

  // Mobile auto-scroll
  useEffect(() => {
    if (stage !== "chaos" || isDesktop.current) return;
    const idx = visible.lastIndexOf(true);
    if (idx >= 0 && chaosRef.current) {
      const el = chaosRef.current.children[idx] as HTMLElement;
      el?.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  }, [visible, stage]);

  // ── PACT ──
  useEffect(() => {
    if (stage !== "pact") return;
    setPactBeat(0);
    setPactIn(false);

    let beat = 0;
    function showBeat() {
      setPactBeat(beat);
      setPactIn(false);
      setTimeout(() => setPactIn(true), 50);

      const hold = PACT_BEATS[beat].hold;
      setTimeout(() => {
        setPactIn(false);
        setTimeout(() => {
          beat++;
          if (beat < PACT_BEATS.length) {
            showBeat();
          } else {
            // "spreadsheet" blurs out violently — handled by pactIn false
            setTimeout(() => setStage("preslam"), 600);
          }
        }, 400);
      }, hold);
    }

    setTimeout(showBeat, 300);
  }, [stage]);

  // ── PRE-SLAM ──
  useEffect(() => {
    if (stage !== "preslam") return;
    const t = setTimeout(() => setStage("final"), 800);
    return () => clearTimeout(t);
  }, [stage]);

  // ── FINAL ──
  useEffect(() => {
    if (stage !== "final") return;
    setFinalIn(false);
    setSlamThud(false);
    // Single slam: scale 2x → 1x with overshoot, then thud flag for subtext
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        setFinalIn(true);
        setTimeout(() => setSlamThud(true), 600);
      });
    });
  }, [stage]);

  const replay = useCallback(() => setStage("chaos"), []);

  return (
    <>
      <style>{`
        @keyframes liquidShift {
          0% { background-position: 0% 50%; }
          50% { background-position: 100% 50%; }
          100% { background-position: 0% 50%; }
        }
      `}</style>

      <div style={{
        position: "fixed", inset: 0,
        background: PAPER,
        display: "flex", alignItems: "center", justifyContent: "center",
        overflow: "hidden",
        fontFamily: "'Inter', -apple-system, system-ui, sans-serif",
        color: INK,
        fontWeight: 400,
        WebkitFontSmoothing: "antialiased",
      }}>

        {/* ═══ SCENE 1: CHAOS ═══ */}
        {stage === "chaos" && (
          <>
            <div
              ref={chaosRef}
              style={{
                width: "100%", height: "100%",
                overflowY: isDesktop.current ? "hidden" : "auto",
                WebkitOverflowScrolling: "touch",
                padding: isDesktop.current ? "0" : "50px 16px 120px",
                display: isDesktop.current ? "block" : "flex",
                flexDirection: "column",
                gap: "18px",
                alignItems: "center",
                scrollbarWidth: "none",
                position: "relative",
                maxWidth: isDesktop.current ? "900px" : undefined,
                margin: isDesktop.current ? "0 auto" : undefined,
              }}
            >
              {CHATS.map((s, i) => {
                const d = shatterDirs.current[i];
                return (
                  <div
                    key={i}
                    style={{
                      ...(isDesktop.current ? {
                        position: "absolute" as const,
                        top: `${s.pos[0]}%`,
                        left: `${s.pos[1]}%`,
                      } : {}),
                      width: "100%",
                      maxWidth: isDesktop.current ? "230px" : "280px",
                      display: "flex",
                      flexDirection: "column" as const,
                      gap: "3px",
                      opacity: visible[i] ? (shatter ? 0 : 1) : 0,
                      transform: visible[i]
                        ? shatter
                          ? `translate(${d.x}px, ${d.y}px) rotate(${d.r}deg) scale(${d.s})`
                          : "translateY(0) scale(1)"
                        : "translateY(16px) scale(0.96)",
                      filter: shatter ? "blur(12px)" : "none",
                      transition: shatter
                        ? "all 0.7s cubic-bezier(0.22, 1, 0.36, 1)"
                        : "opacity 0.5s ease, transform 0.5s cubic-bezier(0.22, 1, 0.36, 1)",
                    }}
                  >
                    {s.msgs.map((m, j) => (
                      <Bubble key={j} msg={m} app={s.app} out={j % 2 !== 0} />
                    ))}
                  </div>
                );
              })}
            </div>

            {/* Climax: "so... what's the plan?" */}
            <div style={{
              position: "fixed", inset: 0,
              display: "flex", flexDirection: "column",
              alignItems: "center", justifyContent: "center",
              pointerEvents: "none", zIndex: 10,
              opacity: climax ? (shatter ? 0 : 1) : 0,
              transform: climax ? (shatter ? "scale(0.8)" : "scale(1)") : "scale(0.9) translateY(8px)",
              filter: shatter ? "blur(16px)" : "none",
              transition: shatter
                ? "all 0.7s cubic-bezier(0.22, 1, 0.36, 1)"
                : "all 0.6s cubic-bezier(0.22, 1, 0.36, 1)",
            }}>
              <span style={{
                fontSize: "clamp(20px, 5vw, 36px)",
                fontWeight: 400,
                letterSpacing: "-0.02em",
                color: INK,
                background: PAPER,
                padding: "12px 24px",
                borderRadius: "20px",
                boxShadow: "0 8px 40px rgba(0,0,0,0.08)",
              }}>
                so... what&apos;s the plan?
              </span>
              <span style={{
                fontSize: "10px",
                fontWeight: 300,
                color: INK,
                opacity: 0.25,
                marginTop: "8px",
                letterSpacing: "0.06em",
              }}>
                Read by everyone · 9:42 PM
              </span>
            </div>

          </>
        )}

        {/* ═══ SCENE 2: THE REEL ═══ */}
        {stage === "reel" && (
          <div style={{
            textAlign: "center", padding: "0 32px",
            width: "100%", maxWidth: "600px",
            display: "flex", flexDirection: "column",
            alignItems: "center", gap: "clamp(8px, 2vh, 16px)",
            opacity: 1,
            animation: "fadeIn 0.8s ease",
          }}>
            {/* SAY */}
            <div style={{
              fontSize: "clamp(11px, 2vw, 16px)",
              fontWeight: 300,
              letterSpacing: "0.35em",
              textTransform: "uppercase",
              opacity: 0.3,
              color: INK,
            }}>
              say
            </div>

            {/* hello */}
            <div style={{
              ...liquidFire,
              fontSize: "clamp(48px, 12vw, 110px)",
              fontWeight: 400,
              fontStyle: "italic",
              letterSpacing: "-0.04em",
              lineHeight: 1,
              padding: "0 8px",
            }}>
              hello
            </div>

            {/* Reel */}
            <div style={{
              width: "100%",
              fontSize: "clamp(18px, 4vw, 32px)",
              fontWeight: 300,
              letterSpacing: "-0.01em",
              color: INK,
            }}>
              <SlotReel
                phrases={REEL_PHRASES}
                onDone={() => setStage("pact")}
              />
            </div>
          </div>
        )}

        {/* ═══ SCENE 3: THE PACT ═══ */}
        {stage === "pact" && (
          <div style={{
            textAlign: "center",
            padding: "0 24px",
            maxWidth: "600px",
          }}>
            {PACT_BEATS[pactBeat] && (
              <div style={{
                opacity: pactIn ? 1 : 0,
                transform: pactIn ? "translateY(0)" : "translateY(6px)",
                transition: pactIn
                  ? "opacity 0.3s ease, transform 0.3s cubic-bezier(0.22, 1, 0.36, 1)"
                  : "opacity 0.25s ease, transform 0.25s ease",
              }}>
                {PACT_BEATS[pactBeat].lines.map((line, i) => (
                  <p key={i} style={{
                    fontSize: "clamp(22px, 5vw, 40px)",
                    fontWeight: 400,
                    letterSpacing: "-0.02em",
                    lineHeight: 1.4,
                    color: i === 0 ? INK : `${INK}99`,
                  }}>
                    {line}
                  </p>
                ))}
              </div>
            )}
          </div>
        )}

        {/* ═══ SCENE 4: PRE-SLAM ═══ */}
        {stage === "preslam" && (
          <div style={{
            fontSize: "clamp(40px, 12vw, 96px)",
            fontWeight: 400,
            fontStyle: "italic",
            letterSpacing: "-0.04em",
            opacity: 0.12,
            textAlign: "center",
            color: INK,
            animation: "fadeIn 0.2s ease",
          }}>
            say
          </div>
        )}

        {/* ═══ SCENE 5: THE SLAM ═══ */}
        {stage === "final" && (
          <div style={{ textAlign: "center", padding: "0 16px" }}>
            {/* hello. — THE SLAM */}
            <div style={{
              ...liquidFire,
              fontSize: "clamp(72px, 22vw, 280px)",
              fontWeight: 400,
              fontStyle: "italic",
              letterSpacing: "-0.04em",
              lineHeight: 1,
              padding: "0 12px",
              opacity: finalIn ? 1 : 0,
              transform: finalIn ? "scale(1)" : "scale(2.5)",
              transition: finalIn
                ? "opacity 0.3s ease, transform 0.5s cubic-bezier(0.22, 1.4, 0.36, 1)"
                : "none",
            }}>
              hello.
            </div>

            {/* Coming soon */}
            <div style={{
              marginTop: "clamp(32px, 5vh, 56px)",
              opacity: slamThud ? 1 : 0,
              transition: "opacity 1s ease 0.8s",
            }}>
              <p style={{
                fontSize: "clamp(8px, 1.2vw, 11px)",
                letterSpacing: "0.6em",
                textTransform: "uppercase",
                opacity: 0.3,
                color: INK,
              }}>
                coming soon
              </p>
            </div>

            <button
              onClick={replay}
              style={{
                position: "fixed",
                bottom: "max(env(safe-area-inset-bottom, 16px), 24px)",
                left: "50%", transform: "translateX(-50%)",
                fontSize: "8px", letterSpacing: "0.3em", textTransform: "uppercase",
                opacity: 0.06, color: INK, background: "none", border: "none",
                cursor: "pointer", padding: "12px 20px",
              }}
            >
              replay
            </button>
          </div>
        )}
      </div>

      <style>{`
        @keyframes fadeIn {
          from { opacity: 0; }
          to { opacity: 1; }
        }
      `}</style>
    </>
  );
}
