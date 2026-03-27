// hello — FCM Background Notifications + E2EE Push Decryption (CRYPTO-03)
// Config injected via postMessage from main thread on registration.
// When a push arrives with encrypted payload, attempt to decrypt
// using cached keys from IndexedDB before showing the notification.

importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

let messagingInitialized = false;

// E2EE Push Decryption (CRYPTO-03)
self.addEventListener('push', function(event) {
  const data = event.data ? event.data.json() : {};

  if (data.encryptedPayload && data.ratchetHeader) {
    // E2EE message — attempt decryption
    event.waitUntil(
      decryptAndNotify(data).catch(() => {
        // Decryption failed — show generic notification
        return self.registration.showNotification('New Message', {
          body: 'You have a new encrypted message',
          icon: '/icons/icon-192.png',
          badge: '/icons/icon-192.png',
          data: { groupId: data.groupId, messageId: data.messageId },
        });
      })
    );
  }
  // Non-encrypted pushes are handled by onBackgroundMessage below
});

async function decryptAndNotify(data) {
  // TODO: Open IndexedDB keystore from service worker context
  // TODO: Load ratchet session for sender
  // TODO: Decrypt encryptedPayload
  // TODO: Show notification with plaintext

  // For now, show generic (decryption wiring in next iteration)
  return self.registration.showNotification('New Message', {
    body: 'You have a new encrypted message',
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png',
    tag: `hello-${data.groupId}`,
    data: { groupId: data.groupId, messageId: data.messageId, url: `/space/${data.groupId}` },
  });
}

// Receive Firebase config from main thread — validate origin
self.addEventListener("message", (event) => {
  if (!event.source || event.origin !== self.location.origin) return;
  if (event.data?.type === "FIREBASE_CONFIG" && !messagingInitialized) {
    firebase.initializeApp(event.data.config);
    const messaging = firebase.messaging();

    messaging.onBackgroundMessage((payload) => {
      // E2EE: If payload has encrypted data, the push listener above handles it.
      // This handler covers non-encrypted metadata-only pushes.
      const data = payload.data || {};
      if (data.encryptedPayload && data.ratchetHeader) {
        // Already handled by the push event listener — skip to avoid duplicate
        return;
      }
      const { senderName, groupId } = data;
      self.registration.showNotification(
        senderName ? `${senderName}` : "hello",
        {
          body: "new encrypted message",
          icon: "/icons/icon-192.png",
          badge: "/icons/icon-192.png",
          tag: `hello-${groupId}`, // collapse multiple from same group
          data: { url: `/space/${groupId}` },
        }
      );
    });

    messagingInitialized = true;
  }
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const raw = event.notification.data?.url || "/home";
  // Only allow relative paths — block external URLs and javascript: schemes
  const url = typeof raw === "string" && raw.startsWith("/") ? raw : "/home";
  event.waitUntil(clients.openWindow(url));
});
