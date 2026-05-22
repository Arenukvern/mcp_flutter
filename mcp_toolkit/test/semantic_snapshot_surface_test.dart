import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

Future<Map<String, Object?>> _snapshotAfterPump(
  final WidgetTester tester,
) async {
  final snapshotFuture = SemanticSnapshotService.buildSemanticSnapshot();
  await tester.pump();
  await tester.pump();
  return snapshotFuture;
}

void main() {
  testWidgets('semantic_snapshot reports flutter_widgets for tappable UI', (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Semantics(
            button: true,
            label: 'Go',
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final snapshot = await _snapshotAfterPump(tester);
    expect(snapshot['interactionSurface'], 'flutter_widgets');
    expect(snapshot['nodeCount'], greaterThan(0));
  });

  testWidgets(
    'semantic_snapshot reports hybrid when no interactive semantics refs',
    (final tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SizedBox(width: 100, height: 100)),
        ),
      );
      await tester.pumpAndSettle();

      final snapshot = await _snapshotAfterPump(tester);
      expect(snapshot['nodeCount'], 0);
      expect(snapshot['interactionSurface'], anyOf('hybrid', 'game_canvas'));
    },
  );
}
