import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

void main() {
  // Regression coverage for a latent bug where SemanticSnapshotService
  // returned physical-pixel coordinates because _globalRect accumulated the
  // root SemanticsNode's device-pixel-ratio transform. With DPR>1 (Retina,
  // most modern phones), synthesized pointer events sent at the resolved
  // center missed the widget by a factor of DPR. See
  // todo/dpr_resolve_center_bounds.md.
  for (final dpr in const <double>[1, 2, 3]) {
    testWidgets('resolveCenter returns logical coords at DPR=$dpr', (
      final tester,
    ) async {
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.resetDevicePixelRatio);

      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                label: 'dpr_target',
                child: SizedBox(key: key, width: 80, height: 40),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final snapshotFuture = SemanticSnapshotService.buildSemanticSnapshot();
      await tester.pump();
      await tester.pump();
      final snapshot = await snapshotFuture;

      final nodes = (snapshot['nodes']! as List).cast<Map<String, Object?>>();
      final node = nodes.firstWhere((final n) => n['label'] == 'dpr_target');
      final ref = node['ref']! as String;

      final resolvedCenter = SemanticSnapshotService.resolveCenter(ref);
      final resolvedBounds = SemanticSnapshotService.resolveBounds(ref);
      final expectedCenter = tester.getCenter(find.byKey(key));
      final expectedRect = tester.getRect(find.byKey(key));

      expect(resolvedCenter, isNotNull);
      expect(resolvedBounds, isNotNull);
      expect(
        (resolvedCenter!.dx - expectedCenter.dx).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'center.dx should be logical at DPR=$dpr',
      );
      expect(
        (resolvedCenter.dy - expectedCenter.dy).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'center.dy should be logical at DPR=$dpr',
      );
      expect(
        (resolvedBounds!.left - expectedRect.left).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'bounds.left should be logical at DPR=$dpr',
      );
      expect(
        (resolvedBounds.top - expectedRect.top).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'bounds.top should be logical at DPR=$dpr',
      );
      expect(
        (resolvedBounds.width - expectedRect.width).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'bounds.width should be logical at DPR=$dpr',
      );
      expect(
        (resolvedBounds.height - expectedRect.height).abs(),
        lessThanOrEqualTo(1.0),
        reason: 'bounds.height should be logical at DPR=$dpr',
      );
    });
  }
}
