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
    expect(find.text('Selection Bubble'), findsNothing);
  });

  testWidgets('overlay selection shows anchored bubble and candidate chips', (
    final tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterLiveEditHost(
          child: Scaffold(
            body: Center(
              child: SizedBox(width: 120, height: 80, child: Text('Target')),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Target')));
    await tester.pumpAndSettle();

    expect(find.text('Selection Bubble'), findsOneWidget);
    expect(find.textContaining('Target'), findsWidgets);
    expect(find.byType(ChoiceChip), findsWidgets);
  });

  testWidgets('orchestrator applies inline AI flow without modal UI', (
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

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Target')));
    await tester.pumpAndSettle();

    final selection = orchestrator.activeSelection!;
    final editable = selection.propertyGroups.firstWhere(
      (final property) => property.editable,
      orElse: () => const LiveEditPropertyDescriptor(
        id: 'width',
        label: 'Width',
        group: LiveEditPropertyGroup.layout,
        kind: LiveEditPropertyKind.number,
        editable: true,
        previewMode: LiveEditPreviewMode.ghost,
        persistable: true,
      ),
    );

    orchestrator.updateDraft(property: editable, targetValue: 140);
    await tester.pumpAndSettle();

    await orchestrator.applyDraft();
    await tester.pumpAndSettle();

    expect(orchestrator.applyPhase, LiveEditApplyPhase.awaitingApproval);
    expect(find.text('AI Bubble'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Approve & Apply'), findsWidgets);

    await orchestrator.applyDraft(approve: true);
    await tester.pumpAndSettle();

    expect(orchestrator.applyPhase, LiveEditApplyPhase.success);
    expect(orchestrator.activeDraftChanges, isEmpty);
    expect(requests.map((final request) => request.approve), [false, true]);
  });

  testWidgets('panel property edit stays non-modal', (final tester) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(body: Center(child: Text('Target'))),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Target')));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Selection Bubble'), findsOneWidget);

    for (
      var index = 0;
      index < orchestrator.activeSelectionCandidates.length;
      index += 1
    ) {
      final selection = orchestrator.activeSelection;
      if (selection != null &&
          selection.propertyGroups.any(
            (final candidate) => candidate.editable,
          )) {
        break;
      }
      orchestrator.selectCandidateAt(index);
      await tester.pumpAndSettle();
    }

    final property = orchestrator.activeSelection!.propertyGroups.firstWhere(
      (final candidate) => candidate.editable,
    );
    orchestrator.focusProperty(property);
    await tester.pumpAndSettle();

    if (property.options.isNotEmpty) {
      final nextOption = property.options.firstWhere(
        (final option) => '$option' != '${property.value}',
        orElse: () => property.options.first,
      );
      await tester.tap(find.widgetWithText(ChoiceChip, nextOption).first);
    } else if (property.kind == LiveEditPropertyKind.boolean) {
      await tester.tap(find.byType(Switch).first);
    } else {
      final textField = find.byType(TextField).first;
      await tester.enterText(
        textField,
        property.kind == LiveEditPropertyKind.string ? 'Retitled' : '140',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
    }
    await tester.pumpAndSettle();

    if (orchestrator.activeDraftChanges.isEmpty) {
      final fallbackValue = switch (property.kind) {
        LiveEditPropertyKind.boolean => !(property.value == true),
        LiveEditPropertyKind.integer => 140,
        LiveEditPropertyKind.number => 140.0,
        _ when property.options.isNotEmpty => property.options.first,
        _ => 'Retitled',
      };
      orchestrator.updateDraft(
        property: property,
        targetValue: fallbackValue,
        surface: LiveEditEditSurface.panel,
      );
      await tester.pumpAndSettle();
    }

    expect(find.byType(AlertDialog), findsNothing);
    expect(orchestrator.activeDraftChanges, isNotEmpty);
  });
}
