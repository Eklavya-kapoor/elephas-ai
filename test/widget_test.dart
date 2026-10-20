import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:elephas_ai/main.dart';
import 'package:elephas_ai/services/overlay_service.dart';
import 'package:elephas_ai/services/elephas_main_service.dart';

void main() {
  testWidgets('Elephas AI app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OverlayService()),
          ChangeNotifierProvider(create: (_) => ElephasMainService.instance),
        ],
        child: const ElephantAI(),
      ),
    );

    // Let the app initialize
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Verify that the app shows Elephas AI branding
    expect(find.textContaining('Elephas'), findsWidgets);
  });

  testWidgets('Elephas AI protection features work', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => OverlayService()),
          ChangeNotifierProvider(create: (_) => ElephasMainService.instance),
        ],
        child: const ElephantAI(),
      ),
    );

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
