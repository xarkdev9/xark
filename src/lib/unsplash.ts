// XARK OS v2.0 — DESTINATION PHOTO FETCHER
// Priority: Pexels (free, 200/hr) → Unsplash (needs paid key) → null
// Returns image URL + blob for Firebase Storage upload.

const PEXELS_API_KEY = process.env.NEXT_PUBLIC_PEXELS_API_KEY;
const UNSPLASH_ACCESS_KEY = process.env.NEXT_PUBLIC_UNSPLASH_ACCESS_KEY;

interface PhotoResult {
  imageBlob: Blob;
  imageUrl: string;
  photographerName: string;
  photographerUrl: string;
}

export async function fetchDestinationPhoto(query: string): Promise<PhotoResult | null> {
  // Try Pexels first (free)
  if (PEXELS_API_KEY) {
    const result = await fetchFromPexels(query);
    if (result) return result;
  }

  // Fallback to Unsplash
  if (UNSPLASH_ACCESS_KEY) {
    const result = await fetchFromUnsplash(query);
    if (result) return result;
  }

  return null;
}

// ── Pexels — free, 200 requests/hour ──
async function fetchFromPexels(query: string): Promise<PhotoResult | null> {
  try {
    const res = await fetch(
      `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=1&orientation=landscape`,
      { headers: { Authorization: PEXELS_API_KEY! } }
    );
    if (!res.ok) return null;

    const data = await res.json();
    const photo = data.photos?.[0];
    if (!photo) return null;

    // Use "large" size — good balance of quality and speed (~800px wide)
    const imageUrl: string = photo.src?.large ?? photo.src?.medium ?? "";
    if (!imageUrl) return null;

    const imgRes = await fetch(imageUrl);
    if (!imgRes.ok) return null;
    const imageBlob = await imgRes.blob();

    return {
      imageBlob,
      imageUrl,
      photographerName: photo.photographer ?? "",
      photographerUrl: photo.photographer_url ?? "",
    };
  } catch {
    return null;
  }
}

// ── Unsplash — needs API key ──
async function fetchFromUnsplash(query: string): Promise<PhotoResult | null> {
  try {
    const res = await fetch(
      `https://api.unsplash.com/photos/random?query=${encodeURIComponent(query)}&orientation=landscape`,
      { headers: { Authorization: `Client-ID ${UNSPLASH_ACCESS_KEY}` } }
    );
    if (!res.ok) return null;

    const data = await res.json();
    const imageUrl: string = data.urls?.regular ?? "";
    if (!imageUrl) return null;

    const imgRes = await fetch(imageUrl);
    if (!imgRes.ok) return null;
    const imageBlob = await imgRes.blob();

    return {
      imageBlob,
      imageUrl,
      photographerName: data.user?.name ?? "",
      photographerUrl: data.user?.links?.html ?? "",
    };
  } catch {
    return null;
  }
}
