// XARK OS v2.0 — Offline Service Worker
// Caches app shell for offline launch. Network-first for API + dynamic pages.

const CACHE_NAME = "xark-v1";
const APP_SHELL = [
  "/login",
  "/galaxy",
  "/icons/icon-192.png",
  "/icons/icon-512.png",
  "/manifest.json",
];

// Install: cache app shell
self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL))
  );
  self.skipWaiting();
});

// Activate: clean old caches
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_NAME).map((k) => caches.delete(k)))
    )
  );
  self.clients.claim();
});

// Fetch: network-first for API/dynamic, cache-first for static
self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  // Skip non-GET, API routes, and Supabase/Firebase calls
  if (
    event.request.method !== "GET" ||
    url.pathname.startsWith("/api/") ||
    url.hostname.includes("supabase") ||
    url.hostname.includes("firebase") ||
    url.hostname.includes("googleapis")
  ) {
    return;
  }

  event.respondWith(
    fetch(event.request)
      .then((response) => {
        // Cache successful page navigations
        if (response.ok && event.request.mode === "navigate") {
          const clone = response.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, clone));
        }
        return response;
      })
      .catch(() => {
        // Offline: serve from cache
        return caches.match(event.request).then((cached) => {
          if (cached) return cached;
          // Offline fallback for navigation: serve /login
          if (event.request.mode === "navigate") {
            return caches.match("/login");
          }
          return new Response("offline", { status: 503 });
        });
      })
  );
});
