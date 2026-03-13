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

// Default client (anon key, no auth token)
const defaultClient = createClient(url, anonKey);

// Authenticated client (recreated when token changes)
let authedClient: SupabaseClient | null = null;

// Set the JWT for authenticated requests (RLS enforcement).
// Called after Firebase auth or dev_login returns a token.
export function setSupabaseToken(token: string | null): void {
  currentToken = token;
  if (token) {
    authedClient = createClient(url, anonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      },
    });
  } else {
    authedClient = null;
  }
}

// The active Supabase client — uses auth token when available.
// Proxy delegates all access to the current active client.
export const supabase: SupabaseClient = new Proxy({} as SupabaseClient, {
  get(_target, prop) {
    const client = authedClient || defaultClient;
    const value = (client as unknown as Record<string | symbol, unknown>)[prop];
    if (typeof value === "function") {
      return value.bind(client);
    }
    return value;
  },
});
