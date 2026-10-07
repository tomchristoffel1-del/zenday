import 'platform_info.dart';
import 'dart:async';
import 'dart:io';
import 'notifications.dart';
import 'storage.dart';

DateTime _atMidnight(DateTime d) => DateTime(d.year, d.month, d.day);

/// Setzt von Aufgaben unabhängige App-Regeln durch: dauerhaft gesperrte
/// Programme, und tägliche Zeitbudgets (wie Bildschirmzeit-Limits). Läuft
/// parallel zu FocusGuard, unabhängig von Zeitfenstern oder Aufgaben.
class UsageGuard {
  Timer? _timer;
  final ZenStorage _storage;
  final Set<String> _recentlyBlocked = {};

  UsageGuard(this._storage);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!isWindowsDesktop) return;
      try {
        await _tick();
      } catch (_) {
        // Ein einzelner fehlgeschlagener Tick darf die App nie mitreißen.
      }
    });
  }

  void stop() => _timer?.cancel();

  Future<void> _tick() async {
    final limits = await _storage.loadAppLimits();
    if (limits.isEmpty) return;

    final today = _atMidnight(DateTime.now());
    final usage = await _storage.loadUsageToday(today);
    var usageChanged = false;

    for (final limit in limits) {
      final running = await _isRunning(limit.process);
      if (!running) {
        _recentlyBlocked.remove(limit.process);
        continue;
      }

      if (limit.alwaysBlocked) {
        await _kill(limit.process, 'ist dauerhaft gesperrt.');
        continue;
      }

      if (limit.dailyMinutes != null) {
        final used = (usage[limit.process] ?? 0) + 5;
        usage[limit.process] = used;
        usageChanged = true;
        if (used >= limit.dailyMinutes! * 60) {
          await _kill(limit.process, 'Tageslimit erreicht.');
        }
      }
    }

    if (usageChanged) {
      await _storage.saveUsageToday(today, usage);
    }
  }

  Future<bool> _isRunning(String processName) async {
    try {
      final check = await Process.run('tasklist', ['/FI', 'IMAGENAME eq $processName']);
      return (check.stdout as String).toLowerCase().contains(processName.toLowerCase());
    } catch (_) {
      return false;
    }
  }

  Future<void> _kill(String processName, String reason) async {
    try {
      await Process.run('taskkill', ['/IM', processName, '/F']);
      if (!_recentlyBlocked.contains(processName)) {
        _recentlyBlocked.add(processName);
        await NotificationService.show(processName, reason);
      }
    } catch (_) {
      // Prozess evtl. schon beendet oder Zugriff verweigert – ignorieren.
    }
  }
}
