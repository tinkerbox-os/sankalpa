// Sankalpa custom service worker.
//
// Replaces the default `flutter_service_worker.js` (we build with
// `--pwa-strategy=none`) so we can add audio caching alongside app-shell
// caching.
//
// Strategy:
//   1. Same-origin requests (Flutter app shell, manifest, icons):
//      stale-while-revalidate. The cached version paints instantly; the
//      network response refreshes the cache for next time.
//   2. Soundscape audio from Supabase Storage public buckets: cache-first,
//      persistent. Once downloaded, plays offline forever (or until the
//      cache is manually cleared).
//   3. Everything else (Supabase auth/REST, etc.): pass through to network.

const APP_CACHE = 'sankalpa-app-v2';
const AUDIO_CACHE = 'sankalpa-audio-v1';
const KEEP_CACHES = [APP_CACHE, AUDIO_CACHE];

self.addEventListener('install', (event) => {
  // Activate new SW immediately on next page load instead of waiting for
  // all tabs to close.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(
      names
        .filter((n) => !KEEP_CACHES.includes(n))
        .map((n) => caches.delete(n)),
    );
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  let url;
  try {
    url = new URL(req.url);
  } catch (_) {
    return;
  }

  // 1. Soundscape audio: cache-first, persistent.
  const isSupabaseStorage =
    url.hostname.endsWith('.supabase.co') &&
    url.pathname.startsWith('/storage/v1/object/public/');
  if (isSupabaseStorage) {
    event.respondWith(audioCacheFirst(req));
    return;
  }

  // 2. Same-origin app files: stale-while-revalidate.
  if (url.origin === self.location.origin) {
    event.respondWith(staleWhileRevalidate(req));
    return;
  }

  // 3. Everything else: pass through.
});

async function audioCacheFirst(request) {
  const cache = await caches.open(AUDIO_CACHE);
  const hit = await cache.match(request);
  if (hit) return hit;
  try {
    const resp = await fetch(request);
    // 200 (full) and 206 (range) — only cache full bodies; many audio
    // elements emit Range requests we don't want to persist as the whole
    // file. If we got 206, fall through and let the browser stitch.
    if (resp.ok && resp.status === 200) {
      cache.put(request, resp.clone()).catch(() => {});
    }
    return resp;
  } catch (e) {
    // Offline + not in cache: surface a synthetic error response so the
    // <audio> element fails gracefully instead of hanging.
    return new Response(null, { status: 504, statusText: 'Offline' });
  }
}

async function staleWhileRevalidate(request) {
  const cache = await caches.open(APP_CACHE);
  const cached = await cache.match(request);
  const networkPromise = fetch(request)
    .then((resp) => {
      if (resp && resp.ok) cache.put(request, resp.clone()).catch(() => {});
      return resp;
    })
    .catch(() => cached);
  return cached || networkPromise;
}

// Allow page to ask "are you ready?" — used by the install prompt UI.
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});
