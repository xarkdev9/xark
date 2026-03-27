// hello OS v2.0 — SearchApi Client
// Replaces Apify for Google Hotels, Flights, Local, and Search.
// ~2-5s per query vs Apify's 15-40s. Real Google data with images.

export interface SearchApiResult {
  title: string;
  price?: string;
  imageUrl?: string;
  description?: string;
  externalUrl?: string;
  rating?: number;
  source: string;
}

const API_BASE = "https://www.searchapi.io/api/v1/search";

async function searchApi(params: Record<string, string>): Promise<Record<string, unknown>> {
  const key = process.env.SEARCHAPI_API_KEY;
  if (!key) {
    console.warn("[searchapi] No API key configured");
    return {};
  }

  const url = new URL(API_BASE);
  url.searchParams.set("api_key", key);
  for (const [k, v] of Object.entries(params)) {
    if (v) url.searchParams.set(k, v);
  }

  console.log(`[searchapi] Fetching: ${url.toString().replace(/api_key=[^&]+/, "api_key=***")}`);
  const res = await fetch(url.toString(), { cache: 'no-store', signal: AbortSignal.timeout(15000) });
  if (!res.ok) {
    const errBody = await res.text().catch(() => "");
    console.error(`[searchapi] ${res.status}: ${errBody}`);
    return {};
  }
  const data = await res.json();
  console.log(`[searchapi] Response keys: ${Object.keys(data).join(", ")}`);
  return data;
}

// ── Google Hotels ──

export async function searchHotels(params: {
  location: string;
  checkIn?: string;
  checkOut?: string;
  query?: string;
}): Promise<SearchApiResult[]> {
  // Default check-in/out: 7 days from now, 2-night stay
  const defaultIn = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
  const defaultOut = new Date(Date.now() + 9 * 86400000).toISOString().slice(0, 10);

  const data = await searchApi({
    engine: "google_hotels",
    q: params.query ? `${params.query} ${params.location}` : params.location,
    check_in_date: params.checkIn || defaultIn,
    check_out_date: params.checkOut || defaultOut,
    num: "10",
  });

  const properties = (data.properties ?? []) as Record<string, unknown>[];
  return properties.map((p) => {
    const images = (p.images ?? []) as Array<{ thumbnail?: string; original?: string }>;
    const rate = p.rate_per_night as Record<string, string> | undefined;
    return {
      title: String(p.name ?? ""),
      price: rate?.lowest ? String(rate.lowest) : undefined,
      imageUrl: images[0]?.original ?? images[0]?.thumbnail ?? undefined,
      description: String(p.description ?? ""),
      externalUrl: p.link ? String(p.link) : undefined,
      rating: typeof p.overall_rating === "number" ? p.overall_rating : undefined,
      source: "google-hotels",
    };
  });
}

// ── Google Flights ──

export async function searchFlights(params: {
  origin: string;
  destination: string;
  date?: string;
  returnDate?: string;
}): Promise<SearchApiResult[]> {
  const defaultDate = new Date(Date.now() + 7 * 86400000).toISOString().slice(0, 10);
  const outbound = params.date || defaultDate;
  // SearchApi requires return_date — default to 7 days after departure
  const returnD = params.returnDate || new Date(new Date(outbound).getTime() + 7 * 86400000).toISOString().slice(0, 10);

  const data = await searchApi({
    engine: "google_flights",
    departure_id: params.origin.toUpperCase(),
    arrival_id: params.destination.toUpperCase(),
    outbound_date: outbound,
    return_date: returnD,
  });

  const best = (data.best_flights ?? []) as Record<string, unknown>[];
  const other = (data.other_flights ?? []) as Record<string, unknown>[];
  const all = [...best.slice(0, 5), ...other.slice(0, 5)];

  return all.map((f) => {
    const legs = (f.flights ?? []) as Record<string, unknown>[];
    const first = legs[0] ?? {};
    const dep = (first.departure_airport ?? {}) as Record<string, string>;
    const arr = (first.arrival_airport ?? {}) as Record<string, string>;
    const airline = String(first.airline ?? "");
    const flightNum = String(first.flight_number ?? "");
    const duration = f.total_duration ? `${f.total_duration} min` : "";
    const stops = legs.length > 1 ? `${legs.length - 1} stop${legs.length > 2 ? "s" : ""}` : "nonstop";
    const logo = first.airline_logo ? String(first.airline_logo) : undefined;

    return {
      title: `${airline} ${flightNum} ${dep.id ?? ""} → ${arr.id ?? ""}`,
      price: f.price ? `$${f.price}` : undefined,
      imageUrl: logo,
      description: `${stops}, ${duration}. ${dep.time ?? ""} → ${arr.time ?? ""}`,
      externalUrl: undefined,
      rating: undefined,
      source: "google-flights",
    };
  });
}

// ── Google Local (restaurants, activities, places) ──

export async function searchLocal(params: {
  query: string;
  location?: string;
}): Promise<SearchApiResult[]> {
  const q = params.location && !params.query.toLowerCase().includes(params.location.toLowerCase())
    ? `${params.query} in ${params.location}`
    : params.query;

  const data = await searchApi({
    engine: "google_local",
    q,
    num: "10",
  });

  const results = (data.local_results ?? []) as Record<string, unknown>[];
  return results.map((p) => {
    // Image: SearchApi returns base64 inline OR a URL
    let imageUrl: string | undefined;
    const img = p.image ?? p.thumbnail;
    if (typeof img === "string") {
      // Skip base64 images (too large for decision cards, will use Pexels fallback)
      imageUrl = img.startsWith("data:") ? undefined : img;
    }

    const price = p.price ? String(p.price) : undefined;
    const extensions = (p.extensions ?? []) as string[];
    const address = extensions.find((e) => /\d/.test(e) && e.length > 10) ?? "";

    return {
      title: String(p.title ?? ""),
      price,
      imageUrl,
      description: [p.comment ? String(p.comment).replace(/^"|"$/g, "") : "", address].filter(Boolean).join(" — "),
      externalUrl: p.website ? String(p.website) : undefined,
      rating: typeof p.rating === "number" ? p.rating : undefined,
      source: "google-local",
    };
  });
}

// ── Google Search (general knowledge) ──

export async function searchGeneral(params: {
  query: string;
}): Promise<SearchApiResult[]> {
  const data = await searchApi({
    engine: "google",
    q: params.query,
    num: "8",
  });

  const results: SearchApiResult[] = [];

  // Answer box (instant answer)
  const ab = data.answer_box as Record<string, unknown> | undefined;
  if (ab) {
    results.push({
      title: String(ab.title ?? ab.answer ?? ""),
      description: String(ab.snippet ?? ab.answer ?? ""),
      externalUrl: ab.link ? String(ab.link) : undefined,
      source: "google-answer",
    });
  }

  // Organic results
  const organic = (data.organic_results ?? []) as Record<string, unknown>[];
  for (const r of organic.slice(0, 6)) {
    results.push({
      title: String(r.title ?? ""),
      description: String(r.snippet ?? ""),
      externalUrl: r.link ? String(r.link) : undefined,
      imageUrl: r.thumbnail ? String(r.thumbnail) : undefined,
      source: "google-search",
    });
  }

  return results;
}
