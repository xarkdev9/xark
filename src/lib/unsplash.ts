const UNSPLASH_ACCESS_KEY = process.env.NEXT_PUBLIC_UNSPLASH_ACCESS_KEY;

interface UnsplashResult {
  imageUrl: string;
  photographerName: string;
  photographerUrl: string;
}

export async function fetchDestinationPhoto(query: string): Promise<UnsplashResult | null> {
  if (!UNSPLASH_ACCESS_KEY) return null;

  try {
    const res = await fetch(
      `https://api.unsplash.com/photos/random?query=${encodeURIComponent(query)}&orientation=landscape`,
      { headers: { Authorization: `Client-ID ${UNSPLASH_ACCESS_KEY}` } }
    );
    if (!res.ok) return null;

    const data = await res.json();
    return {
      imageUrl: data.urls?.regular ?? "",
      photographerName: data.user?.name ?? "",
      photographerUrl: data.user?.links?.html ?? "",
    };
  } catch {
    return null;
  }
}
