import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zenday/income_screen.dart';
import 'package:zenday/main.dart';
import 'package:zenday/study_stats.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ZenDay startet ohne Absturz und zeigt das Onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const ZenDayApp());
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Baue deinen Plan'), findsOneWidget);
    expect(find.textContaining('Anmelden & synchronisieren'), findsOneWidget);
  });

  test('Beträge werden deutsch und englisch geschrieben richtig gelesen', () {
    expect(parseAmount('1234,50'), 1234.5);
    expect(parseAmount('1.234,50'), 1234.5);
    expect(parseAmount('1234.50'), 1234.5);
    expect(parseAmount('1.234'), 1234);
    expect(parseAmount('1.234.567'), 1234567);
    expect(parseAmount('12.5'), 12.5);
    expect(parseAmount('800 €'), 800);
    expect(parseAmount(''), isNull);
    expect(parseAmount('abc'), isNull);
    expect(parseAmount('-5'), isNull);
  });

  test('Zeitformate und Dauer', () {
    expect(fmtClock(3725), '1:02:05');
    expect(fmtHm(7200), '2 h 00 min');
    expect(fmtHm(1500), '25 min');
    expect(durationMinutes('08:00', '10:00'), 120);
    expect(durationMinutes('10:00', null), 0);
    expect(durationMinutes('10:00', '09:00'), 0);
  });
}
