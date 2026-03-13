// XARK OS v2.0 — @xark Intelligence Endpoint
// Silent unless message contains "@xark". Privacy-first.

import { NextRequest, NextResponse } from "next/server";
import { orchestrate } from "@/lib/intelligence/orchestrator";
import { buildGroundingContext, generateGroundingPrompt } from "@/lib/ai-grounding";
import { fetchMessages } from "@/lib/messages";
import { supabaseAdmin } from "@/lib/supabase-admin";

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { message, spaceId } = body;

  // SILENT MODE: no "@xark" prefix = no response
  if (!message || !message.toLowerCase().includes("@xark")) {
    return NextResponse.json({ response: null });
  }

  // Strip "@xark" prefix
  const userMessage = message.replace(/@xark\s*/i, "").trim();

  // Build grounding context (Tier 1 — always available)
  const groundingContext = await buildGroundingContext(spaceId);
  const groundingPrompt = generateGroundingPrompt(groundingContext);

  // Fetch last 15 messages (Tier 2 — on invocation only)
  const allMessages = await fetchMessages(spaceId);
  const recentMessages = allMessages.slice(-15).map((m) => ({
    role: m.role,
    content: m.content,
    sender_name: m.sender_name ?? undefined,
  }));

  // Orchestrate
  const result = await orchestrate({
    userMessage,
    groundingPrompt,
    recentMessages,
    spaceId,
  });

  // If search results exist, insert as decision_items
  if (result.searchResults && result.searchResults.length > 0) {
    const items = result.searchResults.map((r) => ({
      id: `item_${crypto.randomUUID()}`,
      space_id: spaceId,
      title: r.title.toLowerCase(),
      category: result.tool ?? "general",
      description: r.description ?? "",
      state: "proposed",
      proposed_by: null,
      agreement_score: 0,
      weighted_score: 0,
      is_locked: false,
      version: 0,
      metadata: {
        price: r.price,
        image_url: r.imageUrl,
        external_url: r.externalUrl,
        source: "apify",
        rating: r.rating,
      },
    }));

    await supabaseAdmin.from("decision_items").upsert(items, { onConflict: "id" });
  }

  return NextResponse.json({ response: result.response });
}
