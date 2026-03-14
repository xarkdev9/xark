// XARK OS v2.0 — AUTH HOOK
// Firebase Auth (production) + password login (testing).
// Wires the JWT to the Supabase client for RLS enforcement.
// Caches JWT + user in sessionStorage to survive page refreshes.
// Auth is Firebase-only. Supabase Auth is banned.

"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { setSupabaseToken } from "@/lib/supabase";

export interface XarkUser {
  uid: string;
  displayName: string;
}

const SESSION_KEY = "xark_session";

interface CachedSession {
  token: string;
  user: XarkUser;
  expiresAt: number;
}

function getCachedSession(): CachedSession | null {
  if (typeof window === "undefined") return null;
  try {
    const raw = sessionStorage.getItem(SESSION_KEY);
    if (!raw) return null;
    const session: CachedSession = JSON.parse(raw);
    // Check expiry (with 5 min buffer)
    if (session.expiresAt < Date.now() + 300_000) return null;
    return session;
  } catch {
    return null;
  }
}

function cacheSession(token: string, user: XarkUser) {
  if (typeof window === "undefined") return;
  const session: CachedSession = {
    token,
    user,
    expiresAt: Date.now() + 23 * 60 * 60 * 1000, // 23h (JWT is 24h)
  };
  sessionStorage.setItem(SESSION_KEY, JSON.stringify(session));
}

// Password-gated login: call /api/dev-auto-login with username + password.
async function devAutoLogin(
  username: string
): Promise<{ user: XarkUser; token: string } | null> {
  try {
    const password = typeof window !== "undefined"
      ? sessionStorage.getItem("xark_pass") || ""
      : "";

    const res = await fetch("/api/dev-auto-login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username, password }),
    });

    if (!res.ok) return null;

    const data = await res.json();
    const user: XarkUser = { uid: data.user.id, displayName: data.user.displayName };
    const token: string = data.token;

    // Cache for subsequent page loads
    cacheSession(token, user);

    return { user, token };
  } catch {
    return null;
  }
}

// Restore cached session synchronously — called once at module level.
// This ensures the Supabase client has the JWT BEFORE any React effects run.
function restoreCachedToken(): { user: XarkUser; restored: boolean } | null {
  const cached = getCachedSession();
  if (cached) {
    setSupabaseToken(cached.token);
    return { user: cached.user, restored: true };
  }
  return null;
}

export function useAuth(fallbackName?: string): {
  user: XarkUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
} {
  // Try to restore cached session synchronously on first render.
  // This sets the JWT on the Supabase client IMMEDIATELY, before any effect.
  const initialSession = useRef(restoreCachedToken());
  const [user, setUser] = useState<XarkUser | null>(
    initialSession.current?.user ?? null
  );
  const [isLoading, setIsLoading] = useState(
    !initialSession.current?.restored
  );

  const handleFallback = useCallback(
    async (name: string) => {
      // 1. Try cached session first (survives refresh)
      const cached = getCachedSession();
      if (cached) {
        setSupabaseToken(cached.token);
        setUser(cached.user);
        setIsLoading(false);
        return;
      }

      // 2. Try dev login (gets a real JWT for RLS)
      const result = await devAutoLogin(name);
      if (result) {
        setSupabaseToken(result.token);
        setUser(result.user);
      } else {
        // 3. No auth available — use name fallback (no RLS, demo mode)
        console.warn("[xark-auth] NO JWT — name-only fallback (RLS will block writes)");
        setUser({ uid: `name_${name}`, displayName: name });
      }
      setIsLoading(false);
    },
    []
  );

  useEffect(() => {
    // Firebase unconfigured — use dev login or fallback
    if (!auth) {
      // If we already restored from cache, skip
      if (initialSession.current?.restored) return;
      if (fallbackName) {
        handleFallback(fallbackName);
      } else {
        setIsLoading(false);
      }
      return;
    }

    // Firebase configured — listen for auth state changes.
    // CRITICAL: never clear the JWT if we have a valid cached session.
    // Firebase fires onAuthStateChanged(null) when no user is signed in via Firebase,
    // but we may have a valid dev-auto-login JWT that must not be cleared.
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        // Production: get Firebase ID token and set on Supabase
        const token = await firebaseUser.getIdToken();
        setSupabaseToken(token);
        cacheSession(token, {
          uid: firebaseUser.uid,
          displayName:
            firebaseUser.displayName ??
            firebaseUser.phoneNumber ??
            "anon",
        });
        setUser({
          uid: firebaseUser.uid,
          displayName:
            firebaseUser.displayName ??
            firebaseUser.phoneNumber ??
            "anon",
        });
      } else if (fallbackName) {
        // No Firebase user — try dev login path
        // But don't re-run if we already restored from cache
        if (!initialSession.current?.restored) {
          await handleFallback(fallbackName);
        }
      } else {
        // No Firebase user, no fallback name.
        // Only clear JWT if there's no cached session.
        const cached = getCachedSession();
        if (!cached) {
          setSupabaseToken(null);
          setUser(null);
        }
      }
      setIsLoading(false);
    });

    return () => unsubscribe();
  }, [fallbackName, handleFallback]);

  return { user, isAuthenticated: !!user, isLoading };
}
