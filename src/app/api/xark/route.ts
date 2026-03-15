// XARK OS v2.0 — @xark Intelligence Endpoint
// Silent unless message contains "@xark". Privacy-first.

import { NextRequest, NextResponse } from "next/server";
import { orchestrate, isGarbageResponse } from "@/lib/intelligence/orchestrator";
import { buildGroundingContext, generateGroundingPrompt } from "@/lib/ai-grounding";
import { fetchMessages } from "@/lib/messages";
import { sanitizeForIntelligence } from "@/lib/intelligence/sanitize";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { applyLogisticsExtractions, flagStaleLogistics } from "@/lib/member-logistics";
import { verifyAuth } from "@/lib/auth-verify";

// ── Rate limiting — 10 @xark calls per user per minute ──
const rateLimitMap = new Map<string, number[]>();
const RATE_WINDOW = 60_000;
const RATE_MAX = 10;
const MAX_MESSAGE_LENGTH = 1000;

function checkRateLimit(userId: string): boolean {
  const now = Date.now();
  const timestamps = (rateLimitMap.get(userId) ?? []).filter(
    (t) => now - t < RATE_WINDOW
  );
  if (timestamps.length >= RATE_MAX) return false;
  timestamps.push(now);
  rateLimitMap.set(userId, timestamps);
  return true;
}

export async function POST(req: NextRequest) {
  try {
  const body = await req.json();
  const { message, spaceId: reqSpaceId, userId, confirm_action, payload } = body;

  // ── Input validation ──
  if (!reqSpaceId || typeof reqSpaceId !== "string") {
    return NextResponse.json({ response: null }, { status: 400 });
  }

  // ── Message length cap — prevent prompt stuffing ──
  if (message && typeof message === "string" && message.length > MAX_MESSAGE_LENGTH) {
    return NextResponse.json({
      response: "message too long. keep it short.",
    });
  }

  // ── Rate limiting ──
  if (userId && !checkRateLimit(userId)) {
    return NextResponse.json({
      response: "slow down. try again in a minute.",
    });
  }

  // ── Handle confirmations — require auth + space membership ──
  if (confirm_action && (confirm_action === "set_dates" || confirm_action === "confirm_logistics")) {
    const auth = await verifyAuth(req.headers.get("authorization"));
    if (!auth) {
      return NextResponse.json({ response: "unauthorized." }, { status: 401 });
    }

    // Verify caller is a member of the target space
    const { data: membership } = await supabaseAdmin
      .from("space_members")
      .select("user_id")
      .eq("space_id", reqSpaceId)
      .eq("user_id", auth.userId)
      .single();

    if (!membership) {
      return NextResponse.json({ response: "not a member of this space." }, { status: 403 });
    }

    // Use verified userId from JWT, not from request body
    const verifiedUserId = auth.userId;

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
        set_by: verifiedUserId,
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
  }

  // ── Normal @xark flow — require auth ──
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) {
    return NextResponse.json({ response: null }, { status: 401 });
  }

  const spaceId = reqSpaceId;

  // Parallel fetch: space title + grounding context + recent messages
  const [spaceRow, groundingContext, recentMsgs] = await Promise.all([
    supabaseAdmin
      .from("spaces")
      .select("title")
      .eq("id", spaceId)
      .single()
      .then((r) => r.data),
    buildGroundingContext(spaceId),
    fetchMessages(spaceId, { limit: 15 }),
  ]);

  // Follow-up detection: if @xark's last message was a question/request,
  // treat the next user message as a reply even without "@xark" prefix.
  const hasXarkPrefix = message && message.toLowerCase().includes("@xark");
  let isFollowUp = false;
  if (!hasXarkPrefix && recentMsgs.length >= 2) {
    // Find the last non-current message that was from @xark
    const lastXarkMsg = recentMsgs
      .slice(0, -1) // exclude the current message (just sent)
      .reverse()
      .find((m) => m.role === "xark");
    const lastNonXarkMsg = recentMsgs
      .slice(0, -1)
      .reverse()
      .find((m) => m.role !== "xark");
    // If @xark spoke more recently than the last non-xark message, it's a follow-up
    if (lastXarkMsg && lastNonXarkMsg) {
      isFollowUp = new Date(lastXarkMsg.created_at) > new Date(lastNonXarkMsg.created_at);
    } else if (lastXarkMsg && !lastNonXarkMsg) {
      isFollowUp = true;
    }
  }

  // SILENT MODE: no "@xark" prefix and not a follow-up = no response
  if (!message || (!hasXarkPrefix && !isFollowUp)) {
    return NextResponse.json({ response: null });
  }

  // Strip "@xark" prefix if present
  const userMessage = hasXarkPrefix
    ? message.replace(/@xark\s*/i, "").trim()
    : message.trim();

  // Use DB title, or extract from spaceId as fallback (space_add-finland-trip → "add finland trip")
  const spaceTitle = spaceRow?.title
    ?? spaceId.replace(/^space_/, "").replace(/-/g, " ");
  const groundingPrompt = generateGroundingPrompt(groundingContext);
  const sanitizedMessages = sanitizeForIntelligence(recentMsgs);
  const recentMessages = sanitizedMessages.map((m) => ({
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
    spaceTitle,
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
    const searchBatch = `batch_${crypto.randomUUID().slice(0, 8)}`;
    const searchLabel = `${spaceTitle} ${result.tool ?? "general"}`.trim();
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
        source: r.source ?? "apify",
        search_tier: r.source === "gemini-search" ? "gemini-search" : "apify",
        rating: r.rating,
        search_batch: searchBatch,
        search_label: searchLabel,
      },
    }));

    await supabaseAdmin.from("decision_items").upsert(items, { onConflict: "id" });
  }

  // ── Final sanity check — never persist garbage to DB ──
  const finalResponse = isGarbageResponse(result.response)
    ? "couldn't process that. try rephrasing."
    : result.response;

  // Persist @xark response message server-side (RLS blocks role='xark' from client)
  const xarkMsgId = `msg_${crypto.randomUUID()}`;
  await supabaseAdmin.from("messages").insert({
    id: xarkMsgId,
    space_id: spaceId,
    role: "xark",
    content: finalResponse,
    user_id: null,
    sender_name: null,
  });

  return NextResponse.json({ response: finalResponse, messageId: xarkMsgId });

  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    console.error("[/api/xark] error:", errMsg);

    // User-friendly error — don't leak internals
    const userResponse = errMsg.includes("timeout")
      ? "took too long. try again."
      : "something went wrong. try again.";
    return NextResponse.json(
      { response: userResponse },
      { status: 500 }
    );
  }
}
