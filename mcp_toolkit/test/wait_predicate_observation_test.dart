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