// hello OS v2.0 — @hello Intelligence Endpoint
// Silent unless message contains "@hello". Privacy-first.
// UPGRADE 4: maxDuration + optimistic "thinking..." UI via Supabase Realtime.

export const maxDuration = 60; // Prevent Vercel from killing long Apify searches

import { NextRequest, NextResponse, after } from "next/server";
import { orchestrate, isGarbageResponse } from "@/lib/intelligence/orchestrator";
import { buildGroundingContext, generateGroundingPrompt } from "@/lib/ai-grounding";
import { fetchMessages } from "@/lib/messages";
import { sanitizeForIntelligence } from "@/lib/intelligence/sanitize";
import { supabaseAdmin } from "@/lib/supabase-admin";
import { applyLogisticsExtractions, flagStaleLogistics } from "@/lib/member-logistics";
import { verifyAuth } from "@/lib/auth-verify";
import { intersectTasteProfiles, type TasteContext } from "@/lib/taste";

const MAX_MESSAGE_LENGTH = 1000;

// ── Server-side photo fetcher for decision items ──
const PEXELS_KEY = process.env.NEXT_PUBLIC_PEXELS_API_KEY;
const CATEGORY_FALLBACKS: Record<string, string> = {
  local_restaurant: "https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=400",
  restaurant: "https://images.pexels.com/photos/1640777/pexels-photo-1640777.jpeg?auto=compress&cs=tinysrgb&w=400",
  local_activity: "https://images.pexels.com/photos/2387418/pexels-photo-2387418.jpeg?auto=compress&cs=tinysrgb&w=400",
  activity: "https://images.pexels.com/photos/2387418/pexels-photo-2387418.jpeg?auto=compress&cs=tinysrgb&w=400",
  hotel: "https://images.pexels.com/photos/258154/pexels-photo-258154.jpeg?auto=compress&cs=tinysrgb&w=400",
  flight: "https://images.pexels.com/photos/62623/wing-plane-flying-airplane-62623.jpeg?auto=compress&cs=tinysrgb&w=400",
  general: "https://images.pexels.com/photos/1051075/pexels-photo-1051075.jpeg?auto=compress&cs=tinysrgb&w=400",
};

async function fetchPexelsUrl(query: string): Promise<string | null> {
  if (!PEXELS_KEY) return null;
  try {
    const res = await fetch(
      `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=1&orientation=landscape`,
      { headers: { Authorization: PEXELS_KEY }, signal: AbortSignal.timeout(3000) }
    );
    if (!res.ok) return null;
    const data = await res.json();
    return data.photos?.[0]?.src?.medium ?? null;
  } catch { return null; }
}

