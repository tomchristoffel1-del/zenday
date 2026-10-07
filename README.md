# ZenDay

Minimalistischer Wochenplaner mit Gewohnheits-Tracking und optionalem
Fokus-Modus (App-/Website-Sperren, nur Windows).

**Web-Version (iPhone/iPad/Desktop-Browser):**
https://tomchristoffel1-del.github.io/zenday/

Auf dem iPhone/iPad in Safari öffnen → Teilen-Button → "Zum Home-Bildschirm" →
läuft danach wie eine eigene App, auch offline: `web/sw.js` legt beim ersten Laden
alles in den Offline-Speicher (Flutters eigener Service Worker ist in dieser Version
nur eine Attrappe, deshalb der eigene).

## Plattformen

- **Windows**: natives Desktop-Binary, inkl. Fokus-Modus (Programme/Websites
  blockieren, App-Zeitlimits, Autostart).
- **Web**: läuft überall im Browser, keine Installation nötig. Fokus-Modus ist
  hier bewusst deaktiviert (iOS/Browser erlauben kein App-Blocking) – der Code
  dafür ist trotzdem mit ausgeliefert, tut auf Web/iOS aber nichts.
- **iOS nativ**: Code ist vorbereitet, Build braucht einen Mac mit Xcode
  (Apple-Einschränkung, nicht umgehbar).

## Synchronisierung (PC ↔ Handy)

Die Daten liegen zuerst lokal (offline nutzbar) und werden per Firebase
(Firestore, E-Mail/Passwort-Konto) zwischen den Geräten abgeglichen – inklusive
laufendem Lern-Timer. Änderungen ohne Netz werden vorgemerkt und später nachgeholt.

- Logik: `lib/sync/` (`sync_engine.dart` ist reine Dart-Logik mit Tests in
  `test/sync_engine_test.dart`; `firebase_client.dart` spricht die REST-APIs).
- Pro Schlüssel gewinnt die jüngere Änderung. Lerneinheiten sind einzelne
  Einträge, damit sich zwei Geräte dort nicht überschreiben.
- Beim ersten Abgleich eines Geräts gelten die Cloud-Daten; ersetzte lokale Werte
  werden unter `zenday_sync_backup` gesichert. **Erst am PC anmelden**, wo die echten
  Daten liegen.
- Nicht synchronisiert (geräteabhängig): Fokus-Modus, Blocklisten, App-Limits,
  Designmodus, Autostart.
- Zugangsdaten des Firebase-Projekts: `lib/sync/sync_config.dart`
  (`projectId` und Web-`apiKey`; beide sind bei Firebase-Web-Apps öffentlich).
  Solange sie leer sind, arbeitet die App rein lokal.
- Firestore-Regeln: Zugriff nur auf `users/{uid}/…` für den angemeldeten Nutzer.

## Features

- Wochenplan aus wiederkehrenden Aufgaben (Vorlagen) + Ad-hoc-Einträgen pro Tag
- Aufgaben per Klick bearbeiten, mit Wahl "nur heute" oder "für alle Tage"
- Punkte-/Belohnungssystem mit freischaltbaren Akzentfarben und Dark Mode
- Tägliches Tracking: Stimmung, gesund gegessen, kein Zucker (Sport automatisch
  aus dem "Sport & Training"-Task), Jahresübersicht mit Statistiken
- Fokus-Modus (nur Windows): globale Zeitfenster-Sperre, benannte Blocklisten
  mit Aufgaben verknüpft, Easy/Medium/Hard-Bypass mit Wartezeit, App-Zeitlimits
  unabhängig von Aufgaben

## Entwicklung

Lokale Flutter-SDK-Kopie liegt in `Flutter/` (nicht Teil des Repos, siehe
`.gitignore` – bei Bedarf eigenes Flutter-SDK installieren).

```bash
flutter pub get
flutter run -d windows   # natives Windows-Binary
flutter run -d chrome    # Web-Version lokal testen
```

### Web-Version neu deployen

```bash
flutter build web --release --base-href /zenday/
# build/web nach docs/ kopieren, dann committen & pushen
```

GitHub Pages ist auf `main`-Branch, Ordner `/docs` eingestellt (Repo →
Settings → Pages).

## Design

- Monochrome Palette mit freischaltbaren Akzentfarben, native Systemschrift
  (SF Pro / Segoe UI Variable), viel Weißraum.
- Ein Screen (`planner_screen.dart`), keine tiefen Menüs.

## Daten

- `shared_preferences` (lokal, kein Server). Siehe `lib/storage.dart` für alle
  Keys/Strukturen.
