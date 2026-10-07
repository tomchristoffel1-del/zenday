{{flutter_js}}
{{flutter_build_config}}

// Bewusst ohne serviceWorkerSettings: Flutters eigener Service Worker ist in dieser
// Version eine Attrappe, die sich selbst abmeldet. Stattdessen läuft sw.js.
_flutter.loader.load();

// Muss zu sw.js passen.
const ZENDAY_CACHE = 'zenday-v1';
const ZENDAY_CROSS_ORIGIN_HOSTS = ['www.gstatic.com', 'fonts.gstatic.com'];
let zendayWarmedUp = false;

// Beim allerersten Besuch lief noch nichts über den Service Worker. Deshalb alles, was die
// Seite bis jetzt geladen hat (kommt aus dem Browser-Cache, kein zweiter Download), einmal
// in den Offline-Speicher legen. Danach pflegt sw.js den Speicher selbst.
async function zendayWarmUpOfflineCache() {
  if (zendayWarmedUp) return;
  zendayWarmedUp = true;
  try {
    await navigator.serviceWorker.ready;
    const cache = await caches.open(ZENDAY_CACHE);
    const wanted = new Set([location.href.split('#')[0]]);
    for (const entry of performance.getEntriesByType('resource')) {
      const url = new URL(entry.name);
      if (url.origin === location.origin || ZENDAY_CROSS_ORIGIN_HOSTS.includes(url.hostname)) wanted.add(entry.name);
    }
    await Promise.all(
      [...wanted].map(async (url) => {
        if (await cache.match(url)) return;
        try {
          const res = await fetch(url);
          if (res.status === 200) await cache.put(url, res);
        } catch (_) {
          // Einzelne Datei nicht ladbar: egal, der Service Worker holt sie beim nächsten Besuch nach.
        }
      }),
    );
  } catch (_) {
    // Kein Service Worker verfügbar (z. B. privater Modus): App läuft normal, nur ohne Offline-Start.
  }
}

function zendayRegisterServiceWorker() {
  if (!('serviceWorker' in navigator)) return;
  navigator.serviceWorker.register('sw.js').catch((e) => console.warn('Service Worker nicht registriert:', e));
  window.addEventListener('flutter-first-frame', () => setTimeout(zendayWarmUpOfflineCache, 1500), { once: true });
  setTimeout(zendayWarmUpOfflineCache, 15000);
}

if (document.readyState === 'complete') {
  zendayRegisterServiceWorker();
} else {
  window.addEventListener('load', zendayRegisterServiceWorker);
}
