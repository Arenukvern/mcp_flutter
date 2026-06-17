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

Future<Map<String, Object?>> _scrollAfterPumps({
  required final WidgetTester tester,
  required final String direction,
  required final double distance,
}) async {
  final future = GestureInteractionService.scroll(
    direction: direction,
    distance: distance,
  );
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  return future;
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

  testWidgets('semantic_snapshot exposes Semantics identifiers', (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Semantics(
            identifier: 'primary_go_button',
            button: true,
            label: 'Go',
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final snapshot = await _snapshotAfterPump(tester);
    final nodes = snapshot['nodes']! as List<Object?>;
    final button = nodes.cast<Map<String, Object?>>().singleWhere(
      (final node) => node['label'] == 'Go',
    );

    expect(button['identifier'], 'primary_go_button');
  });

  testWidgets('scroll reports movement and refuses false success at boundary', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: 30,
                itemBuilder: (final context, final index) =>
                    SizedBox(height: 48, child: Text('Row $index')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _snapshotAfterPump(tester);

      final boundary = await _scrollAfterPumps(
        tester: tester,
        direction: 'up',
        distance: 120,
      );
      expect(boundary['success'], isFalse);
      expect(boundary['error'], 'no_scroll_movement');

      final moved = await _scrollAfterPumps(
        tester: tester,
        direction: 'down',
        distance: 120,
      );

      expect(moved['success'], isTrue);
      final before = moved['scrollBefore'];
      final after = moved['scrollAfter'];
      if (before case final num beforeValue) {
        if (after case final num afterValue) {
          expect(afterValue, greaterThan(beforeValue));
        } else {
          fail('scrollAfter should be numeric: $after');
        }
      } else {
        fail('scrollBefore should be numeric: $before');
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reveal_search finds an off-screen semantics identifier', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 240,
              child: ListView(
                children: <Widget>[
                  for (var i = 0; i < 12; i++)
                    SizedBox(height: 64, child: Text('Row $i')),
                  Semantics(
                    identifier: 'greeting_input_field',
                    textField: true,
                    child: const TextField(),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final initial = await _snapshotAfterPump(tester);
      final initialNodes = (initial['nodes']! as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(
        initialNodes.any(
          (final node) => node['identifier'] == 'greeting_input_field',
        ),
        isFalse,
      );

      final revealFuture = RevealSearchService.revealSearch(
        query: 'greeting_input_field',
        matchBy: 'identifier',
        direction: 'down',
        maxAttempts: 6,
        distance: 160,
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final result = await revealFuture;

      expect(result['success'], isTrue);
      expect(result['ref'], isA<String>());
      expect(result['snapshotId'], isA<int>());
      final match = result['match']! as Map<String, Object?>;
      expect(match['identifier'], 'greeting_input_field');
      expect(match['ref'], result['ref']);
      final attempts = result['attempts']! as List<Object?>;
      expect(attempts.length, greaterThan(1));
    } finally {
      semantics.dispose();
    }
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
