"use client";

// XARK OS v2.0 — Space View
// Discuss (chat) + Decide (visual stream) toggle.
// Share generates invite link. Invite flow: check auth, join via RPC, remove param.

import { useState, useEffect, useCallback, Suspense } from "react";
import { useParams, useSearchParams, useRouter } from "next/navigation";
import { XarkChat } from "@/components/os/XarkChat";
import { PossibilityHorizon } from "@/components/os/PossibilityHorizon";
import { useAuth } from "@/hooks/useAuth";
import { supabase } from "@/lib/supabase";
import { colors, text, textColor, timing } from "@/lib/theme";

// Demo space title map — used when Supabase is unreachable
const DEMO_TITLES: Record<string, string> = {
  "space_san-diego": "san diego trip",
  space_ananya: "ananya",
  "space_tokyo": "tokyo neon nights",
  space_summer: "summer 2026",
};

type ViewMode = "discuss" | "decide";

function SpacePageInner() {
  const params = useParams();
  const searchParams = useSearchParams();
  const router = useRouter();
  const spaceId = params.id as string;
  const userName = searchParams.get("name") ?? undefined;
  const isInvite = searchParams.get("invite") === "true";

  const { user, isAuthenticated, isLoading: authLoading } = useAuth(userName);
  const resolvedUserId = ((user?.uid ?? userName) || undefined) as string | undefined;

  const [view, setView] = useState<ViewMode>("discuss");
  const [spaceTitle, setSpaceTitle] = useState<string>("");
  const [joining, setJoining] = useState(false);
  const [shareWhisper, setShareWhisper] = useState(false);

  // ── Fetch space title ──
  useEffect(() => {
    async function loadTitle() {
      try {
        const { data } = await supabase
          .from("spaces")
          .select("title")
          .eq("id", spaceId)
          .single();
        if (data?.title) {
          setSpaceTitle(data.title);
          return;
        }
      } catch {
        // fallthrough
      }
      // Demo fallback
      setSpaceTitle(DEMO_TITLES[spaceId] ?? spaceId.replace(/^space_/, "").replace(/-/g, " "));
    }
    loadTitle();
  }, [spaceId]);

  // ── Invite flow: redirect to login if not authenticated, then join ──
  useEffect(() => {
    if (!isInvite || authLoading) return;

    if (!isAuthenticated) {
      // Redirect to login with return URL
      const returnUrl = `/space/${spaceId}?invite=true${userName ? `&name=${userName}` : ""}`;
      router.replace(`/login?returnTo=${encodeURIComponent(returnUrl)}`);
      return;
    }

    // Authenticated — join via RPC
    async function joinSpace() {
      setJoining(true);
      try {
        await supabase.rpc("join_via_invite", { p_space_id: spaceId });
      } catch {
        // Silently handle — user may already be a member
      } finally {
        setJoining(false);
        // Remove invite param
        const newParams = new URLSearchParams(searchParams.toString());
        newParams.delete("invite");
        const remaining = newParams.toString();
        router.replace(`/space/${spaceId}${remaining ? `?${remaining}` : ""}`);
      }
    }
    joinSpace();
  }, [isInvite, isAuthenticated, authLoading, spaceId, userName, router, searchParams]);

  // ── Share action ──
  const handleShare = useCallback(async () => {
    const shareUrl = `${window.location.origin}/space/${spaceId}?invite=true`;
    const shareData = {
      title: spaceTitle || "xark space",
      text: `join ${spaceTitle || "this space"} on xark`,
      url: shareUrl,
    };

    if (typeof navigator !== "undefined" && navigator.share) {
      try {
        await navigator.share(shareData);
        return;
      } catch {
        // User cancelled or share API failed — fall through to clipboard
      }
    }

    // Desktop fallback: clipboard
    try {
      await navigator.clipboard.writeText(shareUrl);
      setShareWhisper(true);
      setTimeout(() => setShareWhisper(false), 2000);
    } catch {
      // Silent fail
    }
  }, [spaceId, spaceTitle]);

  // ── Joining whisper ──
  if (joining) {
    return (
      <div
        className="flex min-h-svh items-center justify-center"
        style={{ background: colors.void }}
      >
        <p style={{ ...text.hint, color: textColor(0.4) }}>
          joining space...
        </p>
      </div>
    );
  }

  return (
    <div className="relative min-h-svh" style={{ background: colors.void }}>
      {/* ── Header: title + view toggle + share ── */}
      <div
        className="fixed inset-x-0 top-0 z-30 px-6 pt-14 pb-4"
        style={{
          background:
            "linear-gradient(to bottom, rgba(var(--xark-void-rgb), 1) 0%, rgba(var(--xark-void-rgb), 0.9) 60%, transparent 100%)",
        }}
      >
        <div className="mx-auto" style={{ maxWidth: "640px" }}>
          {/* ── Space title ── */}
          <p
            style={{
              ...text.spaceTitle,
              color: colors.white,
              opacity: 0.9,
            }}
          >
            {spaceTitle}
          </p>

          {/* ── Toggle + share ── */}
          <div className="mt-3 flex items-center justify-between">
            <div className="flex items-center gap-6">
              <span
                role="button"
                tabIndex={0}
                onClick={() => setView("discuss")}
                onKeyDown={(e) => {
                  if (e.key === "Enter") setView("discuss");
                }}
                className="outline-none"
                style={{
                  ...text.label,
                  color: view === "discuss" ? colors.cyan : colors.white,
                  opacity: view === "discuss" ? 0.9 : 0.4,
                  cursor: "pointer",
                  transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
                }}
              >
                discuss
              </span>
              <span
                role="button"
                tabIndex={0}
                onClick={() => setView("decide")}
                onKeyDown={(e) => {
                  if (e.key === "Enter") setView("decide");
                }}
                className="outline-none"
                style={{
                  ...text.label,
                  color: view === "decide" ? colors.cyan : colors.white,
                  opacity: view === "decide" ? 0.9 : 0.4,
                  cursor: "pointer",
                  transition: `opacity ${timing.transition} ease, color ${timing.transition} ease`,
                }}
              >
                decide
              </span>
            </div>

            {/* ── Share ── */}
            <span
              role="button"
              tabIndex={0}
              onClick={handleShare}
              onKeyDown={(e) => {
                if (e.key === "Enter") handleShare();
              }}
              className="outline-none"
              style={{
                ...text.label,
                color: colors.white,
                opacity: shareWhisper ? 0.7 : 0.4,
                cursor: "pointer",
                transition: `opacity ${timing.transition} ease`,
              }}
            >
              {shareWhisper ? "link copied" : "share"}
            </span>
          </div>
        </div>
      </div>

      {/* ── View content ── */}
      {view === "discuss" ? (
        <XarkChat
          spaceId={spaceId}
          userId={resolvedUserId}
          spaceTitle={spaceTitle}
        />
      ) : (
        <PossibilityHorizon spaceId={spaceId} userId={resolvedUserId} />
      )}
    </div>
  );
}

export default function SpacePage() {
  return (
    <Suspense>
      <SpacePageInner />
    </Suspense>
  );
}
