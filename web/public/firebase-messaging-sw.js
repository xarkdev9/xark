// XARK OS v2.0 — FCM Background Notifications
// Config injected via postMessage from main thread on registration.

importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

let messagingInitialized = false;

// Receive Firebase config from main thread — validate origin
self.addEventListener("message", (event) => {
  if (!event.source || event.origin !== self.location.origin) return;
  if (event.data?.type === "FIREBASE_CONFIG" && !messagingInitialized) {
    firebase.initializeApp(event.data.config);
    const messaging = firebase.messaging();

    messaging.onBackgroundMessage((payload) => {
      // E2EE COMPLIANT: payload.data contains ONLY metadata (senderName, spaceId, event).
      // NEVER plaintext message content. Decryption happens on app open.
      const { senderName, spaceId } = payload.data || {};
      self.registration.showNotification(
        senderName ? `${senderName}` : "xark",
        {
          body: "new encrypted message",
          icon: "/icons/icon-192.png",
          badge: "/icons/icon-192.png",
          tag: `hello-${spaceId}`, // collapse multiple from same space
          data: { url: `/space/${spaceId}` },
        }
      );
    });

    messagingInitialized = true;
  }
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const raw = event.notification.data?.url || "/galaxy";
  // Only allow relative paths — block external URLs and javascript: schemes
  const url = typeof raw === "string" && raw.startsWith("/") ? raw : "/galaxy";
  event.waitUntil(clients.openWindow(url));
});
