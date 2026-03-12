import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Live Edit toggle shows overlay and panel', (tester) async {
    // Use a large surface so the intentional overflow Row in the app doesn't break layout.
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() => binding.setSurfaceSize(null));

    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 30));

    expect(find.text('MCP Toolkit Demo'), findsOneWidget);

    // Tap Live Edit chip (ActionChip at bottom-left; avoid panel "Live Edit" header).
    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Live Edit: ON'), findsOneWidget);
    expect(find.text('Tap a widget to select'), findsOneWidget);

    await tester.tap(find.text('About This Demo'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Draft changes:'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit: ON'));
    await tester.pumpAndSettle();

    expect(find.text('Live Edit'), findsOneWidget);
  });
}
