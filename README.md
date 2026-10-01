# ZenDay

Ultra-minimalistischer Tagesplaner. Ein Bildschirm, keine Menüs, lokale Speicherung.

## Dateistruktur

```
zenday/
├── pubspec.yaml
└── lib/
    ├── main.dart              # Einstiegspunkt, Theme-Auswahl (hell/dunkel)
    ├── theme.dart              # Farben & Typografie (native Systemschrift, monochrom)
    ├── models.dart             # DayData / TimelineEntry
    ├── storage.dart            # Lokale JSON-Persistenz via SharedPreferences
    ├── home_screen.dart        # Der einzige Screen der App
    └── widgets/
        ├── focus_field.dart    # Tages-Statement oben
        ├── timeline_row.dart   # Eine Zeile der Zeitleiste
        └── habit_dot.dart      # Ein Habit-Punkt unten
```

## Einmalige Einrichtung (Flutter SDK ist auf diesem Rechner nicht installiert)

1. Flutter SDK installieren: https://docs.flutter.dev/get-started/install/windows
2. In diesem Ordner die fehlenden Plattform-Ordner erzeugen (bestehende `lib/` und
   `pubspec.yaml` bleiben dabei erhalten):

   ```bash
   flutter create --platforms=windows,ios,macos .
   ```

3. Abhängigkeiten installieren:

   ```bash
   flutter pub get
   ```

4. Starten:

   ```bash
   flutter run -d windows   # auf Windows
   flutter run -d ios       # in Xcode-Simulator auf macOS, für echtes iPhone: Xcode + Signing nötig
   ```

## Design

- Schriftart: native Systemschrift (SF Pro auf iOS/macOS, Segoe UI Variable auf
  Windows) via `fontFamilyFallback`, viel Weißraum, keine Icons außer feinen
  Kreis-Markern.
- Farben: monochrom, ein einziger Akzentton für "erledigt" – siehe `lib/theme.dart`.
- Kein Menü, kein Tab-Bar, keine zweite Seite. Alles passiert in `HomeScreen`.

## Daten

- Pro Tag ein JSON-Eintrag in `SharedPreferences` (Key `zenday_YYYY-MM-DD`).
- Habit-Namen sind global und änderbar per Long-Press auf den Punkt unten.
- Keine Netzwerkaufrufe, keine Ladezeiten – alles synchron aus dem lokalen Cache
  nach dem ersten `await`.
