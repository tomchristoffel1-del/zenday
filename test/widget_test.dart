import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zenday/main.dart';

void main() {
  testWidgets('ZenDay startet ohne Absturz', (WidgetTester tester) async {
    await tester.pumpWidget(const ZenDayApp());
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
