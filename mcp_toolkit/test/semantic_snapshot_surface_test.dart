import 'package:flutter/material.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart'
    show semanticSnapshotNodeFields;
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
            // Fills the body so the screen centre — where a ref-less scroll
            // aims its wheel event — lands on the list itself.
            body: ListView.builder(
              itemCount: 30,
              itemBuilder: (final context, final index) =>
                  SizedBox(height: 48, child: Text('Row $index')),
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

  test('reveal_search only continues after a verified scroll', () {
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
    expect(result['hint'], contains('maxAttempts'));
  });

  testWidgets('reveal_search says what to do when nothing matched', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Only row'))),
        ),
      );
      await tester.pumpAndSettle();

      final revealFuture = RevealSearchService.revealSearch(
        query: 'nothing_here',
        matchBy: 'identifier',
        maxAttempts: 1,
        distance: 120,
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final result = await revealFuture;

      expect(result['success'], isFalse);
      // Either the search ran out of screens or the page could not scroll at
      // all; both are refusals, and both have to name the next step.
      expect(result['error'], anyOf('target_not_found', 'scroll_blocked'));
      expect(result['hint'], isA<String>());
      expect(result['hint'], isNotEmpty);
      // The page publishes no identifier, so the miss says that rather than
      // guessing at split text — an identifier is matched whole.
      expect(result['hint'], contains('published any identifier'));
      expect(result['hint'], isNot(contains('split across nodes')));
      expect(result['identifiersSeen'], 0);
      expect(result['nearIdentifiers'], isEmpty);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reveal_search names the identifiers near a missed one', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Semantics(
                  identifier: 'panel.tab.overview',
                  child: const Text('Overview'),
                ),
                Semantics(
                  identifier: 'panel.tab.jobs',
                  child: const Text('Jobs'),
                ),
                Semantics(
                  identifier: 'other.thing',
                  child: const Text('Other'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final revealFuture = RevealSearchService.revealSearch(
        query: 'panel.tab',
        matchBy: 'identifier',
        maxAttempts: 1,
        distance: 120,
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final result = await revealFuture;

      expect(result['success'], isFalse);
      expect(result['error'], anyOf('target_not_found', 'scroll_blocked'));
      expect(result['identifiersSeen'], 3);
      expect(result['nearIdentifiers'], <String>[
        'panel.tab.jobs',
        'panel.tab.overview',
      ]);
      expect(
        result['hint'],
        contains('"panel.tab.jobs", "panel.tab.overview"'),
      );
      expect(result['hint'], isNot(contains('split across nodes')));
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('reveal_search explains a text miss as a substring test', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('Only row'))),
        ),
      );
      await tester.pumpAndSettle();

      final revealFuture = RevealSearchService.revealSearch(
        query: 'nothing here',
        maxAttempts: 1,
        distance: 120,
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      final result = await revealFuture;

      expect(result['success'], isFalse);
      expect(result['hint'], contains('split across nodes'));
      expect(result.containsKey('nearIdentifiers'), isFalse);
    } finally {
      semantics.dispose();
    }
  });

  test(
    'reveal_search ranks near identifiers by how they resemble the query',
    () {
      expect(
        RevealSearchService.nearIdentifiersFor(
          query: 'panel.tab',
          identifiersSeen: <String>[
            'other.thing',
            'panel.header',
            'sidebar.panel.tab',
            'Panel.Tab',
            'panel.tab.version',
            'panel.tab.overview',
            'panel.tab.overview',
          ],
        ),
        <String>[
          'Panel.Tab',
          'panel.tab.overview',
          'panel.tab.version',
          'sidebar.panel.tab',
          'panel.header',
        ],
      );
      expect(
        RevealSearchService.nearIdentifiersFor(
          query: 'nav.tasks',
          identifiersSeen: <String>['dialog.omniSearch', 'topbar.avatar'],
        ),
        isEmpty,
      );
    },
  );

  group('semantic_snapshot filters', () {
    Future<void> pumpRailAndPanel(final WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                Semantics(
                  identifier: 'rail',
                  container: true,
                  child: Column(
                    children: <Widget>[
                      Semantics(
                        identifier: 'nav.tasks',
                        button: true,
                        onTap: () {},
                        child: const Text('Tasks'),
                      ),
                      Semantics(
                        identifier: 'nav.calendar',
                        button: true,
                        onTap: () {},
                        child: const Text('Calendar'),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  identifier: 'panel',
                  container: true,
                  child: Column(
                    children: <Widget>[
                      Semantics(
                        identifier: 'panel.tab.overview',
                        button: true,
                        onTap: () {},
                        child: const Text('Overview'),
                      ),
                      // No identifier and no boundary of its own: the label
                      // still has to travel with the button node.
                      Semantics(
                        container: true,
                        button: true,
                        onTap: () {},
                        child: const Text('Unnamed button'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    List<Map<String, Object?>> nodesOf(final Map<String, Object?> snapshot) =>
        (snapshot['nodes']! as List<Object?>).cast<Map<String, Object?>>();

    testWidgets('the viewport is stated once, not on every node', (
      final tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpRailAndPanel(tester);
        final snapshot = await _snapshotAfterPump(tester);

        expect(snapshot['viewport'], isA<Map<String, Object?>>());
        for (final node in nodesOf(snapshot)) {
          expect(
            node.containsKey('viewport'),
            isFalse,
            reason: '${node['ref']}',
          );
          expect(node.containsKey('visibleInViewport'), isTrue);
        }
        // A single-ref answer still carries it, since it has no envelope.
        final ref = nodesOf(snapshot).first['ref']! as String;
        expect(
          SemanticSnapshotService.visibilityForRef(ref)['viewport'],
          isA<Map<String, Object?>>(),
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('identifierPrefix keeps the matching nodes only', (
      final tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpRailAndPanel(tester);
        final full = await _snapshotAfterPump(tester);
        final fullRefs = <String, String>{
          for (final node in nodesOf(full))
            if (node['identifier'] is String)
              node['identifier']! as String: node['ref']! as String,
        };

        final future = SemanticSnapshotService.buildSemanticSnapshot(
          filter: const SemanticSnapshotFilter(identifierPrefix: 'nav.'),
        );
        await tester.pump();
        final filtered = await future;

        final nodes = nodesOf(filtered);
        expect(
          nodes.map((final n) => n['identifier']),
          unorderedEquals(<String>['nav.tasks', 'nav.calendar']),
        );
        // Refs number the full walk, so they agree with the unfiltered
        // snapshot and every interaction tool can resolve them.
        for (final node in nodes) {
          expect(node['ref'], fullRefs[node['identifier']]);
          expect(
            SemanticSnapshotService.resolveRef(node['ref']! as String),
            isNotNull,
          );
        }
        expect(filtered['nodeCount'], 2);
        expect(filtered['totalNodeCount'], nodesOf(full).length);
        expect(filtered['filter'], <String, Object?>{
          'identifierPrefix': 'nav.',
        });
        expect(filtered['interactionSurface'], full['interactionSurface']);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('subtreeOf narrows to a node and its descendants', (
      final tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpRailAndPanel(tester);

        // By identifier: no earlier snapshot is needed.
        var future = SemanticSnapshotService.buildSemanticSnapshot(
          filter: const SemanticSnapshotFilter(subtreeOf: 'panel'),
        );
        await tester.pump();
        final byIdentifier = await future;
        final panelNodes = nodesOf(byIdentifier);
        expect(
          panelNodes.map((final n) => n['identifier'] ?? n['label']),
          unorderedEquals(<String>[
            'panel',
            'panel.tab.overview',
            'Unnamed button',
          ]),
        );
        // Children of the kept container name kept refs only.
        final panel = panelNodes.firstWhere(
          (final n) => n['identifier'] == 'panel',
        );
        final keptRefs = panelNodes.map((final n) => n['ref']).toSet();
        expect(
          keptRefs.containsAll(panel['children']! as List<Object?>),
          isTrue,
        );

        // By ref from the latest snapshot.
        final railRef =
            nodesOf(
                  await _snapshotAfterPump(tester),
                ).firstWhere((final n) => n['identifier'] == 'rail')['ref']!
                as String;
        future = SemanticSnapshotService.buildSemanticSnapshot(
          filter: SemanticSnapshotFilter(subtreeOf: railRef),
        );
        await tester.pump();
        final byRef = await future;
        expect(
          nodesOf(byRef).map((final n) => n['identifier']),
          unorderedEquals(<String>['rail', 'nav.tasks', 'nav.calendar']),
        );
      } finally {
        semantics.dispose();
      }
    });

    testWidgets(
      'an unknown subtree root is refused before a snapshot is spent',
      (final tester) async {
        final semantics = tester.ensureSemantics();
        try {
          await pumpRailAndPanel(tester);
          final before = await _snapshotAfterPump(tester);
          final knownRef = nodesOf(before).first['ref']! as String;

          final future = SemanticSnapshotService.buildSemanticSnapshot(
            filter: const SemanticSnapshotFilter(subtreeOf: 'no.such.node'),
          );
          await tester.pump();
          final result = await future;

          expect(result['success'], isFalse);
          expect(result['error'], 'subtree_root_not_found');
          expect(result['hint'], contains('No snapshot was taken'));
          expect(
            SemanticSnapshotService.currentSnapshotId,
            before['snapshot_id'],
            reason: 'a refusal must not move the counter',
          );
          expect(SemanticSnapshotService.resolveRef(knownRef), isNotNull);
        } finally {
          semantics.dispose();
        }
      },
    );

    testWidgets('the entry decodes fields from the wire map', (
      final tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpRailAndPanel(tester);
        // The service extension hands a legacy handler strings only, so the
        // list arrives JSON-encoded; invokeDirect walks that same path.
        final future = OnSemanticSnapshotEntry().invokeDirect(<String, Object?>{
          'identifierPrefix': 'nav.',
          'fields': <String>['identifier', 'label'],
        });
        await tester.pump();
        final result = await future;

        expect(result.ok, isTrue, reason: result.message);
        expect(result.data['filter'], <String, Object?>{
          'identifierPrefix': 'nav.',
          'fields': <String>['identifier', 'label'],
        });
        for (final node in nodesOf(result.data)) {
          expect(
            node.keys,
            unorderedEquals(<String>['ref', 'identifier', 'label']),
          );
        }
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('fields projects every node and always keeps the ref', (
      final tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await pumpRailAndPanel(tester);

        var future = SemanticSnapshotService.buildSemanticSnapshot(
          filter: const SemanticSnapshotFilter(
            fields: <String>['identifier', 'label'],
          ),
        );
        await tester.pump();
        final projected = await future;
        for (final node in nodesOf(projected)) {
          expect(node.keys, isNot(contains('bounds')));
          expect(node.keys, isNot(contains('actions')));
          expect(node.keys, contains('ref'));
          expect(node.keys, anyOf(contains('identifier'), contains('label')));
        }

        future = SemanticSnapshotService.buildSemanticSnapshot(
          filter: const SemanticSnapshotFilter(fields: <String>['ref', 'nope']),
        );
        await tester.pump();
        final refused = await future;
        expect(refused['success'], isFalse);
        expect(refused['error'], 'unknown_field');
        expect(refused['unknownFields'], <String>['nope']);
        expect(refused['acceptedFields'], semanticSnapshotNodeFields);
        expect(refused['hint'], contains('"nope"'));
      } finally {
        semantics.dispose();
      }
    });
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
