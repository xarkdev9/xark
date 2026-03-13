// XARK OS v2.0 — @xark Intelligence Endpoint
// Silent unless message contains "@xark". Privacy-first.

import { NextRequest, NextResponse } from "next/server";
import { orchestrate } from "@/lib/intelligence/orchestrator";
import { buildGroundingContext, generateGroundingPrompt } from "@/lib/ai-grounding";
import { fetchMessages } from "@/lib/messages";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { applyLogisticsExtractions, flagStaleLogistics } from "@/lib/member-logistics";

export async function POST(req: NextRequest) {
  const body = await req.json();
  const { message, spaceId: reqSpaceId, userId, confirm_action, payload } = body;

  // ── Handle confirmations (no Gemini call needed) ──
  if (confirm_action === "set_dates" && payload) {
    const { start_date, end_date, label } = payload;

    // Upsert space_dates with version increment
    const { data: existing } = await supabaseAdmin
      .from("space_dates")
      .select("version")
      .eq("space_id", reqSpaceId)
      .single();

    await supabaseAdmin.from("space_dates").upsert({
      space_id: reqSpaceId,
      start_date,
      end_date,
      label: label ?? null,
      set_by: userId ?? null,
      version: (existing?.version ?? 0) + 1,
      updated_at: new Date().toISOString(),
    });

    // Flag stale apify items — jsonb merge via direct update
    await supabaseAdmin
      .from("decision_items")
      .update({ metadata: { needs_refresh: true } })
      .eq("space_id", reqSpaceId)
      .not("metadata->>source", "is", null);

    // Flag stale logistics
    const staleCount = await flagStaleLogistics(reqSpaceId);
    const staleNote = staleCount > 0
      ? ` ${staleCount} logistics entries may need updating.`
      : "";

    return NextResponse.json({
      response: `dates updated.${staleNote}`,
    });
  }

  if (confirm_action === "confirm_logistics" && payload?.extractions) {
    const { applied, skipped } = await applyLogisticsExtractions(
      reqSpaceId,
      payload.extractions
    );

    let response = `saved origins for ${applied.join(", ")}.`;
    if (skipped.length > 0) {
      response += ` couldn't resolve ${skipped.join(", ")} — which one?`;
    }

    return NextResponse.json({ response });
  }

  // ── Normal @xark flow ──
  const spaceId = reqSpaceId;

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

  // If pending confirmation, return to client without side effects
  if (result.pendingConfirmation) {
    return NextResponse.json({
      response: result.response,
      pendingConfirmation: true,
      action: result.action,
      payload: result.payload,
      extractions: result.extractions,
    });
  }

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
