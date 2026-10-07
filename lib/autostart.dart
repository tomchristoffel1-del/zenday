import 'platform_info.dart';
import 'dart:io';

/// Trägt ZenDay in den Windows-Autostart ein (HKCU Run-Key), damit
/// Blocklisten auch nach einem Neustart ohne manuelles Öffnen greifen.
class Autostart {
  static const _valueName = 'ZenDay';
  static const _keyPath = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';

  static Future<bool> enable() async {
    if (!isWindowsDesktop) return false;
    try {
      final exePath = Platform.resolvedExecutable;
      final result = await Process.run(
        'reg',
        ['add', _keyPath, '/v', _valueName, '/t', 'REG_SZ', '/d', exePath, '/f'],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> disable() async {
    if (!isWindowsDesktop) return false;
    try {
      final result = await Process.run(
        'reg',
        ['delete', _keyPath, '/v', _valueName, '/f'],
      );
      // Exit code 1 bedeutet meist "Eintrag existiert nicht" – auch ok.
      return result.exitCode == 0 || result.exitCode == 1;
    } catch (_) {
      return false;
    }
  }
}
