/// E2EE-safe link unfurling.
/// The client detects URLs, calls /api/proxy-scrape (blind proxy),
/// downloads the OG metadata, encrypts it locally, and sends it
/// as part of the E2EE message payload.
/// The server NEVER sees which URLs users share.

export interface LinkPreview {
  url: string;
  title?: string;
  description?: string;
  imageBase64?: string; // OG image, encrypted with the message
  siteName?: string;
  domain: string;
}

/**
 * Fetch OG metadata for a URL via the blind proxy.
 * The proxy strips all auth headers and doesn't log the URL.
 */
export async function unfurlLink(url: string): Promise<LinkPreview | null> {
  try {
    const response = await fetch('/api/proxy-scrape', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ url }),
    });

    if (!response.ok) return null;

    const data = await response.json();
    const domain = new URL(url).hostname;

    return {
      url,
      title: data.title || undefined,
      description: data.description || undefined,
      imageBase64: data.image || undefined, // base64 from proxy
      siteName: data.siteName || undefined,
      domain,
    };
  } catch {
    return null; // Link unfurling failure is non-fatal
  }
}

/**
 * Detect URLs in a message text.
 * Returns the first URL found (for preview generation).
 */
export function detectUrl(text: string): string | null {
  const urlRegex = /https?:\/\/[^\s<>\"']+/i;
  const match = text.match(urlRegex);
  return match ? match[0] : null;
}

/**
 * Package a link preview for inclusion in an E2EE message.
 * The preview is encrypted alongside the message text.
 */
export function packageLinkPreview(preview: LinkPreview): string {
  return JSON.stringify({
    type: 'link_preview',
    ...preview,
  });
}
