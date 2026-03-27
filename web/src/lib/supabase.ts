// XARK OS v2.0 — SUPABASE POSTGRES CLIENT
// Decision Engine queries ONLY. DB access for heart-sort ranking math.
// Authentication is handled exclusively by Firebase Auth (see Infrastructure Lock).
// The JWT (from Firebase or dev_login) is set via setSupabaseToken() for RLS.

import { createClient, SupabaseClient } from "@supabase/supabase-js";

const url =
  process.env.NEXT_PUBLIC_SUPABASE_URL || "https://placeholder.supabase.co";
const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || "placeholder";

// Track the current auth token
let currentToken: string | null = null;

// SINGLE client instance — never recreated. Avoids GoTrueClient duplication.
// Auth header is injected dynamically via the global fetch override.
const singleClient = createClient(url, anonKey, {
  auth: {
    persistSession: false,     // We manage JWT ourselves (Firebase/dev-auto-login)
    autoRefreshToken: false,   // No Supabase Auth — no token refresh needed
    detectSessionInUrl: false, // No OAuth redirect flow
  },
  global: {
    headers: {},
    fetch: (input, init) => {
      // Inject the current JWT into every request dynamically
      if (currentToken) {
        const headers = new Headers(init?.headers);
        headers.set("Authorization", `Bearer ${currentToken}`);
        return fetch(input, { ...init, headers });
      }
      return fetch(input, init);
    },
  },
});

// Set the JWT for authenticated requests (RLS enforcement).
// Called after Firebase auth or dev_login returns a token.
export function setSupabaseToken(token: string | null): void {
  if (token === currentToken) return; // No-op if unchanged
  currentToken = token;
  console.log(token ? "[xark-auth] JWT set on Supabase client" : "[xark-auth] JWT cleared");
}

// Check if the Supabase client has an authenticated token set.
export function hasSupabaseAuth(): boolean {
  return currentToken !== null;
}

// Get the current JWT for use in API Authorization headers.
export function getSupabaseToken(): string | null {
  return currentToken;
}

// The active Supabase client — single instance, token injected dynamically.
export const supabase: SupabaseClient = singleClient;
