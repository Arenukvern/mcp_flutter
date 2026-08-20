import 'package:flutter/gestures.dart';
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

Future<Map<String, Object?>> _settleAfterPumps(
  final WidgetTester tester,
  final Future<Map<String, Object?>> future, {
  final int pumps = 8,
}) async {
  for (var i = 0; i < pumps; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  return future;
}

String _refFor(final Map<String, Object?> snapshot, final String identifier) {
  final nodes = (snapshot['nodes']! as List<Object?>)
      .cast<Map<String, Object?>>();
  return nodes.firstWhere(
        (final node) => node['identifier'] == identifier,
      )['ref']!
      as String;
}

void main() {
  testWidgets('synthetic hover enters the target and leaves on the next tap', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      var entered = false;
      var exited = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MouseRegion(
                onEnter: (final _) => entered = true,
                onExit: (final _) => exited = true,
                child: Semantics(
                  identifier: 'hover_target',
                  label: 'Hover me',
                  child: const SizedBox(width: 120, height: 60),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ref = _refFor(await _snapshotAfterPump(tester), 'hover_target');

      final hover = await _settleAfterPumps(
        tester,
        GestureInteractionService.hoverAtRef(ref),
      );
      expect(hover['success'], isTrue);
      expect(entered, isTrue);
      expect(exited, isFalse);

      final tap = await _settleAfterPumps(
        tester,
        GestureInteractionService.tapAtRef(ref),
      );
      expect(tap['via'], 'pointer_events');
      expect(exited, isTrue);
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('every gesture releases the synthetic mouse device', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                Semantics(
                  identifier: 'drag_source',
                  label: 'Source',
                  child: const SizedBox(width: 120, height: 60),
                ),
                Semantics(
                  identifier: 'drag_target',
                  label: 'Target',
                  child: const SizedBox(width: 120, height: 60),
                ),
                Semantics(
                  identifier: 'semantic_button',
                  label: 'Act',
                  button: true,
                  onTap: () {},
                  onLongPress: () {},
                  child: const SizedBox(width: 120, height: 60),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final snapshot = await _snapshotAfterPump(tester);
      final source = _refFor(snapshot, 'drag_source');
      final target = _refFor(snapshot, 'drag_target');
      final button = _refFor(snapshot, 'semantic_button');

      final gestures = <String, Future<Map<String, Object?>> Function()>{
        'tap': () => GestureInteractionService.tapAtRef(source),
        'longPress': () => GestureInteractionService.longPressAtRef(source),
        'drag': () => GestureInteractionService.drag(
          fromRef: source,
          toRef: target,
          kind: PointerDeviceKind.mouse,
        ),
        // Tier 1: the semantic action never touches the pointer pipeline, so
        // the release has to come from the gesture entry point itself.
        'semanticTap': () => GestureInteractionService.tapAtRef(button),
        'semanticLongPress': () =>
            GestureInteractionService.longPressAtRef(button),
      };

      final expectedVia = <String, String>{
        'tap': 'pointer_events',
        'longPress': 'pointer_events',
        'drag': 'pointer_events',
        'semanticTap': 'semantic_action',
        'semanticLongPress': 'semantic_action',
      };

      for (final gesture in gestures.entries) {
        await _settleAfterPumps(
          tester,
          GestureInteractionService.hoverAtRef(source),
        );
        expect(
          tester.binding.mouseTracker.mouseIsConnected,
          isTrue,
          reason: 'hover before ${gesture.key} did not park a device',
        );

        final result = await _settleAfterPumps(
          tester,
          gesture.value(),
          pumps: 45,
        );
        expect(result['via'], expectedVia[gesture.key]);
        expect(
          tester.binding.mouseTracker.mouseIsConnected,
          isFalse,
          reason: '${gesture.key} left the synthetic device connected',
        );

        // The platform mouse must still be free to announce itself.
        GestureBinding.instance
          ..handlePointerEvent(
            const PointerAddedEvent(kind: PointerDeviceKind.mouse),
          )
          ..handlePointerEvent(
            const PointerRemovedEvent(kind: PointerDeviceKind.mouse),
          );
        await tester.pump();
      }
    } finally {
      semantics.dispose();
    }
  });

  testWidgets('synthetic hover leaves the platform mouse device untouched', (
    final tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Semantics(
                identifier: 'hover_target',
                label: 'Hover me',
                child: const SizedBox(width: 120, height: 60),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final ref = _refFor(await _snapshotAfterPump(tester), 'hover_target');
      await _settleAfterPumps(
        tester,
        GestureInteractionService.hoverAtRef(ref),
      );

      // What the embedder sends when the cursor enters the window: the
      // platform mouse announces itself as device 0. MouseTracker asserts that
      // such an add only follows a remove for that device, so a synthetic
      // hover parked on device 0 would trip it here.
      GestureBinding.instance.handlePointerEvent(
        const PointerAddedEvent(kind: PointerDeviceKind.mouse),
      );
      await tester.pump();
    } finally {
      semantics.dispose();
    }
  });
}
