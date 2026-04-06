// web/src/lib/intelligence/fli-client.ts
// TypeScript client for the Vercel Python fli function at /api/fli.
// Normalizes fli results to ApifyResult[] for the orchestrator.

import { getCachedFlights, setCachedFlights, type FlightResultItem } from "./flight-cache";
import { buildFlightBookingUrl, getAirlineLogoUrl } from "./deep-links";

export type { FlightResultItem } from "./flight-cache";

interface FliSearchParams {
  origin: string;
  destination: string;
  date: string;
  cabin?: string;
  maxResults?: number;
}

interface FliResponse {
  results: Array<{
    price: number;
    currency: string;
    duration: number;
    stops: number;
    airline_code: string;
    legs: Array<{
      airline: string;
      airline_code: string;
      flight_number: string;
      departure_airport: string;
      arrival_airport: string;
      departure_time: string;
      arrival_time: string;
      duration: number;
    }>;
  }>;
  count: number;
  returned: number;
  source: string;
}

function getFliBaseUrl(): string {
  if (process.env.VERCEL_URL) return `https://${process.env.VERCEL_URL}`;
  if (process.env.NEXT_PUBLIC_APP_URL) return process.env.NEXT_PUBLIC_APP_URL;
  return "http://localhost:3000";
}

export async function searchFlightsFli(params: FliSearchParams): Promise<FlightResultItem[]> {
  const { origin, destination, date } = params;

  // 1. Check cache
  const cached = await getCachedFlights(origin, destination, date);
  if (cached) {
    console.log(`[fli] Cache hit for ${origin}->${destination} on ${date} (${cached.results.length} results, age: ${Math.round((Date.now() - cached.cachedAt) / 60000)}m)`);
    return cached.results;
  }

  // 2. Call fli Python function
  const baseUrl = getFliBaseUrl();
  const url = `${baseUrl}/api/fli`;

  console.log(`[fli] Fetching ${origin}->${destination} on ${date}`);

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      origin,
      destination,
      date,
      cabin: params.cabin || "economy",
      max_results: params.maxResults || 20,
    }),
    cache: "no-store",
    signal: AbortSignal.timeout(10000),
  });

  if (!res.ok) {
    const errBody = await res.text().catch(() => "");
    console.error(`[fli] ${res.status}: ${errBody}`);
    return [];
  }

  const data: FliResponse = await res.json();
  console.log(`[fli] Got ${data.returned} of ${data.count} flights`);

  // 3. Build booking URL
  const bookingUrl = buildFlightBookingUrl({ origin, destination, date });

  // 4. Normalize to FlightResultItem[]
  const results: FlightResultItem[] = data.results.map((f) => {
    const firstLeg = f.legs[0];
    const airlineCode = firstLeg?.airline_code || f.airline_code || "";
    const depTime = firstLeg?.departure_time
      ? new Date(firstLeg.departure_time).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false })
      : "";
    const lastLeg = f.legs[f.legs.length - 1];
    const arrTime = lastLeg?.arrival_time
      ? new Date(lastLeg.arrival_time).toLocaleTimeString("en-US", { hour: "2-digit", minute: "2-digit", hour12: false })
      : "";
    const hrs = Math.floor(f.duration / 60);
    const mins = f.duration % 60;
    const stopsLabel = f.stops === 0 ? "nonstop" : `${f.stops} stop${f.stops > 1 ? "s" : ""}`;

    return {
      title: `${firstLeg?.airline || ""} ${firstLeg?.flight_number || ""} ${firstLeg?.departure_airport || ""} → ${lastLeg?.arrival_airport || ""}`,
      price: f.price > 0 ? `$${f.price}` : undefined,
      imageUrl: airlineCode ? getAirlineLogoUrl(airlineCode) : undefined,
      description: `${stopsLabel}, ${hrs}h${String(mins).padStart(2, "0")}m. ${depTime} → ${arrTime}`,
      externalUrl: bookingUrl,
      bookingUrl,
      source: "fli",
      airlineCode,
      legs: f.legs.map((l) => ({
        airline: l.airline,
        airlineCode: l.airline_code,
        flightNumber: l.flight_number,
        departureAirport: l.departure_airport,
        arrivalAirport: l.arrival_airport,
        departureTime: l.departure_time,
        arrivalTime: l.arrival_time,
        duration: l.duration,
      })),
    };
  });

  // 5. Cache results
  await setCachedFlights(origin, destination, date, results, "fli");

  return results;
}
