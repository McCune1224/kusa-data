const CACHE_NAME = "kusa-data-public-v1"
const STATIC_ASSETS = ["/", "/manifest.webmanifest", "/assets/css/app.css", "/assets/js/app.js"]

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_ASSETS)))
  self.skipWaiting()
})

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))))
  )
  self.clients.claim()
})

self.addEventListener("fetch", event => {
  const request = event.request
  const url = new URL(request.url)
  if (request.method !== "GET" || url.origin !== self.location.origin) return
  if (url.pathname.startsWith("/auth") || url.pathname.startsWith("/settings") || url.pathname.startsWith("/your-tournaments") || url.pathname.startsWith("/leagues") || url.pathname.startsWith("/notifications") || url.pathname.startsWith("/api") || url.pathname.startsWith("/feed")) return
  if (request.headers.has("cookie")) return

  event.respondWith(
    caches.match(request).then(cached => cached || fetch(request).then(response => {
      if (response.ok && (url.pathname.startsWith("/tournament/") || url.pathname.startsWith("/player/") || url.pathname === "/")) {
        const copy = response.clone()
        caches.open(CACHE_NAME).then(cache => cache.put(request, copy))
      }
      return response
    }))
  )
})
