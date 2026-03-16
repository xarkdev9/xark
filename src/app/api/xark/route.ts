// XARK OS v2.0 — @xark Intelligence Endpoint
// Silent unless message contains "@xark". Privacy-first.
// UPGRADE 4: maxDuration + optimistic "thinking..." UI via Supabase Realtime.

export const maxDuration = 60; // Prevent Vercel from killing long Apify searches

import { NextRequest, NextResponse } from "next/server";
import { orchestrate, isGarbageResponse } from "@/lib/intelligence/orchestrator";
import { buildGroundingContext, generateGroundingPrompt } from "@/lib/ai-grounding";
import { fetchMessages } from "@/lib/messages";
import { sanitizeForIntelligence } from "@/lib/intelligence/sanitize";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { applyLogisticsExtractions, flagStaleLogistics } from "@/lib/member-logistics";
import { verifyAuth } from "@/lib/auth-verify";
import { checkRateLimit } from "@/lib/rate-limit";

const MAX_MESSAGE_LENGTH = 1000;

export async function POST(req: NextRequest) {
  try {
  if (!supabaseAdmin) {
    return NextResponse.json({ response: "server not configured." }, { status: 500 });
  }

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

  // H4 fix: rate limiting moved after auth (see below). Old position used client-supplied userId.

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
      // Validate payload shape
      if ((start_date && typeof start_date !== 'string') || (end_date && typeof end_date !== 'string') || (label && typeof label !== 'string')) {
        return NextResponse.json({ response: "invalid date payload." }, { status: 400 });
      }

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

  // ── Normal @xark flow — require auth + space membership ──
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) {
    return NextResponse.json({ response: null }, { status: 401 });
  }

  // H4 fix: rate limit keyed on verified JWT userId, not client-supplied
  if (!checkRateLimit(`xark:${auth.userId}`, 10)) {
    return NextResponse.json({
      response: "group is moving too fast. take a breath. try again in a minute.",
    });
  }

  // Verify caller is a member of the target space
  const { data: membershipCheck } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("space_id", reqSpaceId)
    .eq("user_id", auth.userId)
    .single();

  if (!membershipCheck) {
    return NextResponse.json({ response: "not a member of this space." }, { status: 403 });
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

  // ── Smart Follow-Up Detection ──
  // Fixed: no slice bug (user's message isn't in DB yet), no eavesdropping
  // (only follows up if @xark asked a question AND it was within 3 minutes)
  const hasXarkPrefix = message && message.toLowerCase().includes("@xark");
  let isFollowUp = false;
  let xarkQuestion = "";

  if (!hasXarkPrefix && recentMsgs.length > 0) {
    // fetchMessages returns chronological order — last item is most recent in DB.
    // Current user message is NOT in DB yet, so no slice needed.
    const lastMsg = recentMsgs[recentMsgs.length - 1];

    if (lastMsg.role === "xark") {
      // 1. Did @xark explicitly ask a question?
      const isQuestion = lastMsg.content.includes("?");

      // 2. Was it recent? (Within 3 minutes — prevents waking up hours later)
      const msgTime = new Date(lastMsg.created_at).getTime();
      const isRecent = (Date.now() - msgTime) < 3 * 60 * 1000;

      if (isQuestion && isRecent) {
        isFollowUp = true;
        xarkQuestion = lastMsg.content;
      }
    }
  }

  // SILENT MODE: no "@xark" prefix and not a valid follow-up = no response
  if (!message || (!hasXarkPrefix && !isFollowUp)) {
    return NextResponse.json({ response: null });
  }

  // Strip "@xark" prefix if present
  let userMessage = hasXarkPrefix
    ? message.replace(/@xark\s*/i, "").trim()
    : message.trim();

  // Context injection: invisibly bind @xark's question to the user's answer
  if (isFollowUp) {
    userMessage = `[Answering your question: "${xarkQuestion}"] ${userMessage}`;
  }

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

  // ── UPGRADE 4: Optimistic UI — insert "thinking..." immediately ──
  const xarkMsgId = `msg_${crypto.randomUUID()}`;
  await supabaseAdmin.from("messages").insert({
    id: xarkMsgId,
    space_id: spaceId,
    role: "xark",
    content: "thinking...",
    user_id: null,
    sender_name: null,
    message_type: "xark",  // plaintext — server-side @xark responses are never encrypted
  });

  // Orchestrate (can take 15-40s for Apify searches)
  const result = await orchestrate({
    userMessage,
    groundingPrompt,
    recentMessages,
    spaceId,
    spaceTitle,
  });

  // If pending confirmation, delete the thinking message and return to client
  if (result.pendingConfirmation) {
    await supabaseAdmin.from("messages").delete().eq("id", xarkMsgId);
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
    // Use the user's query as the rail label so each search gets its own section
    // e.g., "coffee spots", "restaurants in rancho bernardo", "brunch"
    const queryText = (message ?? "").replace(/@xark\s*/i, "").trim().toLowerCase();
    const searchLabel = queryText || `${spaceTitle} ${result.tool ?? "general"}`.trim();
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
        search_tier: r.source === "gemini-local" ? "gemini-local" : r.source === "gemini-search" ? "gemini-search" : "apify",
        rating: r.rating,
        search_batch: searchBatch,
        search_label: searchLabel,
      },
    }));

    await supabaseAdmin.from("decision_items").upsert(items, { onConflict: "id" });
  }

  // ── Final sanity check — never persist garbage to DB ──
  if (isGarbageResponse(result.response)) {
    await supabaseAdmin.from("messages").delete().eq("id", xarkMsgId);
    return NextResponse.json({
      response: "couldn't process that. try rephrasing.",
      messageId: xarkMsgId,
    });
  }
  const finalResponse = result.response;

  // ── UPDATE the thinking message with the FINAL response (not a new insert) ──
  await supabaseAdmin.from("messages").update({
    content: finalResponse,
  }).eq("id", xarkMsgId);

  return NextResponse.json({ response: finalResponse, messageId: xarkMsgId });

  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    console.error("[/api/xark] error:", errMsg);

    return NextResponse.json(
      {
        response: errMsg.includes("timeout")
          ? "took too long. try again."
          : "something went wrong. try again.",
      },
      { status: 500 }
    );
  }
}
