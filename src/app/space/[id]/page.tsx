"use client";

import { useState, useEffect } from "react";
import { useParams, useSearchParams, useRouter } from "next/navigation";
import { Suspense } from "react";
import { supabase } from "@/lib/supabase";
import { XarkChat } from "@/components/os/XarkChat";
import { PossibilityHorizon } from "@/components/os/PossibilityHorizon";
import { useAuth } from "@/hooks/useAuth";

import { colors, timing, text, textColor } from "@/lib/theme";

interface SpaceData {
  id: string;
  title: string;
  atmosphere: string;
}

function SpaceContent() {
  const params = useParams();
  const searchParams = useSearchParams();
  const router = useRouter();
  const spaceId = params.id as string;
  const userName = searchParams.get("name") ?? "";
  const isInvite = searchParams.get("invite") === "true";

  const { user, isAuthenticated, isLoading: authLoading } = useAuth(userName || undefined);

  const [space, setSpace] = useState<SpaceData | null>(null);
  const [view, setView] = useState<"chat" | "horizon">("chat");
  const [mounted, setMounted] = useState(false);
  const [shareCopied, setShareCopied] = useState(false);
  const [joinStatus, setJoinStatus] = useState<"idle" | "joining" | "joined">("idle");

  useEffect(() => {
    setMounted(true);
  }, []);

  // ── Demo spaces — used when Supabase is unreachable ──
  const DEMO_SPACES: Record<string, SpaceData> = {
    "space_san-diego": { id: "space_san-diego", title: "san diego trip", atmosphere: "cyan_horizon" },
    "space_ananya": { id: "space_ananya", title: "ananya", atmosphere: "sanctuary" },
    "space_tokyo": { id: "space_tokyo", title: "tokyo neon nights", atmosphere: "amber_glow" },
    "space_summer": { id: "space_summer", title: "summer 2026", atmosphere: "gold_warmth" },
  };

  // Fetch space metadata — fallback to demo if Supabase is unreachable
  useEffect(() => {
    async function fetchSpace() {
      const { data, error } = await supabase
        .from("spaces")
        .select("id, title, atmosphere")
        .eq("id", spaceId)
        .single();

      if (data && !error) {
        setSpace(data as SpaceData);
      } else {
        setSpace(DEMO_SPACES[spaceId] ?? { id: spaceId, title: spaceId.replace(/^space_/, "").replace(/-/g, " "), atmosphere: "" });
      }
    }

    fetchSpace();
  }, [spaceId]);

  // ── Handle invite=true — join via invite RPC ──
  useEffect(() => {
    if (!isInvite || authLoading) return;

    // Not logged in — redirect to login with return path
    if (!isAuthenticated) {
      router.replace(`/login?redirect=${encodeURIComponent(`/space/${spaceId}?invite=true`)}`);
      return;
    }

    // Already joining or joined
    if (joinStatus !== "idle") return;

    async function joinSpace() {
      setJoinStatus("joining");
      try {
        await supabase.rpc("join_via_invite", { p_space_id: spaceId });
      } catch {
        // Fail silently — may already be a member
      }
      setJoinStatus("joined");

      // Remove ?invite=true from URL without reload
      const url = new URL(window.location.href);
      url.searchParams.delete("invite");
      window.history.replaceState({}, "", url.toString());
    }

    joinSpace();
  }, [isInvite, authLoading, isAuthenticated, joinStatus, spaceId, router]);

  // ── Share handler — generates invite link ──
  const handleShare = async () => {
    const inviteUrl = `${window.location.origin}/space/${spaceId}?invite=true`;
    if (navigator.share) {
      try {
        await navigator.share({
          title: space?.title ?? "xark space",
          text: `join us on xark — ${space?.title ?? "a space"}`,
          url: inviteUrl,
        });
      } catch { /* user cancelled */ }
    } else {
      await navigator.clipboard.writeText(inviteUrl);
      setShareCopied(true);
      setTimeout(() => setShareCopied(false), 2000);
    }
  };

  return (
    <div className="relative min-h-svh">
      {/* ── Space header — floats above content ── */}
      <div
        className="fixed top-0 right-0 left-0 z-10 px-6 pt-6 pb-10"
        style={{
          background:
            "linear-gradient(to bottom, rgba(var(--xark-void-rgb), 1) 0%, rgba(var(--xark-void-rgb), 0.98) 40%, rgba(var(--xark-void-rgb), 0.85) 70%, rgba(var(--xark-void-rgb), 0.4) 90%, transparent 100%)",
          opacity: mounted ? 1 : 0,
          transition: "opacity 0.8s ease",
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          {/* ── Space title ── */}
          <h1
            style={{
              ...text.spaceTitle,
              color: colors.white,
              opacity: 0.9,
            }}
          >
            {space?.title ?? ""}
          </h1>

          {/* ── View toggle + share — floating text, no tabs, no boxes ── */}
          <div className="mt-3 flex items-center gap-6">
            <span
              role="button"
              tabIndex={0}
              onClick={() => setView("chat")}
              onKeyDown={(e) => {
                if (e.key === "Enter") setView("chat");
              }}
              className="outline-none"
              style={{
                ...text.label,
                color: view === "chat" ? colors.cyan : colors.white,
                opacity: view === "chat" ? 0.9 : 0.4,
                cursor: "pointer",
                transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
              }}
            >
              discuss
            </span>
            <span
              role="button"
              tabIndex={0}
              onClick={() => setView("horizon")}
              onKeyDown={(e) => {
                if (e.key === "Enter") setView("horizon");
              }}
              className="outline-none"
              style={{
                ...text.label,
                color: view === "horizon" ? colors.cyan : colors.white,
                opacity: view === "horizon" ? 0.9 : 0.4,
                cursor: "pointer",
                transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
              }}
            >
              decide
            </span>

            {/* ── Share — floating text, right side ── */}
            <span
              role="button"
              tabIndex={0}
              onClick={handleShare}
              onKeyDown={async (e) => {
                if (e.key === "Enter") await handleShare();
              }}
              className="ml-auto outline-none"
              style={{
                ...text.label,
                color: colors.white,
                opacity: shareCopied ? 0.7 : 0.4,
                cursor: "pointer",
                transition: `opacity ${timing.transition} ease`,
              }}
            >
              {shareCopied ? "link copied" : "share"}
            </span>
          </div>
        </div>
      </div>

      {/* ── Join status whisper ── */}
      {joinStatus === "joining" && (
        <div
          className="fixed top-24 left-0 right-0 z-20 text-center"
          style={{ ...text.hint, color: textColor(0.4) }}
        >
          joining space...
        </div>
      )}

      {/* ── Content views ── */}
      {view === "chat" && (
        <XarkChat spaceId={spaceId} userId={(user?.uid ?? userName) || undefined} spaceTitle={space?.title} />
      )}

      {view === "horizon" && (
        <PossibilityHorizon spaceId={spaceId} userId={(user?.uid ?? userName) || undefined} />
      )}
    </div>
  );
}

export default function SpacePage() {
  return (
    <Suspense>
      <SpaceContent />
    </Suspense>
  );
}
