import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elephas_ai/main.dart';

void main() {
  testWidgets('Elephas AI app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the app starts with the correct title
    expect(find.text('Elephas AI'), findsOneWidget);

    // Verify that protection status is shown
    expect(find.byType(Card), findsWidgets);

    // Verify bottom navigation exists
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('Navigation between screens works', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Tap on History tab
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    // Should show history screen
    expect(find.text('Scan History'), findsOneWidget);

    // Tap on Settings tab
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    // Should show settings screen
    expect(find.text('Settings'), findsOneWidget);
  });
}
