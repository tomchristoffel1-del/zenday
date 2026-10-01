# ZenDay

Minimalistischer Wochenplaner mit Gewohnheits-Tracking und optionalem
Fokus-Modus (App-/Website-Sperren, nur Windows).

**Web-Version (iPhone/iPad/Desktop-Browser):**
https://tomchristoffel1-del.github.io/zenday/

Auf dem iPhone/iPad in Safari öffnen → Teilen-Button → "Zum Home-Bildschirm" →
läuft danach wie eine eigene App, auch offline (Service Worker cached alles
beim ersten Laden).

## Plattformen

- **Windows**: natives Desktop-Binary, inkl. Fokus-Modus (Programme/Websites
  blockieren, App-Zeitlimits, Autostart).
- **Web**: läuft überall im Browser, keine Installation nötig. Fokus-Modus ist
  hier bewusst deaktiviert (iOS/Browser erlauben kein App-Blocking) – der Code
  dafür ist trotzdem mit ausgeliefert, tut auf Web/iOS aber nichts.
- **iOS nativ**: Code ist vorbereitet, Build braucht einen Mac mit Xcode
  (Apple-Einschränkung, nicht umgehbar).

**Wichtig:** Jede Plattform speichert ihre Daten getrennt (kein Sync). Die
Windows-App und die Web-Version auf dem iPhone sind zwei unabhängige
Datenstände.

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
