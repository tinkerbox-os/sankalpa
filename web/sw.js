// Sankalpa custom service worker.
//
// Replaces the default `flutter_service_worker.js` (we build with
// `--pwa-strategy=none`) so we can add audio caching alongside app-shell
// caching.
//
// Strategy:
//   1. App shell JS/HTML (main.dart.js, flutter.js, index.html, sw):
//      network-first. Stale-while-revalidate was painting yesterday's
//      bundle for a full session after each deploy.
//   2. Other same-origin assets (icons, fonts, manifest):
//      stale-while-revalidate.
//   3. Soundscape audio from Supabase Storage public buckets: cache-first,
//      persistent. Once downloaded, plays offline forever (or until the
//      cache is manually cleared).
//   4. Everything else (Supabase auth/REST, etc.): pass through to network.
//
// APP_CACHE_BUST is rewritten by scripts/deploy.sh on each publish so an
// activate handler drops the previous shell cache immediately.

const APP_CACHE_BUST = 'dev';
const APP_CACHE = `sankalpa-app-${APP_CACHE_BUST}`;
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

  if (url.origin !== self.location.origin) return;

  // 2. App shell that must track deploys: network-first.
  if (isAppShell(url)) {
    event.respondWith(networkFirst(req));
    return;
  }

  // 3. Other same-origin assets: stale-while-revalidate.
  event.respondWith(staleWhileRevalidate(req));
});

function isAppShell(url) {
  const path = url.pathname;
  return (
    path.endsWith('/') ||
    path.endsWith('/index.html') ||
    path.endsWith('/main.dart.js') ||
    path.endsWith('/flutter.js') ||
    path.endsWith('/flutter_bootstrap.js') ||
    path.endsWith('/sw.js') ||
    path.endsWith('.js')
  );
}

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

async function networkFirst(request) {
  const cache = await caches.open(APP_CACHE);
  try {
    const resp = await fetch(request);
    if (resp && resp.ok) {
      cache.put(request, resp.clone()).catch(() => {});
    }
    return resp;
  } catch (_) {
    const cached = await cache.match(request);
    if (cached) return cached;
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
