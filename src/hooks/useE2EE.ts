// XARK OS v2.0 — E2EE Hook
// Manages E2EE lifecycle: init, key registration, encrypt/decrypt.
// Gracefully degrades to legacy mode if migration 014 not applied.

"use client";

import { useState, useEffect, useCallback, useRef } from "react";
import type { EncryptedEnvelope } from "@/lib/crypto/encryption-service";
import type { DecryptedMessage } from "@/lib/crypto/types";

export interface E2EEState {
  ready: boolean;       // crypto initialized (may still be unavailable)
  available: boolean;   // keys registered, tables exist
  deviceId: number | null;
}

export function useE2EE(userId: string | null): E2EEState & {
  encrypt: (text: string, spaceId: string) => Promise<EncryptedEnvelope | null>;
  decrypt: (
    messageId: string,
    senderId: string,
    senderDeviceId: number | null,
    ciphertextB64: string,
    ratchetHeaderB64: string | null,
    recipientId: string,
    spaceId: string
  ) => Promise<DecryptedMessage | null>;
} {
  const [state, setState] = useState<E2EEState>({
    ready: false,
    available: false,
    deviceId: null,
  });
  const initRef = useRef(false);

  useEffect(() => {
    if (!userId || initRef.current) return;
    initRef.current = true;

    async function init() {
      try {
        // BUG 1 fix: wait for JWT with exponential backoff before key registration
        const { getSupabaseToken } = await import("@/lib/supabase");
        let retries = 0;
        const maxRetries = 8;
        while (!getSupabaseToken() && retries < maxRetries) {
          const delay = Math.min(500 * Math.pow(2, retries), 4000);
          await new Promise(r => setTimeout(r, delay));
          retries++;
        }
        if (!getSupabaseToken()) {
          console.error("[xark-e2ee] No JWT after retries — E2EE unavailable");
          setState({ ready: true, available: false, deviceId: null });
          return;
        }
        if (retries > 0) {
          console.log(`[xark-e2ee] JWT ready after ${retries} retries`);
        }

        // Dynamic imports — avoid SSR issues with WASM (libsodium)
        const { initCrypto } = await import("@/lib/crypto/primitives");
        const { hasRegisteredKeys, registerKeys, replenishOTKsIfNeeded } =
          await import("@/lib/crypto/key-manager");
        const { keyStore } = await import("@/lib/crypto/keystore");

        await initCrypto();

        const hasKeys = await hasRegisteredKeys();
        if (!hasKeys) {
          try {
            const { deviceId } = await registerKeys();
            setState({ ready: true, available: true, deviceId });
            return;
          } catch (err) {
            // Migration 014 not applied — E2EE tables don't exist yet
            console.warn("[xark-e2ee] Key registration failed:", err);
            setState({ ready: true, available: false, deviceId: null });
            return;
          }
        }

        // Already registered — E2EE fully wired
        const deviceId = await keyStore.getDeviceId();
        setState({ ready: true, available: true, deviceId });

        // Replenish OTKs in background (fire-and-forget)
        replenishOTKsIfNeeded().catch(() => {});
      } catch (err) {
        console.warn("[xark-e2ee] Init failed:", err);
        setState({ ready: true, available: false, deviceId: null });
      }
    }

    init();
  }, [userId]);

  const encrypt = useCallback(
    async (text: string, spaceId: string): Promise<EncryptedEnvelope | null> => {
      if (!state.available) return null;
      try {
        const { encryptForSpace } = await import(
          "@/lib/crypto/encryption-service"
        );
        return await encryptForSpace(text, spaceId);
      } catch (err) {
        console.warn("[xark-e2ee] Encrypt failed:", err);
        return null;
      }
    },
    [state.available]
  );

  const decrypt = useCallback(
    async (
      messageId: string,
      senderId: string,
      senderDeviceId: number | null,
      ciphertextB64: string,
      ratchetHeaderB64: string | null,
      recipientId: string,
      spaceId: string
    ): Promise<DecryptedMessage | null> => {
      if (!state.available) return null;
      try {
        const { decryptMessage } = await import(
          "@/lib/crypto/encryption-service"
        );
        return await decryptMessage(
          messageId,
          senderId,
          senderDeviceId,
          ciphertextB64,
          ratchetHeaderB64,
          recipientId,
          spaceId
        );
      } catch (err) {
        console.warn("[xark-e2ee] Decrypt failed:", err);
        return null;
      }
    },
    [state.available]
  );

  return { ...state, encrypt, decrypt };
}
