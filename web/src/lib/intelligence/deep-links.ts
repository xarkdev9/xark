// web/src/lib/intelligence/deep-links.ts
// Constructs booking URLs for flights, hotels, and restaurants from search data.

/**
 * Build a Google Flights search URL pre-filled with origin, destination, and date.
 */
export function buildFlightBookingUrl(params: {
  origin: string;
  destination: string;
  date: string;
  returnDate?: string;
}): string {
  const base = "https://www.google.com/travel/flights";
  const q = `flights from ${params.origin} to ${params.destination} on ${params.date}`;
  const url = new URL(base);
  url.searchParams.set("q", q);
  if (params.returnDate) {
    url.searchParams.set("tfs", `r:${params.returnDate}`);
  }
  return url.toString();
}

/**
 * Build a Google Hotels search URL pre-filled with location and dates.
 */
export function buildHotelBookingUrl(params: {
  location: string;
  checkIn?: string;
  checkOut?: string;
}): string {
  const base = "https://www.google.com/travel/hotels";
  const url = new URL(base);
  url.searchParams.set("q", params.location);
  if (params.checkIn && params.checkOut) {
    url.searchParams.set("dates", `${params.checkIn}_${params.checkOut}`);
  }
  return url.toString();
}

/**
 * Build a Google Maps URL for a restaurant or activity.
 */
export function buildMapsUrl(placeName: string): string {
  return `https://www.google.com/maps/search/${encodeURIComponent(placeName)}`;
}

/**
 * Get the local airline logo path.
 * Logos are pre-cached at /airline-logos/{IATA_CODE}.png (727 airlines).
 */
export function getAirlineLogoUrl(iataCode: string): string {
  return `/airline-logos/${iataCode.toUpperCase()}.png`;
}

/**
 * Format a cache staleness label for flight prices.
 * Returns undefined if the price is fresh (<15 min).
 */
export function getCacheStalenessLabel(cachedAt: number): string | undefined {
  const ageMs = Date.now() - cachedAt;
  if (ageMs < 15 * 60 * 1000) return undefined;
  const ageMin = Math.round(ageMs / 60000);
  if (ageMin < 60) return `Price from ${ageMin}m ago. Verify on Google Flights.`;
  const ageHr = Math.round(ageMin / 60);
  return `Price from ${ageHr}h ago. Verify on Google Flights.`;
}
