/**
 * Reads real hotel data from Apify and injects it into demo-live.html.
 *
 * Usage: npx tsx src/build-demo.ts
 */

import { readFileSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const root = resolve(__dirname, "..");

// Read raw Apify data
const rawPath = resolve(root, "data", "hotels-raw.json");
const raw = JSON.parse(readFileSync(rawPath, "utf-8")) as Array<{
  name: string;
  url: string;
  description: string;
  stars: number | null;
  price: number | null;
  rating: number | null;
  ratingLabel: string | null;
  reviews: number | null;
  image: string | null;
  address: { full: string };
}>;

// Transform to slim format for the HTML
const hotelData = raw.map((h) => {
  // Clean up description: take first meaningful sentence
  let desc = (h.description ?? "").replace(/About this property/g, "").trim();
  const firstParagraph = desc.split("\n")[0] ?? "";
  desc = firstParagraph.length > 120 ? firstParagraph.slice(0, 120) + "…" : firstParagraph;

  return {
    name: h.name,
    desc,
    image: h.image ?? "",
    rating: h.rating ?? 0,
    ratingLabel: h.ratingLabel ?? "",
    reviews: h.reviews ?? 0,
    address: h.address?.full ?? "",
    url: h.url,
    stars: h.stars ?? 0,
  };
});

console.log(`Prepared ${hotelData.length} hotels for injection.`);

// Read template HTML
const templatePath = resolve(root, "demo-live.html");
let html = readFileSync(templatePath, "utf-8");

// Replace placeholder with real data
const jsonStr = JSON.stringify(hotelData, null, 2);
html = html.replace("HOTEL_DATA_PLACEHOLDER", jsonStr);

// Write final demo
const outPath = resolve(root, "demo-live.html");
writeFileSync(outPath, html);
console.log(`Written to ${outPath}`);
console.log("\nHotels included:");
for (const h of hotelData) {
  console.log(`  - ${h.name} (${h.rating}/10, ${h.reviews} reviews)`);
}
