// XARK OS v2.0 — Apify Actor Client
// Runs Apify actors and returns structured results.

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

  // Normalize results to our interface
  return items.map((item: Record<string, unknown>) => ({
    title: String(item.name || item.title || ""),
    price: item.price ? String(item.price) : undefined,
    imageUrl: item.imageUrl ? String(item.imageUrl) : (item.image ? String(item.image) : undefined),
    description: item.description ? String(item.description) : undefined,
    externalUrl: item.url ? String(item.url) : undefined,
    rating: typeof item.rating === "number" ? item.rating : undefined,
    source: "apify",
  }));
}
