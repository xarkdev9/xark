// XARK OS v2.0 — Blind Proxy Scraper
// Stateless OG metadata extraction for E2EE link previews.
// Returns title, description, and og:image as Base64 bytes.
//
// PRIVACY MODEL:
// - No authentication required (caller identity is irrelevant)
// - No logging of requested URLs (server is blind to who/where)
// - No database writes (completely stateless)
// - SSRF protection only (block private/internal networks)
// - Image bytes returned inline so client avoids CORS for canvas/AES

import { NextRequest, NextResponse } from 'next/server';
import { parseOGTags } from '@/lib/og-extract';

// ── SSRF protection: block internal/private URLs ──
const BLOCKED_HOSTS = [
  /^localhost$/i,
  /^127\./,
  /^10\./,
  /^172\.(1[6-9]|2\d|3[01])\./,
  /^192\.168\./,
  /^169\.254\./,
  /^0\./,
  /^\[::1\]/,
  /^\[fd/i,
  /^\[fe80:/i,
];

function isUrlSafe(urlString: string): boolean {
  try {
    const parsed = new URL(urlString);
    if (parsed.protocol !== 'http:' && parsed.protocol !== 'https:') return false;
    for (const pattern of BLOCKED_HOSTS) {
      if (pattern.test(parsed.hostname)) return false;
    }
    return true;
  } catch {
    return false;
  }
}

// Chrome-like User-Agent so sites like Airbnb don't block the request
const UA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

// Max image size to fetch (2MB — prevents OOM on giant banners)
const MAX_IMAGE_BYTES = 2 * 1024 * 1024;

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { url } = body;

    if (!url || typeof url !== 'string') {
      return NextResponse.json({ error: 'url required' }, { status: 400 });
    }

    if (!isUrlSafe(url)) {
      return NextResponse.json({ error: 'url not allowed' }, { status: 400 });
    }

    // ── Step 1: Fetch and parse HTML for OG tags ──
    const htmlRes = await fetch(url, {
      headers: { 'User-Agent': UA },
      signal: AbortSignal.timeout(8000),
      redirect: 'follow',
    });

    if (!htmlRes.ok) {
      return NextResponse.json(
        { title: null, description: null, imageBase64: null },
        { status: 200 }
      );
    }

    const html = await htmlRes.text();
    const og = parseOGTags(html);

    const title = og.title || null;
    const description = og.description || null;
    let imageBase64: string | null = null;

    // ── Step 2: Fetch og:image as Base64 bytes ──
    // Client can't fetch cross-origin images (CORS) for canvas drawing or AES encryption.
    // We download the image server-side and return raw bytes so the client can process them.
    if (og.image) {
      let imageUrl = og.image;

      // Resolve relative og:image URLs against the page origin
      if (imageUrl.startsWith('/')) {
        try {
          const pageOrigin = new URL(url).origin;
          imageUrl = `${pageOrigin}${imageUrl}`;
        } catch { /* leave as-is */ }
      }

      if (isUrlSafe(imageUrl)) {
        try {
          const imgRes = await fetch(imageUrl, {
            headers: { 'User-Agent': UA },
            signal: AbortSignal.timeout(5000),
            redirect: 'follow',
          });

          if (imgRes.ok) {
            const contentLength = imgRes.headers.get('content-length');
            if (!contentLength || parseInt(contentLength) <= MAX_IMAGE_BYTES) {
              const arrayBuffer = await imgRes.arrayBuffer();

              // Double-check actual size (content-length can lie)
              if (arrayBuffer.byteLength <= MAX_IMAGE_BYTES) {
                const bytes = new Uint8Array(arrayBuffer);
                let binary = '';
                // Process in chunks to avoid call stack overflow on large arrays
                const CHUNK = 8192;
                for (let i = 0; i < bytes.length; i += CHUNK) {
                  const slice = bytes.subarray(i, Math.min(i + CHUNK, bytes.length));
                  binary += String.fromCharCode(...slice);
                }

                const contentType = imgRes.headers.get('content-type') || 'image/jpeg';
                imageBase64 = `data:${contentType};base64,${btoa(binary)}`;
              }
            }
          }
        } catch {
          // Image fetch failed — non-fatal, return metadata without image
        }
      }
    }

    return NextResponse.json({ title, description, imageBase64 });
  } catch {
    return NextResponse.json(
      { title: null, description: null, imageBase64: null },
      { status: 200 }
    );
  }
}
