const UNSPLASH_ACCESS_KEY = process.env.NEXT_PUBLIC_UNSPLASH_ACCESS_KEY;

interface UnsplashResult {
  imageBlob: Blob;
  imageUrl: string;
  photographerName: string;
  photographerUrl: string;
}

export async function fetchDestinationPhoto(query: string): Promise<UnsplashResult | null> {
  if (!UNSPLASH_ACCESS_KEY) return null;

  try {
    // 1. Get photo metadata from Unsplash API
    const res = await fetch(
      `https://api.unsplash.com/photos/random?query=${encodeURIComponent(query)}&orientation=landscape`,
      { headers: { Authorization: `Client-ID ${UNSPLASH_ACCESS_KEY}` } }
    );
    if (!res.ok) return null;

    const data = await res.json();
    const imageUrl: string = data.urls?.regular ?? "";
    if (!imageUrl) return null;

    // 2. Download the actual image as a blob
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
