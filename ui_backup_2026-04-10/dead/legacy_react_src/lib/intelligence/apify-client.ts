// hello OS v2.0 — Apify Actor Client
// Runs Apify actors and returns structured results.
// startActorAsync() fires an actor with a webhook URL and returns immediately.

import { ApifyClient } from "apify-client";

const client = process.env.APIFY_API_TOKEN
  ? new ApifyClient({ token: process.env.APIFY_API_TOKEN })
  : null;

export interface ApifyResult {
  title: string;
  price?: string;
  imageUrl?: string;
  description?: string;
  externalUrl?: string;
  rating?: number;
  source: string;
}

export async function runActor(
  actorId: string,
  input: Record<string, unknown>
): Promise<ApifyResult[]> {
  if (!client) {
    console.warn("Apify: no API token configured, returning empty results");
    return [];
  }

  const run = await client.actor(actorId).call(input);
  const { items } = await client.dataset(run.defaultDatasetId).listItems();

  // ── Flight actor returns nested structure: { best_flights[], other_flights[] }
  if (items.length > 0 && Array.isArray((items[0] as Record<string, unknown>).best_flights)) {
    return normalizeFlights(items[0] as Record<string, unknown>);
  }

  // ── Standard actors (hotel, maps, search) — flat item list
  return items.map((item: Record<string, unknown>) => normalizeItem(item));
}

export interface AsyncActorResult {
  runId: string;
}

/**
 * Start an Apify actor asynchronously with a webhook callback.
 * Returns immediately with the run ID — results arrive via webhook.
 * Uses the Apify REST API to register a webhook on the run.
 */
export async function startActorAsync(
  actorId: string,
  input: Record<string, unknown>,
  webhookUrl: string
): Promise<AsyncActorResult | null> {
  if (!client) {
    console.warn("Apify: no API token configured, cannot start async actor");
    return null;
  }

  const token = process.env.APIFY_API_TOKEN;
  if (!token) return null;

  // Start the actor run (non-blocking — does not wait for completion)
  const run = await client.actor(actorId).start(input);

  // Register a webhook on this specific run for SUCCEEDED and FAILED events
  // Using Apify REST API: POST /v2/webhooks
  try {
    await fetch("https://api.apify.com/v2/webhooks", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
      },
      body: JSON.stringify({
        eventTypes: ["ACTOR.RUN.SUCCEEDED", "ACTOR.RUN.FAILED", "ACTOR.RUN.TIMED_OUT", "ACTOR.RUN.ABORTED"],
        condition: { actorRunId: run.id },
        requestUrl: webhookUrl,
        isAdHoc: true, // one-time webhook, auto-deleted after firing
      }),
    });
  } catch (err) {
    console.warn("[@hello] failed to register Apify webhook, run will complete but results won't be processed:", err);
    // The actor is already running — it just won't call back. Not fatal.
  }

  console.log(`[@hello] started async actor ${actorId}, runId=${run.id}`);
  return { runId: run.id };
}

/**
 * Normalize a raw Apify dataset items array into ApifyResult[].
 * Used by the webhook endpoint to process results without re-running the actor.
 */
export function normalizeApifyDataset(rawItems: Record<string, unknown>[]): ApifyResult[] {
  if (rawItems.length === 0) return [];

  // Flight actor returns nested structure: { best_flights[], other_flights[] }
  if (Array.isArray(rawItems[0]?.best_flights)) {
    return normalizeFlights(rawItems[0]);
  }

  // Standard actors — flat item list
  return rawItems.map((item) => normalizeItem(item));
}

function normalizeFlights(data: Record<string, unknown>): ApifyResult[] {
  const best = (data.best_flights ?? []) as Record<string, unknown>[];
  const other = (data.other_flights ?? []) as Record<string, unknown>[];
  const allFlights = [...best.slice(0, 5), ...other.slice(0, 5)];

  return allFlights.map((option) => {
    const legs = (option.flights ?? []) as Record<string, unknown>[];
    const firstLeg = legs[0] ?? {};
    const dep = (firstLeg.departure_airport ?? {}) as Record<string, string>;
    const arr = (firstLeg.arrival_airport ?? {}) as Record<string, string>;
    const airline = String(firstLeg.airline ?? "");
    const flightNum = String(firstLeg.flight_number ?? "");
    const duration = option.total_duration ? `${option.total_duration} min` : "";
    const stops = legs.length > 1 ? `${legs.length - 1} stop` : "nonstop";

    return {
      title: `${airline} ${flightNum} ${dep.id ?? ""} → ${arr.id ?? ""}`,
      price: option.price ? `$${option.price}` : undefined,
      description: `${stops}, ${duration}. ${dep.time ?? ""} → ${arr.time ?? ""}`,
      externalUrl: undefined,
      imageUrl: undefined,
      rating: undefined,
      source: "apify",
    };
  });
}

function normalizeItem(item: Record<string, unknown>): ApifyResult {
  return {
    title: String(
      item.name || item.title || item.hotel_name || item.displayName || ""
    ),
    price: item.price
      ? String(item.price)
      : item.totalPrice
        ? String(item.totalPrice)
        : undefined,
    imageUrl: item.imageUrl
      ? String(item.imageUrl)
      : item.image
        ? String(item.image)
        : item.thumbnail
          ? String(item.thumbnail)
          : item.thumbnailUrl
            ? String(item.thumbnailUrl)
            : undefined,
    description: item.description
      ? String(item.description)
      : item.categoryName
        ? String(item.categoryName)
        : undefined,
    externalUrl: item.url
      ? String(item.url)
      : item.link
        ? String(item.link)
        : item.website
          ? String(item.website)
          : undefined,
    rating:
      typeof item.rating === "number"
        ? item.rating
        : typeof item.totalScore === "number"
          ? item.totalScore
          : typeof item.reviewScore === "number"
            ? item.reviewScore
            : undefined,
    source: "apify",
  };
}
