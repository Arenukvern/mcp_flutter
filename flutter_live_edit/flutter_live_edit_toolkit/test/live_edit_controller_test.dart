import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _semanticsId(final String id) => find.byWidgetPredicate(
  (final widget) => widget is Semantics && widget.properties.identifier == id,
);

Finder _activeBubble(final LiveEditOrchestrator orchestrator) => _semanticsId(
  orchestrator.editMode == LiveEditEditMode.ai
      ? 'live_edit_ai_bubble'
      : 'live_edit_selection_bubble',
);

Size _viewportSize(final WidgetTester tester) => Size(
  tester.view.physicalSize.width / tester.view.devicePixelRatio,
  tester.view.physicalSize.height / tester.view.devicePixelRatio,
);

Finder _aiPromptField() => find.byWidgetPredicate(
  (final widget) =>
      widget is TextField &&
      widget.decoration?.hintText?.startsWith('Talk to ') == true,
);

Finder _panelScrollable() => find
    .descendant(
      of: _semanticsId('live_edit_panel'),
      matching: find.byType(Scrollable),
    )
    .first;

List<LiveEditAgentBackend> _testBackends() => const <LiveEditAgentBackend>[
  LiveEditAgentBackend(
    id: 'codex_exec',
    label: 'Codex',
    description: 'Codex backend',
    available: true,
    isDefault: true,
    meta: <String, Object?>{
      'defaultInferenceConfig': <String, Object?>{
        'model': 'gpt-5.3-codex',
        'reasoningEffort': 'medium',
      },
      'effectiveInferenceConfig': <String, Object?>{
        'model': 'gpt-5.3-codex',
        'reasoningEffort': 'medium',
      },
      'supportedModels': <Map<String, Object?>>[
        <String, Object?>{'id': 'gpt-5.3-codex', 'label': 'GPT-5.3-Codex'},
        <String, Object?>{'id': 'gpt-5.4', 'label': 'GPT-5.4'},
      ],
      'supportedReasoningEfforts': <String>['low', 'medium', 'high'],
    },
  ),
  LiveEditAgentBackend(
    id: 'cursor_agent',
    label: 'Cursor',
    description: 'Cursor backend',
    available: true,
    meta: <String, Object?>{
      'defaultInferenceConfig': <String, Object?>{'model': 'claude-3-5-sonnet'},
      'effectiveInferenceConfig': <String, Object?>{
        'model': 'claude-3-5-sonnet',
      },
    },
  ),
];

