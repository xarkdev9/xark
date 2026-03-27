// hello OS v2.0 — Apify Async Webhook Receiver
// Receives completion callbacks from Apify actors started asynchronously.
// Inserts search results as decision_items and updates the phantom receipt.

export const maxDuration = 30;

import { NextRequest, NextResponse } from "next/server";
import { supabaseAdmin } from "@/lib/supabase-admin";
import type { ApifyResult } from "@/lib/intelligence/apify-client";
import { normalizeApifyDataset } from "@/lib/intelligence/apify-client";

export async function POST(req: NextRequest) {
  try {
    if (!supabaseAdmin) {
      return NextResponse.json({ error: "server not configured" }, { status: 500 });
    }

    // Rate limiting moved to edge proxy (BACKEND-03)

    // ── Extract groupId and msgId from query params ──
    const { searchParams } = new URL(req.url);
    const groupId = searchParams.get("groupId");
    const msgId = searchParams.get("msgId");
    const toolName = searchParams.get("tool") || "general";
    const searchLabel = searchParams.get("label") || "";

    if (!groupId || !msgId) {
      return NextResponse.json({ error: "missing groupId or msgId" }, { status: 400 });
    }

    // ── Validate groupId and msgId exist in DB ──
    const [spaceCheck, msgCheck] = await Promise.all([
      supabaseAdmin.from("spaces").select("id").eq("id", groupId).maybeSingle(),
      supabaseAdmin.from("messages").select("id, group_id").eq("id", msgId).maybeSingle(),
    ]);

    if (!spaceCheck.data) {
      return NextResponse.json({ error: "invalid groupId" }, { status: 404 });
    }

    if (!msgCheck.data || msgCheck.data.group_id !== groupId) {
      return NextResponse.json({ error: "invalid msgId or space mismatch" }, { status: 404 });
    }

    // ── Parse Apify webhook payload ──
    // Apify webhooks POST the run object. We need to fetch results from the dataset.
    const body = await req.json();
    const datasetId = body?.resource?.defaultDatasetId;
    const runStatus = body?.resource?.status;

    if (runStatus !== "SUCCEEDED" || !datasetId) {
      // Actor failed or no dataset — update receipt with failure message
      await supabaseAdmin.from("messages").update({
        content: "search didn't return results. try a different query?",
      }).eq("id", msgId);

      return NextResponse.json({ ok: true, status: "actor_failed" });
    }

    // ── Fetch results from the Apify dataset ──
    const apifyToken = process.env.APIFY_API_TOKEN;
    if (!apifyToken) {
      await supabaseAdmin.from("messages").update({
        content: "search config error. try again later.",
      }).eq("id", msgId);
      return NextResponse.json({ error: "no apify token" }, { status: 500 });
    }

    const datasetUrl = `https://api.apify.com/v2/datasets/${datasetId}/items?token=${apifyToken}&limit=15`;
    const datasetRes = await fetch(datasetUrl);
    if (!datasetRes.ok) {
      await supabaseAdmin.from("messages").update({
        content: "couldn't fetch results. try again?",
      }).eq("id", msgId);
      return NextResponse.json({ error: "dataset fetch failed" }, { status: 502 });
    }

    const rawItems = await datasetRes.json();
    if (!Array.isArray(rawItems) || rawItems.length === 0) {
      await supabaseAdmin.from("messages").update({
        content: "search came back empty. try a different query?",
      }).eq("id", msgId);
      return NextResponse.json({ ok: true, status: "no_results" });
    }

    // ── Normalize results using shared normalizer ──
    const results: ApifyResult[] = normalizeApifyDataset(rawItems);

    if (results.length === 0) {
      await supabaseAdmin.from("messages").update({
        content: "search came back empty. try a different query?",
      }).eq("id", msgId);
      return NextResponse.json({ ok: true, status: "no_results" });
    }

    // ── Insert as decision_items (same logic as /api/hello route.ts) ──
    const searchBatch = `batch_${crypto.randomUUID().slice(0, 8)}`;
    const items = results.map((r) => ({
      id: `item_${crypto.randomUUID()}`,
      group_id: groupId,
      title: r.title.toLowerCase(),
      category: toolName,
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
        search_tier: "apify",
        rating: r.rating,
        search_batch: searchBatch,
        search_label: searchLabel || toolName,
      },
    }));

    await supabaseAdmin.from("decision_items").upsert(items, { onConflict: "id" });

    // ── Update the phantom receipt ──
    await supabaseAdmin.from("messages").update({
      content: `found ${results.length} spots. they're in decide.`,
    }).eq("id", msgId);

    return NextResponse.json({ ok: true, inserted: results.length });
  } catch (err) {
    const errMsg = err instanceof Error ? err.message : String(err);
    console.error("[/api/hello/webhook] error:", errMsg);
    return NextResponse.json({ error: "internal error" }, { status: 500 });
  }
}
