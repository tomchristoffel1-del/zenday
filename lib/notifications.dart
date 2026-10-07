import 'platform_info.dart';
import 'dart:io';

/// Desktop-Benachrichtigungen ohne zusätzliches Plugin: ruft den nativen
/// Windows-Toast direkt über PowerShell/WinRT auf. Funktioniert nur, während
/// ZenDay läuft – es gibt (bewusst, um keine Systemdienste zu benötigen)
/// keinen Hintergrunddienst, der die App-geschlossen-Erinnerung übernimmt.
class NotificationService {
  static String _escape(String s) => s.replaceAll("'", "''");

  static Future<void> show(String title, String body) async {
    if (!isWindowsDesktop) return;
    final script = '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
\$xml = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
\$text = \$xml.GetElementsByTagName('text')
\$text.Item(0).AppendChild(\$xml.CreateTextNode('${_escape(title)}')) | Out-Null
\$text.Item(1).AppendChild(\$xml.CreateTextNode('${_escape(body)}')) | Out-Null
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('ZenDay').Show(\$toast)
''';
    try {
      await Process.run(
        'powershell',
        ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', script],
      );
    } catch (_) {
      // Benachrichtigung ist ein Extra, kein kritischer Pfad – still ignorieren.
    }
  }
}
