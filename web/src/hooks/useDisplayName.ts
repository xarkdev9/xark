"use client";

// XARK OS v2.0 — Display Name Resolver (Signal Hybrid Architecture)
// Priority: Local Contact Cache (IndexedDB) → Server display_name → phone fallback.
// The local cache is progressively built from Contact Picker interactions.
// Zero server scraping. Privacy-first.

import { useState, useEffect } from "react";

/**
 * Resolves the best display name for a user.
 * Priority 1: Local IndexedDB contact cache (from Contact Picker interactions)
 * Priority 2: Server-provided display_name
 * Priority 3: Raw phone number (absolute fallback)
 */
export function useDisplayName(
  dbDisplayName: string | null | undefined,
  phone: string | null | undefined
): string {
  const [resolved, setResolved] = useState<string>(
    dbDisplayName || phone || "unknown"
  );

  useEffect(() => {
    if (!phone) {
      setResolved(dbDisplayName || "unknown");
      return;
    }

    const cleanPhone = phone.replace(/\D/g, "").slice(-10);

    // Check local contact cache first
    import("@/lib/crypto/keystore").then(({ keyStore }) => {
      keyStore.getLocalContact(cleanPhone).then((localName) => {
        if (localName) {
          setResolved(localName);
        } else {
          setResolved(dbDisplayName || phone);
        }
      }).catch(() => {
        setResolved(dbDisplayName || phone);
      });
    });
  }, [dbDisplayName, phone]);

  return resolved;
}

/**
 * Non-hook version for use outside React components.
 * Returns a promise.
 */
export async function resolveDisplayName(
  dbDisplayName: string | null | undefined,
  phone: string | null | undefined
): Promise<string> {
  if (!phone) return dbDisplayName || "unknown";

  try {
    const cleanPhone = phone.replace(/\D/g, "").slice(-10);
    const { keyStore } = await import("@/lib/crypto/keystore");
    const localName = await keyStore.getLocalContact(cleanPhone);
    if (localName) return localName;
  } catch {
    // IndexedDB unavailable
  }

  return dbDisplayName || phone;
}
