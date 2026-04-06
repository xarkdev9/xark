// web/src/lib/intelligence/flight-cache.ts
// Caches flight search results in Upstash Redis to protect against fli downtime
// and speed up repeat searches on popular routes. TTL: 4 hours.

import { Redis } from "@upstash/redis";

const redis =
  process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN
    ? new Redis({
        url: process.env.UPSTASH_REDIS_REST_URL,
        token: process.env.UPSTASH_REDIS_REST_TOKEN,
      })
    : null;

const CACHE_TTL_SECONDS = 4 * 60 * 60; // 4 hours
const KEY_PREFIX = "flights";

export interface CachedFlightResult {
  results: FlightResultItem[];
  cachedAt: number;
  source: string;
}

export interface FlightResultItem {
  title: string;
  price: string | undefined;
  imageUrl: string | undefined;
  description: string;
  externalUrl: string | undefined;
  bookingUrl: string;
  source: string;
  airlineCode: string;
  legs: Array<{
    airline: string;
    airlineCode: string;
    flightNumber: string;
    departureAirport: string;
    arrivalAirport: string;
    departureTime: string;
    arrivalTime: string;
    duration: number;
  }>;
}

function cacheKey(origin: string, destination: string, date: string): string {
  return `${KEY_PREFIX}:${origin.toUpperCase()}:${destination.toUpperCase()}:${date}`;
}

export async function getCachedFlights(
  origin: string,
  destination: string,
  date: string
): Promise<CachedFlightResult | null> {
  if (!redis) return null;
  try {
    const key = cacheKey(origin, destination, date);
    const cached = await redis.get<CachedFlightResult>(key);
    return cached ?? null;
  } catch (err) {
    console.warn("[flight-cache] Read failed:", err instanceof Error ? err.message : String(err));
    return null;
  }
}

export async function setCachedFlights(
  origin: string,
  destination: string,
  date: string,
  results: FlightResultItem[],
  source: string
): Promise<void> {
  if (!redis) return;
  try {
    const key = cacheKey(origin, destination, date);
    const value: CachedFlightResult = {
      results: results.slice(0, 20),
      cachedAt: Date.now(),
      source,
    };
    await redis.set(key, value, { ex: CACHE_TTL_SECONDS });
  } catch (err) {
    console.warn("[flight-cache] Write failed:", err instanceof Error ? err.message : String(err));
  }
}
