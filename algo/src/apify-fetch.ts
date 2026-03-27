/**
 * Apify Integration — Fetches real hotel data from Booking.com
 * via the Apify voyager~booking-scraper actor, then transforms
 * results into the format consumed by the Xark consensus engine.
 *
 * Usage: npx tsx src/apify-fetch.ts
 */

import { writeFileSync, mkdirSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));

const APIFY_TOKEN = process.env["APIFY_TOKEN"] ?? "";
const ACTOR_ID = "voyager~booking-scraper";
const BASE_URL = `https://api.apify.com/v2/acts/${ACTOR_ID}/run-sync-get-dataset-items`;

interface ApifyHotelResult {
  name: string;
  url: string;
  description: string;
  stars: number | null;
  price: number | null;
  currency: string | null;
  rating: number | null;
  ratingLabel: string | null;
  reviews: number | null;
  image: string | null;
  address: { full: string; city: string; country: string };
  location: { lat: string; lng: string };
  breakfast: string | null;
  checkIn: string | null;
  checkOut: string | null;
}

interface TransformedItem {
  title: string;
  description: string;
  category: string;
  price: number | null;
  currency: string | null;
  rating: number | null;
  ratingLabel: string | null;
  reviews: number | null;
  image: string | null;
  address: string;
  url: string;
  stars: number | null;
  lat: string;
  lng: string;
}

async function fetchHotels(
  search: string,
  maxItems: number
): Promise<ApifyHotelResult[]> {
  console.log(`Fetching up to ${maxItems} hotels for "${search}"...`);

  const url = `${BASE_URL}?token=${APIFY_TOKEN}`;
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      search,
      maxItems,
      sortBy: "distance_from_search",
      starsCountFilter: "any",
      currency: "USD",
      language: "en-gb",
      minMaxPrice: "0-999999",
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Apify API error ${response.status}: ${text}`);
  }

  const data = (await response.json()) as ApifyHotelResult[];
  console.log(`Got ${data.length} results from Apify.`);
  return data;
}

function transform(hotels: ApifyHotelResult[]): TransformedItem[] {
  return hotels.map((h) => {
    // Build a concise description
    const parts: string[] = [];
    if (h.stars) parts.push(`${h.stars}-star`);
    if (h.rating) parts.push(`${h.rating}/10 (${h.ratingLabel ?? ""})`);
    if (h.reviews) parts.push(`${h.reviews} reviews`);
    if (h.price && h.currency) parts.push(`${h.currency} ${h.price}/night`);
    if (h.breakfast) parts.push(h.breakfast);

    const shortDesc = h.description?.split("\n")[0]?.slice(0, 150) ?? "";

    return {
      title: h.name,
      description: parts.join(" · ") + (shortDesc ? ` — ${shortDesc}` : ""),
      category: "hotel",
      price: h.price,
      currency: h.currency,
      rating: h.rating,
      ratingLabel: h.ratingLabel,
      reviews: h.reviews,
      image: h.image,
      address: h.address?.full ?? "",
      url: h.url,
      stars: h.stars,
      lat: h.location?.lat ?? "",
      lng: h.location?.lng ?? "",
    };
  });
}

async function main() {
  if (!APIFY_TOKEN) {
    console.error("Missing APIFY_TOKEN environment variable.");
    process.exit(1);
  }

  const search = process.argv[2] ?? "San Diego";
  const maxItems = parseInt(process.argv[3] ?? "8", 10);

  const raw = await fetchHotels(search, maxItems);

  const dataDir = resolve(__dirname, "..", "data");
  mkdirSync(dataDir, { recursive: true });

  // Save raw response
  writeFileSync(
    resolve(dataDir, "hotels-raw.json"),
    JSON.stringify(raw, null, 2)
  );
  console.log(`Saved raw data to data/hotels-raw.json`);

  // Save transformed items
  const items = transform(raw);
  writeFileSync(
    resolve(dataDir, "hotels.json"),
    JSON.stringify(items, null, 2)
  );
  console.log(`Saved ${items.length} transformed items to data/hotels.json`);

  // Print summary
  console.log("\n--- Hotel Summary ---");
  for (const item of items) {
    console.log(`  ${item.title}`);
    console.log(`    ${item.description}`);
    console.log();
  }
}

main().catch((err) => {
  console.error("Failed:", err);
  process.exit(1);
});
