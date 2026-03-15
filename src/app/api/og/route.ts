import { NextRequest, NextResponse } from "next/server";
import { fetchOGMetadata } from "@/lib/og-extract";
import { verifyAuth } from "@/lib/auth-verify";

// ── SSRF protection: block internal/private URLs ──
const BLOCKED_HOSTS = [
  /^localhost$/i,
  /^127\./,
  /^10\./,
  /^172\.(1[6-9]|2\d|3[01])\./,
  /^192\.168\./,
  /^169\.254\./,
  /^0\./,
  /^\[::1\]/,
  /^\[fd/i,
  /^\[fe80:/i,
];

function isUrlSafe(urlString: string): boolean {
  try {
    const parsed = new URL(urlString);

    // Only allow http/https schemes
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return false;
    }

    // Block private/reserved hostnames
    const hostname = parsed.hostname;
    for (const pattern of BLOCKED_HOSTS) {
      if (pattern.test(hostname)) return false;
    }

    return true;
  } catch {
    return false;
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { url, insertAsItem, spaceId, title, text } = body;

    let metadata = {};
    if (url && typeof url === "string") {
      if (!isUrlSafe(url)) {
        return NextResponse.json({ error: "url not allowed" }, { status: 400 });
      }
      metadata = await fetchOGMetadata(url);
    }

    // Insert as decision_item — requires authentication + space membership
    if (insertAsItem && spaceId) {
      const auth = await verifyAuth(req.headers.get("authorization"));
      if (!auth) {
        return NextResponse.json({ error: "unauthorized" }, { status: 401 });
      }

      const { supabaseAdmin } = await import("@/lib/supabase-admin");
      if (!supabaseAdmin) {
        return NextResponse.json({ error: "server not configured" }, { status: 500 });
      }

      // Verify caller is a member of the target space
      const { data: membership } = await supabaseAdmin
        .from("space_members")
        .select("user_id")
        .eq("space_id", spaceId)
        .eq("user_id", auth.userId)
        .single();

      if (!membership) {
        return NextResponse.json({ error: "not a member of this space" }, { status: 403 });
      }

      const ogMeta = metadata as Record<string, string>;
      await supabaseAdmin.from("decision_items").insert({
        space_id: spaceId,
        title: ogMeta.title || title || "shared item",
        category: "shared",
        description: ogMeta.description || text || url || "",
        state: "proposed",
        proposed_by: auth.userId,
        metadata: {
          ...ogMeta,
          source: "share_target",
          shared_url: url || undefined,
        },
      });
    }

    return NextResponse.json(metadata);
  } catch {
    return NextResponse.json({ error: "extraction failed" }, { status: 500 });
  }
}