void main() {
  Future<void> selectEditableCandidate(
    final WidgetTester tester,
    final LiveEditOrchestrator orchestrator,
  ) async {
    if (orchestrator.activeSelection?.propertyGroups.any(
          (final property) => property.editable,
        ) ==
        true) {
      return;
    }
    for (
      var index = 0;
      index < orchestrator.activeSelectionCandidates.length;
      index += 1
    ) {
      orchestrator.selectCandidateAt(index);
      await tester.pumpAndSettle();
      if (orchestrator.activeSelection?.propertyGroups.any(
            (final property) => property.editable,
          ) ==
          true) {
        return;
      }
    }
  }

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

  testWidgets('panel shows codex inference controls from backend metadata', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator(
      availableBackends: _testBackends(),
      backendId: 'codex_exec',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(body: Text('Target')),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Target')));
    await tester.pumpAndSettle();

    expect(_semanticsId('live_edit_model_dropdown'), findsOneWidget);
    expect(_semanticsId('live_edit_reasoning_dropdown'), findsOneWidget);
    expect(orchestrator.currentModel, 'gpt-5.3-codex');
    expect(orchestrator.currentReasoningEffort, 'medium');
  });

  testWidgets('switching to cursor exposes free-form model input', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator(
      availableBackends: _testBackends(),
      backendId: 'codex_exec',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(body: Text('Target')),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Target')));
    await tester.pumpAndSettle();
    orchestrator.setBackend('cursor_agent');
    await tester.pumpAndSettle();

    expect(_semanticsId('live_edit_model_input'), findsOneWidget);
    expect(_semanticsId('live_edit_reasoning_dropdown'), findsNothing);
    expect(orchestrator.currentBackendUsesFreeformModel, isTrue);
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
    expect(_semanticsId('live_edit_panel_rail'), findsOneWidget);
    await tester.tapAt(tester.getCenter(find.text('Target')));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsWidgets);
    expect(find.text('Selected'), findsWidgets);
    expect(find.text('Target'), findsWidgets);
  });

  testWidgets('dragging the bubble moves it without starting marquee', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
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

    final bubbleBefore = tester.getTopLeft(_activeBubble(orchestrator));
    final selectedNodeId = orchestrator.activeSelection?.nodeId;
    expect(selectedNodeId, isNotNull);

    await tester.drag(
      _semanticsId('live_edit_bubble_drag_handle'),
      const Offset(48, 36),
    );
    await tester.pumpAndSettle();

    final bubbleAfter = tester.getTopLeft(_activeBubble(orchestrator));
    expect(bubbleAfter.dx, greaterThan(bubbleBefore.dx));
    expect(bubbleAfter.dy, greaterThan(bubbleBefore.dy));
    expect(bubbleAfter.dx - bubbleBefore.dx, lessThanOrEqualTo(48));
    expect(bubbleAfter.dy - bubbleBefore.dy, lessThanOrEqualTo(36));
    expect(orchestrator.activeSelection?.nodeId, selectedNodeId);
    expect(orchestrator.marqueeRect, isNull);
    expect(orchestrator.bubbleDragOffset.dx, closeTo(48, 2));
    expect(orchestrator.bubbleDragOffset.dy, closeTo(36, 2));
  });

  testWidgets('bubble drag survives AI mode and selection changes', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: Scaffold(
            body: Stack(
              children: const <Widget>[
                Positioned(left: 80, top: 80, child: Text('First')),
                Positioned(right: 80, bottom: 120, child: Text('Second')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('First')));
    await tester.pumpAndSettle();

    final firstBefore = tester.getTopLeft(_activeBubble(orchestrator));
    await tester.drag(
      _semanticsId('live_edit_bubble_drag_handle'),
      const Offset(60, 24),
    );
    await tester.pumpAndSettle();

    final firstDragged = tester.getTopLeft(_activeBubble(orchestrator));
    expect(firstDragged.dx - firstBefore.dx, closeTo(60, 2));
    expect(firstDragged.dy, greaterThanOrEqualTo(firstBefore.dy));
    expect(firstDragged.dy - firstBefore.dy, lessThanOrEqualTo(24));
    expect(orchestrator.bubbleDragOffset.dx, closeTo(60, 2));
    expect(orchestrator.bubbleDragOffset.dy, closeTo(24, 2));

    orchestrator.openAiBubble();
    await tester.pumpAndSettle();
    final aiBubble = tester.getTopLeft(_activeBubble(orchestrator));
    expect(aiBubble.dx, closeTo(firstDragged.dx, 2));
    expect(aiBubble.dy, closeTo(firstDragged.dy, 2));

    await tester.tapAt(tester.getCenter(find.text('Second')));
    await tester.pumpAndSettle();
    final secondPlacement = orchestrator.bubblePlacement(
      bounds: orchestrator.activeSelection!.bounds!,
      viewport: _viewportSize(tester),
    );
    final secondDragged = tester.getTopLeft(_activeBubble(orchestrator));
    expect(secondDragged.dx, closeTo(secondPlacement.dx, 2));
    expect(secondDragged.dy, closeTo(secondPlacement.dy, 2));
  });

  testWidgets('bubble stays clamped after drag and resize', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(
            body: Align(alignment: Alignment.topLeft, child: Text('Target')),
          ),
        ),
      ),
    );

    await tester.binding.setSurfaceSize(const Size(520, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Target')));
    await tester.pumpAndSettle();

    await tester.drag(find.byIcon(Icons.open_in_full), const Offset(80, 80));
    await tester.pumpAndSettle();
    await tester.drag(
      _semanticsId('live_edit_bubble_drag_handle'),
      const Offset(800, 800),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      _semanticsId('live_edit_bubble_drag_handle'),
      const Offset(-120, -80),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();

    final bubbleRect = tester.getRect(_activeBubble(orchestrator));
    expect(bubbleRect.left, greaterThanOrEqualTo(16));
    expect(bubbleRect.top, greaterThanOrEqualTo(16));
    expect(bubbleRect.right, lessThanOrEqualTo(520 - 16));
    expect(bubbleRect.bottom, lessThanOrEqualTo(520 - 16));
    expect(tester.getSize(_activeBubble(orchestrator)).width, greaterThan(300));
    expect(
      tester.getSize(_activeBubble(orchestrator)).height,
      greaterThan(300),
    );
  });

  testWidgets('right panel starts as collapsed rail', (final tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FlutterLiveEditHost(child: Scaffold(body: Text('Hello'))),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    expect(_semanticsId('live_edit_panel_rail'), findsOneWidget);
  });

  testWidgets('backend switcher renders and changes selected backend', (
    final tester,
  ) async {
    final requests = <LiveEditApplyDraftRequest>[];
    final orchestrator = LiveEditOrchestrator(
      backendId: 'codex_exec',
      availableBackends: _testBackends(),
      applyDraftDelegate: (final request) async {
        requests.add(request);
        return <String, Object?>{
          'proposalId': 'proposal-switch',
          'executionPlan': <String, Object?>{
            'proposalId': 'proposal-switch',
            'title': 'Apply live edit',
            'summary': 'Cursor prepared a patch and is applying it.',
            'selectedNode': 'Text',
            'requestedChanges': <String>['Rewrite the selected text.'],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.9,
            'riskNotes': const <String>[],
            'agentInstruction': 'Apply the selected changes.',
          },
        };
      },
    );

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
    await selectEditableCandidate(tester, orchestrator);
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();

    expect(find.text('Backend'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Codex'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Cursor'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Cursor'));
    await tester.pumpAndSettle();

    expect(orchestrator.currentBackendId, 'cursor_agent');
    expect(orchestrator.currentBackendLabel, 'Cursor');

    final editable = orchestrator.activeSelection!.propertyGroups.firstWhere(
      (final property) => property.editable,
    );
    orchestrator.updateDraft(property: editable, targetValue: 'Hello');
    await tester.pumpAndSettle();
    await orchestrator.applyDraft();
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.backendId, 'cursor_agent');
    expect(find.textContaining('Cursor'), findsWidgets);
  });

  testWidgets('unavailable backend cannot be selected from switcher', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator(
      backendId: 'codex_exec',
      availableBackends: const <LiveEditAgentBackend>[
        LiveEditAgentBackend(
          id: 'codex_exec',
          label: 'Codex',
          description: 'Codex backend',
          available: true,
          isDefault: true,
        ),
        LiveEditAgentBackend(
          id: 'cursor_agent',
          label: 'Cursor',
          description: 'Cursor backend',
          available: false,
        ),
      ],
    );

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
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Cursor offline'),
    );
    expect(chip.onSelected, isNull);

    orchestrator.setBackend('cursor_agent');
    await tester.pumpAndSettle();

    expect(orchestrator.currentBackendId, 'codex_exec');
  });

  testWidgets(
    'native-style candidate ordering prefers the smallest hit first',
    (final tester) async {
      final orchestrator = LiveEditOrchestrator();
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

      expect(orchestrator.activeSelection, isNotNull);
      expect(orchestrator.activeSelectionCandidates.length, greaterThan(1));
      final first = orchestrator.activeSelectionCandidates.first.bounds!;
      final second = orchestrator.activeSelectionCandidates[1].bounds!;
      expect(
        first.width * first.height,
        lessThanOrEqualTo(second.width * second.height),
      );
    },
  );

  testWidgets('hover highlights a node without selecting it', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(body: Center(child: Text('Hover me'))),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(tester.getCenter(find.text('Hover me')));
    await tester.pumpAndSettle();

    expect(orchestrator.hoverSelection, isNotNull);
    expect(orchestrator.activeSelection, isNull);
  });

  testWidgets('hover reuses lightweight selection for tiny pointer movement', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(body: Center(child: Text('Hover me'))),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    final center = tester.getCenter(find.text('Hover me'));
    await gesture.moveTo(center);
    await tester.pumpAndSettle();

    final firstHover = orchestrator.hoverSelection;
    expect(firstHover, isNotNull);
    expect(firstHover!.detailsTree, isEmpty);
    expect(firstHover.propertiesTree, isEmpty);

    await gesture.moveTo(center + const Offset(2, 2));
    await tester.pumpAndSettle();

    expect(identical(orchestrator.hoverSelection, firstHover), isTrue);
    expect(orchestrator.activeSelection, isNull);
  });

  testWidgets('deeper hover advances to next cached candidate', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
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
    final center = tester.getCenter(find.text('Target'));
    await tester.tapAt(center);
    await tester.pumpAndSettle();

    final selectedNodeId = orchestrator.activeSelection!.nodeId;
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(center);
    await tester.pumpAndSettle();

    final normalHover = orchestrator.hoverSelection;
    expect(normalHover, isNotNull);

    orchestrator.setDeeperPickEnabled(true);
    await tester.pumpAndSettle();
    await gesture.moveTo(center + const Offset(1, 1));
    await tester.pumpAndSettle();

    expect(orchestrator.hoverSelection, isNotNull);
    expect(orchestrator.hoverSelection!.nodeId, isNot(normalHover!.nodeId));
  });

  testWidgets('deeper hover reuses cached preview under tiny movement', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
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
    final center = tester.getCenter(find.text('Target'));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    orchestrator.setDeeperPickEnabled(true);
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(center);
    await tester.pumpAndSettle();
    final firstHover = orchestrator.hoverSelection;
    expect(firstHover, isNotNull);

    await gesture.moveTo(center + const Offset(2, 2));
    await tester.pumpAndSettle();

    expect(identical(orchestrator.hoverSelection, firstHover), isTrue);
  });

  testWidgets('click after deeper hover selects the previewed candidate', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
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
    final center = tester.getCenter(find.text('Target'));
    await tester.tapAt(center);
    await tester.pumpAndSettle();

    final selectedNodeId = orchestrator.activeSelection!.nodeId;
    orchestrator.setDeeperPickEnabled(true);
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    await gesture.moveTo(center);
    await tester.pumpAndSettle();
    final previewNodeId = orchestrator.hoverSelection!.nodeId;
    expect(previewNodeId, isNot(selectedNodeId));

    await tester.tapAt(center);
    await tester.pumpAndSettle();

    expect(orchestrator.activeSelection!.nodeId, previewNodeId);
  });

  testWidgets('marquee drag selects multiple editable nodes', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(padding: EdgeInsets.all(24), child: Text('First')),
                Padding(padding: EdgeInsets.all(24), child: Text('Second')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    final start = tester.getTopLeft(find.text('First')) - const Offset(20, 20);
    final end =
        tester.getBottomRight(find.text('Second')) + const Offset(20, 20);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(orchestrator.activeMultiSelection.length, greaterThan(1));
  });

  testWidgets('touch drag also starts marquee selection', (final tester) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(padding: EdgeInsets.all(24), child: Text('First')),
                Padding(padding: EdgeInsets.all(24), child: Text('Second')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    final start = tester.getTopLeft(find.text('First')) - const Offset(20, 20);
    final end =
        tester.getBottomRight(find.text('Second')) + const Offset(20, 20);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.touch,
    );
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(orchestrator.activeMultiSelection.length, greaterThan(1));
  });

  testWidgets('small mouse movement below threshold stays single selection', (
    final tester,
  ) async {
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

    final center = tester.getCenter(find.text('Target'));
    final gesture = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(2, 2));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(orchestrator.marqueeRect, isNull);
    expect(orchestrator.activeSelection, isNotNull);
    expect(orchestrator.activeMultiSelection.length, 1);
  });

  testWidgets('drag shows lightweight marquee preview before pointer up', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(padding: EdgeInsets.all(24), child: Text('First')),
                Padding(padding: EdgeInsets.all(24), child: Text('Second')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    final start = tester.getTopLeft(find.text('First')) - const Offset(20, 20);
    final end =
        tester.getBottomRight(find.text('Second')) + const Offset(20, 20);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(end);
    await tester.pump();

    expect(orchestrator.marqueeRect, isNotNull);
    expect(orchestrator.marqueePreviewSelections, isNotEmpty);
    expect(
      orchestrator.marqueePreviewSelections.every(
        (final selection) =>
            selection.detailsTree.isEmpty && selection.propertiesTree.isEmpty,
      ),
      isTrue,
    );

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'marquee selects only covered visual nodes in the target branch',
    (final tester) async {
      final orchestrator = LiveEditOrchestrator();
      await tester.pumpWidget(
        MaterialApp(
          home: FlutterLiveEditHost(
            orchestrator: orchestrator,
            child: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Section title'),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        key: const ValueKey<String>('card_container'),
                        width: 220,
                        padding: const EdgeInsets.all(16),
                        color: Colors.orange.shade100,
                        child: const Text('Card body'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      final card = find.byKey(const ValueKey<String>('card_container'));
      final start = tester.getTopLeft(card) - const Offset(8, 8);
      final end = tester.getBottomRight(card) + const Offset(8, 8);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(end);
      await tester.pump();

      final previewNodeIds = orchestrator.marqueePreviewSelections
          .map((final selection) => selection.nodeId)
          .toList(growable: false);
      final previewTypes = orchestrator.marqueePreviewSelections
          .map((final selection) => selection.widgetType)
          .toList(growable: false);
      expect(previewNodeIds, isNotEmpty);
      expect(
        previewTypes,
        everyElement(isNot(anyOf('Column', 'Padding', 'Center', 'Container'))),
      );
      expect(previewTypes, isNot(contains('OutlinedButton')));

      await gesture.up();
      await tester.pumpAndSettle();

      final committedNodeIds = orchestrator.activeMultiSelection
          .map((final selection) => selection.nodeId)
          .toList(growable: false);
      final committedTypes = orchestrator.activeMultiSelection
          .map((final selection) => selection.widgetType)
          .toList(growable: false);
      expect(committedNodeIds, previewNodeIds);
      expect(
        committedTypes,
        everyElement(isNot(anyOf('Column', 'Padding', 'Center', 'Container'))),
      );
      expect(committedTypes, isNot(contains('OutlinedButton')));
    },
  );

  testWidgets(
    'marquee keeps a covered visual widget when no covered child replaces it',
    (final tester) async {
      final orchestrator = LiveEditOrchestrator();
      await tester.pumpWidget(
        MaterialApp(
          home: FlutterLiveEditHost(
            orchestrator: orchestrator,
            child: Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Card(
                      key: const ValueKey<String>('solo_card'),
                      child: const SizedBox(width: 180, height: 96),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      final target = find.byKey(const ValueKey<String>('solo_card'));
      final start = tester.getTopLeft(target) - const Offset(8, 8);
      final end = tester.getBottomRight(target) + const Offset(8, 8);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(end);
      await gesture.up();
      await tester.pumpAndSettle();

      final widgetTypes = orchestrator.activeMultiSelection
          .map((final selection) => selection.widgetType)
          .toSet();
      expect(widgetTypes, contains('SizedBox'));
      expect(widgetTypes, isNot(contains('Column')));
      expect(widgetTypes, isNot(contains('Center')));
    },
  );

  testWidgets('multi-node marquee commit hydrates only active selection', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(padding: EdgeInsets.all(24), child: Text('First')),
                Padding(padding: EdgeInsets.all(24), child: Text('Second')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    final start = tester.getTopLeft(find.text('First')) - const Offset(20, 20);
    final end =
        tester.getBottomRight(find.text('Second')) + const Offset(20, 20);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveTo(end);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(orchestrator.activeMultiSelection.length, greaterThan(1));
    expect(orchestrator.activeSelection, isNotNull);
    expect(orchestrator.activeSelection!.detailsTree, isNotEmpty);
    expect(orchestrator.activeSelection!.propertiesTree, isNotEmpty);

    final nonActiveSelections = orchestrator.activeMultiSelection
        .where(
          (final selection) =>
              selection.nodeId != orchestrator.activeSelection!.nodeId,
        )
        .toList(growable: false);
    expect(nonActiveSelections, isNotEmpty);
    expect(
      nonActiveSelections.every(
        (final selection) =>
            selection.detailsTree.isEmpty && selection.propertiesTree.isEmpty,
      ),
      isTrue,
    );
  });

  testWidgets(
    'selecting another committed marquee node hydrates it on demand',
    (final tester) async {
      final orchestrator = LiveEditOrchestrator();
      await tester.pumpWidget(
        MaterialApp(
          home: FlutterLiveEditHost(
            orchestrator: orchestrator,
            child: const Scaffold(
              body: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(padding: EdgeInsets.all(24), child: Text('First')),
                  Padding(padding: EdgeInsets.all(24), child: Text('Second')),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ActionChip));
      await tester.pumpAndSettle();

      final start =
          tester.getTopLeft(find.text('First')) - const Offset(20, 20);
      final end =
          tester.getBottomRight(find.text('Second')) + const Offset(20, 20);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveTo(end);
      await gesture.up();
      await tester.pumpAndSettle();

      final inactiveIndex = orchestrator.activeSelectionCandidates.indexWhere(
        (final candidate) => !candidate.active,
      );
      expect(inactiveIndex, greaterThanOrEqualTo(0));

      orchestrator.selectCandidateAt(inactiveIndex);
      await tester.pumpAndSettle();

      expect(orchestrator.activeSelection, isNotNull);
      expect(orchestrator.activeSelection!.detailsTree, isNotEmpty);
      expect(orchestrator.activeSelection!.propertiesTree, isNotEmpty);
    },
  );

  testWidgets('dragging does not keep updating hover state', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(
            body: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Padding(padding: EdgeInsets.all(24), child: Text('First')),
                Padding(padding: EdgeInsets.all(24), child: Text('Second')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    final hoverStart = tester.getCenter(find.text('First'));
    await gesture.moveTo(hoverStart);
    await tester.pumpAndSettle();
    final hoverNodeId = orchestrator.hoverSelection?.nodeId;
    expect(hoverNodeId, isNotNull);

    await gesture.down(hoverStart);
    await gesture.moveTo(tester.getCenter(find.text('Second')));
    await tester.pump();

    expect(orchestrator.marqueeRect, isNotNull);
    expect(orchestrator.hoverSelection?.nodeId, hoverNodeId);

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
    'repeated marquee updates with same result do not churn listeners',
    (final tester) async {
      final controller = LiveEditController.instance;
      var notifications = 0;
      void handleNotification() => notifications += 1;
      controller.addListener(handleNotification);
      addTearDown(() => controller.removeListener(handleNotification));

      await tester.pumpWidget(
        const MaterialApp(
          home: FlutterLiveEditHost(
            child: Scaffold(
              body: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Padding(padding: EdgeInsets.all(24), child: Text('First')),
                  Padding(padding: EdgeInsets.all(24), child: Text('Second')),
                ],
              ),
            ),
          ),
        ),
      );

      final started = controller.startSession();
      final sessionId = started['sessionId']! as String;
      controller.setOverlay(sessionId: sessionId, enabled: true);

      final root = tester.element(find.byType(Scaffold));
      final start =
          tester.getTopLeft(find.text('First')) - const Offset(20, 20);
      final end =
          tester.getBottomRight(find.text('Second')) + const Offset(20, 20);
      controller.startMarquee(
        sessionId: sessionId,
        x: start.dx.round(),
        y: start.dy.round(),
      );
      notifications = 0;

      controller.updateMarquee(
        sessionId: sessionId,
        x: end.dx.round(),
        y: end.dy.round(),
        contentRoot: root,
      );
      final afterFirstUpdate = notifications;

      controller.updateMarquee(
        sessionId: sessionId,
        x: end.dx.round(),
        y: end.dy.round(),
        contentRoot: root,
      );

      expect(afterFirstUpdate, 1);
      expect(notifications, 1);
      expect(
        controller.activeMarqueeSelections.every(
          (final selection) =>
              selection.detailsTree.isEmpty && selection.propertiesTree.isEmpty,
        ),
        isTrue,
      );
    },
  );

  testWidgets('only meaningful bubbles are pinned after blur', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator();
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: const Scaffold(
            body: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[Text('Alpha'), Text('Beta')],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.text('Alpha')));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('Beta')));
    await tester.pumpAndSettle();
    expect(orchestrator.pinnedBubbleSummaries, isEmpty);

    await tester.tapAt(tester.getCenter(find.text('Alpha')));
    await tester.pumpAndSettle();
    await selectEditableCandidate(tester, orchestrator);
    final property = orchestrator.activeSelection!.propertyGroups.firstWhere(
      (final candidate) => candidate.editable,
    );
    final targetValue = switch (property.kind) {
      LiveEditPropertyKind.boolean => !(property.value == true),
      LiveEditPropertyKind.integer => 180,
      LiveEditPropertyKind.number => 180.0,
      _ when property.options.isNotEmpty => property.options.first,
      _ => 'Changed',
    };
    orchestrator.updateDraft(property: property, targetValue: targetValue);
    await tester.pumpAndSettle();
    final alphaNodeId = orchestrator.activeSelection!.nodeId;

    final betaCenter = tester.getCenter(find.text('Beta'));
    final betaGesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await betaGesture.addPointer(location: betaCenter);
    await betaGesture.moveTo(betaCenter);
    await tester.pump();
    await betaGesture.down(betaCenter);
    await betaGesture.up();
    await tester.pumpAndSettle();
    expect(orchestrator.pinnedBubbleSummaries.length, lessThanOrEqualTo(1));
    orchestrator.selectTrackedBubble(alphaNodeId);
    await tester.pumpAndSettle();
    expect(orchestrator.activeSelection?.nodeId, alphaNodeId);
  });

  testWidgets('wait action only stages edits and does not dispatch', (
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
    await selectEditableCandidate(tester, orchestrator);
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
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

    await orchestrator.waitForProperty(editable);
    await tester.pumpAndSettle();
    expect(orchestrator.panelExpanded, isTrue);
    expect(orchestrator.applyPhase, LiveEditApplyPhase.idle);
    expect(orchestrator.isWaitingForAgent, isFalse);
    expect(find.byType(AlertDialog), findsNothing);
    expect(orchestrator.needsApproval, isFalse);
    expect(orchestrator.pendingExecutionPlan, isNull);
    expect(requests, isEmpty);
  });

  testWidgets('AI composer enables send without draft changes', (
    final tester,
  ) async {
    final requests = <LiveEditApplyDraftRequest>[];
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        requests.add(request);
        return <String, Object?>{
          'proposalId': 'proposal-ai-only',
          'executionPlan': <String, Object?>{
            'proposalId': 'proposal-ai-only',
            'title': 'Apply live edit',
            'summary': 'Persist the requested text update.',
            'selectedNode': 'Text',
            'requestedChanges': <String>['Update text from AI prompt'],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.8,
            'riskNotes': const <String>[],
            'agentInstruction': 'Update the selected text widget.',
          },
        };
      },
    );

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

    orchestrator.openAiBubble();
    orchestrator.updateAiComposer('Please rewrite this heading.');
    await tester.pumpAndSettle();

    expect(orchestrator.activeDraftChanges, isEmpty);
    expect(orchestrator.canSubmitAiPrompt, isTrue);
    expect(orchestrator.currentActivity?.label, 'Prompt ready');
    expect(find.text('Prompt ready'), findsWidgets);

    await orchestrator.submitAiPrompt();
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.draftChanges, isEmpty);
    expect(requests.single.intentText, 'Please rewrite this heading.');
    expect(orchestrator.pendingExecutionPlan, isNotNull);
    expect(orchestrator.currentActivity?.label, 'Applied');
    expect(find.text('Applied'), findsWidgets);
  });

  testWidgets('direct property edits stay local until apply', (
    final tester,
  ) async {
    final requests = <LiveEditApplyDraftRequest>[];
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        requests.add(request);
        return <String, Object?>{
          'proposalId': 'proposal-batched-edits',
          'executionPlan': <String, Object?>{
            'proposalId': 'proposal-batched-edits',
            'title': 'Apply live edit',
            'summary': 'Persist the staged property edits.',
            'selectedNode': 'SizedBox',
            'requestedChanges': <String>['Width to 140'],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.9,
            'riskNotes': const <String>[],
            'agentInstruction': 'Apply the staged property edits.',
          },
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
    await selectEditableCandidate(tester, orchestrator);
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();

    final editable = orchestrator.activeSelection!.propertyGroups.firstWhere(
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

    expect(requests, isEmpty);
    expect(orchestrator.activeDraftChanges, isNotEmpty);
    expect(orchestrator.historyForActiveSelection, isEmpty);
    expect(find.text('Pending request'), findsWidgets);

    await orchestrator.applyDraft();
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.draftChanges, isNotEmpty);
    expect(requests.single.intentText, contains('Staged fixes:'));
    expect(orchestrator.historyForActiveSelection, hasLength(3));
    expect(orchestrator.historyForActiveSelection.first.role, 'user');
  });

  testWidgets('streamed codex events land in activity and debug history', (
    final tester,
  ) async {
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        request.onEvent?.call(
          const LiveEditRuntimeEvent(
            kind: LiveEditRuntimeEventKind.codex,
            message: 'Starting codex exec stream.',
          ),
        );
        request.onEvent?.call(
          const LiveEditRuntimeEvent(
            kind: LiveEditRuntimeEventKind.codex,
            message: 'Codex streamed output.',
            details: <String>['{"summary":"Streamed proposal"}'],
          ),
        );
        request.onEvent?.call(
          const LiveEditRuntimeEvent(
            kind: LiveEditRuntimeEventKind.debug,
            message: 'Raw stdout chunk from Codex.',
            details: <String>['{"summary":"Streamed proposal"}'],
            debugOnly: true,
          ),
        );
        return <String, Object?>{
          'proposalId': 'proposal-streamed',
          'executionPlan': <String, Object?>{
            'proposalId': 'proposal-streamed',
            'title': 'Apply live edit',
            'summary': 'Persist the streamed property edit.',
            'selectedNode': 'SizedBox',
            'requestedChanges': <String>['Width to 140'],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.9,
            'riskNotes': const <String>[],
            'agentInstruction': 'Apply the streamed property edits.',
          },
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
    await selectEditableCandidate(tester, orchestrator);
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();

    final editable = orchestrator.activeSelection!.propertyGroups.firstWhere(
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

    expect(
      orchestrator.activityTimelineForActiveSelection.any(
        (final entry) =>
            entry.label == 'Applying with agent' ||
            entry.summary.contains('proposal'),
      ),
      isTrue,
    );
    expect(
      orchestrator.debugTimelineForActiveSelection.any(
        (final entry) => entry.message.contains('Raw stdout chunk from Codex.'),
      ),
      isTrue,
    );
  });

  testWidgets('apply combines staged drafts with AI prompt into one request', (
    final tester,
  ) async {
    final requests = <LiveEditApplyDraftRequest>[];
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        requests.add(request);
        return <String, Object?>{
          'proposalId': 'proposal-combined',
          'executionPlan': <String, Object?>{
            'proposalId': 'proposal-combined',
            'title': 'Apply live edit',
            'summary': 'Persist the staged text update.',
            'selectedNode': 'Text',
            'requestedChanges': <String>[
              'Update text to Hello',
              'Rewrite the tone to be more direct.',
            ],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.9,
            'riskNotes': const <String>[],
            'agentInstruction': 'Apply the staged text update.',
          },
        };
      },
    );

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
    await selectEditableCandidate(tester, orchestrator);

    final editable = orchestrator.activeSelection!.propertyGroups.firstWhere(
      (final property) => property.editable,
    );
    orchestrator.updateDraft(property: editable, targetValue: 'Hello');
    orchestrator.updateAiComposer('Rewrite the tone to be more direct.');
    await tester.pumpAndSettle();

    await orchestrator.applyDraft();
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.draftChanges, isNotEmpty);
    expect(
      requests.single.intentText,
      allOf(
        contains('Rewrite the tone to be more direct.'),
        contains('Staged fixes:'),
        contains('Hello'),
      ),
    );
    expect(
      orchestrator.historyForActiveSelection.first.message,
      contains('Staged fixes:'),
    );
  });

  testWidgets('inspector composer can send without switching mode first', (
    final tester,
  ) async {
    final requests = <LiveEditApplyDraftRequest>[];
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        requests.add(request);
        return <String, Object?>{
          'proposalId': 'proposal-ai-panel',
          'executionPlan': <String, Object?>{
            'proposalId': 'proposal-ai-panel',
            'title': 'Apply live edit',
            'summary': 'Persist the requested text update.',
            'selectedNode': 'Text',
            'requestedChanges': <String>['Update text from AI prompt'],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.8,
            'riskNotes': const <String>[],
            'agentInstruction': 'Update the selected text widget.',
          },
        };
      },
    );

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
    orchestrator.selectNode(tester.getCenter(find.text('Target')));
    await tester.pumpAndSettle();
    orchestrator.togglePanelDisplayMode();
    await tester.pumpAndSettle();

    final promptField = _aiPromptField();
    expect(promptField, findsOneWidget);

    await tester.enterText(promptField, 'Rewrite the selected text.');
    await tester.pumpAndSettle();

    expect(orchestrator.canSubmitAiPrompt, isTrue);
    final sendButton = find.widgetWithText(FilledButton, 'Send');
    expect(sendButton, findsOneWidget);
    expect(tester.widget<FilledButton>(sendButton).onPressed, isNotNull);

    await orchestrator.submitAiPrompt();
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.draftChanges, isEmpty);
    expect(requests.single.intentText, 'Rewrite the selected text.');
    expect(requests.single.selection?.nodeId, isNotEmpty);
    expect(orchestrator.lastError, isNull);
    expect(orchestrator.editMode, LiveEditEditMode.ai);
  });

  testWidgets('retry keeps prompt-only requests in AI mode', (
    final tester,
  ) async {
    var attempts = 0;
    final requests = <LiveEditApplyDraftRequest>[];
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        requests.add(request);
        attempts += 1;
        if (attempts == 1) {
          return <String, Object?>{'ok': false, 'message': 'backend offline'};
        }
        return <String, Object?>{
          'proposalId': 'proposal-ai-retry',
          'executionPlan': <String, Object?>{
            'proposalId': 'proposal-ai-retry',
            'title': 'Apply live edit',
            'summary': 'Persist the requested text update.',
            'selectedNode': 'Text',
            'requestedChanges': <String>['Update text from AI prompt'],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.8,
            'riskNotes': const <String>[],
            'agentInstruction': 'Update the selected text widget.',
          },
        };
      },
    );

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
    orchestrator.selectNode(tester.getCenter(find.text('Target')));
    await tester.pumpAndSettle();
    orchestrator.togglePanelDisplayMode();
    await tester.pumpAndSettle();

    await tester.enterText(_aiPromptField(), 'Rewrite the selected text.');
    await tester.pumpAndSettle();

    await orchestrator.submitAiPrompt();
    await tester.pumpAndSettle();

    expect(orchestrator.applyPhase, LiveEditApplyPhase.failed);
    expect(orchestrator.lastError, 'backend offline');
    expect(orchestrator.aiComposer, 'Rewrite the selected text.');

    orchestrator.focusProperty(
      const LiveEditPropertyDescriptor(
        id: 'bounds',
        label: 'Bounds',
        group: LiveEditPropertyGroup.diagnostics,
        kind: LiveEditPropertyKind.object,
      ),
    );
    await tester.pumpAndSettle();
    expect(orchestrator.editMode, isNot(LiveEditEditMode.ai));

    await orchestrator.retryApply();
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests.last.intentText, 'Rewrite the selected text.');
    expect(orchestrator.lastError, isNull);
    expect(orchestrator.editMode, LiveEditEditMode.ai);
    expect(orchestrator.pendingExecutionPlan, isNotNull);
  });

  testWidgets(
    'selected prompt stays hidden until debug mode and shows empty state',
    (final tester) async {
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
      if (orchestrator.activeSelection == null) {
        orchestrator.selectNode(tester.getCenter(find.text('Target')));
        await tester.pumpAndSettle();
      }
      await tester.tap(_semanticsId('live_edit_panel_expand_button'));
      await tester.pumpAndSettle();

      expect(_semanticsId('live_edit_selected_prompt'), findsNothing);
      expect(
        find.text('No agent request sent for this bubble yet.'),
        findsNothing,
      );

      orchestrator.setDebugModeEnabled(true);
      await tester.pumpAndSettle();

      expect(_semanticsId('live_edit_selected_prompt'), findsOneWidget);
      expect(
        find.text('No agent request sent for this bubble yet.'),
        findsOneWidget,
      );

      await tester.tap(_semanticsId('live_edit_selected_prompt'));
      await tester.pumpAndSettle();

      expect(
        find.text('No agent request sent for this bubble yet.'),
        findsWidgets,
      );
    },
    skip: true,
  );

  testWidgets('selected prompt tracks the active selection in debug mode', (
    final tester,
  ) async {
    const promptText = '''
You are an agent working directly inside a Dart/Flutter workspace.

Direct apply request:
{
  "instructionText": "Rewrite the selected text."
}
''';
    final orchestrator = LiveEditOrchestrator(
      applyDraftDelegate: (final request) async {
        request.onEvent?.call(
          const LiveEditRuntimeEvent(
            kind: LiveEditRuntimeEventKind.debug,
            message: 'Resolved backend prompt captured.',
            promptText: promptText,
            debugOnly: true,
          ),
        );
        return <String, Object?>{
          'proposalId': 'proposal-selected-prompt',
          'executionPlan': <String, Object?>{
            'proposalId': 'proposal-selected-prompt',
            'title': 'Apply this bubble change',
            'summary': 'Persist the requested text update.',
            'selectedNode': 'Text',
            'requestedChanges': <String>['Update text from AI prompt'],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.8,
            'riskNotes': const <String>[],
            'agentInstruction': 'Update the selected text widget.',
          },
          'executionResult': <String, Object?>{
            'executionId': 'proposal-selected-prompt',
            'backendId': 'codex_exec',
            'summary': 'Persist the requested text update.',
            'changedFiles': <String>['lib/main.dart'],
            'warnings': const <String>[],
            'validationSteps': const <String>[],
          },
        };
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: FlutterLiveEditHost(
          orchestrator: orchestrator,
          child: Scaffold(
            body: Stack(
              children: const <Widget>[
                Positioned(left: 80, top: 120, child: Text('First')),
                Positioned(left: 80, top: 240, child: Text('Second')),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(ActionChip));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.text('First')));
    await tester.pumpAndSettle();
    if (orchestrator.activeSelection == null) {
      orchestrator.selectNode(tester.getCenter(find.text('First')));
      await tester.pumpAndSettle();
    }
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();

    orchestrator.setDebugModeEnabled(true);
    orchestrator.updateAiComposer('Rewrite the selected text.');
    await tester.pumpAndSettle();

    await orchestrator.submitAiPrompt();
    await tester.pumpAndSettle();

    if (!orchestrator.panelExpanded) {
      orchestrator.expandPanel();
      await tester.pumpAndSettle();
    }

    expect(_semanticsId('live_edit_selected_prompt'), findsOneWidget);
    await tester.tap(_semanticsId('live_edit_selected_prompt'));
    await tester.pumpAndSettle();

    final firstPrompt = orchestrator.debugPromptForActiveSelection;
    final firstNodeId = orchestrator.activeSelection?.nodeId;
    expect(firstNodeId, isNotNull);
    expect(
      find.textContaining('You are an agent working directly inside'),
      findsOneWidget,
    );
    expect(
      find.textContaining('"instructionText": "Rewrite the selected text."'),
      findsOneWidget,
    );

    orchestrator.selectNode(tester.getCenter(find.text('Second')));
    await tester.pumpAndSettle();
    expect(orchestrator.debugPromptForActiveSelection, isNull);

    expect(
      find.text('No agent request sent for this bubble yet.'),
      findsWidgets,
    );

    orchestrator.selectTrackedBubble(firstNodeId!);
    await tester.pumpAndSettle();
    expect(orchestrator.debugPromptForActiveSelection, firstPrompt);

    expect(
      find.textContaining('You are an agent working directly inside'),
      findsOneWidget,
    );
  }, skip: true);

  testWidgets(
    'debug source and technical details stay hidden until debug mode',
    (final tester) async {
      final orchestrator = LiveEditOrchestrator(
        applyDraftDelegate: (final request) async => <String, Object?>{
          'proposalId': 'proposal-ai-only',
          'executionPlan': <String, Object?>{
            'proposalId': 'proposal-ai-only',
            'title': 'Apply live edit',
            'summary': 'Persist the requested text update.',
            'selectedNode': 'Text',
            'requestedChanges': <String>['Update text from AI prompt'],
            'affectedFiles': <String>['lib/main.dart'],
            'confidence': 0.8,
            'riskNotes': const <String>[],
            'agentInstruction': 'Update the selected text widget.',
          },
        },
      );

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
      await tester.tap(_semanticsId('live_edit_panel_expand_button'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Code:'), findsNothing);
      expect(find.text('Technical details'), findsNothing);

      orchestrator.openAiBubble();
      orchestrator.updateAiComposer('Rewrite the selected text.');
      await tester.pumpAndSettle();
      await orchestrator.submitAiPrompt();
      await tester.pumpAndSettle();

      expect(orchestrator.currentActivity?.label, 'Applied');
      expect(find.text('Technical details'), findsNothing);

      orchestrator.setDebugModeEnabled(true);
      await tester.pumpAndSettle();
      if (!orchestrator.panelExpanded) {
        orchestrator.expandPanel();
        await tester.pumpAndSettle();
      }

      expect(find.textContaining('Code:'), findsWidgets);
      expect(find.text('Technical details'), findsWidgets);
    },
  );

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
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Selected'), findsWidgets);

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

    expect(find.byType(AlertDialog), findsNothing);
    expect(orchestrator.activeDraftChanges, isNotEmpty);
  });

  testWidgets('selection and active property persist across draft updates', (
    final tester,
  ) async {
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
    await selectEditableCandidate(tester, orchestrator);

    final selection = orchestrator.activeSelection!;
    final property = selection.propertyGroups.firstWhere(
      (final candidate) => candidate.editable,
    );
    final updatedValue = switch (property.kind) {
      LiveEditPropertyKind.boolean => !(property.value == true),
      LiveEditPropertyKind.integer => 144,
      LiveEditPropertyKind.number => 144.0,
      _ when property.options.isNotEmpty => property.options.first,
      _ => 'Retitled',
    };

    orchestrator.focusProperty(property);
    orchestrator.updateDraft(
      property: property,
      targetValue: updatedValue,
      surface: LiveEditEditSurface.panel,
    );
    await tester.pumpAndSettle();

    expect(orchestrator.activeSelection?.nodeId, selection.nodeId);
    expect(orchestrator.activePropertyId, property.id);
    expect(orchestrator.activeDraftChanges.single.propertyId, property.id);
  });
}
