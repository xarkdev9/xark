// XARK OS v2.0 — Offline Service Worker
// Caches app shell for offline launch. Network-first for API + dynamic pages.
// Intercepts PWA share target POSTs to keep files client-side (E2EE pipeline).

const CACHE_NAME = "hello-v5";
const SHARE_CACHE = "hello-shared-files";
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

// Activate: clean old caches (preserve share cache)
self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(
        keys
          .filter((k) => k !== CACHE_NAME && k !== SHARE_CACHE)
          .map((k) => caches.delete(k))
      )
    )
  );
  self.clients.claim();
});

// Fetch: intercept share target POST, then network-first for pages
self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);

  // ── SHARE TARGET INTERCEPTOR ──
  // When Android shares a file to xark, the browser sends a POST to /_share-target.
  // We intercept it HERE in the service worker so the raw file never touches the server.
  // The file is stashed in CacheStorage, and the client reads it for E2EE encryption.
  if (event.request.method === "POST" && url.pathname === "/_share-target") {
    event.respondWith(
      (async () => {
        try {
          const formData = await event.request.formData();
          const file = formData.get("shared_file");
          const title = formData.get("title") || "";
          const text = formData.get("text") || "";
          const sharedUrl = formData.get("url") || "";

          if (file && file instanceof File) {
            // Stash the file in CacheStorage for the client to read
            const cache = await caches.open(SHARE_CACHE);
            const response = new Response(file, {
              headers: {
                "Content-Type": file.type || "application/octet-stream",
                "X-Filename": encodeURIComponent(file.name || "shared.jpg"),
              },
            });
            await cache.put("/shared-image", response);

            // Redirect to share page with file flag
            const params = new URLSearchParams();
            params.set("has_local_file", "true");
            if (title) params.set("title", title);
            if (text) params.set("text", text);
            return Response.redirect(`/share?${params.toString()}`, 303);
          }

          // No file — fall back to URL/text share
          const params = new URLSearchParams();
          if (title) params.set("title", title);
          if (text) params.set("text", text);
          if (sharedUrl) params.set("url", sharedUrl);
          return Response.redirect(`/share?${params.toString()}`, 303);
        } catch (err) {
          // On any error, redirect to galaxy
          return Response.redirect("/galaxy", 303);
        }
      })()
    );
    return;
  }

  // Skip non-GET, API routes, and all external service calls
  if (
    event.request.method !== "GET" ||
    url.pathname.startsWith("/api/") ||
    url.hostname !== self.location.hostname
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
