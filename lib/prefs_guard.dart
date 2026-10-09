import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'platform_info.dart';

/// Schützt die lokale Datendatei unter Windows.
///
/// shared_preferences schreibt die Datei direkt (nicht atomar). Geht der PC beim
/// Speichern aus, bleibt eine Datei voller Null-Bytes zurück, und ohne Schutz
/// startet die App danach nicht mehr. Deshalb:
/// - vor dem Start: kaputte Datei beiseitelegen und die letzte gute Sicherung einspielen,
/// - im Betrieb: regelmäßig Sicherungen schreiben (atomar: temp-Datei + Umbenennen).
class PrefsGuard {
  PrefsGuard._();

  static const _keepDailyBackups = 14;
  static const _backupInterval = Duration(minutes: 10);
  static Timer? _timer;

  static Directory? get _dir {
    final appData = Platform.environment['APPDATA'];
    if (appData == null) return null;
    return Directory('$appData\\com.example\\zenday');
  }

  static File? get _prefsFile => _dir == null ? null : File('${_dir!.path}\\shared_preferences.json');
  static Directory? get _backupDir => _dir == null ? null : Directory('${_dir!.path}\\backups');

  /// Liefert den Inhalt, wenn die Datei ein gültiges JSON-Objekt ist, sonst null.
  static String? _validContent(File f) {
    try {
      if (!f.existsSync()) return null;
      final s = f.readAsStringSync();
      return jsonDecode(s) is Map ? s : null;
    } catch (_) {
      return null;
    }
  }

  static String _stamp(DateTime t) =>
      '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

  /// Vor dem ersten Zugriff auf SharedPreferences aufrufen. Wirft nie.
  static void repairBeforeStart() {
    if (!isWindowsDesktop) return;
    try {
      final file = _prefsFile;
      if (file == null || !file.existsSync()) return;
      if (_validContent(file) != null) return;

      final now = DateTime.now();
      final corrupt = '${file.path}.corrupt-${now.millisecondsSinceEpoch}';
      file.renameSync(corrupt);
      debugPrint('PrefsGuard: beschädigte Datendatei nach $corrupt verschoben');

      final backup = _newestValidBackup();
      if (backup != null) {
        backup.copySync(file.path);
        debugPrint('PrefsGuard: Sicherung ${backup.path} eingespielt');
      }
      // Ohne Sicherung startet die App leer; nach der Anmeldung kommen die Daten aus der Cloud.
    } catch (e) {
      debugPrint('PrefsGuard: Reparatur fehlgeschlagen: $e');
    }
  }

  static File? _newestValidBackup() {
    final dir = _backupDir;
    if (dir == null || !dir.existsSync()) return null;
    final files = dir.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    for (final f in files) {
      if (_validContent(f) != null) return f;
    }
    return null;
  }

  /// Nach erfolgreichem Start: sofort sichern und danach alle 10 Minuten.
  static void startBackups() {
    if (!isWindowsDesktop) return;
    backupNow();
    _timer ??= Timer.periodic(_backupInterval, (_) => backupNow());
  }

  static void backupNow() {
    try {
      final file = _prefsFile;
      final dir = _backupDir;
      if (file == null || dir == null) return;
      final content = _validContent(file);
      if (content == null) return; // nie eine kaputte Datei über eine gute Sicherung schreiben

      dir.createSync(recursive: true);
      _writeAtomic(File('${dir.path}\\latest.json'), content);
      _writeAtomic(File('${dir.path}\\${_stamp(DateTime.now())}.json'), content);
      _pruneDaily(dir);
    } catch (e) {
      debugPrint('PrefsGuard: Sicherung fehlgeschlagen: $e');
    }
  }

  static void _writeAtomic(File target, String content) {
    final tmp = File('${target.path}.tmp');
    final raf = tmp.openSync(mode: FileMode.write);
    try {
      raf.writeStringSync(content);
      raf.flushSync();
    } finally {
      raf.closeSync();
    }
    tmp.renameSync(target.path);
  }

  static void _pruneDaily(Directory dir) {
    final daily = dir
        .listSync()
        .whereType<File>()
        .where((f) => RegExp(r'\d{4}-\d{2}-\d{2}\.json$').hasMatch(f.path))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final f in daily.skip(_keepDailyBackups)) {
      f.deleteSync();
    }
  }
}
