// Server-side OG metadata extraction. No browser APIs.

export interface OGMetadata {
  title?: string;
  image?: string;
  description?: string;
  price?: string;
  siteName?: string;
  url?: string;
}

/** Parse OG tags from raw HTML string */
export function parseOGTags(html: string): OGMetadata {
  const result: OGMetadata = {};

  // Extract og: meta tags
  const ogPattern = /<meta\s+(?:[^>]*?\s+)?property=["'](og:[^"']+)["']\s+(?:[^>]*?\s+)?content=["']([^"']*)["'][^>]*>/gi;
  let match;
  while ((match = ogPattern.exec(html)) !== null) {
    const prop = match[1].toLowerCase();
    const content = match[2];
    if (prop === "og:title") result.title = content;
    else if (prop === "og:image") result.image = content;
    else if (prop === "og:description") result.description = content;
    else if (prop === "og:site_name") result.siteName = content;
    else if (prop === "og:url") result.url = content;
  }

  // Also check content-first attribute ordering
  const ogPatternReverse = /<meta\s+(?:[^>]*?\s+)?content=["']([^"']*)["']\s+(?:[^>]*?\s+)?property=["'](og:[^"']+)["'][^>]*>/gi;
  while ((match = ogPatternReverse.exec(html)) !== null) {
    const content = match[1];
    const prop = match[2].toLowerCase();
    if (prop === "og:title" && !result.title) result.title = content;
    else if (prop === "og:image" && !result.image) result.image = content;
    else if (prop === "og:description" && !result.description) result.description = content;
    else if (prop === "og:site_name" && !result.siteName) result.siteName = content;
    else if (prop === "og:url" && !result.url) result.url = content;
  }

  // Extract product:price:amount
  const pricePattern = /<meta\s+(?:[^>]*?\s+)?property=["']product:price:amount["']\s+(?:[^>]*?\s+)?content=["']([^"']*)["'][^>]*>/i;
  const priceMatch = pricePattern.exec(html);
  if (priceMatch) result.price = priceMatch[1];

  // Fallback: <title> tag if no og:title
  if (!result.title) {
    const titleMatch = /<title>([^<]*)<\/title>/i.exec(html);
    if (titleMatch) result.title = titleMatch[1].trim();
  }

  return result;
}

/** Fetch URL and extract OG metadata (server-side only) */
export async function fetchOGMetadata(url: string): Promise<OGMetadata> {
  try {
    const response = await fetch(url, {
      headers: { "User-Agent": "XarkBot/1.0 (OG Preview)" },
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) return { url };
    const html = await response.text();
    return { ...parseOGTags(html), url };
  } catch {
    return { url };
  }
}
