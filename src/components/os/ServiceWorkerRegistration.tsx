"use client";

import { useEffect } from "react";

export function ServiceWorkerRegistration() {
  useEffect(() => {
    if (!("serviceWorker" in navigator)) return;
    if (!process.env.NEXT_PUBLIC_FIREBASE_API_KEY) return;

    navigator.serviceWorker
      .register("/firebase-messaging-sw.js")
      .then((reg) => {
        // Wait for the service worker to be active before posting config
        const sw = reg.active || reg.installing || reg.waiting;
        if (!sw) return;

        const sendConfig = () => {
          sw.postMessage({
            type: "FIREBASE_CONFIG",
            config: {
              apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY,
              projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID,
              messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID,
              appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID,
            },
          });
        };

        if (sw.state === "activated") {
          sendConfig();
        } else {
          sw.addEventListener("statechange", () => {
            if (sw.state === "activated") sendConfig();
          });
        }
      })
      .catch(() => {
        // Service worker registration failed — silent fallback
      });
  }, []);

  return null;
}
