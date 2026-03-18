// XARK OS v2.0 — Security Headers Middleware
// Nonce-based CSP. E2EE app: CSP is the last defense before key extraction.
// No unsafe-eval. No unsafe-inline in script-src. Pinned Supabase (no wildcard).
//
// CRITICAL: Nonce must be injected into BOTH request headers (for Next.js SSR
// to add nonce="" to its own <script> tags) AND response headers (for the browser
// to enforce the policy). Without the request-side injection, Next.js generates
// scripts without nonces → browser blocks hydration → White Screen of Death.

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

const SUPABASE_PROJECT = "ldnsxwkkxwztqyqkyuqa";

export function middleware(request: NextRequest) {
  // Generate cryptographic nonce for this request
  const nonce = Buffer.from(crypto.getRandomValues(new Uint8Array(16))).toString('base64');

  // ── Build Strict CSP ──
  const csp = [
    "default-src 'self'",
    // Scripts: nonce-based only. Firebase Auth (gstatic, recaptcha) explicitly whitelisted.
    // 'strict-dynamic' allows nonce'd scripts to load their own dependencies.
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic' https://www.gstatic.com https://apis.google.com https://www.google.com https://www.recaptcha.net`,
    // Styles: nonce-based. React's style={} prop sets DOM properties directly (not CSP-affected).
    `style-src 'self' 'nonce-${nonce}'`,
    // Images: pinned Supabase, explicit image sources
    `img-src 'self' data: blob: https://images.unsplash.com https://images.pexels.com https://firebasestorage.googleapis.com https://${SUPABASE_PROJECT}.supabase.co`,
    "font-src 'self'",
    // Connections: PINNED Supabase (no wildcard), Firebase, Google APIs
    `connect-src 'self' https://${SUPABASE_PROJECT}.supabase.co wss://${SUPABASE_PROJECT}.supabase.co https://generativelanguage.googleapis.com https://firebasestorage.googleapis.com https://identitytoolkit.googleapis.com https://securetoken.googleapis.com https://fcmregistrations.googleapis.com https://www.google.com https://www.recaptcha.net https://www.gstatic.com https://apis.google.com`,
    "media-src 'self' https://videos.pexels.com",
    "worker-src 'self' blob:",
    `frame-src 'self' https://${SUPABASE_PROJECT}.supabase.co https://*.firebaseapp.com https://www.google.com https://www.recaptcha.net`,
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
  ].join("; ");

  // ── Inject nonce into REQUEST headers (downstream to Next.js SSR) ──
  // Next.js App Router reads x-nonce from the request to add nonce="" attributes
  // to its own injected <script> and <link> tags during server-side rendering.
  // Without this, Next.js generates scripts WITHOUT nonces → CSP blocks them → WSOD.
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
    // Apply to all routes except static files and Next.js internals
    "/((?!_next/static|_next/image|favicon.ico|icons/).*)",
  ],
};