export async function POST(req: NextRequest) {
  let helloMsgId: string | null = null;
  try {
  if (!supabaseAdmin) {
    return NextResponse.json({ response: "server not configured." }, { status: 500 });
  }

  const body = await req.json();
  const { message, groupId: reqGroupId, userId, confirm_action, payload, slotPayload, silent } = body;

  // ── Input validation ──
  if (!reqGroupId || typeof reqGroupId !== "string") {
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
      .eq("group_id", reqGroupId)
      .eq("user_id", auth.userId)
      .maybeSingle();

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
        .eq("group_id", reqGroupId)
        .maybeSingle();

      await supabaseAdmin.from("space_dates").upsert({
        group_id: reqGroupId,
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
        .eq("group_id", reqGroupId)
        .not("metadata->>source", "is", null);

      // Flag stale logistics
      const staleCount = await flagStaleLogistics(reqGroupId);
      const staleNote = staleCount > 0
        ? ` ${staleCount} logistics entries may need updating.`
        : "";

      return NextResponse.json({
        response: `dates updated.${staleNote}`,
      });
    }

    if (confirm_action === "confirm_logistics" && payload?.extractions) {
      const { applied, skipped } = await applyLogisticsExtractions(
        reqGroupId,
        payload.extractions
      );

      let response = `saved origins for ${applied.join(", ")}.`;
      if (skipped.length > 0) {
        response += ` couldn't resolve ${skipped.join(", ")} — which one?`;
      }

      return NextResponse.json({ response });
    }
  }

  // ── Normal @hello flow — require auth + space membership ──
  const auth = await verifyAuth(req.headers.get("authorization"));
  if (!auth) {
    return NextResponse.json({ response: null }, { status: 401 });
  }

  // Rate limiting moved to edge proxy (BACKEND-03)

  // Verify caller is a member of the target space
  const { data: membershipCheck } = await supabaseAdmin
    .from("space_members")
    .select("user_id")
    .eq("group_id", reqGroupId)
    .eq("user_id", auth.userId)
    .maybeSingle();

  if (!membershipCheck) {
    return NextResponse.json({ response: "not a member of this space." }, { status: 403 });
  }

  const groupId = reqGroupId;

  // ── PRIORITY 2: Short-circuit — fetch messages FIRST, check prefix before heavy reads ──
  const recentMsgs = await fetchMessages(groupId, { limit: 15 });

  const msgLower = message?.toLowerCase() ?? "";
  const hasHelloPrefix = !!(message && msgLower.includes("@hello"));
  let isFollowUp = false;
  let helloQuestion = "";

  if (!hasHelloPrefix && recentMsgs.length > 0) {
    const lastMsg = recentMsgs[recentMsgs.length - 1];
    if (lastMsg.role === "hello") {
      const isQuestion = lastMsg.content?.includes("?") ?? false;
      const msgTime = new Date(lastMsg.created_at).getTime();
      const isRecent = (Date.now() - msgTime) < 3 * 60 * 1000;
      if (isQuestion && isRecent) {
        isFollowUp = true;
        helloQuestion = lastMsg.content;
      }
    }
  }

  // Follow-up rate limiting moved to edge proxy (BACKEND-03)

  // SILENT MODE: no "@hello" prefix and not a valid follow-up = exit early (ZERO heavy DB reads)
  if (!message || (!hasHelloPrefix && !isFollowUp)) {
    return NextResponse.json({ response: null });
  }

  // ── NOW fetch heavy context (only when @hello is actually triggered) ──
  const tasteTimeout = new Promise<null>((resolve) => setTimeout(() => resolve(null), 800));
  const tasteFetch = supabaseAdmin
    ? supabaseAdmin.rpc("get_space_taste_profiles", { p_group_id: groupId }).then((r) => r.data)
    : Promise.resolve(null);

  const [spaceRow, groundingContext, tasteRaw, senderRow] = await Promise.all([
    supabaseAdmin.from("spaces").select("title").eq("id", groupId).maybeSingle().then((r) => r.data),
    buildGroundingContext(groupId),
    Promise.race([tasteFetch, tasteTimeout]),
    supabaseAdmin.from("users").select("display_name").eq("id", auth.userId).maybeSingle().then((r) => r.data),
  ]);

  let tasteContext: TasteContext | null = null;
  if (Array.isArray(tasteRaw) && tasteRaw.length > 0) {
    try { tasteContext = intersectTasteProfiles(tasteRaw); } catch { /* silent */ }
  }

  let userMessage = hasHelloPrefix ? message.replace(/@(?:hello|hello)\s*/i, "").trim() : message.trim();
  if (isFollowUp) {
    userMessage = `[Answering your question: "${helloQuestion}"] ${userMessage}`;
  }

  const spaceTitle = spaceRow?.title ?? groupId.replace(/^space_/, "").replace(/-/g, " ");
  const groundingPrompt = generateGroundingPrompt(groundingContext);
  const sanitizedMessages = sanitizeForIntelligence(recentMsgs);
  const recentMessages = sanitizedMessages.map((m) => ({
    role: m.role,
    content: m.content,
    sender_name: m.sender_name ?? undefined,
  }));

  // ── PHANTOM RECEIPT — instant visible feedback (skipped in silent mode) ──
  const queryText = (message ?? "").replace(/@(?:hello|hello)\s*/i, "").trim();
  const senderName = senderRow?.display_name ?? auth.userId.replace(/^phone_/, "");
  helloMsgId = `msg_${crypto.randomUUID()}`;
  if (!silent) {
    await supabaseAdmin.from("messages").insert({
      id: helloMsgId,
      group_id: groupId,
      role: "hello",
      content: `${senderName} is scouting ${queryText || "..."}`,
      user_id: auth.userId,
      sender_name: null,
      message_type: "helloReceipt",
    });
  }

  // ── Orchestrate with realtime thinking updates (PRIORITY 9) ──
  const updateReceipt = async (text: string) => {
    await supabaseAdmin.from("messages").update({ content: text }).eq("id", helloMsgId);
  };

  // ── PRIORITY 11: Build base webhook URL for async Apify actors ──
  // The orchestrator appends &tool=<toolName> after Gemini determines the tool.
  const baseUrl = process.env.NEXT_PUBLIC_APP_URL || "https://gethello.ai";
  const queryTextForLabel = (message ?? "").replace(/@(?:hello|hello)\s*/i, "").trim().toLowerCase();
  const webhookUrl = `${baseUrl}/api/hello/webhook?groupId=${encodeURIComponent(groupId)}&msgId=${encodeURIComponent(helloMsgId)}&label=${encodeURIComponent(queryTextForLabel)}`;

  const result = await orchestrate({
    userMessage,
    groundingPrompt,
    recentMessages,
    groupId,
    spaceTitle,
    tasteContext,
    onProgress: updateReceipt,
    webhookUrl,
    slotPayload: slotPayload ?? undefined,
  });

  // ── PRIORITY 11: Async mode — Apify actor was started, no results yet ──
  // The webhook will insert decision_items and update the receipt when the actor finishes.
  if (result.action === "search" && !result.searchResults && result._debug?.asyncRunId) {
    await updateReceipt(`scouting ${queryTextForLabel || "..."}... results incoming.`);
    return NextResponse.json({ response: result.response, messageId: helloMsgId, async: true });
  }

  // If pending confirmation, delete the thinking message and return to client
  if (result.pendingConfirmation) {
    await supabaseAdmin.from("messages").delete().eq("id", helloMsgId);
    return NextResponse.json({
      response: result.response,
      pendingConfirmation: true,
      action: result.action,
      payload: result.payload,
      extractions: result.extractions,
    });
  }

  // If poll generated, save options as decision items and upgrade message
  if (result.action === "create_poll" && result.payload?.options) {
    const pollId = `poll_${crypto.randomUUID().slice(0, 8)}`;
    const options = result.payload.options as string[];
    const replyText = result.response || "Created a poll. tap your pick.";
    const pollTitle = result.payload?.title || "Live Poll";
    const bgPollMsgId = helloMsgId;

    // PRIORITY 13: Background DB writes for poll items + receipt upgrade
    after(async () => {
      try {
        const items = options.map((opt) => ({
          id: `item_${crypto.randomUUID()}`,
          group_id: groupId,
          title: String(opt),
          category: "poll",
          description: "",
          state: "proposed",
          proposed_by: null,
          agreement_score: 0,
          weighted_score: 0,
          is_locked: false,
          version: 0,
          metadata: { search_batch: pollId, poll_title: pollTitle },
        }));

        await supabaseAdmin!.from("decision_items").upsert(items, { onConflict: "id" });

        await supabaseAdmin!.from("messages").update({
          content: JSON.stringify({ text: replyText, title: pollTitle, poll_id: pollId }),
          message_type: "hello_poll",
        }).eq("id", bgPollMsgId);
      } catch (bgErr) {
        console.error("[/api/hello] background poll write failed:", bgErr instanceof Error ? bgErr.message : String(bgErr));
      }
    });

    return NextResponse.json({ response: replyText, messageId: helloMsgId });
  }

  // ── Final sanity check — never persist garbage to DB ──
  if (isGarbageResponse(result.response)) {
    // Garbage cleanup must be synchronous — client gets error response
    await supabaseAdmin.from("messages").delete().eq("id", helloMsgId);
    return NextResponse.json({
      response: "couldn't process that. try rephrasing.",
      messageId: helloMsgId,
    });
  }

  // ── Compute response text synchronously (needed for HTTP response) ──
  const resultCount = result.searchResults?.length ?? 0;
  const queryLabel = (message ?? "").replace(/@(?:hello|hello)\s*/i, "").trim().toLowerCase();
  const completionText = resultCount > 0
    ? `found ${resultCount} spots for ${queryLabel || "your search"}. decide →`
    : result.response;

  // ── PRIORITY 13: Background DB Writes ──
  // Return HTTP response BEFORE final Supabase writes complete.
  // The phantom receipt's "scouting..." text is already visible via Realtime.
  // These writes update decision_items + receipt content for persistence.
  const bgHelloMsgId = helloMsgId;
  after(async () => {
    try {
      // If search results exist, insert as decision_items with photos
      if (result.searchResults && result.searchResults.length > 0) {
        const searchBatch = `batch_${crypto.randomUUID().slice(0, 8)}`;
        const queryTextLower = (message ?? "").replace(/@(?:hello|hello)\s*/i, "").trim().toLowerCase();
        const searchLabel = queryTextLower || `${spaceTitle} ${result.tool ?? "general"}`.trim();
        const category = result.tool ?? "general";
        const fallbackImg = CATEGORY_FALLBACKS[category] ?? CATEGORY_FALLBACKS.general;

        // Fetch photos in parallel (max 3s each, non-blocking)
        const photoUrls = await Promise.all(
          result.searchResults.map(async (r) => {
            if (r.imageUrl) return r.imageUrl; // Apify already has images
            const pexelsUrl = await fetchPexelsUrl(r.title);
            return pexelsUrl ?? fallbackImg;
          })
        );

        const items = result.searchResults.map((r, idx) => ({
          id: `item_${crypto.randomUUID()}`,
          group_id: groupId,
          title: r.title.toLowerCase(),
          category,
          description: r.description ?? "",
          state: "proposed",
          proposed_by: null,
          agreement_score: 0,
          weighted_score: 0,
          is_locked: false,
          version: 0,
          metadata: {
            price: r.price,
            image_url: photoUrls[idx] ?? fallbackImg,
            external_url: r.externalUrl,
            booking_url: r.externalUrl,
            source: r.source ?? "searchapi",
            search_tier: r.source === "fli" ? "fli" : r.source?.startsWith("google-") ? "searchapi" : r.source === "gemini-local" ? "gemini-local" : r.source === "gemini-search" ? "gemini-search" : "apify",
            rating: r.rating,
            search_batch: searchBatch,
            search_label: searchLabel,
            cached_at: Date.now(),
          },
        }));

        await supabaseAdmin!.from("decision_items").upsert(items, { onConflict: "id" });
      }

      // Update the phantom receipt with completion summary (skip in silent mode)
      if (!silent) {
        await supabaseAdmin!.from("messages").update({
          content: completionText,
        }).eq("id", bgHelloMsgId);
      }
    } catch (bgErr) {
      console.error("[/api/hello] background write failed:", bgErr instanceof Error ? bgErr.message : String(bgErr));
    }
  });

  // In silent mode (HelloPanel), return search results in the response body
  if (silent) {
    return NextResponse.json({
      response: completionText,
      searchResults: result.searchResults?.map((r) => ({
        title: r.title,
        price: r.price,
        imageUrl: r.imageUrl,
        description: r.description,
        rating: r.rating,
      })) ?? [],
    });
  }

  return NextResponse.json({ response: completionText, messageId: helloMsgId });

  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    console.error("[/api/hello] error:", errMsg);

    if (helloMsgId && supabaseAdmin) {
      await supabaseAdmin.from("messages").update({
        content: errMsg.includes("timeout") ? "took too long. try again." : "something went wrong. try again.",
      }).eq("id", helloMsgId);
    }

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
