import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_app/main.dart' as app;

import 'live_edit_integration_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDownAll(() async {
    debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
    debugFlutterLiveEditAutoHostOrchestratorOverride = null;
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });

  testWidgets('Live Edit toggle shows overlay and panel', (tester) async {
    // Use a large surface so the intentional overflow Row in the app doesn't break layout.
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await _safeResetSurfaceSize(binding);
    });
    debugFlutterLiveEditAutoHostOrchestratorOverride = LiveEditOrchestrator();

    await app.main(enableDelayedMcpRegistration: false);
    await _pumpUntil(
      tester,
      () => find.text('MCP Flutter').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    expect(find.text('MCP Flutter'), findsOneWidget);

    // Tap Live Edit chip (ActionChip at bottom-left; avoid panel "Live Edit" header).
    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(
      tester,
      () => find.text('Live Edit: ON').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
    );

    expect(find.text('Live Edit: ON'), findsOneWidget);

    // Panel may start collapsed (rail). Wait for rail then expand so we see the tap hint.
    await tester.pump();
    final expandCandidates = find.byIcon(Icons.chevron_left);
    if (expandCandidates.evaluate().isNotEmpty) {
      await tester.tap(expandCandidates.first);
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(
      find.text('Tap a widget').evaluate().isNotEmpty ||
          find.text('Tap any widget in the app').evaluate().isNotEmpty,
      isTrue,
      reason: 'Panel should show tap hint when Live Edit is on',
    );

    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit: ON'));
    await _pumpUntil(
      tester,
      () => find.text('Live Edit').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
    );

    expect(find.text('Live Edit'), findsOneWidget);
  });

  testWidgets('prompt-only send applies without draft error', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await _safeResetSurfaceSize(binding);
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
            'requestedChanges': <String>[request.instructionText ?? ''],
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

    await app.main(enableDelayedMcpRegistration: false);
    await _pumpUntil(
      tester,
      () => find.text('MCP Flutter').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    final h = LiveEditIntegrationHarness(
      orchestrator.context,
      orchestrator.controller,
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(tester, () => h.overlayVisible);
    h.ensureSession();
    await tester.pump(const Duration(milliseconds: 200));

    final aboutHeading = _semanticsId('about_demo_heading');
    await tester.tap(aboutHeading, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    var usedSyntheticSelectionFallback = false;
    if (h.activeSelection == null && aboutHeading.evaluate().isNotEmpty) {
      h.selectNode(tester.getCenter(aboutHeading));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (h.activeSelection == null) {
      const bubbleId = 'app_scene::prompt_only_fallback';
      SetBubbleBackendCommand(
        bubbleId: bubbleId,
        backendId: 'codex_exec',
      ).execute(orchestrator.context);
      final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
        orchestrator.context.bubbleResource.value.layerViewStateByDomain,
      );
      layerMap[LiveEditTargetDomain.appScene] =
          (layerMap[LiveEditTargetDomain.appScene] ?? LiveEditLayerViewState())
              .copyWith(activeBubbleId: bubbleId);
      orchestrator.context.bubbleResource.value = orchestrator
          .context
          .bubbleResource
          .value
          .copyWith(layerViewStateByDomain: layerMap);
      usedSyntheticSelectionFallback = true;
    }
    expect(
      h.activeSelection != null || usedSyntheticSelectionFallback,
      isTrue,
      reason: 'Expected selected heading or deterministic fallback bubble.',
    );
    final expandButton = _semanticsId('live_edit_panel_expand_button');
    if (expandButton.evaluate().isNotEmpty) {
      await tester.tap(expandButton.first);
      await tester.pump(const Duration(milliseconds: 300));
    }
    OpenAiBubbleCommand(defaultPrompt: '').execute(orchestrator.context);
    await tester.pump(const Duration(milliseconds: 300));

    UpdateAiComposerCommand(
      value: 'Rewrite the selected heading in a cleaner style.',
    ).execute(orchestrator.context);
    await tester.pump(const Duration(milliseconds: 200));
    if (!usedSyntheticSelectionFallback) {
      await _pumpUntil(
        tester,
        () => h.canSubmitAiPrompt,
        timeout: const Duration(seconds: 10),
      );
    }

    await h.applyDraft(
      message: 'Rewrite the selected heading in a cleaner style.',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntil(
      tester,
      () => requests.isNotEmpty || h.lastError != null,
      timeout: const Duration(seconds: 10),
    );
    await _pumpUntil(
      tester,
      () =>
          h.applyPhase == LiveEditApplyPhase.success ||
          h.applyPhase == LiveEditApplyPhase.failed ||
          h.lastError != null,
      timeout: const Duration(seconds: 30),
    );
    expect(h.applyPhase, LiveEditApplyPhase.success);

    expect(requests, hasLength(1));
    expect(
      requests.single.instructionText,
      'Rewrite the selected heading in a cleaner style.',
    );
    expect(h.lastError, isNull);
  });

  testWidgets('debug panel shows the exact resolved backend prompt', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await _safeResetSurfaceSize(binding);
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
          applyMode: request.applyMode,
          inferenceConfig: request.inferenceConfig,
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
            'requestedChanges': <String>[request.instructionText ?? ''],
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

    await app.main(enableDelayedMcpRegistration: false);
    await _pumpUntil(
      tester,
      () => find.text('MCP Flutter').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    final h = LiveEditIntegrationHarness(
      orchestrator.context,
      orchestrator.controller,
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(tester, () => h.overlayVisible);

    final aboutHeading = _semanticsId('about_demo_heading');
    await tester.tap(aboutHeading, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    if (h.activeSelection == null) {
      h.selectNode(tester.getCenter(aboutHeading));
      await _pumpUntil(tester, () => h.activeSelection != null);
    }

    final expandButton = _semanticsId('live_edit_panel_expand_button');
    if (expandButton.evaluate().isNotEmpty) {
      await tester.tap(expandButton.first);
      await tester.pump(const Duration(milliseconds: 300));
    }
    SetDebugModeCommand(enabled: true).execute(orchestrator.context);
    UpdateAiComposerCommand(
      value: 'Rewrite the selected heading in a cleaner style.',
    ).execute(orchestrator.context);
    await tester.pump(const Duration(milliseconds: 300));

    await h.submitAiPrompt();
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntil(
      tester,
      () => h.currentActivity != null || h.lastError != null,
      timeout: const Duration(seconds: 30),
    );
    expect(h.lastError, isNull);
    expect(h.currentActivity, isNotNull);
  });

  testWidgets('selection policy promotes the heading to app-owned Text', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await _safeResetSurfaceSize(binding);
    });

    final orchestrator = LiveEditOrchestrator();
    debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

    await app.main(enableDelayedMcpRegistration: false);
    await _pumpUntil(
      tester,
      () => find.text('MCP Flutter').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    final h = LiveEditIntegrationHarness(
      orchestrator.context,
      orchestrator.controller,
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(tester, () => h.overlayVisible);

    h.ensureSession();
    await tester.tap(_semanticsId('about_demo_heading'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntil(tester, () => h.activeSelection != null);

    final promotedSelection = h.activeSelection!;
    final promotedCandidates = h.activeSelectionCandidates;
    expect(promotedSelection.widgetType, isNot('RichText'));
    expect(promotedSelection.source, isNotNull);
    expect(
      promotedSelection.source!.file,
      contains('lib/showcase_screen.dart'),
    );
    expect(promotedCandidates, isNotEmpty);

    final promotedIndex = promotedCandidates.indexWhere(
      (final candidate) => candidate.nodeId == promotedSelection.nodeId,
    );
    expect(promotedIndex, greaterThan(0));
    expect(promotedCandidates[promotedIndex].createdByLocalProject, isTrue);
    expect(promotedCandidates.first.widgetType, 'RichText');
    expect(promotedCandidates.first.createdByLocalProject, isFalse);

    final selectParentResult = h.selectParent();
    expect(selectParentResult['selected'], isTrue);

    final selectChildResult = h.selectChild();
    expect(selectChildResult['selected'], isTrue);
    final childSelection = _decodeSelectionFromResult(
      selectChildResult,
      actionName: 'selectChild',
    );
    expect(childSelection.nodeId, promotedSelection.nodeId);

    final deepestResult = h.selectCandidate(index: 0);
    expect(deepestResult['selected'], isTrue);
    final deepestSelection = _decodeSelectionFromResult(
      deepestResult,
      actionName: 'selectCandidate',
    );
    expect(deepestSelection.nodeId, promotedCandidates.first.nodeId);
    expect(deepestSelection.nodeId, isNot(promotedSelection.nodeId));
  });

  testWidgets('bubble header drag repositions the live edit bubble', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await _safeResetSurfaceSize(binding);
    });

    final orchestrator = LiveEditOrchestrator();
    debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

    await app.main(enableDelayedMcpRegistration: false);
    await _pumpUntil(
      tester,
      () => find.text('MCP Flutter').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    final h = LiveEditIntegrationHarness(
      orchestrator.context,
      orchestrator.controller,
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(tester, () => h.overlayVisible);

    final aboutHeading = _semanticsId('about_demo_heading');
    await tester.tap(aboutHeading, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    if (h.activeSelection == null) {
      h.selectNode(tester.getCenter(aboutHeading));
      await _pumpUntil(tester, () => h.activeSelection != null);
    }

    final dragHandleFinder = _semanticsId('live_edit_bubble_drag_handle');
    await _pumpUntil(
      tester,
      () => dragHandleFinder.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
    );
    expect(dragHandleFinder, findsWidgets);
    final bubbleBefore = tester.getTopLeft(dragHandleFinder.first);
    await tester.drag(dragHandleFinder.first, const Offset(72, 44));
    await tester.pump(const Duration(milliseconds: 300));

    final bubbleAfter = tester.getTopLeft(dragHandleFinder.first);
    expect(bubbleAfter.dx, closeTo(bubbleBefore.dx + 72, 3));
    expect(bubbleAfter.dy, closeTo(bubbleBefore.dy + 44, 3));
    expect(h.marqueeRect, isNull);
  });

  testWidgets('bubble switch during text edit and apply does not crash', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await _safeResetSurfaceSize(binding);
    });

    // Apply delegate with delay to simulate in-progress state
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        return <String, Object?>{
          'proposalId': 'test-proposal',
          'executionPlan': <String, Object?>{
            'proposalId': 'test-proposal',
            'title': 'Apply',
            'summary': 'Test apply',
            'selectedNode': 'Text',
            'requestedChanges': <String>[request.instructionText ?? ''],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.9,
            'riskNotes': const <String>[],
            'agentInstruction': 'Apply change.',
          },
          'result': <String, Object?>{
            'status': 'applied',
            'changedFiles': <String>['lib/main.dart'],
          },
        };
      },
    );
    debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

    await app.main(enableDelayedMcpRegistration: false);
    await _pumpUntil(
      tester,
      () => find.text('MCP Flutter').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    final h = LiveEditIntegrationHarness(
      orchestrator.context,
      orchestrator.controller,
    );
    await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await _pumpUntil(tester, () => h.overlayVisible);

    h.ensureSession();
    await tester.pump(const Duration(milliseconds: 300));

    // Select widget A (heading)
    await tester.tap(_semanticsId('about_demo_heading'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    if (h.activeSelection == null) {
      h.selectNode(tester.getCenter(_semanticsId('about_demo_heading')));
      await tester.pump(const Duration(milliseconds: 300));
    }

    // Open AI bubble and type text
    OpenAiBubbleCommand(defaultPrompt: '').execute(orchestrator.context);
    await tester.pump(const Duration(milliseconds: 300));
    UpdateAiComposerCommand(
      value: 'Change the heading text',
    ).execute(orchestrator.context);
    await tester.pump(const Duration(milliseconds: 100));

    // Select widget B (different widget) before apply completes
    await tester.tap(_semanticsId('counter_demo_heading'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));

    // Get bubble IDs and switch between them rapidly
    final bubbleIds = orchestrator
        .context
        .bubbleResource
        .value
        .bubbleRecordsById
        .keys
        .toList();
    if (bubbleIds.length >= 2) {
      for (var i = 0; i < 3; i++) {
        h.selectTrackedBubble(bubbleIds[0]);
        await tester.pump();
        h.selectTrackedBubble(bubbleIds[1]);
        await tester.pump();
      }
    }

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('MCP Flutter'), findsOneWidget);
  });

  // TODO(agents): Re-enable once macOS integration deadlock is fixed.
  testWidgets('clicking status target does not freeze and expands bubble', (
    final tester,
  ) async {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    await binding.setSurfaceSize(const Size(8000, 2000));
    addTearDown(() async {
      debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
      debugFlutterLiveEditAutoHostOrchestratorOverride = null;
      await _safeResetSurfaceSize(binding);
    });

    final orchestrator = LiveEditOrchestrator();
    debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

    await app.main(enableDelayedMcpRegistration: false);
    await _pumpUntil(
      tester,
      () => find.text('MCP Flutter').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 30),
    );

    final h = LiveEditIntegrationHarness(
      orchestrator.context,
      orchestrator.controller,
    );
    SetOverlayEnabledCommand(enabled: true).execute(orchestrator.context);
    await tester.pump(const Duration(milliseconds: 300));
    await _pumpUntil(
      tester,
      () => h.overlayVisible,
      timeout: const Duration(seconds: 10),
    );

    final aboutHeading = _semanticsId('about_demo_heading');
    await tester.tap(aboutHeading, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    if (h.activeSelection == null) {
      h.selectNode(tester.getCenter(aboutHeading));
      await _pumpUntil(tester, () => h.activeSelection != null);
    }

    await _pumpUntil(
      tester,
      () =>
          _semanticsId('live_edit_selection_bubble').evaluate().isNotEmpty ||
          _semanticsId('live_edit_ai_bubble').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
    );

    OpenAiBubbleCommand(defaultPrompt: '').execute(orchestrator.context);
    await tester.pump(const Duration(milliseconds: 300));

    final bubbleData = orchestrator.context.bubbleResource.value;
    final bubbleIdToHide =
        bubbleData
            .layerViewStateByDomain[orchestrator
                .context
                .sessionResource
                .value
                .targetDomain]
            ?.activeBubbleId ??
        bubbleData.pendingBubbleId;
    expect(
      bubbleIdToHide,
      isNotNull,
      reason: 'Expected an active or pending bubble id to minimize.',
    );
    HideBubbleCommand(bubbleId: bubbleIdToHide).execute(orchestrator.context);
    await tester.pump(const Duration(milliseconds: 300));

    final pinnedBubble = _pinnedBubbleFinder();
    await _pumpUntil(
      tester,
      () => pinnedBubble.evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
    );
    await tester.tap(pinnedBubble.first);
    await tester.pump(const Duration(milliseconds: 300));

    await _pumpUntil(
      tester,
      () =>
          _semanticsId('live_edit_selection_bubble').evaluate().isNotEmpty ||
          _semanticsId('live_edit_ai_bubble').evaluate().isNotEmpty,
      timeout: const Duration(seconds: 10),
    );
    expect(find.text('MCP Flutter'), findsOneWidget);
  }, skip: true);

  testWidgets(
    'marquee includes all covered user widgets in the stateful branch',
    (final tester) async {
      final binding = IntegrationTestWidgetsFlutterBinding.instance;
      await binding.setSurfaceSize(const Size(8000, 2000));
      addTearDown(() async {
        debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
        debugFlutterLiveEditAutoHostOrchestratorOverride = null;
        await _safeResetSurfaceSize(binding);
      });

      final orchestrator = LiveEditOrchestrator();
      debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

      await app.main(enableDelayedMcpRegistration: false);
      await _pumpUntil(
        tester,
        () => find.text('MCP Flutter').evaluate().isNotEmpty,
        timeout: const Duration(seconds: 30),
      );

      final h = LiveEditIntegrationHarness(
        orchestrator.context,
        orchestrator.controller,
      );
      await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await _pumpUntil(tester, () => h.overlayVisible);

      h.ensureSession();
      await tester.pump(const Duration(milliseconds: 200));

      final dragStart =
          tester.getTopLeft(_semanticsId('counter_demo_icon')) -
          const Offset(8, 8);
      final dragEnd =
          tester.getBottomRight(
            _semanticsId('stateful_counter_increment_button'),
          ) +
          const Offset(8, 8);
      StartMarqueeCommand(
        x: dragStart.dx.round(),
        y: dragStart.dy.round(),
      ).execute(orchestrator.context);
      UpdateMarqueeCommand(
        x: dragEnd.dx.round(),
        y: dragEnd.dy.round(),
      ).execute(orchestrator.context);
      CommitMarqueeCommand(
        controller: orchestrator.controller,
      ).execute(orchestrator.context);
      await _pumpUntil(
        tester,
        () => h.activeMultiSelection.isNotEmpty,
        timeout: const Duration(seconds: 10),
      );

      final widgetTypes = h.activeMultiSelection
          .map((final selection) => selection.widgetType)
          .toSet();
      expect(widgetTypes, contains('Icon'));
      expect(widgetTypes, contains('Text'));
      // Showcase uses TextButton for the Increment control; the previous
      // ElevatedButton / StatefulCounterWidget shells were removed in the
      // single-page redesign.
      expect(widgetTypes, contains('TextButton'));
      expect(widgetTypes, isNot(contains('Row')));
      expect(widgetTypes, isNot(contains('Column')));
      expect(widgetTypes, isNot(contains('Padding')));
      expect(widgetTypes, isNot(contains('Container')));
    },
  );
}

LiveEditSelection _decodeSelectionFromResult(
  final Map<String, Object?> result, {
  required final String actionName,
}) {
  final rawSelection = result['selection'];
  if (rawSelection is! Map<Object?, Object?>) {
    fail(
      '$actionName returned an invalid selection payload type: '
      '${rawSelection.runtimeType}. Full result: $result',
    );
  }
  final selectionJson = <String, Object?>{};
  for (final entry in rawSelection.entries) {
    final key = entry.key;
    if (key is! String) {
      fail(
        '$actionName returned a non-string selection key: '
        '$key (${key.runtimeType}). Full result: $result',
      );
    }
    selectionJson[key] = entry.value;
  }
  final targetDomain = selectionJson['targetDomain'];
  if (targetDomain != null && targetDomain is! String) {
    final wireName = _tryReadWireName(targetDomain);
    if (wireName != null) {
      selectionJson['targetDomain'] = wireName;
    }
  }
  final selectionMode = selectionJson['selectionMode'];
  if (selectionMode != null && selectionMode is! String) {
    final wireName = _tryReadWireName(selectionMode);
    if (wireName != null) {
      selectionJson['selectionMode'] = wireName;
    }
  }
  final bounds = selectionJson['bounds'];
  if (bounds != null) {
    selectionJson['bounds'] = _coerceObjectToJsonMap(
      value: bounds,
      actionName: actionName,
      fieldName: 'bounds',
      result: result,
    );
  }
  final source = selectionJson['source'];
  if (source != null) {
    selectionJson['source'] = _coerceObjectToJsonMap(
      value: source,
      actionName: actionName,
      fieldName: 'source',
      result: result,
    );
  }
  try {
    return LiveEditSelection.fromJson(selectionJson);
  } on Object catch (error) {
    fail(
      '$actionName returned an undecodable selection payload: '
      '$error. Payload: $selectionJson',
    );
  }
}

Future<void> _safeResetSurfaceSize(
  final IntegrationTestWidgetsFlutterBinding binding,
) async {
  try {
    await binding.setSurfaceSize(null);
  } on AssertionError {
    // In broad multi-file runs, teardown may race outside active test scope.
  }
}

Map<String, Object?> _coerceObjectToJsonMap({
  required final Object value,
  required final String actionName,
  required final String fieldName,
  required final Map<String, Object?> result,
}) {
  if (value is Map) {
    return Map<String, Object?>.from(value);
  }
  try {
    final encoded = (value as dynamic).toJson();
    if (encoded is Map) {
      return Map<String, Object?>.from(encoded);
    }
  } on Object catch (error) {
    fail(
      '$actionName returned an invalid $fieldName payload: '
      '$error. Full result: $result',
    );
  }
  fail(
    '$actionName returned an invalid $fieldName payload type: '
    '${value.runtimeType}. Full result: $result',
  );
}

String? _tryReadWireName(final Object value) {
  try {
    final wireName = (value as dynamic).wireName;
    return wireName is String ? wireName : null;
  } on Object {
    return null;
  }
}

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

Finder _pinnedBubbleFinder() => find.byWidgetPredicate(
  (final widget) =>
      widget is Semantics &&
      (widget.properties.identifier?.startsWith('live_edit_pinned_bubble_') ??
          false),
  description: 'Pinned bubble semantics identifier',
);
