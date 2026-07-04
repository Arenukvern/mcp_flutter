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

  testWidgets('visible subtree signature does not mutate snapshot refs', (
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
                itemCount: 12,
                itemBuilder: (final context, final index) =>
                    SizedBox(height: 48, child: Text('Row $index')),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final snapshot = await _snapshotAfterPump(tester);
      final snapshotId = SemanticSnapshotService.currentSnapshotId;
      final nodes = (snapshot['nodes']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final scrollable = nodes.singleWhere(
        (final node) => node['type'] == 'scrollable',
      );
      final row = nodes.firstWhere((final node) => node['label'] == 'Row 0');
      final scrollableRef = scrollable['ref']! as String;
      final rowRef = row['ref']! as String;
      final scrollableNode = SemanticSnapshotService.resolveRef(scrollableRef)!;
      final rowNode = SemanticSnapshotService.resolveRef(rowRef);

      final signature = SemanticSnapshotService.visibleSubtreeSignature(
        scrollableNode,
      );

      expect(signature['available'], isTrue);
      expect(signature['signatureHash'], isA<int>());
      expect(SemanticSnapshotService.currentSnapshotId, snapshotId);
      expect(SemanticSnapshotService.resolveRef(rowRef), same(rowNode));
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

  test('reveal_search only continues after verified or deferred scroll', () {
    expect(
      RevealSearchService.shouldContinueAfterScrollForTesting(<String, Object?>{
        'success': false,
        'deferredMovementCheck': true,
      }),
      isTrue,
    );
    expect(
      RevealSearchService.shouldContinueAfterScrollForTesting(<String, Object?>{
        'success': true,
        'movementVerified': true,
      }),
      isTrue,
    );
    expect(
      RevealSearchService.shouldContinueAfterScrollForTesting(<String, Object?>{
        'success': false,
        'via': 'semantic_action',
        'platform': 'web',
        'error': 'no_scroll_movement',
        'dispatched': true,
      }),
      isFalse,
    );
    expect(
      RevealSearchService.shouldContinueAfterScrollForTesting(<String, Object?>{
        'success': false,
        'platform': 'web',
        'error': 'unsupported_scroll_action',
      }),
      isFalse,
    );
  });

  test('reveal_search found-but-not-actionable payload is a failure', () {
    final result = RevealSearchService.foundButNotActionableResultForTesting(
      snapshot: const <String, Object?>{
        'snapshot_id': 7,
        'viewport': <String, Object?>{'width': 400, 'height': 400},
      },
      match: const <String, Object?>{
        'ref': 's_3',
        'identifier': 'partly_visible_target',
        'visibleInViewport': true,
        'centerInViewport': false,
      },
      query: 'partly_visible_target',
      matchBy: 'identifier',
      direction: 'down',
      maxAttempts: 0,
      distance: 300,
      attempts: const <Map<String, Object?>>[
        <String, Object?>{
          'attempt': 0,
          'found': true,
          'ref': 's_3',
          'visibleInViewport': true,
          'centerInViewport': false,
        },
      ],
    );

    expect(result['success'], isFalse);
    expect(result['error'], 'target_not_actionable');
    expect(result['actionable'], isFalse);
    expect(result['ref'], 's_3');
    expect(result['visibleInViewport'], isTrue);
    expect(result['centerInViewport'], isFalse);
    expect(result['recommendedNextAction'], 'scroll_more');
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
