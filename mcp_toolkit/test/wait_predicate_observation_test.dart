import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  testWidgets('changed predicate returns structured delta on success', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: _DelayedLabel())),
      );
      await tester.pumpAndSettle();

      final baseline = await _publicSnapshot(tester);
      final since = baseline['snapshot_id']! as int;

      final waitFuture = WaitPredicateService.waitFor(
        predicate: <String, Object?>{'kind': 'changed', 'since': since},
        timeoutMs: 3000,
      );

      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final result = await waitFuture;
      expect(result['matched'], isTrue);
      expect(result['delta'], isA<String>());
      expect(result['added'], isA<List<Object?>>());
      expect(result['since'], since);
    } finally {
      semantics.dispose();
    }
  });

  test('changed predicate reports baseline_evicted when since is missing', () async {
    final result = await WaitPredicateService.waitFor(
      predicate: const {'kind': 'changed', 'since': 1},
      timeoutMs: 10,
    );
    expect(result['matched'], isFalse);
    expect(result['error'], 'baseline_evicted');
  });

  testWidgets('timeout carries observedRevision vs wait-start baseline', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('static'))),
    );
    await tester.pumpAndSettle();
    await _publicSnapshot(tester);
    final waitStartId = SemanticSnapshotService.currentSnapshotId;

    final waitFuture = WaitPredicateService.waitFor(
      predicate: const {'kind': 'text', 'text': 'missing_label'},
      timeoutMs: 200,
    );

    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 15)),
      );
      await tester.pump();
    }

    final result = await waitFuture;
    expect(result['matched'], isFalse);
    expect(result['lastSnapshotId'], waitStartId);
    expect(result['observedRevision'], isA<int>());
    expect(result['delta'], isA<String>());
    expect(result['added'], isA<List<Object?>>());
  });
}

Future<Map<String, Object?>> _publicSnapshot(WidgetTester tester) async {
  final future = SemanticSnapshotService.buildSemanticSnapshot();
  await tester.pump();
  await tester.pump();
  return future;
}

class _DelayedLabel extends StatefulWidget {
  const _DelayedLabel();

  @override
  State<_DelayedLabel> createState() => _DelayedLabelState();
}

class _DelayedLabelState extends State<_DelayedLabel> {
  var _label = 'Before';

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _label = 'After');
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Semantics(
      identifier: 'status_line',
      label: _label,
      child: const SizedBox(width: 40, height: 40),
    ),
  );
}