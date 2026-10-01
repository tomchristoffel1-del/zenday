import 'package:flutter/material.dart';
import 'accent_options.dart';
import 'storage.dart';

/// Globaler, freischaltbarer Theme-Zustand. Hell ist immer verfügbar;
/// Dunkel wird ab einer bestimmten Punktzahl manuell umschaltbar. Die
/// Akzentfarbe ist die eigentliche Belohnung fürs Punktesammeln.
class AppSettings {
  static const darkModeUnlockPoints = 4;
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier(ThemeMode.light);
  static final ValueNotifier<int> accentIndex = ValueNotifier(0);

  static Future<void> load(ZenStorage storage) async {
    final savedMode = await storage.loadThemeModePref();
    themeMode.value = savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
    accentIndex.value = await storage.loadAccentIndex();
  }

  static Future<void> toggle(ZenStorage storage) async {
    final next = themeMode.value == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    themeMode.value = next;
    await storage.saveThemeModePref(next == ThemeMode.dark ? 'dark' : 'light');
  }

  static Future<void> setAccent(ZenStorage storage, int index) async {
    if (index < 0 || index >= accentOptions.length) return;
    accentIndex.value = index;
    await storage.saveAccentIndex(index);
  }
}
