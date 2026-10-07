import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zenday/accent_options.dart';
import 'package:zenday/income_screen.dart';
import 'package:zenday/planner_screen.dart';
import 'package:zenday/study_screen.dart';
import 'package:zenday/sync_screen.dart';
import 'package:zenday/theme.dart';

Widget _app(Widget home) => MaterialApp(
      theme: buildZenTheme(ZenColors.light.copyWith(accent: accentOptions[0].light), Brightness.light),
      home: home,
    );

/// Prüft, dass die Screens auf kleinen Handys ohne Überlauf-Fehler aufgebaut werden.
void main() {
  setUpAll(() => initializeDateFormatting('de_DE', null));

  /// Scrollt eine Liste komplett durch, damit auch spät gebaute Einträge auf Überlauf geprüft werden.
  Future<void> scrollThrough(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -500));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    }
  }

  const phones = {'iPhone 12 (390x844)': Size(390, 844), 'kleines Handy (320x568)': Size(320, 568)};

  for (final entry in phones.entries) {
    group(entry.key, () {
      setUp(() => SharedPreferences.setMockInitialValues({
            'flutter.zenday_onboarded': true,
            'flutter.zenday_templates':
                '[{"id":"t1","title":"Lernblock 1: WiWi","repeat":"daily","customDays":[],"startTime":"08:00","endTime":"10:00","isStudy":true}]',
            'flutter.zenday_income_2026-09': '1234.5',
          }));

      Future<void> open(WidgetTester tester, Widget home) async {
        tester.view.physicalSize = entry.value * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_app(home));
        await tester.pump(const Duration(milliseconds: 600));
      }

      testWidgets('Planer', (tester) async {
        await open(tester, const PlannerScreen());
        expect(find.text('Wie fühlst du dich heute?'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('Arbeitstracker', (tester) async {
        await open(tester, const IncomeScreen());
        expect(find.text('Arbeitstracker'), findsOneWidget);
        expect(find.textContaining('1.234,50'), findsWidgets);
        expect(tester.takeException(), isNull);
        await scrollThrough(tester);
      });

      testWidgets('Lerntracker', (tester) async {
        await open(tester, const StudyScreen());
        expect(find.text('Lernen starten'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await scrollThrough(tester);
        expect(find.text('Pflichtaufgaben'), findsNothing, reason: 'bis ans Ende gescrollt, Überschrift liegt darüber');
        await tester.pumpWidget(const SizedBox());
      });

      testWidgets('Synchronisierung', (tester) async {
        await open(tester, const SyncScreen());
        expect(find.text('Synchronisierung'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
