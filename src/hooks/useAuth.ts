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
import { makeUserId } from "@/lib/user-id";

export interface XarkUser {
  uid: string;
  displayName: string;
}

const SESSION_KEY = "xark_session";

// Transient password — never persisted to storage. Set by login page, cleared after use.
let _transientPassword = "";

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
  // E2EE key-manager reads userId from localStorage
  localStorage.setItem("xark_user_id", user.uid);
}

/** Set the transient password for dev login. Called by login page — never persisted. */
export function setDevPassword(pw: string) { _transientPassword = pw; }

// Password-gated login: call /api/dev-auto-login with username + password.
async function devAutoLogin(
  username: string
): Promise<{ user: XarkUser; token: string } | null> {
  try {
    const password = _transientPassword;

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
    localStorage.setItem("xark_user_id", cached.user.uid);
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
      // 1. Try cached session first — but ONLY if it matches the requested name.
      //    Tab duplication copies sessionStorage, so Myna's tab can inherit Ram's session.
      const cached = getCachedSession();
      if (cached && cached.user.displayName.toLowerCase() === name.toLowerCase()) {
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
        const fallbackUser = { uid: makeUserId("name", name), displayName: name };
        localStorage.setItem("xark_user_id", fallbackUser.uid);
        setUser(fallbackUser);
      }
      setIsLoading(false);
    },
    []
  );

  useEffect(() => {
    // Firebase unconfigured — use dev login or fallback
    if (!auth) {
      // If we restored from cache, verify it matches the requested fallbackName.
      // Tab duplication copies sessionStorage — Myna's tab can inherit Ram's session.
      if (initialSession.current?.restored) {
        if (fallbackName && initialSession.current.user.displayName.toLowerCase() !== fallbackName.toLowerCase()) {
          // Cached user doesn't match — clear stale session and re-login
          sessionStorage.removeItem(SESSION_KEY);
          initialSession.current = null;
          setUser(null); // Clear stale user from useState init
          // Fall through to handleFallback below
        } else {
          return; // Cached user matches or no fallbackName to compare
        }
      }
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
        // Check if we already have a valid cached Supabase JWT — don't overwrite
        const cached = getCachedSession();
        if (cached) {
          setSupabaseToken(cached.token);
          setUser(cached.user);
          setIsLoading(false);
          return;
        }

        // No cached session — exchange Firebase token for Supabase JWT
        try {
          const firebaseToken = await firebaseUser.getIdToken();
          const res = await fetch("/api/phone-auth", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ firebaseToken, displayName: firebaseUser.displayName ?? undefined }),
          });
          if (res.ok) {
            const data = await res.json();
            setSupabaseToken(data.token);
            cacheSession(data.token, { uid: data.user.id, displayName: data.user.displayName });
            setUser({ uid: data.user.id, displayName: data.user.displayName });
          } else {
            // phone-auth failed — use Firebase UID as fallback
            setUser({
              uid: firebaseUser.uid,
              displayName: firebaseUser.displayName ?? firebaseUser.phoneNumber ?? "anon",
            });
          }
        } catch {
          setUser({
            uid: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? firebaseUser.phoneNumber ?? "anon",
          });
        }
      } else if (fallbackName) {
        // No Firebase user — try dev login path
        // But don't re-run if we already restored from cache AND user matches
        const restoredMatches = initialSession.current?.restored
          && initialSession.current.user.displayName.toLowerCase() === fallbackName.toLowerCase();
        if (!restoredMatches) {
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
