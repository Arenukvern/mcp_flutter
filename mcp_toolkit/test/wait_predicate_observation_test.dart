import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';
import 'package:universal_automation_semantics/universal_automation_semantics.dart';

import 'package:mcp_toolkit/src/services/semantic_delta_wire.dart';

void main() {
  test('changed delta wire includes rendered text and structured counts', () {
    final before = Observation.of(
      familySnapshotFromNodes(
        <Map<String, Object?>>[
          <String, Object?>{'ref': 's_0', 'label': 'Before', 'type': 'text'},
        ],
        snapshotId: 1,
        capturedAt: DateTime.utc(2026),
      ),
      const SemanticView(),
    );
    final after = Observation.of(
      familySnapshotFromNodes(
        <Map<String, Object?>>[
          <String, Object?>{'ref': 's_0', 'label': 'After', 'type': 'text'},
        ],
        snapshotId: 2,
        capturedAt: DateTime.utc(2026),
      ),
      const SemanticView(),
    );
    final wire = cappedDeltaRender(after.diff(before));
    expect(wire['delta'], isA<String>());
    expect(wire['changed'], isA<List<Object?>>());
    expect(wire['deltaTruncated'], isA<bool>());
  });

  test('changed predicate reports baseline_evicted when since is missing', () async {
    final result = await WaitPredicateService.waitFor(
      predicate: const {'kind': 'changed', 'since': 1},
      timeoutMs: 10,
    );
    expect(result['matched'], isFalse);
    expect(result['error'], 'baseline_evicted');
  });

  testWidgets('changed reports unknown reply text after chat line appears', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: _ChatReplyFixture())),
    );
    await tester.pump();
    final baseline = await _buildAfterPumps(tester);
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
    final structured = result['added'] as List<Object?>?;
  expect(structured, isNotNull);
    final joined = structured!.map((e) => e.toString()).join('\n');
    expect(joined, contains('ready when you are'));
  });

  test('timeout carries observedRevision and capped delta', () {
    final baselineNodes = <Map<String, Object?>>[
      <String, Object?>{'ref': 's_0', 'label': 'Orders', 'type': 'text'},
    ];
    final baselineObs = Observation.of(
      familySnapshotFromNodes(
        baselineNodes,
        snapshotId: 2,
        capturedAt: DateTime.utc(2026),
      ),
      const SemanticView(),
    );
    final result = WaitPredicateService.buildTimeoutResponseForTesting(
      predicate: const {'kind': 'text', 'text': 'missing'},
      elapsedMs: 400,
      waitStartSnapshotId: 2,
      waitStartBaseline: baselineObs,
      lastSnapshot: <String, Object?>{
        'snapshot_id': 2,
        'observed_revision': 11,
        'nodes': <Object?>[
          <String, Object?>{
            'ref': 's_0',
            'label': 'Orders',
            'type': 'text',
          },
        ],
      },
    );
    expect(result['lastSnapshotId'], 2);
    expect(result['observedRevision'], 11);
    expect(result['delta'], isA<String>());
    expect(result['added'], isA<List<Object?>>());
  });
}

class _ChatReplyFixture extends StatefulWidget {
  const _ChatReplyFixture();

  @override
  State<_ChatReplyFixture> createState() => _ChatReplyFixtureState();
}

class _ChatReplyFixtureState extends State<_ChatReplyFixture> {
  bool _showReply = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _showReply = true);
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: _showReply
        ? Semantics(
            label: "14:20\nI'm here and ready when you are.",
            child: const SizedBox(width: 200, height: 40),
          )
        : const Text('Waiting…'),
  );
}

Future<Map<String, Object?>> _buildAfterPumps(WidgetTester tester) async {
  final future = SemanticSnapshotService.buildSemanticSnapshot();
  await tester.pump();
  await tester.pump();
  return future;
}