import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:mcp_toolkit/src/services/semantic_observation_history.dart';

void main() {
  Future<Map<String, Object?>> snapshotAfterPump(
    WidgetTester tester, {
    bool render = false,
    bool diff = false,
    SemanticSnapshotFilter? filter,
  }) async {
    final future = SemanticSnapshotService.buildSemanticSnapshot(
      render: render,
      diff: diff,
      filter: filter,
    );
    await tester.pump();
    await tester.pump();
    return future;
  }

  testWidgets('first diff with no prior same-filter snapshot uses baseline null', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Semantics(
            identifier: 'go',
            button: true,
            label: 'Go',
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final snapshot = await snapshotAfterPump(tester, diff: true);
    expect(snapshot['baseline'], isNull);
    expect(snapshot['baselineReason'], 'no_prior_same_filter');
    expect(snapshot['delta'], isNull);
  });

  testWidgets('labelPrefix filters nodes and identifierPrefix yields nearLabels', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Semantics(
            identifier: 'home_action',
            button: true,
            label: 'nav Home',
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final snapshot = await snapshotAfterPump(
      tester,
      filter: SemanticSnapshotFilter(
        identifierPrefix: 'nav.',
        labelPrefix: 'nav ',
      ),
    );
    final nodes = (snapshot['nodes']! as List<Object?>).cast<Map<String, Object?>>();
    expect(nodes, hasLength(1));
    expect(nodes.single['label'], 'nav Home');
    expect(snapshot['nearLabels'], isNull);

    final idOnly = await snapshotAfterPump(
      tester,
      filter: SemanticSnapshotFilter(identifierPrefix: 'nav'),
    );
    expect((idOnly['nodes']! as List).isEmpty, isTrue);
    expect(idOnly['nearLabels'], contains('nav Home'));
  });

  testWidgets('warnings cover tappable-without-name and label-like identifier', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Semantics(
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox(width: 40, height: 40),
                ),
              ),
              Semantics(
                button: true,
                label: 'settings.save',
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final snapshot = await snapshotAfterPump(tester);
    final warnings =
        (snapshot['warnings']! as List<Object?>).cast<Map<String, Object?>>();
    expect(
      warnings.map((w) => w['reason']),
      containsAll(<String>['tappable_without_name', 'label_looks_like_identifier']),
    );
  });

  testWidgets('public snapshot records the filtered observation in the ring', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Semantics(
                identifier: 'alpha',
                button: true,
                label: 'Alpha',
                child: const SizedBox(width: 40, height: 40),
              ),
              Semantics(
                identifier: 'beta',
                button: true,
                label: 'Beta',
                child: const SizedBox(width: 40, height: 40),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final filtered = await snapshotAfterPump(
      tester,
      filter: SemanticSnapshotFilter(labelPrefix: 'Alpha'),
    );
    final since = filtered['snapshot_id']! as int;
    final record = SemanticObservationHistory.instance.lookupSince(since);
    expect(record, isNotNull);
    expect(record!.filterKey, contains('labelPrefix'));
    final rendered = record.observation.render();
    expect(rendered, contains('Alpha'));
    expect(rendered, isNot(contains('Beta')));

    final filter = SemanticSnapshotFilter(labelPrefix: 'Alpha');
    final peekFuture = SemanticSnapshotService.peekSemanticSnapshot(
      filter: filter,
    );
    await tester.pump();
    final peek = await peekFuture;
    final current = SemanticSnapshotService.observationFromSnapshot(
      peek,
      filter: filter,
    );
    expect(current.diff(record.observation).isEmpty, isTrue);
  });

  testWidgets('peek strips misleading refs while full-tree refs stay valid', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              identifier: 'target_a',
              button: true,
              label: 'Alpha',
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final snapshot = await snapshotAfterPump(tester);
      final targetRef = (snapshot['nodes']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .singleWhere((n) => n['identifier'] == 'target_a')['ref']! as String;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Semantics(
              identifier: 'target_b',
              button: true,
              label: 'Beta',
              child: const SizedBox(width: 48, height: 48),
            ),
          ),
        ),
      );
      await tester.pump();

      final peekFuture = SemanticSnapshotService.peekSemanticSnapshot();
      await tester.pump();
      final peek = await peekFuture;

      expect(peek['refBound'], isFalse);
      final peekB = (peek['nodes']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .singleWhere((n) => n['identifier'] == 'target_b');
      expect(peekB.containsKey('ref'), isFalse);
      expect(SemanticSnapshotService.resolveRef(targetRef), isNotNull);
    } finally {
      semantics.dispose();
    }
  });
}