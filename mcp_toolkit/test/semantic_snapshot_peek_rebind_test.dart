import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

/// [SemanticSnapshotService.peekSemanticSnapshot] must not rebind public refs.
void main() {
  testWidgets('peek does not rebind public refs while snapshot_id is frozen', (
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

      final snapshot = await _buildAfterPumps(tester);
      final publicId = SemanticSnapshotService.currentSnapshotId;
      final targetRef = (snapshot['nodes']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .singleWhere((n) => n['identifier'] == 'target_a')['ref']! as String;
      final boundBefore = SemanticSnapshotService.resolveRef(targetRef);
      expect(boundBefore, isNotNull);

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

      expect(SemanticSnapshotService.currentSnapshotId, publicId);
      expect(SemanticSnapshotService.resolveRef(targetRef), same(boundBefore));
      expect(peek['refBound'], isFalse);
      final peekB = (peek['nodes']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .singleWhere((n) => n['identifier'] == 'target_b');
      expect(peekB.containsKey('ref'), isFalse);
    } finally {
      semantics.dispose();
    }
  });
}

Future<Map<String, Object?>> _buildAfterPumps(WidgetTester tester) async {
  final future = SemanticSnapshotService.buildSemanticSnapshot();
  await tester.pump();
  await tester.pump();
  return future;
}