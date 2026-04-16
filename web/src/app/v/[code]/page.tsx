// hello OS v2.0 — Web Voter View
// Public page at /v/[code] — unauthenticated users vote on group decisions.
// Server component: validates invite, fetches items, renders voter UI.

import { supabaseAdmin } from "@/lib/supabase-admin";
import VoteHeader from "./vote-header";
import VoteCard from "./vote-card";

interface DecisionItem {
  id: string;
  title: string;
  category: string;
  agreement_score: number;
  weighted_score: number;
  is_locked: boolean;
  metadata: Record<string, unknown>;
}

// Demo data for when Supabase is not configured or invite is invalid
const DEMO_ITEMS: DecisionItem[] = [
  {
    id: "demo_beach-sunset",
    title: "sunset kayaking tour",
    category: "Activity",
    agreement_score: 0.65,
    weighted_score: 12,
    is_locked: false,
    metadata: { photo: "https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800&q=80" },
  },
  {
    id: "demo_rooftop-dinner",
    title: "rooftop dinner downtown",
    category: "Dining",
    agreement_score: 0.45,
    weighted_score: 7,
    is_locked: false,
    metadata: { photo: "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80" },
  },
  {
    id: "demo_art-museum",
    title: "contemporary art museum",
    category: "Culture",
    agreement_score: 0.3,
    weighted_score: 3,
    is_locked: false,
    metadata: { photo: "https://images.unsplash.com/photo-1554907984-15263bfd63bd?w=800&q=80" },
  },
];

export default async function VoterPage({
  params,
}: {
  params: Promise<{ code: string }>;
}) {
  const { code } = await params;

  let tripName = "Trip Plans";
  let memberCount = 4;
  let items: DecisionItem[] = DEMO_ITEMS;
  let inviteCode = code;
  let isDemo = true;

  // Try to load real data from Supabase
  if (supabaseAdmin) {
    try {
      // Validate invite code
      const { data: invite } = await supabaseAdmin
        .from("summon_links")
        .select("code, creator_id, space_id, expires_at, claimed_by")
        .eq("code", code)
        .single();

      if (invite?.space_id) {
        const groupId = invite.space_id;

        // Fetch group info
        const { data: group } = await supabaseAdmin
          .from("groups")
          .select("title")
          .eq("id", groupId)
          .single();

        if (group?.title) {
          tripName = group.title;
        }

        // Fetch member count
        const { count } = await supabaseAdmin
          .from("group_members")
          .select("user_id", { count: "exact", head: true })
          .eq("group_id", groupId);

        if (count) {
          memberCount = count;
        }

        // Fetch decision items (unlocked only)
        const { data: dbItems } = await supabaseAdmin
          .from("decision_items")
          .select("id, title, category, agreement_score, weighted_score, is_locked, metadata")
          .eq("group_id", groupId)
          .eq("is_locked", false)
          .order("weighted_score", { ascending: false });

        if (dbItems && dbItems.length > 0) {
          items = dbItems as DecisionItem[];
          isDemo = false;
        }

        inviteCode = code;
      }
    } catch (err) {
      console.error("[voter-page] Failed to load data:", err);
      // Fall through to demo data
    }
  }

  return (
    <div
      style={{
        minHeight: "100vh",
        backgroundColor: "#FAFAFA",
        fontFamily: "var(--font-inter), Inter, sans-serif",
      }}
    >
      <VoteHeader tripName={tripName} memberCount={memberCount} />

      <main style={{ padding: "16px 16px 120px", maxWidth: "480px", margin: "0 auto" }}>
        {isDemo && (
          <p
            style={{
              fontSize: "13px",
              fontWeight: 400,
              color: "var(--hello-ink-tertiary, #8A8A94)",
              textAlign: "center",
              margin: "0 0 16px 0",
            }}
          >
            demo mode — showing sample items
          </p>
        )}

        {items.map((item) => (
          <VoteCard
            key={item.id}
            inviteCode={inviteCode}
            itemId={item.id}
            title={item.title}
            category={item.category || "General"}
            photoUrl={(item.metadata?.photo as string) || undefined}
            agreementScore={item.agreement_score}
            weightedScore={item.weighted_score}
          />
        ))}
      </main>

      {/* Conversion banner */}
      <div
        style={{
          position: "fixed",
          bottom: 0,
          left: 0,
          right: 0,
          zIndex: 10,
          backdropFilter: "blur(14px)",
          WebkitBackdropFilter: "blur(14px)",
          backgroundColor: "rgba(255, 255, 255, 0.85)",
          borderTop: "1px solid rgba(0, 0, 0, 0.06)",
          padding: "16px 24px",
          textAlign: "center",
        }}
      >
        <p
          style={{
            fontFamily: "var(--font-inter), Inter, sans-serif",
            fontSize: "14px",
            fontWeight: 400,
            color: "var(--hello-ink-secondary, #6B6B78)",
            margin: 0,
          }}
        >
          Want the full trip experience?{" "}
          <a
            href="https://gethello.ai"
            style={{
              color: "var(--hello-accent, #FF6B35)",
              textDecoration: "none",
            }}
          >
            Get hello &rarr;
          </a>
        </p>
      </div>
    </div>
  );
}
