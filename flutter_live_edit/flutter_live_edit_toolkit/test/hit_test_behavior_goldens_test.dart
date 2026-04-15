// Behavioral golden tests for hover, marquee, and candidate cycling.
//
// Phase 0 regression gate for the selection state-machine migration
// (see `todo/selection_state_machine.md`). Assertions are on selection
// sets / hover IDs / marquee bounds — never on pixels or layout — so
// later phases can rewire internals without breaking these goldens.
//
// Each test mirrors a currently-passing pattern in
// `live_edit_controller_test.dart` to keep the harness style uniform.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

LiveEditTargetDomain _domain(final LiveEditOrchestrator o) =>
    selectPresentedLayer(o.context);
String? _sid(final LiveEditOrchestrator o) =>
    o.context.sessionResource.value.activeSessionId;
LiveEditSelection? _selection(final LiveEditOrchestrator o) => o.controller
    .selectionForDomain(targetDomain: _domain(o), sessionId: _sid(o));
List<LiveEditSelection> _multiSelection(final LiveEditOrchestrator o) => o
    .controller
    .multiSelectionForDomain(targetDomain: _domain(o), sessionId: _sid(o));
List<LiveEditSelectionCandidate> _candidates(final LiveEditOrchestrator o) => o
    .controller
    .selectionCandidatesForDomain(targetDomain: _domain(o), sessionId: _sid(o));
LiveEditSelection? _hoverSelection(final LiveEditOrchestrator o) =>
    o.controller.hoverSelectionForDomain(
      targetDomain: _domain(o),
      sessionId: _sid(o),
    );
Rect? _marqueeRect(final LiveEditOrchestrator o) => o.controller
    .marqueeRectForDomain(targetDomain: _domain(o), sessionId: _sid(o));

Set<String> _selectionKeys(final Iterable<LiveEditSelection> selections) =>
    selections.map((final s) => s.nodeId).toSet();

void main() {
  group('hit-test behavioral goldens', () {
    testWidgets('hover tracks as pointer moves between targets', (
      final tester,
    ) async {
      final orchestrator = LiveEditOrchestrator();
      addTearDown(orchestrator.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: FlutterLiveEditHost(
            orchestrator: orchestrator,
            child: const Scaffold(
              body: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(padding: EdgeInsets.all(32), child: Text('Alpha')),
                  Padding(padding: EdgeInsets.all(32), child: Text('Beta')),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      final gesture = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await gesture.addPointer();
      // Golden: before any move, nothing is hovered.
      expect(_hoverSelection(orchestrator), isNull);

      await gesture.moveTo(tester.getCenter(find.text('Alpha')));
      await tester.pumpAndSettle();
      final alphaHover = _hoverSelection(orchestrator);
      expect(alphaHover, isNotNull);
      expect(_selection(orchestrator), isNull);

      await gesture.moveTo(tester.getCenter(find.text('Beta')));
      await tester.pumpAndSettle();
      final betaHover = _hoverSelection(orchestrator);
      expect(betaHover, isNotNull);
      // Golden: hover id changes when pointer moves to a different target.
      expect(betaHover!.nodeId, isNot(alphaHover!.nodeId));

      await gesture.moveTo(tester.getCenter(find.text('Alpha')));
      await tester.pumpAndSettle();
      expect(_hoverSelection(orchestrator)?.nodeId, alphaHover.nodeId);
    });

    testWidgets('marquee rubber-band commits a multi-node selection set', (
      final tester,
    ) async {
      final orchestrator = LiveEditOrchestrator();
      addTearDown(orchestrator.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: FlutterLiveEditHost(
            orchestrator: orchestrator,
            child: const Scaffold(
              body: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(padding: EdgeInsets.all(24), child: Text('One')),
                  Padding(padding: EdgeInsets.all(24), child: Text('Two')),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      final start =
          tester.getTopLeft(find.text('One')) - const Offset(20, 20);
      final end =
          tester.getBottomRight(find.text('Two')) + const Offset(20, 20);

      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(end);
      // Golden: while dragging, a marquee rect is present and contains both
      // targets.
      await tester.pump();
      final inFlightRect = _marqueeRect(orchestrator);
      expect(inFlightRect, isNotNull);
      expect(inFlightRect!.contains(tester.getCenter(find.text('One'))), isTrue);
      expect(inFlightRect.contains(tester.getCenter(find.text('Two'))), isTrue);

      await gesture.up();
      await tester.pumpAndSettle();

      // Golden: commit produces a multi-selection set with >= 2 unique
      // nodeIds; marquee preview rect is cleared.
      expect(_marqueeRect(orchestrator), isNull);
      final committed = _multiSelection(orchestrator);
      expect(committed.length, greaterThanOrEqualTo(2));
      expect(_selectionKeys(committed).length, committed.length);
    });

    testWidgets(
      'candidate cycling advances active candidate through SelectCandidateAtCommand',
      (final tester) async {
        final orchestrator = LiveEditOrchestrator();
        addTearDown(orchestrator.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: FlutterLiveEditHost(
              orchestrator: orchestrator,
              child: const Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: ColoredBox(
                      color: Colors.blue,
                      child: Center(
                        child: SizedBox(
                          width: 80,
                          height: 80,
                          child: ColoredBox(
                            color: Colors.amber,
                            child: Text('Target'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.byType(ActionChip));
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getCenter(find.text('Target')));
        await tester.pumpAndSettle();

        final candidates = _candidates(orchestrator);
        // Golden: nested layout must expose more than one candidate.
        expect(candidates.length, greaterThan(1));

        final initialActive = candidates.indexWhere(
          (final candidate) => candidate.active,
        );
        expect(initialActive, isNot(-1));

        final nextIndex = candidates
            .indexWhere((final candidate) => !candidate.active);
        expect(nextIndex, isNot(-1));

        SelectCandidateAtCommand(
          controller: orchestrator.controller,
          index: nextIndex,
        ).execute(orchestrator.context);
        await tester.pumpAndSettle();

        final advanced = _candidates(orchestrator);
        final advancedActive = advanced.indexWhere(
          (final candidate) => candidate.active,
        );
        // Golden: the nth candidate becomes active after
        // SelectCandidateAtCommand(index: n) and the selection tracks it.
        expect(advancedActive, nextIndex);
        expect(
          _selection(orchestrator)?.nodeId,
          advanced[nextIndex].nodeId,
        );
      },
    );
  });
}
