import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'theme.dart';

/// Gemeinsame Logik zum Auswählen eines Windows-Programms – laufende
/// Fenster oder installierte Software – mit Suchleiste. Wird sowohl vom
/// einfachen Fokus-Modus als auch von den benannten Blocklisten genutzt.
class AppPicker {
  static Future<List<Map<String, String>>> loadRunningApps() async {
    if (!Platform.isWindows) return [];
    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "Get-Process | Where-Object { \$_.MainWindowTitle -ne '' } | "
            "Select-Object ProcessName, MainWindowTitle | ConvertTo-Json -Compress",
      ]);
      final out = (result.stdout as String).trim();
      if (out.isEmpty) return [];
      final decoded = jsonDecode(out);
      final list = decoded is List ? decoded : [decoded];
      final seen = <String>{};
      final apps = <Map<String, String>>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final process = map['ProcessName'] as String? ?? '';
        final title = map['MainWindowTitle'] as String? ?? process;
        if (process.isEmpty || process.toLowerCase() == 'zenday') continue;
        if (!seen.add(process.toLowerCase())) continue;
        apps.add({'process': process, 'title': title});
      }
      apps.sort((a, b) => a['title']!.toLowerCase().compareTo(b['title']!.toLowerCase()));
      return apps;
    } catch (_) {
      return [];
    }
  }

  static Future<List<Map<String, String>>> loadInstalledApps() async {
    if (!Platform.isWindows) return [];
    try {
      const script = r'''
$paths = @(
  'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
  'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
)
Get-ItemProperty $paths -ErrorAction SilentlyContinue |
  Where-Object { $_.DisplayName -and $_.DisplayName.Trim() -ne '' } |
  Select-Object DisplayName, DisplayIcon |
  ConvertTo-Json -Compress
''';
      final result = await Process.run('powershell', ['-NoProfile', '-Command', script]);
      final out = (result.stdout as String).trim();
      if (out.isEmpty) return [];
      final decoded = jsonDecode(out);
      final list = decoded is List ? decoded : [decoded];
      final seen = <String>{};
      final apps = <Map<String, String>>[];
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final name = (map['DisplayName'] as String?)?.trim() ?? '';
        if (name.isEmpty || !seen.add(name.toLowerCase())) continue;
        var exe = '';
        final icon = map['DisplayIcon'] as String?;
        if (icon != null && icon.isNotEmpty) {
          final path = icon.split(',').first.trim().replaceAll('"', '');
          if (path.toLowerCase().endsWith('.exe')) {
            exe = path.split(RegExp(r'[\\/]')).last;
          }
        }
        apps.add({'name': name, 'exe': exe});
      }
      apps.sort((a, b) => a['name']!.toLowerCase().compareTo(b['name']!.toLowerCase()));
      return apps;
    } catch (_) {
      return [];
    }
  }

  /// Zeigt eine durchsuchbare Bottom-Sheet-Liste und liefert den gewählten
  /// Programmnamen (z. B. "chrome.exe") zurück, oder null bei Abbruch.
  static Future<String?> showSheet(
    BuildContext context, {
    required List<Map<String, String>> apps,
    required String Function(Map<String, String>) title,
    required String Function(Map<String, String>) subtitle,
    required String? Function(Map<String, String>) exe,
    required String emptyText,
  }) async {
    final colors = Theme.of(context).extension<ZenTheme>()!.colors;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        if (apps.isEmpty) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(emptyText, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
            ),
          );
        }
        var query = '';
        return SafeArea(
          child: StatefulBuilder(
            builder: (ctx, setFilterState) {
              final visible =
                  apps.where((a) => title(a).toLowerCase().contains(query.toLowerCase())).toList();
              return ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: TextField(
                        autofocus: true,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Suchen…',
                          hintStyle: TextStyle(color: colors.textTertiary),
                          prefixIcon: Icon(Icons.search, size: 18, color: colors.textTertiary),
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: colors.divider),
                          ),
                        ),
                        onChanged: (v) => setFilterState(() => query = v),
                      ),
                    ),
                    Flexible(
                      child: visible.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text('Nichts gefunden.',
                                  style: TextStyle(color: colors.textTertiary, fontSize: 13)),
                            )
                          : ListView(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              children: visible.map((app) {
                                final exeName = exe(app);
                                return ListTile(
                                  title: Text(title(app),
                                      style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                                  subtitle: Text(subtitle(app),
                                      style: TextStyle(color: colors.textTertiary, fontSize: 12)),
                                  enabled: exeName != null,
                                  onTap: exeName == null ? null : () => Navigator.pop(ctx, exeName),
                                );
                              }).toList(),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Future<String?> pickRunningProcess(BuildContext context) async {
    final apps = await loadRunningApps();
    if (!context.mounted) return null;
    return showSheet(
      context,
      apps: apps,
      title: (a) => a['title']!,
      subtitle: (a) => '${a['process']}.exe',
      exe: (a) => '${a['process']}.exe',
      emptyText: Platform.isWindows
          ? 'Keine laufenden Programme mit offenem Fenster gefunden.'
          : 'Programm-Auswahl ist nur unter Windows verfügbar.',
    );
  }

  static Future<String?> pickInstalledApp(BuildContext context) async {
    final apps = await loadInstalledApps();
    if (!context.mounted) return null;
    return showSheet(
      context,
      apps: apps,
      title: (a) => a['name']!,
      subtitle: (a) => a['exe']!.isEmpty ? 'Programmdatei unbekannt' : a['exe']!,
      exe: (a) => a['exe']!.isEmpty ? null : a['exe']!,
      emptyText: Platform.isWindows
          ? 'Keine installierten Programme gefunden.'
          : 'Programm-Auswahl ist nur unter Windows verfügbar.',
    );
  }
}
