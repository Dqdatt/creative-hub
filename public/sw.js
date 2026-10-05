/* CreativeHub service worker.
 * - Trang (navigation): mạng trước, mất mạng thì dùng bản index.html đã lưu.
 * - /assets/* (tên file có hash): lấy cache trước.
 * - Font Google, icon, logo: dùng cache rồi cập nhật ngầm.
 * - Supabase và mọi request khác: không can thiệp, luôn đi thẳng ra mạng.
 */
const VERSION = 'v1';
const SHELL_CACHE = `ch-shell-${VERSION}`;
const ASSET_CACHE = `ch-assets-${VERSION}`;
const RUNTIME_CACHE = `ch-runtime-${VERSION}`;
const SHELL_URLS = ['/', '/index.html', '/manifest.webmanifest', '/logo.png', '/icons/icon-192.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(SHELL_CACHE)
      .then((cache) => cache.addAll(SHELL_URLS))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  const keep = new Set([SHELL_CACHE, ASSET_CACHE, RUNTIME_CACHE]);
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => !keep.has(key)).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  );
});

async function networkFirstPage(request) {
  try {
    const response = await fetch(request);
    if (response.ok) {
      const cache = await caches.open(SHELL_CACHE);
      cache.put('/index.html', response.clone());
    }
    return response;
  } catch {
    const cached = await caches.match('/index.html');
    return cached || Response.error();
  }
}

async function cacheFirst(request, cacheName) {
  const cached = await caches.match(request);
  if (cached) return cached;
  const response = await fetch(request);
  if (response.ok) {
    const cache = await caches.open(cacheName);
    cache.put(request, response.clone());
  }
  return response;
}

async function staleWhileRevalidate(request, cacheName) {
  const cache = await caches.open(cacheName);
  const cached = await cache.match(request);
  const network = fetch(request)
    .then((response) => {
      if (response.ok || response.type === 'opaque') cache.put(request, response.clone());
      return response;
    })
    .catch(() => cached);
  return cached || network;
}

self.addEventListener('fetch', (event) => {
  const { request } = event;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);

  if (request.mode === 'navigate' && url.origin === self.location.origin) {
    event.respondWith(networkFirstPage(request));
    return;
  }

  if (url.origin === self.location.origin) {
    if (url.pathname.startsWith('/assets/')) {
      event.respondWith(cacheFirst(request, ASSET_CACHE));
      return;
    }
    if (url.pathname.startsWith('/icons/') || url.pathname === '/logo.png' || url.pathname === '/manifest.webmanifest') {
      event.respondWith(staleWhileRevalidate(request, RUNTIME_CACHE));
    }
    return;
  }

  if (url.hostname === 'fonts.googleapis.com' || url.hostname === 'fonts.gstatic.com') {
    event.respondWith(staleWhileRevalidate(request, RUNTIME_CACHE));
  }
});
