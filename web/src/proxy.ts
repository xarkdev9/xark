// hello OS v2.0 — Security Headers Proxy + Edge Rate Limiting (Next.js 16)
// BACKEND-03: Upstash Redis rate limiting runs BEFORE serverless functions spin up.
// Nonce-based CSP. E2EE app: CSP is the last defense before key extraction.
// No unsafe-eval in prod. No unsafe-inline in script-src. Pinned Supabase (no wildcard).
//
// Next.js 16 automatic nonce injection:
// 1. Proxy generates nonce → sets CSP header on request
// 2. Next.js parses 'nonce-{value}' from CSP header during SSR
// 3. Nonce auto-applied to: framework scripts, page bundles, inline scripts/styles
// Pages MUST be dynamically rendered for nonces to work.

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { ROUTE_RATE_CONFIG, checkLimit } from "@/lib/rate-limit-edge";

const SUPABASE_PROJECT = "ldnsxwkkxwztqyqkyuqa";

// ── JWT userId extraction (lightweight — no verification, just decode) ──
// The actual JWT verification happens in the API route handler.
// We only need the sub claim for rate limit keying.
function extractUserIdFromJwt(authHeader: string | null): string | null {
  if (!authHeader) return null;
  const token = authHeader.replace(/^Bearer\s+/i, '');
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  try {
    // Base64url decode the payload (middle segment)
    const payload = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const decoded = JSON.parse(atob(payload));
    return typeof decoded.sub === 'string' ? decoded.sub : null;
  } catch {
    return null;
  }
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // ── Edge Rate Limiting (API routes only) ──
  // Runs BEFORE serverless functions spin up — blocks malicious traffic at the edge.
  if (pathname.startsWith('/api/') && ROUTE_RATE_CONFIG) {
    // Match pathname against route config
    // For sub-routes like /api/hello/webhook, try exact match first, then parent
    const routeConfig = ROUTE_RATE_CONFIG.get(pathname)
      ?? ROUTE_RATE_CONFIG.get(pathname.replace(/\/[^/]+$/, ''));

    if (routeConfig) {
      // Determine rate limit key
      let key: string;
      if (routeConfig.keyByIp) {
        // IP-based keying (phone-auth — no JWT available yet)
        key = request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
          || request.headers.get('x-real-ip')
          || 'unknown';
      } else {
        // JWT-based keying (authenticated routes)
        const userId = extractUserIdFromJwt(request.headers.get('authorization'));
        key = userId || request.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
          || request.headers.get('x-real-ip')
          || 'unknown';
      }

      const result = await checkLimit(routeConfig.limiter, key, routeConfig.failureMode);

      if (!result.allowed) {
        return NextResponse.json(
          { error: result.status === 503 ? 'service temporarily unavailable' : 'rate limited' },
          {
            status: result.status ?? 429,
            headers: {
              'Retry-After': String(result.retryAfter ?? 60),
              'X-RateLimit-Policy': routeConfig.prefix,
            },
          },
        );
      }
    }

    // API routes return JSON — CSP not needed. Pass through after rate limit check.
    return NextResponse.next();
  }

  // ── CSP Nonce Injection (non-API routes) ──

  // Generate cryptographic nonce for this request
  const nonce = Buffer.from(crypto.randomUUID()).toString('base64');
  const isDev = process.env.NODE_ENV === 'development';

  // ── Build Strict CSP ──
  const csp = [
    "default-src 'self'",
    // Scripts: nonce-based + strict-dynamic (nonce'd scripts can load dependencies).
    // Firebase Auth (gstatic, recaptcha) explicitly whitelisted.
    // unsafe-eval only in dev (React error stack reconstruction).
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic' 'unsafe-eval' 'wasm-unsafe-eval' https://www.gstatic.com https://apis.google.com https://www.google.com https://www.recaptcha.net`,
    // Styles: unsafe-inline required because React SSR generates inline style=""
    // attributes via style={{}} props — these cannot be nonce'd individually.
    // Next.js auto-nonces <style> tags, but style="" attrs need unsafe-inline.
    `style-src 'self' 'unsafe-inline'`,
    // Images: pinned Supabase, explicit image sources.
    `img-src 'self' blob: data: https://images.unsplash.com https://images.pexels.com https://firebasestorage.googleapis.com https://${SUPABASE_PROJECT}.supabase.co https://*.googleusercontent.com https://*.gstatic.com https://photos.hotelbeds.com`,
    "font-src 'self'",
    // Connections: PINNED Supabase (no wildcard), Firebase, Google APIs
    `connect-src 'self' https://${SUPABASE_PROJECT}.supabase.co wss://${SUPABASE_PROJECT}.supabase.co https://generativelanguage.googleapis.com https://firebasestorage.googleapis.com https://identitytoolkit.googleapis.com https://securetoken.googleapis.com https://fcmregistrations.googleapis.com https://www.google.com https://www.recaptcha.net https://www.gstatic.com https://apis.google.com`,
    "media-src 'self' https://videos.pexels.com",
    "worker-src 'self' blob:",
    `frame-src 'self' https://${SUPABASE_PROJECT}.supabase.co https://*.firebaseapp.com https://www.google.com https://www.recaptcha.net`,
    "frame-ancestors 'none'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "upgrade-insecure-requests",
  ].join("; ");

  // ── Inject nonce + CSP into REQUEST headers (downstream to Next.js SSR) ──
  // Next.js parses 'nonce-{value}' from CSP during rendering and auto-applies
  // nonce="" to all framework <script> and <style> tags.
  const requestHeaders = new Headers(request.headers);
  requestHeaders.set("x-nonce", nonce);
  requestHeaders.set("Content-Security-Policy", csp);

  // Create response with mutated request headers flowing downstream
  const response = NextResponse.next({
    request: {
      headers: requestHeaders,
    },
  });

  // ── Set security headers on RESPONSE (upstream to browser) ──
  response.headers.set("X-Frame-Options", "DENY");
  response.headers.set("X-Content-Type-Options", "nosniff");
  response.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  response.headers.set("Strict-Transport-Security", "max-age=63072000; includeSubDomains; preload");
  response.headers.set("Cross-Origin-Opener-Policy", "same-origin");
  response.headers.set(
    "Permissions-Policy",
    "camera=(self), microphone=(self), geolocation=(self)"
  );
  response.headers.set("Content-Security-Policy", csp);
  response.headers.set("x-nonce", nonce);

  return response;
}

export const config = {
  matcher: [
    // API routes — rate limiting only (no CSP needed for JSON responses)
    "/api/:path*",
    // All non-static routes — CSP nonce injection
    {
      source: "/((?!_next/static|_next/image|favicon.ico|icons/).*)",
      missing: [
        { type: "header", key: "next-router-prefetch" },
        { type: "header", key: "purpose", value: "prefetch" },
      ],
    },
  ],
};
