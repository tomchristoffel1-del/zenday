import 'dart:async';
import 'dart:io';
import 'models.dart';
import 'notifications.dart';

/// Prüft periodisch, ob wir uns im konfigurierten Fokus-Zeitfenster befinden,
/// und beendet blockierte Prozesse, falls sie laufen. Windows-only – auf
/// anderen Plattformen ist das eine bewusste No-op (kein Prozess-Kill-Zugriff).
class FocusGuard {
  static const _hostsPath = r'C:\Windows\System32\drivers\etc\hosts';
  static const _markerStart = '# ZenDay-BLOCK-START';
  static const _markerEnd = '# ZenDay-BLOCK-END';

  Timer? _timer;
  final Set<String> _recentlyBlocked = {};
  List<String>? _lastAppliedWebsites;

  void start(Future<FocusConfig> Function() loadConfig) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!Platform.isWindows) return;
      try {
        final config = await loadConfig();
        final active = config.enabled && _isWithinWindow(config);

        if (active) {
          for (final proc in config.blockedProcesses) {
            await _killIfRunning(proc);
          }
          await _applyWebsiteBlocks(config.blockedWebsites);
        } else {
          _recentlyBlocked.clear();
          await _applyWebsiteBlocks(const []);
        }
      } catch (_) {
        // Ein einzelner fehlgeschlagener Tick darf die App nie mitreißen.
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _applyWebsiteBlocks(const []);
  }

  bool _isWithinWindow(FocusConfig config) {
    if (config.startTime == null || config.endTime == null) return true;
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final start = _toMinutes(config.startTime!);
    final end = _toMinutes(config.endTime!);
    if (start == null || end == null) return true;
    if (start <= end) {
      return nowMinutes >= start && nowMinutes < end;
    }
    // Über Mitternacht hinweg (z.B. 22:00 - 02:00).
    return nowMinutes >= start || nowMinutes < end;
  }

  int? _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  Future<void> _killIfRunning(String processName) async {
    try {
      final check = await Process.run(
        'tasklist',
        ['/FI', 'IMAGENAME eq $processName'],
      );
      if (!(check.stdout as String).toLowerCase().contains(processName.toLowerCase())) {
        return;
      }
      await Process.run('taskkill', ['/IM', processName, '/F']);
      if (!_recentlyBlocked.contains(processName)) {
        _recentlyBlocked.add(processName);
        await NotificationService.show('Fokus-Zeit', '$processName wurde blockiert.');
      }
    } catch (_) {
      // Prozess existiert evtl. nicht oder Zugriff verweigert – ignorieren.
    }
  }

  /// Trägt Domains in die hosts-Datei ein (auf 127.0.0.1 umgeleitet), sodass
  /// sie im Browser nicht mehr erreichbar sind. Braucht Admin-Rechte für
  /// ZenDay – ohne die schlägt das still fehl (siehe Hinweis im Fokus-Screen).
  Future<void> _applyWebsiteBlocks(List<String> domains) async {
    if (_lastAppliedWebsites != null &&
        _lastAppliedWebsites!.length == domains.length &&
        _lastAppliedWebsites!.every(domains.contains)) {
      return;
    }
    try {
      final file = File(_hostsPath);
      final lines = await file.readAsLines();
      final kept = <String>[];
      var inBlock = false;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed == _markerStart) {
          inBlock = true;
          continue;
        }
        if (trimmed == _markerEnd) {
          inBlock = false;
          continue;
        }
        if (!inBlock) kept.add(line);
      }
      if (domains.isNotEmpty) {
        kept.add(_markerStart);
        for (final d in domains) {
          kept.add('127.0.0.1 $d');
          kept.add('127.0.0.1 www.$d');
        }
        kept.add(_markerEnd);
      }
      await file.writeAsString('${kept.join('\n')}\n');
      await Process.run('ipconfig', ['/flushdns']);
      _lastAppliedWebsites = domains;
    } catch (_) {
      // Keine Schreibrechte auf die hosts-Datei – ZenDay müsste als
      // Administrator laufen, damit Website-Blocking greift.
    }
  }
}
