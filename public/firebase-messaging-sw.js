// XARK OS v2.0 — FCM Background Notifications
// Config injected via postMessage from main thread on registration.

importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js");

let messagingInitialized = false;

// Receive Firebase config from main thread
self.addEventListener("message", (event) => {
  if (event.data?.type === "FIREBASE_CONFIG" && !messagingInitialized) {
    firebase.initializeApp(event.data.config);
    const messaging = firebase.messaging();

    messaging.onBackgroundMessage((payload) => {
      const { title, body, spaceId } = payload.data || {};
      self.registration.showNotification(title || "xark", {
        body: body || "",
        icon: "/icons/icon-192.png",
        data: { url: `/space/${spaceId}` },
      });
    });

    messagingInitialized = true;
  }
});

self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = event.notification.data?.url || "/galaxy";
  event.waitUntil(clients.openWindow(url));
});
