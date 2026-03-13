// XARK OS v2.0 — AUTH HOOK
// Firebase Auth (production) + dev_login bypass (dev mode).
// Wires the JWT to the Supabase client for RLS enforcement.
// Auth is Firebase-only. Supabase Auth is banned.

"use client";

import { useState, useEffect, useCallback } from "react";
import { onAuthStateChanged } from "firebase/auth";
import { auth } from "@/lib/firebase";
import { setSupabaseToken } from "@/lib/supabase";

export interface XarkUser {
  uid: string;
  displayName: string;
}

// Dev auto-login: call /api/dev-auto-login with just a username.
// No passwords in the client bundle. Server generates JWT if DEV_MODE=true.
// Returns 404 in production — fails silently, falls back to name-only mode.
async function devAutoLogin(
  username: string
): Promise<{ user: XarkUser; token: string } | null> {
  try {
    const res = await fetch("/api/dev-auto-login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username }),
    });

    if (!res.ok) return null;

    const data = await res.json();
    return {
      user: { uid: data.user.id, displayName: data.user.displayName },
      token: data.token,
    };
  } catch {
    return null;
  }
}

export function useAuth(fallbackName?: string): {
  user: XarkUser | null;
  isAuthenticated: boolean;
  isLoading: boolean;
} {
  const [user, setUser] = useState<XarkUser | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const handleFallback = useCallback(
    async (name: string) => {
      // Try dev login first (gets a real JWT for RLS)
      const result = await devAutoLogin(name);
      if (result) {
        setSupabaseToken(result.token);
        setUser(result.user);
      } else {
        // No dev auth available — use name fallback (no RLS, demo mode)
        setUser({ uid: `name_${name}`, displayName: name });
      }
      setIsLoading(false);
    },
    []
  );

  useEffect(() => {
    // Firebase unconfigured — use dev login or fallback
    if (!auth) {
      if (fallbackName) {
        handleFallback(fallbackName);
      } else {
        setIsLoading(false);
      }
      return;
    }

    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        // Production: get Firebase ID token and set on Supabase
        const token = await firebaseUser.getIdToken();
        setSupabaseToken(token);
        setUser({
          uid: firebaseUser.uid,
          displayName:
            firebaseUser.displayName ??
            firebaseUser.phoneNumber ??
            "anon",
        });
      } else if (fallbackName) {
        await handleFallback(fallbackName);
      } else {
        setSupabaseToken(null);
        setUser(null);
      }
      setIsLoading(false);
    });

    return () => unsubscribe();
  }, [fallbackName, handleFallback]);

  return { user, isAuthenticated: !!user, isLoading };
}
