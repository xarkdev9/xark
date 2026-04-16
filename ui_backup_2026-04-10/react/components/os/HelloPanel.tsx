"use client";

// hello OS v2.0 — HelloPanel (Raycast-style AI Assistant Panel)
// Input at thumb arc (bottom). Results grow upward. Category results → Decide stream.
// Conversational answers render as glanceable micro-widgets inline.
// Drag-to-dismiss. Haptic feedback. Ghost recents. Ambient context.

import { useState, useRef, useCallback, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import { Search, X, ChevronRight } from "lucide-react";
import { colors, ink, surface } from "@/lib/theme";

// ── Types ──
type SlotType = "intent" | "location" | "date" | "budget" | "query";
interface Slot { id: string; type: SlotType; value: string; label: string; }

const INTENT_MAP: Record<string, { value: string; label: string }> = {
  hotel: { value: "hotel", label: "🏨 hotels" }, hotels: { value: "hotel", label: "🏨 hotels" },
  stay: { value: "hotel", label: "🏨 stays" }, stays: { value: "hotel", label: "🏨 stays" },
  airbnb: { value: "hotel", label: "🏨 airbnb" }, resort: { value: "hotel", label: "🏨 resorts" },
  resorts: { value: "hotel", label: "🏨 resorts" },
  flight: { value: "flight", label: "✈️ flights" }, flights: { value: "flight", label: "✈️ flights" },
  fly: { value: "flight", label: "✈️ flights" },
  restaurant: { value: "restaurant", label: "🍽️ food" }, restaurants: { value: "restaurant", label: "🍽️ food" },
  food: { value: "restaurant", label: "🍽️ food" }, dinner: { value: "restaurant", label: "🍽️ dinner" },
  lunch: { value: "restaurant", label: "🍽️ lunch" }, brunch: { value: "restaurant", label: "🍽️ brunch" },
  coffee: { value: "restaurant", label: "☕ coffee" }, bars: { value: "restaurant", label: "🍸 bars" },
  things: { value: "activity", label: "📍 places" }, activities: { value: "activity", label: "📍 activities" },
  places: { value: "activity", label: "📍 places" }, sunset: { value: "activity", label: "📍 sunset spots" },
  beach: { value: "activity", label: "📍 beaches" },
};

const BUDGET_PATTERN = /(?:under|below|max|budget|<)\s*\$?(\d+)/i;
const CONVERSATIONAL_PATTERNS = [
  /^split\s+\d/i, /^what\s+day\s+is/i, /^how\s+many\s+days/i,
  /^how\s+much\s+is/i, /^calculate/i, /^convert\s+\d/i,
  /^thank/i, /^who\s+voted/i, /^what(?:'s| is) the status/i,
  /^how\s+to\s+say/i, /^\d+\s*[\+\-\*\/x×÷]\s*\d/i,
];

const CATEGORY_INTENTS = new Set(["hotel", "flight", "restaurant", "activity"]);

// ── Haptics ──
function haptic(type: "light" | "success" = "light") {
  if (typeof navigator !== "undefined" && navigator.vibrate) {
    navigator.vibrate(type === "success" ? [15, 30, 20] : 10);
  }
}

// ── Search History (localStorage) ──
const HISTORY_KEY = "hello_search_history";
const MAX_HISTORY = 8;
function getHistory(): Array<{ query: string; count: number }> {
  try { return JSON.parse(localStorage.getItem(HISTORY_KEY) || "[]"); } catch { return []; }
}
function addHistory(query: string, count: number) {
  try {
    const h = getHistory().filter((x) => x.query !== query);
    h.unshift({ query, count });
    localStorage.setItem(HISTORY_KEY, JSON.stringify(h.slice(0, MAX_HISTORY)));
  } catch { /* silent */ }
}

// ── Result types ──
interface PanelResult {
  type: "receipt" | "answer";
  text: string;
  count?: number;
  images?: string[];
  intent?: string;
}

export interface HelloPanelPayload {
  source: "slide_panel";
  intent: string;
  confidence: number;
  params: Record<string, string>;
  rawMessage: string;
}

export interface HelloPanelResult {
  title: string;
  price?: string;
  imageUrl?: string;
  description?: string;
  rating?: number;
}

interface HelloPanelProps {
  open: boolean;
  onClose: () => void;
  onSubmit: (payload: HelloPanelPayload) => Promise<{
    response: string;
    results?: HelloPanelResult[];
  }>;
  onSwitchToDecide?: () => void;
  spaceTitle?: string;
}

export function HelloPanel({ open, onClose, onSubmit, onSwitchToDecide, spaceTitle }: HelloPanelProps) {
  const [inputValue, setInputValue] = useState("");
  const [slots, setSlots] = useState<Slot[]>([]);
  const [searching, setSearching] = useState(false);
  const [panelResults, setPanelResults] = useState<PanelResult[]>([]);
  const [history, setHistory] = useState<Array<{ query: string; count: number }>>([]);
  const inputRef = useRef<HTMLInputElement>(null);
  const resultsRef = useRef<HTMLDivElement>(null);

  // Ambient context
  const isPersonName = spaceTitle && (/&|,/.test(spaceTitle) || /^[a-z]+ [a-z]+$/i.test(spaceTitle.trim()) || spaceTitle.trim().split(/\s+/).length <= 2);
  const hasDestKeyword = spaceTitle && /trip|travel|vacation|visit|tour|2026|2025|city|beach|island/i.test(spaceTitle);
  const suggestedLocation = spaceTitle && (!isPersonName || hasDestKeyword) && spaceTitle !== "untitled" ? spaceTitle : null;
  const hasLocationSlot = slots.some((s) => s.type === "location");
  const hasIntentSlot = slots.some((s) => s.type === "intent");

  useEffect(() => {
    if (open) {
      setTimeout(() => inputRef.current?.focus(), 150);
      setHistory(getHistory());
      haptic("light");
    }
  }, [open]);

  useEffect(() => {
    if (!open) { setInputValue(""); setSlots([]); setSearching(false); setPanelResults([]); }
  }, [open]);

  // Auto-scroll results to bottom (newest visible)
  useEffect(() => {
    if (panelResults.length > 0 && resultsRef.current) {
      resultsRef.current.scrollTop = resultsRef.current.scrollHeight;
    }
  }, [panelResults]);

  const addSlot = useCallback((slot: Slot) => {
    setSlots((prev) => prev.some((s) => s.type === slot.type) ? prev : [...prev, slot]);
    haptic("light");
  }, []);

  // ── Fluid Parser ──
  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === "Backspace" && inputValue === "") {
      setSlots((prev) => prev.slice(0, -1));
      haptic("light");
      return;
    }
    if (e.key === " ") {
      const word = inputValue.trim().toLowerCase();
      if (INTENT_MAP[word] && !hasIntentSlot) {
        addSlot({ id: `i_${Date.now()}`, type: "intent", value: INTENT_MAP[word].value, label: INTENT_MAP[word].label });
        setInputValue("");
        e.preventDefault();
      }
    }
    if (e.key === "Enter") {
      e.preventDefault();
      const trimmed = inputValue.trim();
      if (!trimmed && slots.length === 0) return;

      // Extract budget
      const budgetMatch = trimmed.match(BUDGET_PATTERN);
      if (budgetMatch && !slots.some((s) => s.type === "budget")) {
        addSlot({ id: `b_${Date.now()}`, type: "budget", value: budgetMatch[1], label: `💰 <$${budgetMatch[1]}` });
      }
      // Extract multi-word location
      if (!hasLocationSlot) {
        const locMatch = trimmed.match(/\b(?:in|near|around|at)\s+(.+)$/i);
        if (locMatch?.[1]) {
          const loc = locMatch[1].replace(BUDGET_PATTERN, "").trim();
          if (loc) addSlot({ id: `l_${Date.now()}`, type: "location", value: loc, label: `📍 ${loc}` });
        }
      }
      setTimeout(() => fireSearch(), 10);
    }
  };

  // ── Fire Search ──
  const fireSearch = async () => {
    const intentSlot = slots.find((s) => s.type === "intent");
    const locationSlot = slots.find((s) => s.type === "location");
    const budgetSlot = slots.find((s) => s.type === "budget");
    const remaining = inputValue.trim();

    let intent = intentSlot?.value || "general";
    if (!intentSlot && remaining) {
      for (const w of remaining.toLowerCase().split(/\s+/)) {
        if (INTENT_MAP[w]) { intent = INTENT_MAP[w].value; break; }
      }
    }

    let confidence = intentSlot ? 1.0 : 0.5;
    const fullQuery = [remaining, ...slots.map((s) => s.value)].join(" ");
    if (CONVERSATIONAL_PATTERNS.some((p) => p.test(fullQuery) || p.test(remaining))) {
      confidence = 0;
      intent = "general";
    }

    const location = locationSlot?.value || "";
    const rawParts = [intent !== "general" ? intent + "s" : "", remaining, locationSlot ? `in ${locationSlot.value}` : ""].filter(Boolean);
    const rawMessage = rawParts.join(" ").trim() || remaining;

    const payload: HelloPanelPayload = {
      source: "slide_panel", intent, confidence,
      params: { query: remaining || rawMessage, location, ...(budgetSlot && { maxPrice: budgetSlot.value }) },
      rawMessage: `@hello ${rawMessage}`,
    };

    setSearching(true);
    setInputValue("");

    try {
      const result = await onSubmit(payload);
      const isCategory = CATEGORY_INTENTS.has(intent) && (result.results?.length ?? 0) > 0;
      const images = result.results?.slice(0, 3).map((r) => r.imageUrl).filter(Boolean) as string[] || [];

      const newResult: PanelResult = isCategory
        ? { type: "receipt", text: `${intent}s added to decide`, count: result.results?.length ?? 0, images, intent }
        : { type: "answer", text: result.response };

      setPanelResults((prev) => [...prev, newResult]);
      addHistory(rawMessage, result.results?.length ?? 0);
      setHistory(getHistory());
      haptic("success");
    } catch {
      setPanelResults((prev) => [...prev, { type: "answer", text: "something went wrong. try again." }]);
    } finally {
      setSearching(false);
      setSlots([]);
      setTimeout(() => inputRef.current?.focus(), 100);
    }
  };

  return (
    <AnimatePresence>
      {open && (
        <>
          {/* Dimmed overlay (no backdrop-blur per constitution) */}
          <motion.div
            initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
            transition={{ duration: 0.15 }}
            onClick={onClose}
            style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.6)", zIndex: 70 }}
          />

          {/* Panel — drag-to-dismiss */}
          <motion.div
            initial={{ y: "100%" }} animate={{ y: 0 }} exit={{ y: "100%" }}
            transition={{ type: "spring", damping: 25, stiffness: 200 }}
            drag="y" dragConstraints={{ top: 0 }} dragElastic={0.2}
            onDragEnd={(_, info) => { if (info.offset.y > 100) onClose(); }}
            style={{
              position: "fixed", bottom: 0, left: 0, right: 0,
              background: surface.chrome,
              borderRadius: "20px 20px 0 0",
              zIndex: 71,
              height: "70dvh",
              maxHeight: "600px",
              display: "flex",
              flexDirection: "column",
              paddingBottom: "max(env(safe-area-inset-bottom, 12px), 12px)",
            }}
          >
            {/* Drag handle + close */}
            <div style={{ display: "flex", justifyContent: "center", alignItems: "center", padding: "8px 16px 4px", position: "relative" }}>
              <div style={{ width: "36px", height: "4px", borderRadius: "2px", background: "rgba(128,128,128,0.2)" }} />
              <button onClick={onClose} style={{ position: "absolute", right: "12px", background: "none", border: "none", cursor: "pointer", padding: "4px", color: ink.tertiary }}>
                <X size={18} />
              </button>
            </div>

            {/* Results area — grows upward (justify-end) */}
            <div ref={resultsRef} style={{
              flex: 1, overflowY: "auto", display: "flex", flexDirection: "column",
              justifyContent: "flex-end", gap: "10px", padding: "8px 16px",
              minHeight: 0,
            }}>
              <AnimatePresence>
                {panelResults.map((res, i) => (
                  <motion.div
                    key={i}
                    initial={{ opacity: 0, y: 10, scale: 0.97 }}
                    animate={{ opacity: 1, y: 0, scale: 1 }}
                    transition={{ duration: 0.2 }}
                  >
                    {res.type === "answer" ? (
                      /* ── Glanceable Micro-Widget ── */
                      <div style={{
                        background: "rgba(255,107,53,0.06)",
                        padding: "16px",
                        borderRadius: "16px",
                        border: "0.5px solid rgba(255,107,53,0.12)",
                      }}>
                        <p style={{ fontSize: "36px", fontWeight: 400, color: ink.primary, lineHeight: 1.1, letterSpacing: "-0.02em" }}>
                          {res.text}
                        </p>
                      </div>
                    ) : (
                      /* ── Actionable Receipt ── */
                      <div
                        onClick={() => { onSwitchToDecide?.(); onClose(); }}
                        style={{
                          background: surface.recessed,
                          padding: "12px 14px",
                          borderRadius: "16px",
                          display: "flex",
                          alignItems: "center",
                          justifyContent: "space-between",
                          cursor: "pointer",
                        }}
                      >
                        <div style={{ display: "flex", alignItems: "center", gap: "10px" }}>
                          {/* Overlapping thumbnail stack */}
                          {res.images && res.images.length > 0 && (
                            <div style={{ display: "flex", marginLeft: "4px" }}>
                              {res.images.slice(0, 3).map((img, j) => (
                                <img key={j} src={img} alt="" style={{
                                  width: "36px", height: "36px", borderRadius: "50%",
                                  objectFit: "cover", border: `2px solid ${surface.chrome}`,
                                  marginLeft: j > 0 ? "-10px" : 0,
                                }} />
                              ))}
                            </div>
                          )}
                          <span style={{ fontSize: "13px", fontWeight: 400, color: ink.primary }}>
                            <span style={{ fontSize: "15px", color: colors.accent }}>{res.count}</span>
                            {" "}{res.text}
                          </span>
                        </div>
                        <ChevronRight size={18} color={ink.tertiary} />
                      </div>
                    )}
                  </motion.div>
                ))}
              </AnimatePresence>

              {/* Searching indicator */}
              {searching && (
                <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
                  style={{ textAlign: "center", padding: "12px" }}>
                  <span style={{ fontSize: "12px", fontWeight: 300, color: ink.tertiary }}>searching...</span>
                </motion.div>
              )}
            </div>

            {/* Ghost Recents — horizontal scrolling pills above input */}
            {history.length > 0 && panelResults.length === 0 && !searching && (
              <div style={{
                display: "flex", gap: "8px", overflowX: "auto", padding: "4px 16px 8px",
                scrollbarWidth: "none", WebkitOverflowScrolling: "touch",
              }}>
                {history.map((h, i) => (
                  <button key={i}
                    onClick={() => { setInputValue(h.query); haptic("light"); setTimeout(() => inputRef.current?.focus(), 50); }}
                    style={{
                      flexShrink: 0, fontSize: "12px", fontWeight: 300, color: ink.tertiary,
                      background: surface.recessed, padding: "6px 12px", borderRadius: "20px",
                      border: "none", cursor: "pointer", whiteSpace: "nowrap",
                    }}>
                    {h.query}
                  </button>
                ))}
              </div>
            )}

            {/* Input bar — BOTTOM (thumb arc) */}
            <div style={{
              display: "flex", flexWrap: "wrap", alignItems: "center", gap: "6px",
              background: surface.recessed, borderRadius: "16px", padding: "10px 12px",
              margin: "0 12px", minHeight: "48px", position: "relative",
            }}>
              <Search size={16} color={ink.tertiary} style={{ flexShrink: 0, opacity: 0.5 }} />

              {/* Locked chips */}
              {slots.map((slot) => (
                <motion.span layout key={slot.id} style={{
                  background: surface.chrome, fontSize: "13px", fontWeight: 400, color: ink.primary,
                  padding: "4px 10px", borderRadius: "8px", border: "0.5px solid rgba(128,128,128,0.15)",
                  whiteSpace: "nowrap",
                }}>
                  {slot.label}
                </motion.span>
              ))}

              {/* Ghost location suggestion */}
              {!hasLocationSlot && suggestedLocation && !inputValue.toLowerCase().includes(suggestedLocation.toLowerCase()) && slots.length > 0 && (
                <span role="button" tabIndex={0}
                  onClick={() => addSlot({ id: `l_${Date.now()}`, type: "location", value: suggestedLocation, label: `📍 ${suggestedLocation}` })}
                  style={{ fontSize: "12px", fontWeight: 300, color: ink.tertiary, opacity: 0.4, cursor: "pointer", padding: "2px 6px" }}>
                  in {suggestedLocation} ↵
                </span>
              )}

              {/* Text input */}
              <input ref={inputRef} type="text" value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyDown={handleKeyDown}
                disabled={searching}
                placeholder={slots.length === 0 ? "what's the plan?" : ""}
                style={{
                  flex: 1, minWidth: "80px", background: "transparent", border: "none", outline: "none",
                  fontSize: "15px", fontWeight: 400, color: ink.primary, padding: "2px 4px",
                  opacity: searching ? 0.3 : 1,
                }}
              />

              {/* Go button */}
              {(inputValue.trim().length > 0 || slots.length > 0) && !searching && (
                <button onClick={() => { if (inputValue.trim() || slots.length) fireSearch(); }}
                  style={{
                    background: colors.accent, color: "#fff", border: "none", borderRadius: "10px",
                    padding: "6px 10px", cursor: "pointer", flexShrink: 0, display: "flex", alignItems: "center",
                  }}>
                  <ChevronRight size={16} strokeWidth={3} />
                </button>
              )}
            </div>
          </motion.div>
        </>
      )}
    </AnimatePresence>
  );
}
