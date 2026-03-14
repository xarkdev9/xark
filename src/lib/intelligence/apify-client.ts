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

  // ── Flight actor returns nested structure: { best_flights[], other_flights[] }
  if (items.length > 0 && Array.isArray((items[0] as Record<string, unknown>).best_flights)) {
    return normalizeFlights(items[0] as Record<string, unknown>);
  }

  // ── Standard actors (hotel, maps, search) — flat item list
  return items.map((item: Record<string, unknown>) => normalizeItem(item));
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
