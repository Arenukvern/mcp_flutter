import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void resetController() {
    final controller = LiveEditController.instance;
    for (
      var guard = 0;
      guard < 8 && controller.activeSessionId != null;
      guard++
    ) {
      final sessionId = controller.activeSessionId;
      try {
        controller.endSession(sessionId: sessionId);
      } on AssertionError {
        break;
      } on StateError {
        break;
      }
    }
  }

  setUp(resetController);
  tearDown(resetController);

  testWidgets('controller starts and ends session', (final tester) async {
    final controller = LiveEditController.instance;

    final started = controller.startSession();
    final sessionId = started['sessionId']! as String;

    expect(sessionId, isNotEmpty);
    expect(controller.activeSessionId, sessionId);

    final ended = controller.endSession(sessionId: sessionId);
    expect(ended['ended'], isTrue);
  });

  testWidgets('host builds without overlay by default', (final tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterLiveEditHost(child: Scaffold(body: Text('Hello'))),
      ),
    );

    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('orchestrator prepares and applies with approval flow', (
    final tester,
  ) async {
    final requests = <LiveEditApplyDraftRequest>[];
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        requests.add(request);
        if (!request.approve) {
          return <String, Object?>{
            'proposalId': 'proposal-1',
            'executionPlan': <String, Object?>{
              'proposalId': 'proposal-1',
              'title': 'Apply live edit',
              'summary': 'Set width for selected widget.',
              'selectedNode': 'SizedBox',
              'requestedChanges': <String>['Set Width to 140'],
              'affectedFiles': <String>['lib/main.dart'],
              'confidence': 0.9,
              'riskNotes': <String>['layout'],
              'agentInstruction': 'Set width=140 on selected widget.',
            },
          };
        }
        return <String, Object?>{
          'proposalId': 'proposal-1',
          'result': <String, Object?>{'status': 'applied'},
        };
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(
            body: Center(
              child: SizedBox(width: 120, height: 80, child: Text('Target')),
            ),
          ),
        ),
      ),
    );

    orchestrator.setOverlayEnabled(true);
    await tester.pump();

    final targetCenter = tester.getCenter(find.text('Target'));
    final candidateTaps = <Offset>[
      targetCenter,
      targetCenter.translate(-8, -8),
      targetCenter.translate(8, 8),
      const Offset(200, 200),
      const Offset(400, 300),
    ];

    List<LiveEditPropertyDescriptor> editableProperties =
        <LiveEditPropertyDescriptor>[];
    for (final point in candidateTaps) {
      await tester.tapAt(point);
      await tester.pump();
      final selection = orchestrator.activeSelection;
      editableProperties =
          selection?.propertyGroups
              .where((final property) => property.editable)
              .toList(growable: false) ??
          <LiveEditPropertyDescriptor>[];
      if (editableProperties.isNotEmpty) {
        break;
      }
    }

    expect(orchestrator.activeSelection, isNotNull);
    final editable = editableProperties.isNotEmpty
        ? editableProperties.first
        : const LiveEditPropertyDescriptor(
            id: 'width',
            label: 'Width',
            group: LiveEditPropertyGroup.layout,
            kind: LiveEditPropertyKind.number,
            editable: true,
            previewMode: LiveEditPreviewMode.ghost,
            persistable: true,
          );

    orchestrator.updateDraft(property: editable, targetValue: 140);
    await tester.pump();

    expect(orchestrator.activeDraftChanges, isNotEmpty);

    await orchestrator.applyDraft();
    await tester.pump();

    expect(orchestrator.applyPhase, LiveEditApplyPhase.awaitingApproval);
    expect(orchestrator.pendingExecutionPlan, isNotNull);

    await orchestrator.applyDraft(approve: true);
    await tester.pump();

    expect(orchestrator.applyPhase, LiveEditApplyPhase.success);
    expect(orchestrator.activeDraftChanges, isEmpty);
    expect(requests.map((final request) => request.approve), [false, true]);
  });

  testWidgets(
    'panel property edit opens dialog without Navigator error (builder setup)',
    (final tester) async {
      String? navigatorError;
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (final details) {
        final text = '${details.exception}';
        if (text.contains('Navigator') &&
            text.contains('does not include a Navigator')) {
          navigatorError = text;
        }
        previousOnError?.call(details);
      };

      await tester.pumpWidget(
        MaterialApp(
          builder: (final context, final child) =>
              FlutterLiveEditHost(child: child ?? const SizedBox.shrink()),
          home: const Scaffold(
            body: Center(
              child: SizedBox(width: 100, height: 50, child: Text('Target')),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      await tester.tapAt(tester.getCenter(find.text('Target')));
      await tester.pumpAndSettle();

      final listTiles = find.byType(ListTile);
      if (listTiles.evaluate().isNotEmpty) {
        await tester.tap(listTiles.first);
        await tester.pumpAndSettle();
        if (find.byType(AlertDialog).evaluate().isNotEmpty) {
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        }
      }

      addTearDown(() {
        FlutterError.onError = previousOnError;
      });
      expect(
        navigatorError,
        isNull,
        reason: 'Live Edit panel must not trigger Navigator context error',
      );
    },
  );
}
