// ignore_for_file: avoid_print

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:test_app/main.dart' as app;

import 'live_edit_integration_harness.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugFlutterLiveEditAutoHostOrchestratorOverride = null;
  });

  tearDown(() {
    debugFlutterLiveEditAutoHostOrchestratorOverride?.dispose();
    debugFlutterLiveEditAutoHostOrchestratorOverride = null;
  });

  testWidgets(
    'app overlay round-trips the deterministic fixture through a real agent',
    skip: !_runAgentIntegration,
    (final tester) async {
      final harness = _LiveEditAgentIntegrationHarness();
      addTearDown(harness.dispose);
      addTearDown(() => binding.setSurfaceSize(null));

      final orchestrator = await _launchIntegrationApp(
        tester,
        binding,
        harness,
      );
      final h = LiveEditIntegrationHarness(
        orchestrator.context,
        orchestrator.controller,
      );
      await _enableLiveEdit(tester, h);

      expect(_semanticsId('live_edit_test_target'), findsOneWidget);
      expect(_fixtureText(_fixtureOriginalText), findsOneWidget);

      await _roundTripFixtureText(
        tester,
        h,
        from: _fixtureOriginalText,
        to: _fixtureUpdatedText,
      );
      await _roundTripFixtureText(
        tester,
        h,
        from: _fixtureUpdatedText,
        to: _fixtureOriginalText,
      );

      final selectionSource = h.activeSelection?.source?.file;
      expect(selectionSource, isNotNull);
      final mappedSourcePath = harness.mappedFileForSource(selectionSource!);
      expect(mappedSourcePath, isNotNull);

      final changedContents = await File(mappedSourcePath!).readAsString();
      expect(changedContents, contains(_fixtureOriginalText));
      expect(changedContents, isNot(contains(_fixtureUpdatedText)));
      expect(
        changedContents,
        isNot(equals(harness.originalContentsForSource(selectionSource))),
      );
      expect(h.applyPhase, LiveEditApplyPhase.success);
      expect(h.activeDraftChanges, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );

  testWidgets(
    'draft overlay ai bubble round-trips through a real agent',
    skip: !_runAgentIntegration,
    (final tester) async {
      final harness = _LiveEditAgentIntegrationHarness();
      addTearDown(harness.dispose);
      addTearDown(() => binding.setSurfaceSize(null));

      final orchestrator = await _launchIntegrationApp(
        tester,
        binding,
        harness,
      );
      final h = LiveEditIntegrationHarness(
        orchestrator.context,
        orchestrator.controller,
      );
      await _enableLiveEdit(tester, h);
      await _selectFixtureTarget(tester, h);

      final appSelectionNodeId = h.activeSelection?.nodeId;
      expect(appSelectionNodeId, isNotNull);

      await _roundTripToolAiBubbleColor(tester, h);

      final toolSelectionSource = h.activeSelection?.source?.file;
      expect(toolSelectionSource, isNotNull);
      expect(
        _containsPath(
          'flutter_live_edit/flutter_live_edit_toolkit/lib/src/live_edit_overlay_theme.dart',
          toolSelectionSource!,
        ),
        isTrue,
      );

      final mappedSourcePath = harness.mappedFileForSource(toolSelectionSource);
      expect(mappedSourcePath, isNotNull);
      final changedContents = await File(mappedSourcePath!).readAsString();
      expect(
        changedContents,
        isNot(equals(harness.originalContentsForSource(toolSelectionSource))),
      );
      expect(changedContents, contains('backgroundColor'));
      expect(changedContents, contains('0xFFFFFBEB'));

      h.setTargetDomain(LiveEditTargetDomain.appScene);
      await tester.pumpAndSettle();
      expect(h.activeSelection?.targetDomain, LiveEditTargetDomain.appScene);
      expect(h.activeSelection?.nodeId, appSelectionNodeId);
    },
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

const _agentBackendId = String.fromEnvironment(
  'LIVE_EDIT_AGENT_BACKEND',
  defaultValue: 'codex_exec',
);
const _agentIntent = String.fromEnvironment(
  'LIVE_EDIT_AGENT_INTENT',
  defaultValue:
      'Persist the requested live-edit change with minimal source edits.',
);
const _agentWorkingDirectoryDefine = String.fromEnvironment(
  'LIVE_EDIT_AGENT_WORKING_DIRECTORY',
);

const _bubbleOriginalColor = Color(0xFFFFFBEB);
const _bubbleUpdatedColor = Color(0xFF112233);
const _fixtureOriginalText = 'Live Edit Test Target';
const _fixtureSourceBasename = 'live_edit_codex_fixture.dart';
const _fixtureUpdatedText = 'Live Edit Agent Target';

const _runAgentIntegration = bool.fromEnvironment(
  'RUN_LIVE_EDIT_AGENT_INTEGRATION',
);

Material _activeAiBubbleMaterial(final WidgetTester tester) => tester.widget(
  find.descendant(of: _aiBubbleKey(), matching: find.byType(Material)).first,
);

Finder _aiBubbleKey() => find.byKey(
  LiveEditOverlayThemeModel.instance.keyFor(kLiveEditAiBubbleSurfaceId),
);

Future<void> _applyCurrentDraft(
  final WidgetTester tester,
  final LiveEditIntegrationHarness h,
) async {
  final applyFuture = h.applyDraft(
    message: h.canSubmitAiPrompt ? h.aiComposer : null,
  );
  await tester.pump();
  await _pumpUntil(
    tester,
    () => h.applyPhase == LiveEditApplyPhase.success || h.lastError != null,
    timeout: const Duration(minutes: 4),
  );
  await applyFuture;
  expect(h.lastError, isNull);
  await tester.pumpAndSettle();
  expect(h.currentActivity?.label, 'Applied');
}

bool _containsPath(final String parent, final String child) {
  final normalizedParent = _normalizePath(parent).replaceAll('\\', '/');
  final normalizedChild = _normalizePath(child).replaceAll('\\', '/');
  return normalizedChild == normalizedParent ||
      normalizedChild.startsWith('$normalizedParent/');
}

void _copyShallowDirectory(
  final Directory source,
  final Directory destination,
) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    if (entity is! File) {
      continue;
    }
    final name = entity.uri.pathSegments.last;
    final targetFile = File('${destination.path}/$name');
    targetFile.parent.createSync(recursive: true);
    targetFile.writeAsBytesSync(entity.readAsBytesSync());
  }
}

Future<void> _enableLiveEdit(
  final WidgetTester tester,
  final LiveEditIntegrationHarness h,
) async {
  await tester.tap(find.widgetWithText(ActionChip, 'Live Edit'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await _pumpUntil(
    tester,
    () => h.overlayVisible,
    timeout: const Duration(seconds: 10),
  );
}

Future<void> _ensurePanelExpanded(
  final WidgetTester tester,
  final LiveEditIntegrationHarness h,
) async {
  if (!h.panelExpanded) {
    await tester.tap(_semanticsId('live_edit_panel_expand_button'));
    await tester.pumpAndSettle();
  }
}

String _errorMessageWithDetails(final String message, {final Object? details}) {
  final normalizedMessage = message.trim().isEmpty
      ? 'Live edit failed.'
      : message.trim();
  if (details is Map) {
    final map = details.map(
      (final key, final value) => MapEntry('$key', value),
    );
    final stderr = '${map['stderr'] ?? ''}'.trim();
    if (stderr.isNotEmpty && stderr != normalizedMessage) {
      return '$normalizedMessage\n$stderr';
    }
  }
  final raw = '$details'.trim();
  if (raw.isNotEmpty && raw != 'null' && raw != normalizedMessage) {
    return '$normalizedMessage\n$raw';
  }
  return normalizedMessage;
}

Map<String, Object?> _failureResponse(
  final String message, {
  final Object? details,
  final Map<String, Object?> meta = const <String, Object?>{},
}) => <String, Object?>{
  'ok': false,
  'message': _errorMessageWithDetails(message, details: details),
  'details': details,
  if (meta.isNotEmpty) 'meta': meta,
  'error': <String, Object?>{
    'message': _errorMessageWithDetails(message, details: details),
    'details': ?details,
    if (meta.isNotEmpty) 'meta': meta,
  },
};

String _fixtureRenderedText(final WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(_fixtureRichText()).text.toPlainText();

Finder _fixtureRichText() => find.descendant(
  of: _semanticsId('live_edit_test_target'),
  matching: find.byType(RichText),
);

Finder _fixtureText(final String value) => find.descendant(
  of: _semanticsId('live_edit_test_target'),
  matching: find.byWidgetPredicate(
    (final widget) => widget is Text && widget.data == value,
    description: 'Fixture text $value',
  ),
);

String _joinPath(final String left, final String right) {
  final normalizedLeft = left.endsWith(Platform.pathSeparator)
      ? left.substring(0, left.length - 1)
      : left;
  final normalizedRight = right.startsWith(Platform.pathSeparator)
      ? right.substring(1)
      : right;
  return '$normalizedLeft${Platform.pathSeparator}$normalizedRight';
}

Future<LiveEditOrchestrator> _launchIntegrationApp(
  final WidgetTester tester,
  final IntegrationTestWidgetsFlutterBinding binding,
  final _LiveEditAgentIntegrationHarness harness,
) async {
  await binding.setSurfaceSize(const Size(8000, 2000));
  final orchestrator = LiveEditOrchestrator(
    applyDraftDelegate: harness.handle,
    backendId: _agentBackendId,
    workingDirectory: _resolvedWorkingDirectory(),
    intentText: _agentIntent,
  );
  debugFlutterLiveEditAutoHostOrchestratorOverride = orchestrator;

  await app.main();
  print('[agent-test] app main started');
  await _pumpUntil(
    tester,
    () => find.text('MCP Toolkit Demo').evaluate().isNotEmpty,
    timeout: const Duration(seconds: 30),
  );
  print('[agent-test] app visible');
  return orchestrator;
}

String _normalizePath(final String rawPath) {
  final uri = Uri.tryParse(rawPath);
  if (uri != null && uri.scheme == 'file') {
    return uri.toFilePath();
  }
  return rawPath;
}

String _packageRootFromSource(final String sourceFile) {
  var cursor = File(sourceFile).parent;
  while (true) {
    if (File('${cursor.path}/pubspec.yaml').existsSync()) {
      return cursor.path;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      break;
    }
    cursor = parent;
  }
  return File(sourceFile).parent.path;
}

Future<void> _pumpUntil(
  final WidgetTester tester,
  final bool Function() condition, {
  required final Duration timeout,
  final Duration step = const Duration(milliseconds: 250),
}) async {
  final endTime = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(endTime)) {
    await tester.pump(step);
    if (condition()) {
      return;
    }
  }
  fail('Timed out waiting for integration condition.');
}

String _relativePath({required final String root, required final String path}) {
  final normalizedRoot = _normalizePath(root).replaceAll('\\', '/');
  final normalizedPath = _normalizePath(path).replaceAll('\\', '/');
  if (normalizedPath == normalizedRoot) {
    return '';
  }
  if (normalizedPath.startsWith('$normalizedRoot/')) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  return normalizedPath.split('/').last;
}

String _repoRootFromPath(final String seedPath) {
  var cursor = Directory(seedPath);
  if (!cursor.existsSync()) {
    cursor = File(seedPath).parent;
  }
  while (true) {
    final hasApp = Directory('${cursor.path}/flutter_test_app').existsSync();
    final hasLiveEdit = Directory(
      '${cursor.path}/flutter_live_edit',
    ).existsSync();
    if (hasApp && hasLiveEdit) {
      return cursor.path;
    }
    final parent = cursor.parent;
    if (parent.path == cursor.path) {
      break;
    }
    cursor = parent;
  }
  return _resolvedWorkingDirectory();
}

List<String> _requestDebugDetails(
  final LiveEditApplyDraftRequest request, {
  required final String backendId,
  required final String workingDirectory,
}) => <String>[
  'Session: ${request.sessionId}',
  'Backend: $backendId',
  if ((request.inferenceConfig?.model ?? '').trim().isNotEmpty)
    'Model: ${request.inferenceConfig!.model}',
  if ((request.inferenceConfig?.reasoningEffort ?? '').trim().isNotEmpty)
    'Reasoning: ${request.inferenceConfig!.reasoningEffort}',
  'Workspace: $workingDirectory',
  'Node: ${request.effectivePrimarySelection?.nodeId ?? '<none>'}',
  'Drafts: 0',
  'Instruction present: ${((request.effectiveInstructionText ?? '').trim().isNotEmpty)}',
];

String _resolvedWorkingDirectory() => _agentWorkingDirectoryDefine.isNotEmpty
    ? _agentWorkingDirectoryDefine
    : Directory.current.path;

LiveEditSelection _rewriteSelectionSource({
  required final LiveEditSelection selection,
  required final String sourceFile,
  required final String rewrittenFile,
}) {
  final source = selection.source;
  if (source == null || _normalizePath(source.file) != sourceFile) {
    return selection;
  }
  return LiveEditSelection(
    sessionId: selection.sessionId,
    nodeId: selection.nodeId,
    widgetType: selection.widgetType,
    targetDomain: selection.targetDomain,
    renderObjectType: selection.renderObjectType,
    bounds: selection.bounds,
    source: LiveEditSourceLocation(
      file: rewrittenFile,
      line: source.line,
      column: source.column,
      sourceHint: source.sourceHint,
    ),
    propertiesForWire: selection.propertiesForWire,
    layoutContext: selection.layoutContext,
    parentChain: selection.parentChain,
    detailsTree: selection.detailsTree,
    propertiesTree: selection.propertiesTree,
    rawNode: selection.rawNode,
    selectionMode: selection.selectionMode,
    selectedNodeIds: selection.selectedNodeIds,
  );
}

LiveEditSourceTarget _rewriteSourceTarget({
  required final LiveEditSourceTarget target,
  required final String sourceFile,
  required final String rewrittenFile,
  required final String workingDirectory,
}) {
  final absolutePath = target.absolutePath;
  if (absolutePath == null || absolutePath.trim().isEmpty) {
    return target;
  }
  final normalizedSourceFile = _normalizePath(sourceFile);
  final normalizedTargetPath = _normalizePath(absolutePath);
  if (normalizedTargetPath != normalizedSourceFile) {
    return target;
  }
  final workspacePath = _containsPath(workingDirectory, rewrittenFile)
      ? _relativePath(root: workingDirectory, path: rewrittenFile)
      : target.workspacePath;
  return LiveEditSourceTarget(
    nodeId: target.nodeId,
    widgetType: target.widgetType,
    absolutePath: rewrittenFile,
    workspacePath: workspacePath,
    line: target.line,
    column: target.column,
  );
}

Future<void> _roundTripFixtureText(
  final WidgetTester tester,
  final LiveEditIntegrationHarness h, {
  required final String from,
  required final String to,
}) async {
  expect(_fixtureRenderedText(tester), from);
  await _selectFixtureTarget(tester, h);
  await _selectEditableFixtureCandidate(tester, h);
  await _ensurePanelExpanded(tester, h);
  expect(h.activeSelection?.source?.file, contains(_fixtureSourceBasename));
  print(
    '[agent-test] fixture selection '
    'widget=${h.activeSelection?.widgetType} '
    'render=${h.activeSelection?.renderObjectType} '
    'node=${h.activeSelection?.nodeId}',
  );

  OpenAiBubbleCommand(defaultPrompt: '').execute(h.context);
  UpdateAiComposerCommand(
    value: "Change the displayed text from '$from' to '$to'.",
  ).execute(h.context);
  await tester.pumpAndSettle();

  expect(h.aiComposer.trim().isNotEmpty, isTrue);
  expect(_fixtureRenderedText(tester), to);
  await _applyCurrentDraft(tester, h);
  expect(_fixtureRenderedText(tester), to);
}

Future<void> _roundTripToolAiBubbleColor(
  final WidgetTester tester,
  final LiveEditIntegrationHarness h,
) async {
  await _selectToolAiBubble(tester, h);
  await _ensurePanelExpanded(tester, h);

  expect(_activeAiBubbleMaterial(tester).color, _bubbleOriginalColor);
  OpenAiBubbleCommand(defaultPrompt: '').execute(h.context);
  UpdateAiComposerCommand(
    value: 'Change the Container backgroundColor to #112233',
  ).execute(h.context);
  await tester.pumpAndSettle();
  await _applyCurrentDraft(tester, h);
  expect(_activeAiBubbleMaterial(tester).color, _bubbleUpdatedColor);

  UpdateAiComposerCommand(
    value: 'Change the Container backgroundColor back to #FFFBEB',
  ).execute(h.context);
  await tester.pumpAndSettle();
  await _applyCurrentDraft(tester, h);
  expect(_activeAiBubbleMaterial(tester).color, _bubbleOriginalColor);
}

Future<void> _selectEditableFixtureCandidate(
  final WidgetTester tester,
  final LiveEditIntegrationHarness h,
) async {
  bool hasFixtureSourceSelection() {
    final selection = h.activeSelection;
    if (selection == null) return false;
    final sourceFile = selection.source?.file ?? '';
    return sourceFile.contains(_fixtureSourceBasename);
  }

  if (hasFixtureSourceSelection()) {
    return;
  }

  for (var index = 0; index < h.activeSelectionCandidates.length; index += 1) {
    h.selectCandidateAt(index);
    await tester.pumpAndSettle();
    if (hasFixtureSourceSelection()) {
      return;
    }
  }

  fail('Could not resolve an editable text candidate for the fixture target.');
}

Future<void> _selectFixtureTarget(
  final WidgetTester tester,
  final LiveEditIntegrationHarness h,
) async {
  bool hasFixtureSourceSelection() {
    final selection = h.activeSelection;
    if (selection == null) return false;
    final sourceFile = selection.source?.file ?? '';
    return sourceFile.contains(_fixtureSourceBasename);
  }

  await tester.tap(_fixtureText(_fixtureOriginalText), warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 300));
  if (!hasFixtureSourceSelection()) {
    h.selectNode(tester.getCenter(_fixtureText(_fixtureOriginalText)));
    await _pumpUntil(
      tester,
      () => h.activeSelection != null,
      timeout: const Duration(seconds: 10),
    );
  }

  if (!hasFixtureSourceSelection()) {
    final fixtureCenter = tester.getCenter(_fixtureRichText());
    h.hoverNode(fixtureCenter, deeperMode: true);
    await tester.pumpAndSettle();
    h.selectNode(
      fixtureCenter,
      preferHoverPreview: true,
      selectionPolicy: LiveEditSelectionPolicy.deepest,
    );
    await tester.pumpAndSettle();
  }
}

Future<void> _selectToolAiBubble(
  final WidgetTester tester,
  final LiveEditIntegrationHarness h,
) async {
  OpenAiBubbleCommand(defaultPrompt: '').execute(h.context);
  await tester.pumpAndSettle();
  expect(_aiBubbleKey(), findsOneWidget);

  await tester.tap(find.widgetWithText(ChoiceChip, 'Tools'));
  await tester.pumpAndSettle();

  expect(h.targetDomain, LiveEditTargetDomain.toolScene);
  expect(h.activeSelection?.targetDomain, LiveEditTargetDomain.appScene);
  expect(_semanticsId('live_edit_ai_bubble'), findsOneWidget);

  h.selectTrackedBubble(kLiveEditAiBubbleSurfaceId);
  await tester.pumpAndSettle();

  expect(h.activeSelection, isNotNull);
  expect(h.activeSelection!.targetDomain, LiveEditTargetDomain.toolScene);
  expect(h.activeSelection!.nodeId, kLiveEditAiBubbleSurfaceId);
}

Finder _semanticsId(final String id) => find.byWidgetPredicate(
  (final widget) => widget is Semantics && widget.properties.identifier == id,
  description: 'Semantics identifier $id',
);

final class _LiveEditAgentIntegrationHarness {
  final LiveEditAgentService service = LiveEditAgentService();
  final Set<String> _copiedPackageRoots = <String>{};
  final Map<String, String> _mappedFilesBySource = <String, String>{};
  final Map<String, String> _originalContentsByMapped = <String, String>{};

  Directory? _workspace;
  String? _workspaceRoot;
  String? _repoRoot;

  Future<void> dispose() async {
    final workspace = _workspace;
    if (workspace != null && workspace.existsSync()) {
      await workspace.delete(recursive: true);
    }
  }

  Future<Map<String, Object?>> handle(
    final LiveEditApplyDraftRequest request,
  ) async {
    request.onEvent?.call(
      const LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Preparing integration workspace.',
      ),
    );
    print(
      '[agent-test] handle backend=${request.backendId ?? _agentBackendId} '
      'approve=${request.approve} drafts=0',
    );
    final workingDirectory = await _ensureWorkspaceForRequest(request);
    final backendId = request.backendId ?? _agentBackendId;
    final debugDetails = _requestDebugDetails(
      request,
      backendId: backendId,
      workingDirectory: workingDirectory,
    );
    print('[agent-test] workspace=$workingDirectory');

    request.onEvent?.call(
      LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.codex,
        message: 'Preparing source context for $_agentBackendId.',
        details: <String>[
          'Workspace: $workingDirectory',
          'Backend: $backendId',
        ],
      ),
    );
    request.onEvent?.call(
      LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.debug,
        message: 'Resolve request dispatched.',
        details: <String>[
          ...debugDetails,
          if ((request.effectiveInstructionText ?? '').trim().isNotEmpty)
            'Instruction: ${request.effectiveInstructionText}',
        ],
        debugOnly: true,
      ),
    );
    print('[agent-test] resolving via $backendId');

    final rewrittenPrimarySelection = _rewriteSelection(
      request.effectivePrimarySelection,
    );
    final rewrittenSourceTargets = _rewriteSourceTargets(
      request.sourceTargets,
      workingDirectory: workingDirectory,
    );
    final rewrittenPrimarySource = rewrittenPrimarySelection?.source?.file;
    final rewrittenPrimaryExists =
        rewrittenPrimarySource != null &&
        rewrittenPrimarySource.trim().isNotEmpty &&
        File(_normalizePath(rewrittenPrimarySource)).existsSync();
    print(
      '[agent-test] rewritten primary source='
      '${rewrittenPrimarySource ?? '<none>'} '
      'exists=$rewrittenPrimaryExists '
      'sourceTargets=${rewrittenSourceTargets.map((final target) => target.absolutePath).join(', ')}',
    );

    final resolutionRequest = LiveEditResolutionRequest(
      sessionId: request.sessionId,
      bubbleId: request.effectiveBubbleId,
      backendId: backendId,
      workingDirectory: workingDirectory,
      instructionText: request.effectiveInstructionText,
      primarySelection: rewrittenPrimarySelection,
      selectedWidgets: request.effectiveSelectedWidgets
          .map(_rewriteSelection)
          .whereType<LiveEditSelection>()
          .toList(growable: false),
      sourceTargets: rewrittenSourceTargets,
      applyMode: request.applyMode,
      inferenceConfig: request.inferenceConfig,
    );
    final promptText = service.buildResolvedPrompt(resolutionRequest);
    request.onEvent?.call(
      LiveEditRuntimeEvent(
        kind: LiveEditRuntimeEventKind.debug,
        message: 'Resolved backend prompt captured.',
        details: <String>[
          ...debugDetails,
          'Prompt bytes: ${promptText.length}',
        ],
        promptText: promptText,
        debugOnly: true,
      ),
    );
    try {
      final execution = await service.executeDirectApply(resolutionRequest);
      final executionPlan = service.buildExecutionPlanForExecution(
        request: resolutionRequest,
        execution: execution,
      );
      request.onEvent?.call(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.codex,
          message: 'Agent applied the requested live-edit change.',
          details: <String>[execution.summary, ...execution.changedFiles],
        ),
      );
      request.onEvent?.call(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Execution result received.',
          details: <String>[
            'Execution: ${execution.executionId}',
            'Backend: ${execution.backendId}',
            ...execution.changedFiles,
          ],
          debugOnly: true,
        ),
      );
      print(
        '[agent-test] direct apply complete '
        'files=${execution.changedFiles.length}',
      );
      return <String, Object?>{
        'proposalId': execution.executionId,
        'executionPlan': executionPlan.toJson(),
        'executionResult': execution.toJson(),
        'result': execution.toJson(),
      };
    } on LiveEditAgentException catch (error) {
      request.onEvent?.call(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Direct apply request failed.',
          details: <String>[
            ...debugDetails,
            'Error: ${_errorMessageWithDetails(error.message, details: error.details)}',
          ],
          debugOnly: true,
        ),
      );
      return _failureResponse(
        error.message,
        details: error.details,
        meta: error.meta,
      );
    } on Exception catch (error) {
      request.onEvent?.call(
        LiveEditRuntimeEvent(
          kind: LiveEditRuntimeEventKind.debug,
          message: 'Direct apply request failed.',
          details: <String>[...debugDetails, 'Error: $error'],
          debugOnly: true,
        ),
      );
      return _failureResponse('$error');
    }
  }

  String? mappedFileForSource(final String sourceFile) =>
      _mappedFilesBySource[_normalizePath(sourceFile)];

  String? originalContentsForSource(final String sourceFile) {
    final mapped = mappedFileForSource(sourceFile);
    if (mapped == null) {
      return null;
    }
    return _originalContentsByMapped[mapped];
  }

  Future<void> _ensureMappedSelection(
    final LiveEditSelection? selection,
  ) async {
    final sourceFile = selection?.source?.file;
    if (sourceFile == null || sourceFile.trim().isEmpty) {
      return;
    }
    final normalizedSourceFile = _normalizePath(sourceFile);
    if (_mappedFilesBySource.containsKey(normalizedSourceFile)) {
      return;
    }

    final workspaceRoot = await _ensureWorkspaceRoot(normalizedSourceFile);
    final repoRoot = _repoRoot!;
    final packageRoot = _packageRootFromSource(normalizedSourceFile);
    await _ensurePackageCopied(
      packageRoot: packageRoot,
      repoRoot: repoRoot,
      workspaceRoot: workspaceRoot,
    );

    final relativePath = _relativePath(
      root: repoRoot,
      path: normalizedSourceFile,
    );
    final mappedPath = _joinPath(workspaceRoot, relativePath);
    _mappedFilesBySource[normalizedSourceFile] = mappedPath;

    final copiedSourceFile = File(mappedPath);
    if (copiedSourceFile.existsSync()) {
      _originalContentsByMapped[mappedPath] = await copiedSourceFile
          .readAsString();
      print('[agent-test] mapped source=$mappedPath');
    }
  }

  Future<void> _ensurePackageCopied({
    required final String packageRoot,
    required final String repoRoot,
    required final String workspaceRoot,
  }) async {
    final normalizedPackageRoot = _normalizePath(packageRoot);
    if (_copiedPackageRoots.contains(normalizedPackageRoot)) {
      return;
    }
    _copiedPackageRoots.add(normalizedPackageRoot);

    final relativePackageRoot = _relativePath(
      root: repoRoot,
      path: normalizedPackageRoot,
    );
    final targetPackageRoot = relativePackageRoot.isEmpty
        ? workspaceRoot
        : _joinPath(workspaceRoot, relativePackageRoot);

    final libSource = Directory('$normalizedPackageRoot/lib');
    if (libSource.existsSync()) {
      _copyShallowDirectory(libSource, Directory('$targetPackageRoot/lib'));
    }
    for (final relativeFile in <String>[
      'pubspec.yaml',
      'analysis_options.yaml',
    ]) {
      final sourceFile = File('$normalizedPackageRoot/$relativeFile');
      if (!sourceFile.existsSync()) {
        continue;
      }
      final targetFile = File('$targetPackageRoot/$relativeFile');
      targetFile.parent.createSync(recursive: true);
      targetFile.writeAsBytesSync(sourceFile.readAsBytesSync());
    }
  }

  Future<String> _ensureWorkspaceForRequest(
    final LiveEditApplyDraftRequest request,
  ) async {
    await _ensureMappedSelection(request.effectivePrimarySelection);
    for (final selection in request.effectiveSelectedWidgets) {
      await _ensureMappedSelection(selection);
    }
    return _workspaceRoot ?? _resolvedWorkingDirectory();
  }

  Future<String> _ensureWorkspaceRoot(final String sourceFile) async {
    if (_workspaceRoot != null) {
      return _workspaceRoot!;
    }
    final repoRoot = _repoRootFromPath(sourceFile);
    _repoRoot = repoRoot;
    print('[agent-test] creating temp workspace from $repoRoot');
    final workspace = await Directory.systemTemp.createTemp(
      'live_edit_agent_workspace_',
    );
    _workspace = workspace;
    _workspaceRoot = workspace.path;
    return workspace.path;
  }

  LiveEditSelection? _rewriteSelection(final LiveEditSelection? selection) {
    final sourceFile = selection?.source?.file;
    if (selection == null || sourceFile == null || sourceFile.trim().isEmpty) {
      return selection;
    }
    final normalizedSourceFile = _normalizePath(sourceFile);
    final mappedSourcePath = _mappedFilesBySource[normalizedSourceFile];
    if (mappedSourcePath == null) {
      return selection;
    }
    return _rewriteSelectionSource(
      selection: selection,
      sourceFile: normalizedSourceFile,
      rewrittenFile: mappedSourcePath,
    );
  }

  List<LiveEditSourceTarget> _rewriteSourceTargets(
    final List<LiveEditSourceTarget> sourceTargets, {
    required final String workingDirectory,
  }) {
    if (sourceTargets.isEmpty) {
      return const <LiveEditSourceTarget>[];
    }
    return sourceTargets
        .map((final target) {
          final absolutePath = target.absolutePath;
          if (absolutePath == null || absolutePath.trim().isEmpty) {
            return target;
          }
          final mappedPath = _mappedFilesBySource[_normalizePath(absolutePath)];
          if (mappedPath == null) {
            return target;
          }
          return _rewriteSourceTarget(
            target: target,
            sourceFile: absolutePath,
            rewrittenFile: mappedPath,
            workingDirectory: workingDirectory,
          );
        })
        .toList(growable: false);
  }
}
