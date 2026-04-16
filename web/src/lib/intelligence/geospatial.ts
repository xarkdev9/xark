// web/src/lib/intelligence/geospatial.ts
// Google Maps Distance Matrix API for validating travel times between itinerary slots.
// Used in Pass 2 of itinerary generation to prevent impossible itineraries.

const MAPS_API_BASE = "https://maps.googleapis.com/maps/api/distancematrix/json";
const MAX_TRAVEL_MINUTES = 60; // Flag if consecutive slots are >60min apart

export interface TravelValidation {
  from: string;
  to: string;
  durationMinutes: number;
  durationText: string;
  distanceKm: number;
  mode: "drive" | "walk" | "transit";
  exceedsThreshold: boolean;
  mapsUrl: string;
}

/**
 * Validate travel time between two locations using Google Maps Distance Matrix API.
 * Returns null if API key is missing or API call fails (fail-open — don't block itinerary).
 */
export async function validateTravelTime(
  from: string,
  to: string,
  mode: "driving" | "walking" | "transit" = "driving"
): Promise<TravelValidation | null> {
  const apiKey = process.env.GOOGLE_MAPS_API_KEY;
  if (!apiKey) {
    console.warn("[geospatial] No GOOGLE_MAPS_API_KEY configured, skipping validation");
    return null;
  }

  try {
    const url = new URL(MAPS_API_BASE);
    url.searchParams.set("origins", from);
    url.searchParams.set("destinations", to);
    url.searchParams.set("mode", mode);
    url.searchParams.set("key", apiKey);

    const res = await fetch(url.toString(), {
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });

    if (!res.ok) {
      console.warn(`[geospatial] API returned ${res.status}`);
      return null;
    }

    const data = await res.json();
    const element = data.rows?.[0]?.elements?.[0];

    if (!element || element.status !== "OK") {
      console.warn(`[geospatial] No route found from "${from}" to "${to}"`);
      return null;
    }

    const durationMinutes = Math.round(element.duration.value / 60);
    const distanceKm = Math.round(element.distance.value / 1000);
    const modeShort = mode === "driving" ? "drive" : mode === "walking" ? "walk" : "transit";

    return {
      from,
      to,
      durationMinutes,
      durationText: element.duration.text,
      distanceKm,
      mode: modeShort,
      exceedsThreshold: durationMinutes > MAX_TRAVEL_MINUTES,
      mapsUrl: `https://www.google.com/maps/dir/${encodeURIComponent(from)}/${encodeURIComponent(to)}`,
    };
  } catch (err) {
    console.warn("[geospatial] Distance Matrix failed:", err instanceof Error ? err.message : String(err));
    return null;
  }
}

/**
 * Validate all consecutive slot pairs in a day's itinerary.
 * Returns an array of TravelValidation results (one per pair).
 * Pairs that exceed the threshold are flagged — caller decides whether to
 * insert a travel block or re-prompt the AI for a closer alternative.
 */
export async function validateDaySlots(
  slots: Array<{ query: string; time: string }>
): Promise<TravelValidation[]> {
  if (slots.length < 2) return [];

  const pairs: Array<{ from: string; to: string }> = [];
  for (let i = 0; i < slots.length - 1; i++) {
    pairs.push({ from: slots[i].query, to: slots[i + 1].query });
  }

  // Batch all pairs concurrently (each is a separate API call)
  const results = await Promise.all(
    pairs.map((p) => validateTravelTime(p.from, p.to))
  );

  return results.filter((r): r is TravelValidation => r !== null);
}

/**
 * Build a travel block object for insertion between itinerary slots.
 * Used when travel time exceeds the threshold and the caller decides
 * to insert a connector card rather than re-prompting.
 */
export function buildTravelBlock(validation: TravelValidation): {
  time: string;
  type: "travel";
  duration: number;
  mode: string;
  note: string;
  mapsUrl: string;
  fromLocation: string;
  toLocation: string;
} {
  return {
    time: "travel",
    type: "travel",
    duration: validation.durationMinutes,
    mode: validation.mode,
    note: `${validation.durationText} ${validation.mode} from ${validation.from} to ${validation.to}`,
    mapsUrl: validation.mapsUrl,
    fromLocation: validation.from,
    toLocation: validation.to,
  };
}
