import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_live_edit_agent/flutter_live_edit_agent.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_app/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Live Edit toggle shows overlay and panel', (tester) async {
    // Use a large surface so the intentional overflow Row in the app doesn't break layout.
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() => binding.setSurfaceSize(null));

    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 30));

    expect(find.text('MCP Toolkit Demo'), findsOneWidget);

    // Tap Live Edit chip (ActionChip at bottom-left; avoid panel "Live Edit" header).
    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.text('Live Edit: ON'), findsOneWidget);
    expect(find.text('Tap a widget'), findsOneWidget);

    await tester.tap(find.text('About This Demo'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Draft changes:'), findsOneWidget);

    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit: ON'));
    await tester.pumpAndSettle();

    expect(find.text('Live Edit'), findsOneWidget);
  });

  testWidgets('prompt-only send applies without draft error', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await binding.setSurfaceSize(null);
    });

    final requests = <LiveEditApplyDraftRequest>[];
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        requests.add(request);
        return <String, Object?>{
          'proposalId': 'prompt-only-proposal',
          'executionPlan': <String, Object?>{
            'proposalId': 'prompt-only-proposal',
            'title': 'Apply live edit',
            'summary': 'Persist the selected heading text from the AI prompt.',
            'selectedNode': 'Text',
            'requestedChanges': <String>[request.intentText ?? ''],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.88,
            'riskNotes': const <String>[],
            'agentInstruction': 'Persist the selected heading text.',
          },
          'result': <String, Object?>{
            'status': 'applied',
            'changedFiles': <String>['lib/main.dart'],
          },
        };
      },
    );
    debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

    await app.main();
    await _pumpUntil(
      tester,
      () => find.text('MCP Toolkit Demo').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(tester, () => orchestrator.overlayVisible);

    final aboutHeading = _semanticsId('about_demo_heading');
    await tester.tap(aboutHeading, warnIfMissed: false);
    await tester.pumpAndSettle();
    if (orchestrator.activeSelection == null) {
      orchestrator.selectNode(tester.getCenter(aboutHeading));
      await _pumpUntil(tester, () => orchestrator.activeSelection != null);
    }
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();
    OpenAiBubbleCommand(defaultPrompt: '').execute(orchestrator.context);
    await tester.pumpAndSettle();

    final promptField = find.descendant(
      of: _semanticsId('live_edit_ai_prompt_field'),
      matching: find.byType(TextField),
    );
    expect(promptField, findsAtLeast(1));
    UpdateAiComposerCommand(
      value: 'Rewrite the selected heading in a cleaner style.',
    ).execute(orchestrator.context);
    await tester.pump(const Duration(milliseconds: 200));

    await orchestrator.applyDraft(
      message: 'Rewrite the selected heading in a cleaner style.',
    );
    await tester.pumpAndSettle();
    await _pumpUntil(
      tester,
      () => orchestrator.currentActivity?.label == 'Applied',
    );

    expect(requests, hasLength(1));
    expect(requests.single.draftChanges, isEmpty);
    expect(
      requests.single.intentText,
      'Rewrite the selected heading in a cleaner style.',
    );
    expect(orchestrator.pendingExecutionPlan, isNotNull);
    expect(orchestrator.lastError, isNull);
    expect(find.textContaining('No draft', findRichText: true), findsNothing);
  });

  testWidgets('debug panel shows the exact resolved backend prompt', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await binding.setSurfaceSize(null);
    });

    final agentService = LiveEditAgentService();
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        final resolutionRequest = LiveEditResolutionRequest(
          sessionId: request.sessionId,
          bubbleId: request.effectiveBubbleId,
          backendId: request.backendId ?? 'codex_exec',
          workingDirectory: Directory.current.path,
          instructionText: request.effectiveInstructionText,
          primarySelection: request.effectivePrimarySelection,
          selectedWidgets: request.effectiveSelectedWidgets,
          sourceTargets: request.sourceTargets,
          stagedPropertyChanges: request.effectiveStagedPropertyChanges,
          applyMode: request.applyMode,
          inferenceConfig: request.inferenceConfig,
          intentText: request.intentText,
          draftChanges: request.draftChanges,
          selection: request.selection,
          meta: const <String, Object?>{
            'integrationTest': true,
            'driver': 'live_edit_test',
          },
        );
        final promptText = agentService.buildResolvedPrompt(resolutionRequest);
        request.onEvent?.call(
          LiveEditRuntimeEvent(
            kind: LiveEditRuntimeEventKind.debug,
            message: 'Resolved backend prompt captured.',
            promptText: promptText,
            debugOnly: true,
          ),
        );
        return <String, Object?>{
          'proposalId': 'prompt-debug-proposal',
          'executionPlan': <String, Object?>{
            'proposalId': 'prompt-debug-proposal',
            'title': 'Apply this bubble change',
            'summary': 'Persist the selected heading text from the AI prompt.',
            'selectedNode': 'Text',
            'requestedChanges': <String>[request.intentText ?? ''],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.88,
            'riskNotes': const <String>[],
            'agentInstruction': 'Persist the selected heading text.',
          },
          'executionResult': <String, Object?>{
            'executionId': 'prompt-debug-proposal',
            'backendId': 'codex_exec',
            'summary': 'Persist the selected heading text from the AI prompt.',
            'changedFiles': <String>['lib/main.dart'],
            'warnings': const <String>[],
            'validationSteps': const <String>[],
          },
          'result': <String, Object?>{
            'executionId': 'prompt-debug-proposal',
            'backendId': 'codex_exec',
            'summary': 'Persist the selected heading text from the AI prompt.',
            'changedFiles': <String>['lib/main.dart'],
            'warnings': const <String>[],
            'validationSteps': const <String>[],
          },
        };
      },
    );
    debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

    await app.main();
    await _pumpUntil(
      tester,
      () => find.text('MCP Toolkit Demo').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(tester, () => orchestrator.overlayVisible);

    final aboutHeading = _semanticsId('about_demo_heading');
    await tester.tap(aboutHeading, warnIfMissed: false);
    await tester.pumpAndSettle();
    if (orchestrator.activeSelection == null) {
      orchestrator.selectNode(tester.getCenter(aboutHeading));
      await _pumpUntil(tester, () => orchestrator.activeSelection != null);
    }

    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();
    SetDebugModeCommand(enabled: true).execute(orchestrator.context);
    UpdateAiComposerCommand(
      value: 'Rewrite the selected heading in a cleaner style.',
    ).execute(orchestrator.context);
    await tester.pumpAndSettle();

    await orchestrator.submitAiPrompt();
    await tester.pumpAndSettle();
    await _pumpUntil(
      tester,
      () => orchestrator.debugPromptForActiveSelection != null,
    );

    if (!orchestrator.panelExpanded) {
      ExpandPanelCommand().execute(orchestrator.context);
      await tester.pumpAndSettle();
    }

    expect(_semanticsId('live_edit_selected_prompt'), findsOneWidget);
    await tester.tap(_semanticsId('live_edit_selected_prompt'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('You are an agent working directly inside'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '"instructionText": "Rewrite the selected heading in a cleaner style."',
      ),
      findsOneWidget,
    );
  });

  testWidgets('selection policy promotes the heading to app-owned Text', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await binding.setSurfaceSize(null);
    });

    final orchestrator = LiveEditOrchestrator();
    debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

    await app.main();
    await _pumpUntil(
      tester,
      () => find.text('MCP Toolkit Demo').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(tester, () => orchestrator.overlayVisible);

    final sessionId = orchestrator.ensureSession();
    await tester.tap(find.text('About This Demo'), warnIfMissed: false);
    await tester.pumpAndSettle();
    await _pumpUntil(tester, () => orchestrator.activeSelection != null);

    final promotedSelection = orchestrator.activeSelection!;
    final promotedCandidates = orchestrator.activeSelectionCandidates;
    expect(promotedSelection.widgetType, isNot('RichText'));
    expect(promotedSelection.source, isNotNull);
    expect(promotedSelection.source!.file, contains('lib/main.dart'));
    expect(promotedCandidates, isNotEmpty);

    final promotedIndex = promotedCandidates.indexWhere(
      (final candidate) => candidate.nodeId == promotedSelection.nodeId,
    );
    expect(promotedIndex, greaterThan(0));
    expect(promotedCandidates[promotedIndex].createdByLocalProject, isTrue);
    expect(promotedCandidates.first.widgetType, 'RichText');
    expect(promotedCandidates.first.createdByLocalProject, isFalse);

    final selectParentResult = orchestrator.controller.selectParent(
      sessionId: sessionId,
    );
    expect(selectParentResult['selected'], isTrue);

    final selectChildResult = orchestrator.controller.selectChild(
      sessionId: sessionId,
    );
    expect(selectChildResult['selected'], isTrue);
    final childSelection =
        (selectChildResult['selection'] as Map<Object?, Object?>)
            .cast<String, Object?>();
    expect(childSelection['nodeId'], promotedSelection.nodeId);

    final deepestResult = orchestrator.controller.selectCandidate(
      sessionId: sessionId,
      index: 0,
    );
    expect(deepestResult['selected'], isTrue);
    final deepestSelection =
        (deepestResult['selection'] as Map<Object?, Object?>)
            .cast<String, Object?>();
    expect(deepestSelection['nodeId'], promotedCandidates.first.nodeId);
    expect(deepestSelection['nodeId'], isNot(promotedSelection.nodeId));
  });

  testWidgets('bubble header drag repositions the live edit bubble', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await binding.setSurfaceSize(null);
    });

    final orchestrator = LiveEditOrchestrator();
    debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

    await app.main();
    await _pumpUntil(
      tester,
      () => find.text('MCP Toolkit Demo').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(tester, () => orchestrator.overlayVisible);

    final aboutHeading = _semanticsId('about_demo_heading');
    await tester.tap(aboutHeading, warnIfMissed: false);
    await tester.pumpAndSettle();
    if (orchestrator.activeSelection == null) {
      orchestrator.selectNode(tester.getCenter(aboutHeading));
      await _pumpUntil(tester, () => orchestrator.activeSelection != null);
    }

    final bubbleBefore = tester.getTopLeft(
      _semanticsId('live_edit_selection_bubble'),
    );
    await tester.drag(
      _semanticsId('live_edit_bubble_drag_handle'),
      const Offset(72, 44),
    );
    await tester.pumpAndSettle();

    final bubbleAfter = tester.getTopLeft(
      _semanticsId('live_edit_selection_bubble'),
    );
    expect(bubbleAfter.dx, closeTo(bubbleBefore.dx + 72, 3));
    expect(bubbleAfter.dy, closeTo(bubbleBefore.dy + 44, 3));
    expect(orchestrator.marqueeRect, isNull);
  });

  testWidgets(
    'marquee includes all covered user widgets in the stateful branch',
    (final tester) async {
      final binding = IntegrationTestWidgetsFlutterBinding.instance;
      await binding.setSurfaceSize(const Size(8000, 2000));
      addTearDown(() async {
        debugFlutterLiveEditAutoHostOrchestratorOverride = null;
        await binding.setSurfaceSize(null);
      });

      final orchestrator = LiveEditOrchestrator();
      debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

      await app.main();
      await _pumpUntil(
        tester,
        () => find.text('MCP Toolkit Demo').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
      );

      await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await _pumpUntil(tester, () => orchestrator.overlayVisible);

      final dragStart =
          tester.getTopLeft(_semanticsId('counter_demo_icon')) -
          const Offset(8, 8);
      final dragEnd =
          tester.getBottomRight(
            _semanticsId('stateful_counter_increment_button'),
          ) +
          const Offset(8, 8);
      final gesture = await tester.startGesture(
        dragStart,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(dragEnd);
      await gesture.up();
      await tester.pumpAndSettle();

      final widgetTypes = orchestrator.activeMultiSelection
          .map((final selection) => selection.widgetType)
          .toSet();
      expect(widgetTypes, contains('Icon'));
      expect(widgetTypes, contains('Text'));
      expect(widgetTypes, contains('ElevatedButton'));
      expect(widgetTypes, contains('StatefulCounterWidget'));
      expect(widgetTypes, isNot(contains('Row')));
      expect(widgetTypes, isNot(contains('Column')));
      expect(widgetTypes, isNot(contains('Padding')));
      expect(widgetTypes, isNot(contains('Container')));
    },
  );
}

Finder _panelScrollable() => find
    .descendant(
      of: _semanticsId('live_edit_panel'),
      matching: find.byType(Scrollable),
    )
    .first;

Future<void> _pumpUntil(
  final WidgetTester tester,
  final bool Function() condition, {
  final Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('Timed out waiting for condition after $timeout');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _semanticsId(final String id) => find.byWidgetPredicate(
  (final widget) => widget is Semantics && widget.properties.identifier == id,
  description: 'Semantics identifier $id',
);
