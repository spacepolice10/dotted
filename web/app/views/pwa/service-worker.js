// Caches only public, fingerprinted static files. Pages, JSON, Turbo streams and
// Active Storage blobs hold per-user data and must never be stored here.
const CACHE_VERSION = "dotted-static-v1"
const PRECACHE_URLS = [
  "/offline.html",
  "/icon.png",
  "/icon-192.png",
  "/apple-touch-icon.png"
]
const CACHEABLE_DESTINATIONS = ["style", "script", "font"]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll(PRECACHE_URLS))
  )
  self.skipWaiting()
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(
      keys.filter((key) => key.startsWith("dotted-") && key !== CACHE_VERSION).map((key) => caches.delete(key))
    ))
  )
  self.clients.claim()
})

self.addEventListener("fetch", (event) => {
  const request = event.request

  if (request.method !== "GET") return

  if (request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match("/offline.html")))
    return
  }

  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return
  if (!url.pathname.startsWith("/assets/")) return
  if (!CACHEABLE_DESTINATIONS.includes(request.destination)) return

  event.respondWith(
    caches.match(request).then((cached) => cached || fetch(request).then((response) => {
      if (response.ok) {
        const copy = response.clone()
        caches.open(CACHE_VERSION).then((cache) => cache.put(request, copy))
      }
      return response
    }))
  )
})
