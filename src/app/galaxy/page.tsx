"use client";

// XARK OS v2.0 — GALAXY PAGE
// Tab toggle: People | Plans. Dream input fixed above ControlCaret.

import { Suspense, useState, useCallback, useRef } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { AwarenessStream } from "@/components/os/AwarenessStream";
import { PeopleDock } from "@/components/os/PeopleDock";
import { MemoriesTab } from "@/components/os/MemoriesTab";
import { useAuth } from "@/hooks/useAuth";
import { createSpace, getOptimisticSpaceId } from "@/lib/spaces";
import { colors, opacity, timing, layout, text } from "@/lib/theme";

type GalaxyTab = "people" | "plans" | "memories";

// ── Send icon ──
function SendIcon({ color, size = 24 }: { color: string; size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="11" stroke={color} strokeWidth="1.5" />
      <path d="M12 16V8M12 8l-4 4M12 8l4 4" stroke={color} strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

function GalaxyContent() {
  const searchParams = useSearchParams();
  const router = useRouter();
  const userName = searchParams.get("name") ?? "";
  const { user } = useAuth(userName || undefined);
  const [activeTab, setActiveTab] = useState<GalaxyTab>("plans");

  // Dream input state
  const [dream, setDream] = useState("");
  const [isCreating, setIsCreating] = useState(false);
  const [inputFocused, setInputFocused] = useState(false);
  const inputRef = useRef<HTMLInputElement>(null);

  const userId = user?.uid ?? `name_${userName}`;

  const handleSpaceTap = (spaceId: string, viewMode?: "decide") => {
    const viewParam = viewMode ? `&view=${viewMode}` : "";
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}${viewParam}`);
  };

  const handlePersonTap = (spaceId: string) => {
    router.push(`/space/${spaceId}?name=${encodeURIComponent(userName)}`);
  };

  const manifestDream = useCallback(async () => {
    const raw = dream.trim();
    if (!raw || isCreating) return;
    setIsCreating(true);

    // Strip "@xark create" / "@xark" prefix — user wants a space, not an @xark command
    const txt = raw.replace(/^@xark\s+(create|make|start|new)\s+/i, "").replace(/^@xark\s+/i, "").trim() || raw;

    const spaceId = getOptimisticSpaceId(txt);
    handleSpaceTap(spaceId);
    createSpace(txt, userId).catch(() => {});
  }, [dream, isCreating, userId]);

  return (
    <div className="relative" style={{ height: "100dvh", overflow: "hidden", display: "flex", flexDirection: "column" }}>
      {/* ── Spectrum Wash ── */}
      <div
        className="pointer-events-none fixed inset-0"
        style={{
          background: [
            `radial-gradient(ellipse 70% 50% at 30% 30%, rgba(var(--xark-accent-rgb), ${opacity.meshCyan}) 0%, transparent 60%)`,
            `radial-gradient(ellipse 60% 40% at 70% 60%, rgba(var(--xark-amber-rgb), ${opacity.meshAmber}) 0%, transparent 50%)`,
          ].join(", "),
        }}
      />

      {/* ── Mesh Pulse ── */}
      <div
        className="pointer-events-none fixed inset-0"
        style={{
          background: `radial-gradient(ellipse 80% 60% at 50% 40%, rgba(var(--xark-white-rgb), 0.03) 0%, transparent 100%)`,
          animation: `meshPulse ${timing.meshPulse} ease-in-out infinite`,
        }}
      />

      {/* ── Tab header ── */}
      <div
        className="relative z-10 px-6"
        style={{ paddingTop: "calc(env(safe-area-inset-top, 0px) + 48px)", flexShrink: 0 }}
      >
        <div
          className="mx-auto flex gap-6"
          style={{ maxWidth: layout.maxWidth }}
        >
          {(["people", "plans", "memories"] as GalaxyTab[]).map((tab) => {
            const isActive = activeTab === tab;
            return (
              <span
                key={tab}
                role="button"
                tabIndex={0}
                onClick={() => setActiveTab(tab)}
                onKeyDown={(e) => { if (e.key === "Enter") setActiveTab(tab); }}
                className="cursor-pointer outline-none"
                style={{
                  ...text.label,
                  position: "relative",
                  color: isActive ? colors.cyan : colors.white,
                  opacity: isActive ? 0.85 : 0.25,
                  transition: `opacity 0.4s ease, color 0.4s ease`,
                  paddingBottom: "10px",
                }}
              >
                {tab}
                {/* Ambient underline glow — wider, brighter */}
                <span
                  style={{
                    position: "absolute",
                    bottom: 0,
                    left: 0,
                    width: "100%",
                    height: "2px",
                    background: `linear-gradient(90deg, transparent 5%, ${colors.cyan} 50%, transparent 95%)`,
                    opacity: isActive ? 0.7 : 0,
                    transition: "opacity 0.4s ease",
                  }}
                />
                {/* Soft halo behind active tab */}
                <span
                  style={{
                    position: "absolute",
                    bottom: "-2px",
                    left: "-20%",
                    width: "140%",
                    height: "8px",
                    background: `radial-gradient(ellipse at center, rgba(var(--xark-accent-rgb), 0.25) 0%, transparent 70%)`,
                    opacity: isActive ? 1 : 0,
                    transition: "opacity 0.4s ease",
                    pointerEvents: "none",
                  }}
                />
              </span>
            );
          })}
        </div>
      </div>

      {/* ── Scrollable content ── */}
      <div
        className="relative z-10"
        style={{ flex: 1, overflowY: "auto", paddingTop: "16px", paddingBottom: "120px" }}
      >
        {activeTab === "people" && (
          <PeopleDock
            userId={userId}
            userName={userName}
            onPersonTap={handlePersonTap}
          />
        )}
        {activeTab === "plans" && (
          <AwarenessStream
            userId={userId}
            userName={userName}
            onSpaceTap={handleSpaceTap}
          />
        )}
        {activeTab === "memories" && (
          <MemoriesTab userId={userId} />
        )}
      </div>

      {/* ── Dream input — fixed above ControlCaret ── */}
      <div
        className="fixed inset-x-0 z-[20]"
        style={{
          bottom: "56px",
          background: colors.void,
          paddingTop: "8px",
          paddingBottom: "8px",
        }}
      >
        <div className="mx-auto px-6" style={{ maxWidth: layout.maxWidth }}>
          <div
            style={{
              height: "1px",
              background: `linear-gradient(90deg, transparent, ${colors.cyan}, transparent)`,
              opacity: 0.15,
              marginBottom: "10px",
            }}
          />

          <div className="flex items-center gap-3">
            <div className="flex-1">
              <input
                ref={inputRef}
                type="text"
                value={dream}
                onChange={(e) => setDream(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") manifestDream();
                }}
                placeholder="a trip, a dinner, a plan..."
                enterKeyHint="send"
                disabled={isCreating}
                spellCheck={false}
                autoComplete="off"
                autoCapitalize="sentences"
                onFocus={() => setInputFocused(true)}
                onBlur={() => setInputFocused(false)}
                className="w-full bg-transparent outline-none"
                style={{
                  ...text.input,
                  color: colors.white,
                  caretColor: colors.cyan,
                  opacity: isCreating ? 0.3 : 1,
                }}
              />
            </div>

            {dream.trim().length > 0 && (
              <span
                role="button"
                tabIndex={0}
                onClick={manifestDream}
                onKeyDown={(e) => { if (e.key === "Enter") manifestDream(); }}
                className="cursor-pointer outline-none"
                style={{
                  flexShrink: 0,
                  opacity: isCreating ? 0.3 : 0.6,
                  transition: `opacity ${timing.transition} ease`,
                }}
                onMouseEnter={(e) => { if (!isCreating) e.currentTarget.style.opacity = "0.9"; }}
                onMouseLeave={(e) => { if (!isCreating) e.currentTarget.style.opacity = "0.6"; }}
              >
                <SendIcon color={colors.cyan} />
              </span>
            )}
          </div>

          {/* Living ambient line */}
          <div
            style={{
              marginTop: "4px",
              height: "1px",
              width: dream.length > 0
                ? `min(${Math.max(dream.length * 6, 40)}px, 100%)`
                : inputFocused ? "60px" : "0px",
              background: `linear-gradient(90deg, ${colors.cyan}, transparent)`,
              opacity: dream.length > 0 ? 0.4 : 0.2,
              animation: `ambientBreath ${timing.breath} ease-in-out infinite`,
              transition: `width 0.3s ease, opacity ${timing.transition} ease`,
            }}
          />
        </div>
      </div>

      {/* ── Void fill below input ── */}
      <div
        className="fixed inset-x-0 z-[19]"
        style={{ bottom: 0, height: "56px", background: colors.void }}
      />

      <style jsx>{`
        @keyframes meshPulse {
          0%, 100% { opacity: 0; }
          50% { opacity: 1; }
        }
        input::placeholder {
          color: ${colors.white};
          opacity: ${opacity.whisper};
          letter-spacing: 0.04em;
        }
        @keyframes ambientBreath {
          0%, 100% { opacity: 0.6; }
          50% { opacity: 1; }
        }
      `}</style>
    </div>
  );
}

export default function GalaxyPage() {
  return (
    <Suspense>
      <GalaxyContent />
    </Suspense>
  );
}
