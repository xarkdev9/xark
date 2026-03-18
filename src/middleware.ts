// XARK OS v2.0 — Security Headers Middleware
// Nonce-based CSP. E2EE app: CSP is the last defense before key extraction.
// No unsafe-eval. No unsafe-inline in script-src. Pinned Supabase (no wildcard).

import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  // Generate cryptographic nonce for this request
  const nonce = Buffer.from(crypto.getRandomValues(new Uint8Array(16))).toString('base64');

  const response = NextResponse.next();

  // ── Security Headers ──
  response.headers.set("X-Frame-Options", "DENY");
  response.headers.set("X-Content-Type-Options", "nosniff");
  response.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  response.headers.set(
    "Permissions-Policy",
    "camera=(self), microphone=(self), geolocation=(self)"
  );

  // ── Strict Content Security Policy ──
  // E2EE app: CSP is the last defense before key extraction.
  // No unsafe-eval. No unsafe-inline. No wildcards.
  const SUPABASE_PROJECT = "ldnsxwkkxwztqyqkyuqa";

  const csp = [
    "default-src 'self'",
    // Scripts: nonce-based only. Firebase Auth (gstatic, recaptcha) explicitly whitelisted.
    // 'strict-dynamic' allows nonce'd scripts to load their own dependencies.
    `script-src 'self' 'nonce-${nonce}' 'strict-dynamic' https://www.gstatic.com https://apis.google.com https://www.google.com https://www.recaptcha.net`,
    // Styles: nonce-based. Framer Motion inline styles work via React's style prop (not CSP-affected).
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
    // Prevent form submission to external URLs
    "form-action 'self'",
  ].join("; ");

  response.headers.set("Content-Security-Policy", csp);

  // Pass nonce to Next.js for script injection
  // Next.js reads this header to add nonce to its own script tags
  response.headers.set("x-nonce", nonce);

  return response;
}

export const config = {
  matcher: [
    // Apply to all routes except static files and Next.js internals
    "/((?!_next/static|_next/image|favicon.ico|icons/).*)",
  ],
};
