'use strict';

// Offline-Zwischenspeicher für ZenDay. Flutters eigener Service Worker ist in
// dieser Flutter-Version nur noch eine Attrappe, deshalb gibt es diesen hier.
//
// Strategie: immer zuerst das Netz (damit Updates sofort da sind). Ist das Netz
// weg oder nach 4 s nicht da, kommt die zuletzt gespeicherte Kopie. Alles, was
// einmal erfolgreich geladen wurde, ist danach auch offline verfügbar.

const CACHE = 'zenday-v1';
const NETWORK_TIMEOUT_MS = 4000;
const CROSS_ORIGIN_HOSTS = ['www.gstatic.com', 'fonts.gstatic.com'];

self.addEventListener('install', () => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(names.filter((n) => n !== CACHE).map((n) => caches.delete(n)));
      await self.clients.claim();
    })(),
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  const sameOrigin = url.origin === self.location.origin;
  // Anfragen an Firebase/Google-APIs (Sync) nie anfassen.
  if (!sameOrigin && !CROSS_ORIGIN_HOSTS.includes(url.hostname)) return;

  event.respondWith(handle(event, req, sameOrigin));
});

async function handle(event, req, sameOrigin) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(req);

  const network = (sameOrigin ? fetch(req.url, { cache: 'no-cache', credentials: 'same-origin' }) : fetch(req)).then(
    async (res) => {
      const cacheable = res.status === 200 && (res.type === 'basic' || res.type === 'cors');
      if (cacheable) await cache.put(req, res.clone()).catch(() => {});
      return res;
    },
  );

  // Erster Besuch dieser Datei: ohne Kopie bleibt nur das Netz.
  if (!cached) {
    return network.catch(() => offlineFallback(req, cache));
  }

  const timeout = new Promise((resolve) => setTimeout(() => resolve(null), NETWORK_TIMEOUT_MS));
  const winner = await Promise.race([network.catch(() => null), timeout]);
  if (winner) return winner;

  // Netz fehlt oder ist zu langsam: gespeicherte Kopie liefern, Update im Hintergrund weiterladen.
  event.waitUntil(network.catch(() => {}));
  return cached;
}

async function offlineFallback(req, cache) {
  if (req.mode === 'navigate') {
    const scope = self.registration.scope;
    const page = (await cache.match(scope)) || (await cache.match(scope + 'index.html'));
    if (page) return page;
  }
  return new Response('Offline', { status: 503, statusText: 'Offline' });
}
