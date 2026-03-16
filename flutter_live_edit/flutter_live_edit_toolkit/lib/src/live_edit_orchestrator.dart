import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'commands/commands.dart';
import 'live_edit_context.dart';
import 'live_edit_controller_adapter.dart';
import 'live_edit_types.dart';
import 'resources/resources.dart';
import 'services/services.dart';

List<LiveEditPropertyDescriptor> _commonEditableProperties(
  final List<LiveEditSelection> selections,
) {
  if (selections.isEmpty) {
    return const <LiveEditPropertyDescriptor>[];
  }
  final base = selections.first.propertyGroups
      .where((final property) => property.editable)
      .toList(growable: false);
  return base
      .where(
        (final property) => selections
            .skip(1)
            .every(
              (final selection) => selection.propertyGroups.any(
                (final candidate) =>
                    candidate.id == property.id &&
                    candidate.kind == property.kind &&
                    candidate.editable,
              ),
            ),
      )
      .toList(growable: false);
}

String _fallbackBackendLabel(final String backendId) => backendId
    .split(RegExp(r'[_\-\s]+'))
    .where((final part) => part.isNotEmpty)
    .map(
      (final part) =>
          '${part.substring(0, 1).toUpperCase()}${part.substring(1).toLowerCase()}',
    )
    .join(' ');

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

double _maxDouble(final double left, final double right) =>
    left > right ? left : right;

double _minDouble(final double left, final double right) =>
    left < right ? left : right;

final class LiveEditOrchestrator extends ChangeNotifier {
  LiveEditOrchestrator({
    final LiveEditController? controller,
    this.applyDraftDelegate,
    final String? backendId,
    final List<LiveEditAgentBackend> availableBackends =
        const <LiveEditAgentBackend>[],
    this.workingDirectory,
    this.intentText,
  }) : _availableBackends = List<LiveEditAgentBackend>.unmodifiable(
         availableBackends,
       ),
       _backendId = _resolveInitialBackendId(
         availableBackends: availableBackends,
         backendId: backendId,
       ) {
    _sessionResource = LiveEditSessionResource();
    _selectionResource = LiveEditSelectionResource();
    _draftResource = LiveEditDraftResource();
    _bubbleResource = LiveEditBubbleResource();
    _panelViewResource = LiveEditPanelViewResource();
    _sessionService = LiveEditSessionService();
    _applyService = LiveEditApplyService(
      applyDraftDelegate: applyDraftDelegate,
    );
    _context = LiveEditContext(
      sessionResource: _sessionResource,
      selectionResource: _selectionResource,
      draftResource: _draftResource,
      bubbleResource: _bubbleResource,
      panelViewResource: _panelViewResource,
      sessionService: _sessionService,
      applyService: _applyService,
      applyEventSink: _emitEventForBubble,
    );
    _controller = LiveEditController(_context);
    LiveEditOrchestrator.instance = this;
    void onResourceChange() => notifyListeners();
    _sessionResource.addListener(onResourceChange);
    _selectionResource.addListener(onResourceChange);
    _draftResource.addListener(onResourceChange);
    _bubbleResource.addListener(onResourceChange);
    _panelViewResource.addListener(onResourceChange);
  }

  late final LiveEditSessionResource _sessionResource;
  late final LiveEditSelectionResource _selectionResource;
  late final LiveEditDraftResource _draftResource;
  late final LiveEditBubbleResource _bubbleResource;
  late final LiveEditPanelViewResource _panelViewResource;
  late final LiveEditSessionService _sessionService;
  late final LiveEditApplyService _applyService;
  late final LiveEditContext _context;
  late final LiveEditController _controller;

  LiveEditController get controller => _controller;

  /// Property-edit plugin: delegate to session service.
  set propertyDescriptorProvider(
    final List<LiveEditPropertyDescriptor> Function(
      Element element,
      LiveEditTargetDomain targetDomain,
    )?
    value,
  ) {
    _sessionService.propertyDescriptorProvider = value;
  }

  /// MCP / toolkit: run command and return result map.
  Map<String, Object?> startSession({
    final String? requestedSessionId,
    final LiveEditTargetDomain targetDomain = LiveEditTargetDomain.appScene,
  }) => StartSessionCommand(
    requestedSessionId: requestedSessionId,
    targetDomain: targetDomain,
  ).execute(_context);

  Map<String, Object?> setOverlay({
    required final bool enabled,
    final String? sessionId,
  }) => SetOverlayCommand(
    sessionId: sessionId,
    enabled: enabled,
  ).execute(_context);

  Map<String, Object?> getTree({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) => GetTreeCommand(
    sessionId: sessionId,
    targetDomain: targetDomain,
  ).execute(_context);

  Map<String, Object?> selectAtPoint({
    required final int x,
    required final int y,
    final String? sessionId,
    final int? viewId,
    final LiveEditSelectionPolicy? selectionPolicy,
    final LiveEditTargetDomain? targetDomain,
  }) => SelectAtPointCommand(
    sessionId: sessionId,
    x: x,
    y: y,
    viewId: viewId,
    selectionPolicy: selectionPolicy ?? LiveEditSelectionPolicy.deepest,
    targetDomain: targetDomain,
  ).execute(_context);

  Map<String, Object?> getSelection({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) => GetSelectionCommand(
    sessionId: sessionId,
    targetDomain: targetDomain,
  ).execute(_context);

  /// MCP: update draft from a serialized change; returns result map.
  Map<String, Object?> updateDraftFromChange({
    required final LiveEditDraftChange change,
    final String? sessionId,
  }) => UpdateDraftCommand(
    sessionId: sessionId,
    change: change,
  ).execute(_context);

  Map<String, Object?> getDraft({
    final String? sessionId,
    final LiveEditTargetDomain? targetDomain,
  }) => GetDraftCommand(
    sessionId: sessionId,
    targetDomain: targetDomain,
  ).execute(_context);

  Map<String, Object?> discardDraft({final String? sessionId}) =>
      DiscardDraftCommand(sessionId: sessionId).execute(_context);

  Map<String, Object?> endSession({final String? sessionId}) =>
      EndSessionCommand(sessionId: sessionId).execute(_context);

  static LiveEditOrchestrator? instance;

  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final String? workingDirectory;
  final String? intentText;
  String? _backendId;
  List<LiveEditAgentBackend> _availableBackends;
  final Map<String, LiveEditInferenceConfig> _inferenceConfigByBackend =
      <String, LiveEditInferenceConfig>{};

  bool _disposed = false;
  String? _lastSelectionIdentity;
  bool _toolPresentationArmed = false;

  LiveEditBubbleId? get activeBubbleId =>
      _layerViewStateFor(_presentationLayer).activeBubbleId ??
      _bubbleIdForSelection(activeSelection);
  bool get activeBubbleResolved =>
      _hasText(activeBubbleId) &&
      _bubbleResource.value.resolvedBubbleIds.contains(activeBubbleId);
  List<LiveEditDraftChange> get activeDraftChanges =>
      _activeBubbleState?.draftChanges ?? _draftChangesForActiveSelection();
  LiveEditTargetDomain get activeLayer => targetDomain;
  List<LiveEditSelection> get activeMultiSelection =>
      _controller.multiSelectionForDomain(
        targetDomain: _presentationLayer,
        sessionId: activeSessionId,
      );
  LiveEditPropertyDescriptor? get activeProperty {
    final properties = effectiveProperties;
    if (properties.isEmpty) return null;
    final activeId = _layerViewStateFor(_presentationLayer).activePropertyId;
    if (_hasText(activeId)) {
      for (final property in properties) {
        if (property.id == activeId) {
          return property;
        }
      }
    }
    for (final property in properties) {
      if (property.editable) {
        return property;
      }
    }
    return properties.first;
  }

  String? get activePropertyId =>
      _layerViewStateFor(_presentationLayer).activePropertyId;
  LiveEditSelection? get activeSelection =>
      selectionByDomain(_presentationLayer);
  List<LiveEditSelectionCandidate> get activeSelectionCandidates =>
      _controller.selectionCandidatesForDomain(
        targetDomain: _presentationLayer,
        sessionId: activeSessionId,
      );
  String? get activeSessionId => _sessionResource.value.activeSessionId;
  List<LiveEditActivityEntry> get activityTimelineForActiveSelection =>
      List<LiveEditActivityEntry>.unmodifiable(
        _activeBubbleState?.activity ?? const <LiveEditActivityEntry>[],
      );
  bool get aiBubbleVisible =>
      overlayVisible &&
      activeSelection != null &&
      (editMode == LiveEditEditMode.ai ||
          needsApproval ||
          applyPhase == LiveEditApplyPhase.success);
  String get aiComposer =>
      _activeBubbleState?.instructionText ??
      _bubbleResource.value.globalComposerText;
  LiveEditApplyPhase get applyPhase => _bubbleResource.value.applyPhase;
  List<LiveEditAgentBackend> get availableBackends => _availableBackends;
  Offset get bubbleDragOffset =>
      _activeBubbleState?.bubbleDragOffset ?? Offset.zero;
  double get bubbleHeight => _panelViewResource.value.bubbleHeight;
  LiveEditBubbleStatus get bubbleStatusForActiveSelection {
    final bubble = _activeBubbleState;
    return bubble?.status ?? LiveEditBubbleStatus.editing;
  }

  List<LiveEditBubbleSummary> get bubbleSummaries {
    final domains = <LiveEditTargetDomain>[targetDomain, inactiveLayer];
    return domains.expand(bubbleSummariesByDomain).toList(growable: false);
  }

  double get bubbleWidth => _panelViewResource.value.bubbleWidth;
  bool get canApplyAllBubbles =>
      !isApplyingBusy && _pendingBubbleStates().length > 1;
  bool get canResolveActiveBubble =>
      bubbleStatusForActiveSelection == LiveEditBubbleStatus.applied &&
      _hasText(activeBubbleId);
  bool get canSubmitAiPrompt =>
      activeSelection != null &&
      hasAiPrompt &&
      !needsApproval &&
      !isApplyingBusy;
  bool get canTriggerApply =>
      needsApproval || hasDraftChanges || canSubmitAiPrompt;
  LiveEditActivityEntry? get currentActivity {
    final bubbleId = activeBubbleId;
    if (!_hasText(bubbleId)) {
      return null;
    }
    final backendLabel = backendLabelForBubble(bubbleId);
    final now = DateTime.now().toUtc();
    final applyPhase = _bubbleResource.value.applyPhase;
    final lastErr = _bubbleResource.value.lastError;
    if (applyPhase == LiveEditApplyPhase.failed && _hasText(lastErr)) {
      return LiveEditActivityEntry(
        step: LiveEditActivityStep.failed,
        label: 'Failed',
        summary: _failureSummary(lastErr!, bubbleId: bubbleId),
        details: <String>[lastErr],
        timestamp: now,
        nodeId: bubbleId,
        errorText: lastErr,
      );
    }
    if (applyPhase == LiveEditApplyPhase.success) {
      final timeline = _activeBubbleState?.activity;
      if (timeline != null && timeline.isNotEmpty) {
        return timeline.last;
      }
      return LiveEditActivityEntry(
        step: LiveEditActivityStep.finished,
        label: 'Applied',
        summary: 'Live-edit changes are applied for this node.',
        timestamp: now,
        nodeId: bubbleId,
      );
    }
    if (needsApproval) {
      final timeline = _activeBubbleState?.activity;
      if (timeline != null && timeline.isNotEmpty) {
        return timeline.last;
      }
      return LiveEditActivityEntry(
        step: LiveEditActivityStep.applyingChanges,
        label: 'Applying',
        summary:
            _bubbleResource.value.pendingExecutionPlan?.summary ??
            '$backendLabel is applying this bubble change.',
        timestamp: now,
        nodeId: bubbleId,
      );
    }
    if (hasDraftChanges) {
      return LiveEditActivityEntry(
        step: LiveEditActivityStep.draftReady,
        label: 'Draft ready',
        summary: 'Draft changes are ready to send to $backendLabel.',
        timestamp: now,
        nodeId: bubbleId,
      );
    }
    if (canSubmitAiPrompt) {
      return LiveEditActivityEntry(
        step: LiveEditActivityStep.promptReady,
        label: 'Prompt ready',
        summary: 'AI prompt is ready to send to $backendLabel.',
        timestamp: now,
        nodeId: bubbleId,
      );
    }
    final timeline = _activeBubbleState?.activity;
    if (timeline != null && timeline.isNotEmpty) {
      return timeline.last;
    }
    return null;
  }

  LiveEditAgentBackend? get currentBackend {
    final bubbleId = activeBubbleId;
    return backendForBubble(bubbleId);
  }

  String? get currentBackendId =>
      backendIdForBubble(activeBubbleId) ?? _backendId;
  String get currentBackendLabel =>
      currentBackend?.label.trim().isNotEmpty == true
      ? currentBackend!.label
      : _hasText(_backendId)
      ? _fallbackBackendLabel(_backendId!)
      : 'AI agent';
  bool get currentBackendUsesFreeformModel =>
      currentBackend?.id == 'cursor_agent';

  LiveEditInferenceConfig? get currentInferenceConfig {
    final bubbleId = activeBubbleId;
    return inferenceConfigForBubble(bubbleId);
  }

  String? get currentModel => currentInferenceConfig?.model;

  String? get currentReasoningEffort => currentInferenceConfig?.reasoningEffort;
  List<LiveEditCodexModelOption> get currentSupportedModels {
    final backend = currentBackend;
    if (backend == null || backend.id != 'codex_exec') {
      return const <LiveEditCodexModelOption>[];
    }
    final models = backend.meta['supportedModels'];
    if (models is! List) {
      return LiveEditCodexOptions.supportedModels;
    }
    return models
        .whereType<Map>()
        .map(
          (final item) => LiveEditCodexModelOption.fromJson(
            item.map((final key, final value) => MapEntry('$key', value)),
          ),
        )
        .toList(growable: false);
  }

  List<String> get currentSupportedReasoningEfforts {
    final backend = currentBackend;
    if (backend == null || backend.id != 'codex_exec') {
      return const <String>[];
    }
    final efforts = backend.meta['supportedReasoningEfforts'];
    if (efforts is! List) {
      return LiveEditCodexOptions.supportedReasoningEfforts;
    }
    return efforts.map((final item) => '$item').toList(growable: false);
  }

  bool get debugModeEnabled => _panelViewResource.value.debugModeEnabled;
  String? get debugPromptForActiveSelection {
    final prompt = _activeBubbleState?.debugPromptText?.trim();
    return _hasText(prompt) ? prompt : null;
  }

  List<LiveEditTimelineEntry> get debugTimelineForActiveSelection =>
      List<LiveEditTimelineEntry>.unmodifiable(
        _activeBubbleState?.debugTimeline ?? const <LiveEditTimelineEntry>[],
      );
  bool get deeperPickEnabled => _panelViewResource.value.deeperPickEnabled;

  bool get editingToolScene => targetDomain == LiveEditTargetDomain.toolScene;
  LiveEditEditMode get editMode =>
      _layerViewStateFor(_presentationLayer).editMode;
  List<LiveEditPropertyDescriptor> get effectiveProperties => hasMultiSelection
      ? _commonEditableProperties(activeMultiSelection)
      : activeSelection?.propertyGroups ?? const <LiveEditPropertyDescriptor>[];

  List<LiveEditBubbleSummary> get expandedBubbleSummaries {
    final domains = <LiveEditTargetDomain>[targetDomain, inactiveLayer];
    return domains
        .expand(expandedBubbleSummariesByDomain)
        .toList(growable: false);
  }

  bool get hasAgentBackedDrafts {
    final selection = activeSelection;
    if (selection == null) {
      return false;
    }
    for (final draft in activeDraftChanges) {
      for (final property in selection.propertyGroups) {
        if (property.id == draft.propertyId &&
            property.requiresAgentForPersistence) {
          return true;
        }
      }
    }
    return false;
  }

  bool get hasAiPrompt => _hasText(aiComposer);
  bool get hasBackendChoice => _availableBackends.length > 1;
  bool get hasDraftChanges => activeDraftChanges.isNotEmpty;

  bool get hasMarqueePreview =>
      marqueeRect != null && marqueePreviewSelections.isNotEmpty;

  bool get hasMultiSelection => activeMultiSelection.length > 1;

  List<LiveEditTimelineEntry> get historyForActiveSelection =>
      List<LiveEditTimelineEntry>.unmodifiable(
        _activeBubbleState?.history ?? const <LiveEditTimelineEntry>[],
      );
  LiveEditSelection? get hoverSelection => _controller.hoverSelection;
  LiveEditTargetDomain get inactiveLayer =>
      targetDomain == LiveEditTargetDomain.appScene
      ? LiveEditTargetDomain.toolScene
      : LiveEditTargetDomain.appScene;

  bool get isApplyingBusy {
    final phase = _bubbleResource.value.applyPhase;
    return phase == LiveEditApplyPhase.preparing ||
        phase == LiveEditApplyPhase.applying;
  }

  bool get isWaitingForAgent =>
      bubbleStatusForActiveSelection == LiveEditBubbleStatus.waiting;
  String? get lastError =>
      _activeBubbleState?.lastError ?? _bubbleResource.value.lastError;
  List<LiveEditSelection> get marqueePreviewSelections =>
      _controller.marqueeSelectionsForDomain(
        targetDomain: _presentationLayer,
        sessionId: activeSessionId,
      );

  Rect? get marqueeRect => _controller.marqueeRectForDomain(
    targetDomain: _presentationLayer,
    sessionId: activeSessionId,
  );

  bool get needsApproval =>
      _bubbleResource.value.applyPhase == LiveEditApplyPhase.awaitingApproval &&
      _bubbleResource.value.pendingExecutionPlan != null &&
      _hasText(_bubbleResource.value.pendingProposalId);

  bool get overlayVisible => _sessionResource.value.overlayVisible;

  LiveEditPanelDisplayMode get panelDisplayMode =>
      _panelViewResource.value.panelDisplayMode;
  Offset get panelDragOffset => _panelViewResource.value.panelDragOffset;
  bool get panelExpanded =>
      panelDisplayMode == LiveEditPanelDisplayMode.expanded;
  double get panelHeight => panelExpanded
      ? _panelViewResource.value.panelExpandedHeight
      : _panelViewResource.value.panelRailHeight;
  double get panelWidth => panelExpanded
      ? _panelViewResource.value.panelExpandedWidth
      : _panelViewResource.value.panelRailWidth;
  int get pendingBubbleCount => _pendingBubbleStates().length;

  LiveEditExecutionPlan? get pendingExecutionPlan =>
      _activeBubbleState?.executionPlan ??
      _bubbleResource.value.pendingExecutionPlan;

  List<LiveEditBubbleSummary> get pinnedBubbleSummaries => bubbleSummaries
      .where(
        (final summary) =>
            summary.displayState == LiveEditBubbleDisplayState.minimized,
      )
      .toList(growable: false);

  LiveEditTargetDomain get presentedLayer =>
      editingToolScene && !_toolPresentationArmed
      ? LiveEditTargetDomain.appScene
      : targetDomain;

  String? get stagedDraftSummary {
    if (!hasDraftChanges) {
      return null;
    }
    return activeDraftChanges
        .map(_describeDraftChange)
        .where(_hasText)
        .join(' | ');
  }

  String? get stagedPromptText {
    final prompt = aiComposer.trim();
    return prompt.isEmpty ? null : prompt;
  }

  String? get stagedRequestSummary {
    final sections = <String>[
      if (_hasText(stagedDraftSummary)) 'Edits: ${stagedDraftSummary!}',
      if (_hasText(stagedPromptText)) 'Prompt: ${stagedPromptText!}',
    ];
    if (sections.isEmpty) {
      return null;
    }
    return sections.join('\n');
  }

  LiveEditTargetDomain get targetDomain => _sessionResource.value.targetDomain;

  LiveEditBubbleRecord? get _activeBubbleState =>
      _bubbleRecordFor(activeBubbleId);

  LiveEditTargetDomain get _presentationLayer => presentedLayer;

  Future<void> applyAllBubbles() async =>
      ApplyAllBubblesCommand().execute(_context);

  Future<void> applyDraft({
    final bool approve = false,
    final String? message,
  }) async {
    if (!_hasText(activeBubbleId)) {
      _setError('No draft changes to apply.');
      return;
    }
    await ApplyDraftCommand(
      approve: approve,
      message: message,
      workingDirectory: workingDirectory,
      intentText: intentText,
      globalBackendId: _backendId,
    ).execute(_context);
  }

  Future<void> applyDraftForBubble(
    final String bubbleId, {
    final bool approve = false,
    final String? message,
  }) async {
    if (!_hasText(bubbleId)) return;
    await ApplyDraftForBubbleCommand(
      bubbleId: bubbleId,
      approve: approve,
      message: message,
      workingDirectory: workingDirectory,
      intentText: intentText,
      globalBackendId: _backendId,
    ).execute(_context);
  }

  Offset autoBubblePlacement({
    required final LiveEditBounds bounds,
    required final Size viewport,
  }) {
    const gap = 12.0;
    final rightSpace = viewport.width - bounds.right - 16;
    final leftSpace = bounds.left - 16;
    double left;
    double top = _maxDouble(16, bounds.top);

    if (rightSpace >= bubbleWidth) {
      left = bounds.right + gap;
    } else if (leftSpace >= bubbleWidth) {
      left = bounds.left - bubbleWidth - gap;
    } else {
      left = _minDouble(
        viewport.width - bubbleWidth - 16,
        _maxDouble(16, bounds.left),
      );
      top = _minDouble(
        viewport.height - bubbleHeight - 16,
        bounds.bottom + gap,
      );
    }

    top = _minDouble(top, viewport.height - bubbleHeight - 16);
    return Offset(left, _maxDouble(16, top));
  }

  LiveEditAgentBackend? backendForBubble(final String? bubbleId) {
    final backendId = backendIdForBubble(bubbleId);
    if (!_hasText(backendId)) {
      return null;
    }
    for (final backend in _availableBackends) {
      if (backend.id == backendId) {
        return backend;
      }
    }
    return null;
  }

  String? backendIdForBubble(final String? bubbleId) {
    final bubbleBackendId = _bubbleRecordFor(bubbleId)?.backendId?.trim();
    if (_hasText(bubbleBackendId)) {
      return bubbleBackendId;
    }
    final globalBackendId = _backendId?.trim();
    if (_hasText(globalBackendId)) {
      return globalBackendId;
    }
    return _availableBackends.isEmpty ? null : _availableBackends.first.id;
  }

  String backendLabelForBubble(final String? bubbleId) {
    final backend = backendForBubble(bubbleId);
    if (backend?.label.trim().isNotEmpty == true) {
      return backend!.label;
    }
    final backendId = backendIdForBubble(bubbleId);
    return _hasText(backendId) ? _fallbackBackendLabel(backendId!) : 'AI agent';
  }

  void beginInlineEdit(
    final LiveEditPropertyDescriptor property, {
    final LiveEditEditSurface? surface,
  }) => FocusPropertyCommand(
    property: property,
    surface: surface,
    defaultPrompt: _defaultAiPrompt(),
    expandPanel: false,
  ).execute(_context);

  LiveEditBubbleRecord? bubbleForSelectionInLayer(
    final LiveEditTargetDomain domain, {
    final LiveEditSelection? selection,
  }) => _bubbleRecordFor(
    _bubbleIdForSelection(selection ?? selectionByDomain(domain)),
  );

  Offset bubblePlacement({
    required final LiveEditBounds bounds,
    required final Size viewport,
  }) => clampBubblePlacement(
    placement:
        autoBubblePlacement(bounds: bounds, viewport: viewport) +
        bubbleDragOffset,
    viewport: viewport,
  );

  Offset bubblePlacementFor(
    final String bubbleId, {
    required final LiveEditBounds bounds,
    required final Size viewport,
  }) {
    final dragOffset =
        _bubbleRecordFor(bubbleId)?.bubbleDragOffset ?? Offset.zero;
    return clampBubblePlacement(
      placement:
          autoBubblePlacement(bounds: bounds, viewport: viewport) + dragOffset,
      viewport: viewport,
    );
  }

  LiveEditBubbleRecord? bubbleRecordFor(final String? bubbleId) =>
      _bubbleRecordFor(bubbleId);

  LiveEditBubbleStatus bubbleStatusForBubble(final String? bubbleId) =>
      _hasText(bubbleId)
      ? (_bubbleRecordFor(bubbleId)?.status ?? LiveEditBubbleStatus.editing)
      : LiveEditBubbleStatus.editing;

  List<LiveEditBubbleSummary> bubbleSummariesByDomain(
    final LiveEditTargetDomain domain,
  ) {
    final data = _bubbleResource.value;
    final summaries = data.bubbleRecordsById.values
        .where(
          (final bubble) =>
              bubble.targetDomain == domain &&
              bubble.displayState == LiveEditBubbleDisplayState.minimized &&
              !data.resolvedBubbleIds.contains(bubble.bubbleId),
        )
        .map((final bubble) {
          final selection = bubble.primarySelection;
          final source = selection?.source;
          return LiveEditBubbleSummary(
            bubbleId: bubble.bubbleId,
            targetDomain: bubble.targetDomain,
            targetKey: bubble.targetKey,
            nodeId: selection?.nodeId ?? bubble.targetKey,
            label: selection?.widgetType ?? bubble.targetKey,
            status: bubble.status,
            active: bubble.bubbleId == activeBubbleId,
            displayState: bubble.displayState,
            bounds: selection?.bounds,
            sourceLabel: !_hasText(source?.file)
                ? null
                : '${source!.file}${source.line == null ? '' : ':${source.line}'}',
          );
        })
        .toList(growable: false);
    summaries.sort((final left, final right) {
      final activeScore = (right.active ? 1 : 0) - (left.active ? 1 : 0);
      if (activeScore != 0) {
        return activeScore;
      }
      return left.label.compareTo(right.label);
    });
    return summaries;
  }

  void cancelMarquee() {
    _sessionService.cancelMarquee(sessionId: activeSessionId);
    _context.applySessionUpdate(_sessionService.lastUpdate);
    notifyListeners();
  }

  bool canTriggerApplyForBubble(final String? bubbleId) =>
      _hasText(bubbleId) &&
      (needsApprovalForBubble(bubbleId) ||
          (_bubbleRecordFor(bubbleId)?.hasPendingApply ?? false));

  Offset clampBubblePlacement({
    required final Offset placement,
    required final Size viewport,
  }) {
    final maxLeft = _maxDouble(16, viewport.width - bubbleWidth - 16);
    final maxTop = _maxDouble(16, viewport.height - bubbleHeight - 16);
    return Offset(
      placement.dx.clamp(16, maxLeft),
      placement.dy.clamp(16, maxTop),
    );
  }

  Offset clampPanelPlacement({
    required final Offset placement,
    required final Size viewport,
  }) {
    final maxLeft = _maxDouble(16, viewport.width - panelWidth - 16);
    final maxTop = _maxDouble(16, viewport.height - panelHeight - 16);
    return Offset(
      placement.dx.clamp(16, maxLeft),
      placement.dy.clamp(16, maxTop),
    );
  }

  void clearHover() {
    if (!_hasText(activeSessionId)) {
      return;
    }
    _sessionService.clearHover(sessionId: activeSessionId);
    _context.applySessionUpdate(_sessionService.lastUpdate);
  }

  void collapsePanel() => CollapsePanelCommand().execute(_context);

  void commitMarquee() {
    _sessionService.commitMarquee(sessionId: activeSessionId);
    _context.applySessionUpdate(_sessionService.lastUpdate);
    _restoreBubbleState(_bubbleIdForSelection(activeSelection));
    _syncSelectionState();
  }

  void cycleSelectionCandidate(final int delta) {
    final candidates = activeSelectionCandidates;
    if (candidates.isEmpty) {
      return;
    }
    final activeIndex = candidates.indexWhere(
      (final candidate) => candidate.active,
    );
    final nextIndex = activeIndex < 0
        ? 0
        : (activeIndex + delta + candidates.length) % candidates.length;
    _sessionService.selectCandidate(
      sessionId: activeSessionId,
      index: nextIndex,
      targetDomain: _presentationLayer,
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
    _restoreBubbleState(_bubbleIdForSelection(activeSelection));
    _syncSelectionState();
  }

  @override
  void dispose() {
    _disposed = true;
    if (instance == this) instance = null;
    super.dispose();
  }

  List<LiveEditDraftChange> draftsByDomain(final LiveEditTargetDomain domain) =>
      _controller.draftChangesForDomain(
        targetDomain: domain,
        sessionId: activeSessionId,
      );

  void dragBubble(final Offset delta) =>
      DragBubbleCommand(delta: delta).execute(_context);

  void dragBubbleFor(final String bubbleId, final Offset delta) =>
      DragBubbleForCommand(bubbleId: bubbleId, delta: delta).execute(_context);

  void dragPanel(final Offset delta) =>
      DragPanelCommand(delta: delta).execute(_context);

  Object? effectiveValueForProperty(final LiveEditPropertyDescriptor property) {
    final draft = activeDraftChanges.lastWhere(
      (final candidate) => candidate.propertyId == property.id,
      orElse: () => LiveEditDraftChange(
        nodeId: activeSelection?.nodeId ?? '',
        propertyId: '',
        targetValue: null,
      ),
    );
    if (_hasText(draft.propertyId)) {
      return draft.targetValue;
    }
    return property.value;
  }

  String ensureSession() {
    final current = activeSessionId;
    if (_hasText(current)) {
      return current!;
    }
    final started = _sessionService.startSession(targetDomain: targetDomain);
    _context.applySessionUpdate(_sessionService.lastUpdate);
    return '${started['sessionId'] ?? ''}';
  }

  LiveEditExecutionPlan? executionPlanForBubble(final String? bubbleId) {
    final data = _bubbleResource.value;
    return _hasText(bubbleId) && bubbleId == data.pendingBubbleId
        ? data.pendingExecutionPlan
        : _bubbleRecordFor(bubbleId)?.executionPlan;
  }

  List<LiveEditBubbleSummary> expandedBubbleSummariesByDomain(
    final LiveEditTargetDomain domain,
  ) {
    final data = _bubbleResource.value;
    final summaries = data.bubbleRecordsById.values
        .where(
          (final bubble) =>
              bubble.targetDomain == domain &&
              bubble.displayState == LiveEditBubbleDisplayState.expanded &&
              !data.resolvedBubbleIds.contains(bubble.bubbleId),
        )
        .map((final bubble) {
          final selection = bubble.primarySelection;
          final source = selection?.source;
          return LiveEditBubbleSummary(
            bubbleId: bubble.bubbleId,
            targetDomain: bubble.targetDomain,
            targetKey: bubble.targetKey,
            nodeId: selection?.nodeId ?? bubble.targetKey,
            label: selection?.widgetType ?? bubble.targetKey,
            status: bubble.status,
            active: bubble.bubbleId == activeBubbleId,
            displayState: bubble.displayState,
            bounds: selection?.bounds,
            sourceLabel: !_hasText(source?.file)
                ? null
                : '${source!.file}${source.line == null ? '' : ':${source.line}'}',
          );
        })
        .toList(growable: false);
    summaries.sort((final left, final right) {
      final activeScore = (right.active ? 1 : 0) - (left.active ? 1 : 0);
      if (activeScore != 0) {
        return activeScore;
      }
      return left.label.compareTo(right.label);
    });
    return summaries;
  }

  void expandPanel() => ExpandPanelCommand().execute(_context);

  /// Prefills overlay, panel, and one demo bubble for use in
  /// [live_edit_tooling_ui_kit]. Call after building the host/tool layer.
  void prefillForToolingShowcase() {
    final sessionId = ensureSession();
    setOverlayEnabled(true);
    expandPanel();
    const bubbleId = 'showcase:tool-layer';
    final selection = LiveEditSelection(
      sessionId: sessionId,
      nodeId: 'showcase_bubble',
      widgetType: 'SelectionBubble',
      propertyGroups: <LiveEditPropertyDescriptor>[
        const LiveEditPropertyDescriptor(
          id: 'label',
          label: 'Label',
          group: LiveEditPropertyGroup.content,
          kind: LiveEditPropertyKind.string,
          value: 'Demo bubble',
          editable: true,
        ),
      ],
      rawNode: const <String, Object?>{'surfaceId': 'ai_bubble'},
      targetDomain: LiveEditTargetDomain.toolScene,
      bounds: const LiveEditBounds(
        left: 24,
        top: 100,
        right: 324,
        bottom: 340,
        width: 300,
        height: 240,
      ),
    );
    final record = LiveEditBubbleRecord(
      bubbleId: bubbleId,
      targetDomain: LiveEditTargetDomain.toolScene,
      targetKey: 'SelectionBubble',
      primarySelection: selection,
      selectedWidgets: <LiveEditSelection>[selection],
      instructionText: 'Prefilled prompt for tooling UI development.',
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      _bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = record;
    final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      _bubbleResource.value.layerViewStateByDomain,
    );
    layerMap[LiveEditTargetDomain.toolScene] =
        (layerMap[LiveEditTargetDomain.toolScene] ?? LiveEditLayerViewState())
            .copyWith(activeBubbleId: bubbleId, editMode: LiveEditEditMode.ai);
    _bubbleResource.value = _bubbleResource.value.copyWith(
      bubbleRecordsById: records,
      layerViewStateByDomain: layerMap,
    );
    // Keep appScene so overlay hit-test uses _nativeElementHitCandidates;
    // toolScene would use _toolElementHitCandidates and filter, which can
    // yield no hover/selection when the tool layer is the host child.
    _sessionService.setTargetDomain(
      sessionId: sessionId,
      targetDomain: LiveEditTargetDomain.appScene,
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
    notifyListeners();
  }

  void focusProperty(final LiveEditPropertyDescriptor property) {
    FocusPropertyCommand(
      property: property,
      defaultPrompt: _defaultAiPrompt(),
    ).execute(_context);
  }

  bool hasDraftForProperty(final LiveEditPropertyDescriptor property) =>
      activeDraftChanges.any((final draft) => draft.propertyId == property.id);

  void hideActiveBubble() {
    hideBubble(activeBubbleId);
  }

  void hideBubble(final String? bubbleId) =>
      HideBubbleCommand(bubbleId: bubbleId).execute(_context);

  List<LiveEditTimelineEntry> historyForBubble(final String? bubbleId) =>
      List<LiveEditTimelineEntry>.unmodifiable(
        _hasText(bubbleId)
            ? (_bubbleRecordFor(bubbleId)?.history ??
                  const <LiveEditTimelineEntry>[])
            : (_activeBubbleState?.history ?? const <LiveEditTimelineEntry>[]),
      );

  void hoverNode(
    final Offset globalOffset, {
    final GlobalKey? contentKey,
    final bool deeperMode = false,
  }) {
    final sessionId = ensureSession();
    final contentRoot = contentKey?.currentContext;
    _sessionService.hoverAtPoint(
      sessionId: sessionId,
      x: globalOffset.dx.round(),
      y: globalOffset.dy.round(),
      deeperMode: deeperMode || deeperPickEnabled,
      contentRoot: contentRoot is Element ? contentRoot : null,
      targetDomain: targetDomain,
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
  }

  LiveEditInferenceConfig? inferenceConfigForBubble(final String? bubbleId) {
    final bubble = _bubbleRecordFor(bubbleId);
    if (bubble?.inferenceConfig != null) {
      return bubble!.inferenceConfig;
    }
    final backend = backendForBubble(bubbleId);
    if (backend == null) {
      return null;
    }
    return _inferenceConfigByBackend[backend.id] ??
        _backendEffectiveConfig(backend);
  }

  String instructionTextForBubble(final String? bubbleId) {
    if (_hasText(bubbleId)) {
      return _bubbleRecordFor(bubbleId)?.instructionText ?? '';
    }
    return _activeBubbleState?.instructionText ??
        _bubbleResource.value.globalComposerText;
  }

  bool isPropertyWaiting(final LiveEditPropertyDescriptor property) {
    final data = _bubbleResource.value;
    return isWaitingForAgent &&
        activeBubbleId == data.pendingBubbleId &&
        property.id == data.pendingPropertyId;
  }

  String? lastErrorForBubble(final String? bubbleId) => _hasText(bubbleId)
      ? _bubbleRecordFor(bubbleId)?.lastError
      : (_activeBubbleState?.lastError ?? _bubbleResource.value.lastError);

  bool needsApprovalForBubble(final String? bubbleId) =>
      _hasText(bubbleId) &&
      bubbleId == _bubbleResource.value.pendingBubbleId &&
      needsApproval;

  void openAiBubble({final LiveEditPropertyDescriptor? property}) {
    OpenAiBubbleCommand(
      property: property,
      defaultPrompt: _defaultAiPrompt(),
    ).execute(_context);
  }

  Offset panelPlacement({required final Size viewport}) => clampPanelPlacement(
    placement:
        Offset(viewport.width - panelWidth - 16, 16) +
        _panelViewResource.value.panelDragOffset,
    viewport: viewport,
  );

  void resetBubbleDrag() {
    final bubble = _activeBubbleState;
    if (bubble == null || bubble.bubbleDragOffset == Offset.zero) return;
    DragBubbleCommand(delta: -bubble.bubbleDragOffset).execute(_context);
  }

  void resizeBubble({
    required final double width,
    required final double height,
  }) => ResizeBubbleCommand(width: width, height: height).execute(_context);

  void resizePanel({
    required final double width,
    required final double height,
  }) => ResizePanelCommand(width: width, height: height).execute(_context);

  void resolveActiveBubble() => ResolveActiveBubbleCommand().execute(_context);

  Future<void> retryApply() async {
    openAiBubble();
    await applyDraft(message: aiComposer);
  }

  void selectCandidateAt(final int index) {
    _sessionService.selectCandidate(
      sessionId: activeSessionId,
      index: index,
      targetDomain: _presentationLayer,
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
    _restoreBubbleState(_bubbleIdForSelection(activeSelection));
    _syncSelectionState();
  }

  void selectChildCandidate() {
    _sessionService.selectChild(
      sessionId: activeSessionId,
      targetDomain: _presentationLayer,
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
    _restoreBubbleState(_bubbleIdForSelection(activeSelection));
    _syncSelectionState();
  }

  LiveEditSelection? selectionByDomain(final LiveEditTargetDomain domain) =>
      _controller.selectionForDomain(
        targetDomain: domain,
        sessionId: activeSessionId,
      );

  void selectNode(
    final Offset globalOffset, {
    final GlobalKey? contentKey,
    final bool preferHoverPreview = false,
    final LiveEditSelectionPolicy selectionPolicy =
        LiveEditSelectionPolicy.nearestProjectAncestor,
  }) {
    _captureCurrentBubbleState();
    final sessionId = ensureSession();
    final contentRoot = contentKey?.currentContext;
    _sessionService.selectAtPoint(
      sessionId: sessionId,
      x: globalOffset.dx.round(),
      y: globalOffset.dy.round(),
      preferHoverPreview: preferHoverPreview || deeperPickEnabled,
      selectionPolicy: selectionPolicy,
      contentRoot: contentRoot is Element ? contentRoot : null,
      targetDomain: targetDomain,
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
    if (targetDomain == LiveEditTargetDomain.toolScene) {
      _toolPresentationArmed =
          selectionByDomain(LiveEditTargetDomain.toolScene) != null;
    }
    final selectedBubbleId = _bubbleIdForSelection(activeSelection);
    if (_hasText(selectedBubbleId)) {
      final next = Set<LiveEditBubbleId>.from(
        _bubbleResource.value.resolvedBubbleIds,
      )..remove(selectedBubbleId);
      _bubbleResource.value = _bubbleResource.value.copyWith(
        resolvedBubbleIds: next,
      );
    }
    _restoreBubbleState(selectedBubbleId);
    _syncSelectionState();
    if (targetDomain == LiveEditTargetDomain.toolScene &&
        activeSelection?.targetDomain == LiveEditTargetDomain.toolScene) {
      openAiBubble();
    }
  }

  void selectParentCandidate() {
    _sessionService.selectParent(
      sessionId: activeSessionId,
      targetDomain: _presentationLayer,
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
    _restoreBubbleState(_bubbleIdForSelection(activeSelection));
    _syncSelectionState();
  }

  void selectTrackedBubble(final String nodeId) {
    final records = _bubbleResource.value.bubbleRecordsById;
    final resolvedBubbleId = records.containsKey(nodeId)
        ? nodeId
        : records.keys.firstWhere(
            (final bubbleId) => bubbleId.endsWith('::$nodeId'),
            orElse: () => nodeId,
          );
    final nextResolved = Set<LiveEditBubbleId>.from(
      _bubbleResource.value.resolvedBubbleIds,
    )..remove(resolvedBubbleId);
    _bubbleResource.value = _bubbleResource.value.copyWith(
      resolvedBubbleIds: nextResolved,
    );
    _finalizeCurrentBubbleOnBlur(nextNodeId: resolvedBubbleId);
    final bubble = _bubbleRecordFor(resolvedBubbleId);
    final trackedNodeId = bubble?.primarySelection?.nodeId ?? nodeId;
    final bubbleDomain = bubble?.targetDomain ?? targetDomain;
    _toolPresentationArmed = bubbleDomain == LiveEditTargetDomain.toolScene;
    _sessionService.selectTrackedNode(
      sessionId: activeSessionId,
      nodeId: trackedNodeId,
      targetDomain: bubbleDomain,
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
    final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
      _bubbleResource.value.layerViewStateByDomain,
    );
    layerMap[bubbleDomain] =
        (layerMap[bubbleDomain] ?? LiveEditLayerViewState()).copyWith(
          activeBubbleId: resolvedBubbleId,
        );
    _bubbleResource.value = _bubbleResource.value.copyWith(
      layerViewStateByDomain: layerMap,
    );
    _restoreBubbleState(resolvedBubbleId);
    if (_bubbleRecordFor(resolvedBubbleId) == null) {
      final selection = selectionByDomain(bubbleDomain);
      final record = _ensureBubbleState(
        resolvedBubbleId,
        selection: selection,
        selectedWidgets: selection != null
            ? <LiveEditSelection>[selection]
            : const <LiveEditSelection>[],
      ).copyWith(displayState: LiveEditBubbleDisplayState.expanded);
      final newRecords = Map<String, LiveEditBubbleRecord>.from(
        _bubbleResource.value.bubbleRecordsById,
      );
      newRecords[resolvedBubbleId] = record;
      _bubbleResource.value = _bubbleResource.value.copyWith(
        bubbleRecordsById: newRecords,
      );
    }
    _syncSelectionState();
    notifyListeners();
  }

  void setAvailableBackends(final List<LiveEditAgentBackend> backends) {
    _availableBackends = List<LiveEditAgentBackend>.unmodifiable(backends);
    for (final backend in _availableBackends) {
      final config = _backendEffectiveConfig(backend);
      if (config != null) {
        _inferenceConfigByBackend.putIfAbsent(backend.id, () => config);
      }
    }
    _backendId = _resolveInitialBackendId(
      availableBackends: _availableBackends,
      backendId: _backendId,
    );
    notifyListeners();
  }

  void setBackend(final String backendId) {
    final bubbleId = _bubbleIdForSelection(activeSelection);
    if (_hasText(bubbleId)) {
      setBubbleBackend(bubbleId!, backendId);
      return;
    }
    final normalized = backendId.trim();
    if (normalized.isEmpty || normalized == _backendId) {
      return;
    }
    final backend = _availableBackends.firstWhere(
      (final candidate) => candidate.id == normalized,
      orElse: () => LiveEditAgentBackend(
        id: normalized,
        label: _fallbackBackendLabel(normalized),
        description: '',
        available: true,
      ),
    );
    if (!backend.available) {
      return;
    }
    _backendId = normalized;
    final config = _backendEffectiveConfig(backend);
    if (config != null) {
      _inferenceConfigByBackend.putIfAbsent(normalized, () => config);
    }
    _appendDebug(
      message: 'Selected backend changed.',
      details: <String>[
        'Backend: ${backend.label}',
        if (_hasText(currentModel)) 'Model: ${currentModel!}',
        if (_hasText(currentReasoningEffort))
          'Reasoning: ${currentReasoningEffort!}',
      ],
      nodeId: activeSelection?.nodeId,
    );
    notifyListeners();
  }

  void setBubbleBackend(final String bubbleId, final String backendId) {
    final normalized = backendId.trim();
    if (normalized.isEmpty) return;
    final backend = _availableBackends.firstWhere(
      (final candidate) => candidate.id == normalized,
      orElse: () => LiveEditAgentBackend(
        id: normalized,
        label: _fallbackBackendLabel(normalized),
        description: '',
        available: true,
      ),
    );
    if (!backend.available) return;
    if (_bubbleRecordFor(bubbleId) == null) {
      final record = _ensureBubbleState(
        bubbleId,
        selection: activeSelection,
        selectedWidgets: _bubbleRecordFor(bubbleId)?.selectedWidgets,
      );
      final records = Map<String, LiveEditBubbleRecord>.from(
        _bubbleResource.value.bubbleRecordsById,
      );
      records[bubbleId] = record;
      _bubbleResource.value = _bubbleResource.value.copyWith(
        bubbleRecordsById: records,
      );
    }
    SetBubbleBackendCommand(
      bubbleId: bubbleId,
      backendId: normalized,
      inferenceConfig:
          _inferenceConfigByBackend[normalized] ??
          _backendEffectiveConfig(backend),
    ).execute(_context);
    _appendDebug(
      message: 'Selected backend changed.',
      details: <String>[
        'Backend: ${backend.label}',
        if (_hasText(inferenceConfigForBubble(bubbleId)?.model))
          'Model: ${inferenceConfigForBubble(bubbleId)!.model!}',
        if (_hasText(inferenceConfigForBubble(bubbleId)?.reasoningEffort))
          'Reasoning: ${inferenceConfigForBubble(bubbleId)!.reasoningEffort!}',
      ],
      nodeId: bubbleId,
    );
  }

  void setBubbleInferenceConfig({
    required final String bubbleId,
    final String? model,
    final String? reasoningEffort,
  }) {
    final backend = backendForBubble(bubbleId);
    if (backend == null) {
      return;
    }
    final nextConfig = LiveEditCodexOptions.normalizeConfig(
      LiveEditInferenceConfig(
        model: _hasText(model) ? model!.trim() : null,
        reasoningEffort: backend.id == 'codex_exec' && _hasText(reasoningEffort)
            ? reasoningEffort!.trim()
            : null,
      ),
    );
    final bubble = _ensureBubbleState(
      bubbleId,
      selection:
          _bubbleRecordFor(bubbleId)?.primarySelection ?? activeSelection,
      selectedWidgets: _bubbleRecordFor(bubbleId)?.selectedWidgets,
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      _bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = bubble.copyWith(
      backendId: backend.id,
      inferenceConfig: nextConfig,
    );
    _bubbleResource.value = _bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
    _appendDebug(
      message: 'Inference config updated.',
      details: <String>[
        'Backend: ${backend.label}',
        'Model: ${nextConfig?.model ?? '(default)'}',
        if (backend.id == 'codex_exec')
          'Reasoning: ${nextConfig?.reasoningEffort ?? '(default)'}',
      ],
      nodeId: bubbleId,
    );
    notifyListeners();
  }

  void setDebugModeEnabled(final bool enabled) =>
      SetDebugModeCommand(enabled: enabled).execute(_context);

  void setDeeperPickEnabled(final bool enabled) =>
      SetDeeperPickCommand(enabled: enabled).execute(_context);

  void setInferenceConfig({
    final String? model,
    final String? reasoningEffort,
  }) {
    final bubbleId = _bubbleIdForSelection(activeSelection);
    if (_hasText(bubbleId)) {
      setBubbleInferenceConfig(
        bubbleId: bubbleId!,
        model: model,
        reasoningEffort: reasoningEffort,
      );
      return;
    }
    final backend = currentBackend;
    if (backend == null) {
      return;
    }
    final nextConfig = LiveEditCodexOptions.normalizeConfig(
      LiveEditInferenceConfig(
        model: _hasText(model) ? model!.trim() : null,
        reasoningEffort: backend.id == 'codex_exec' && _hasText(reasoningEffort)
            ? reasoningEffort!.trim()
            : null,
      ),
    );
    if (nextConfig == null) {
      _inferenceConfigByBackend.remove(backend.id);
    } else {
      _inferenceConfigByBackend[backend.id] = nextConfig;
    }
    _appendDebug(
      message: 'Inference config updated.',
      details: <String>[
        'Backend: ${backend.label}',
        'Model: ${nextConfig?.model ?? '(default)'}',
        if (backend.id == 'codex_exec')
          'Reasoning: ${nextConfig?.reasoningEffort ?? '(default)'}',
      ],
      nodeId: activeSelection?.nodeId,
    );
    notifyListeners();
  }

  void setOverlayEnabled(final bool enabled) {
    final sessionId = ensureSession();
    _sessionService.setOverlay(sessionId: sessionId, enabled: enabled);
    _context.applySessionUpdate(_sessionService.lastUpdate);
    if (!enabled) {
      _toolPresentationArmed = false;
      SetEditModeCommand(editMode: LiveEditEditMode.inspect).execute(_context);
      CollapsePanelCommand().execute(_context);
      _bubbleResource.value = _bubbleResource.value.copyWith(
        globalComposerText: '',
        applyPhase: LiveEditApplyPhase.idle,
      );
    }
    notifyListeners();
  }

  void setTargetDomain(final LiveEditTargetDomain domain) {
    final sessionId = ensureSession();
    _sessionService.setTargetDomain(sessionId: sessionId, targetDomain: domain);
    _context.applySessionUpdate(_sessionService.lastUpdate);
    if (domain == LiveEditTargetDomain.toolScene) {
      _toolPresentationArmed = false;
    }
    ExpandPanelCommand().execute(_context);
    notifyListeners();
  }

  Future<void> showApprovalSheet(final BuildContext context) async {
    openAiBubble();
    await applyDraft(message: aiComposer);
  }

  String? stagedDraftSummaryForBubble(final String? bubbleId) {
    if (!_hasText(bubbleId)) {
      return stagedDraftSummary;
    }
    final record = _bubbleRecordFor(bubbleId);
    final changes = record?.draftChanges ?? const <LiveEditDraftChange>[];
    if (changes.isEmpty) return null;
    final selection = record?.primarySelection;
    return changes
        .map((final d) => _describeDraftChangeFor(selection, d))
        .where(_hasText)
        .join(' | ');
  }

  String? stagedRequestSummaryForBubble(final String? bubbleId) {
    final sections = <String>[
      if (_hasText(stagedDraftSummaryForBubble(bubbleId)))
        'Edits: ${stagedDraftSummaryForBubble(bubbleId)!}',
      if (instructionTextForBubble(bubbleId).trim().isNotEmpty)
        'Prompt: ${instructionTextForBubble(bubbleId).trim()}',
    ];
    if (sections.isEmpty) return null;
    return sections.join('\n');
  }

  void startMarquee(final Offset globalOffset) {
    _captureCurrentBubbleState();
    _sessionService.startMarquee(
      sessionId: ensureSession(),
      x: globalOffset.dx.round(),
      y: globalOffset.dy.round(),
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
  }

  Future<void> submitAiPrompt() async {
    openAiBubble();
    if (!canSubmitAiPrompt) {
      return;
    }
    await applyDraft(message: aiComposer);
  }

  void togglePanelDisplayMode() =>
      TogglePanelDisplayModeCommand().execute(_context);

  void undoDraft() {
    ensureSession();
    UndoDraftCommand().execute(_context);
  }

  void updateAiComposer(final String value) =>
      UpdateAiComposerCommand(value: value).execute(_context);

  void updateBubbleComposer(final String bubbleId, final String value) {
    if (!_hasText(bubbleId)) return;
    UpdateBubbleComposerCommand(
      bubbleId: bubbleId,
      value: value,
    ).execute(_context);
  }

  void updateDraft({
    required final LiveEditPropertyDescriptor property,
    required final Object? targetValue,
    final LiveEditEditSurface? surface,
  }) {
    final sessionId = ensureSession();
    final selection = activeSelection;
    if (selection == null) {
      _setError('No live-edit selection is active.');
      return;
    }

    final previewMode = property.canPreviewExactly
        ? LiveEditPreviewMode.exact
        : (property.previewMode == LiveEditPreviewMode.none
              ? LiveEditPreviewMode.ghost
              : property.previewMode);

    final meta = <String, Object?>{
      'requiresAgentForPersistence': property.requiresAgentForPersistence,
      'editSurface': (surface ?? property.preferredEditSurface).wireName,
      'targetDomain': selection.targetDomain.wireName,
      'selectionNodeId': selection.nodeId,
      if (_hasText('${property.meta['surfaceId'] ?? ''}'))
        'surfaceId': '${property.meta['surfaceId']}',
    };
    if (hasMultiSelection) {
      _sessionService.updateDraftBatch(
        sessionId: sessionId,
        nodeIds: activeMultiSelection
            .map((final item) => item.nodeId)
            .toList(growable: false),
        propertyId: property.id,
        targetValue: targetValue,
        previewMode: previewMode,
        intentText: _resolveIntentText(null),
        meta: meta,
      );
    } else {
      _sessionService.updateDraft(
        sessionId: sessionId,
        change: LiveEditDraftChange(
          nodeId: selection.nodeId,
          propertyId: property.id,
          targetValue: targetValue,
          previewMode: previewMode,
          confidence: property.safeToAutoGroupInApply ? 0.95 : 0.75,
          intentText: _resolveIntentText(null),
          meta: meta,
        ),
      );
    }
    _context.applySessionUpdate(_sessionService.lastUpdate);

    SetActivePropertyCommand(activePropertyId: property.id).execute(_context);
    final editMode =
        property.requiresAgentForPersistence ||
            (surface ?? property.preferredEditSurface) ==
                LiveEditEditSurface.aiBubble
        ? LiveEditEditMode.ai
        : LiveEditEditMode.edit;
    SetEditModeCommand(editMode: editMode).execute(_context);
    _bubbleResource.value = _bubbleResource.value.copyWith(
      lastError: null,
      applyPhase: LiveEditApplyPhase.idle,
    );
    final bubbleId = _bubbleIdForSelection(selection);
    if (_hasText(bubbleId)) {
      final next = Set<LiveEditBubbleId>.from(
        _bubbleResource.value.resolvedBubbleIds,
      )..remove(bubbleId);
      _bubbleResource.value = _bubbleResource.value.copyWith(
        resolvedBubbleIds: next,
      );
    }
    _captureBubbleState(
      selection: selection,
      selectedWidgets: _activeSelectedWidgets(),
      instructionText: aiComposer,
      status: LiveEditBubbleStatus.editing,
    );
    if (editMode == LiveEditEditMode.ai && !_hasText(aiComposer)) {
      updateAiComposer(_defaultAiPrompt());
    }
    _appendDebug(
      message: 'Edited ${property.label}.',
      details: <String>[
        'Value: $targetValue',
        'Preview: ${previewMode.wireName}',
        if (_hasText(selection.source?.file))
          'Source: ${selection.source!.file}${selection.source?.line == null ? '' : ':${selection.source!.line}'}',
      ],
      nodeId: bubbleId,
    );
    notifyListeners();
  }

  void updateMarquee(final Offset globalOffset, {final GlobalKey? contentKey}) {
    final contentRoot = contentKey?.currentContext;
    _sessionService.updateMarquee(
      sessionId: activeSessionId,
      x: globalOffset.dx.round(),
      y: globalOffset.dy.round(),
      contentRoot: contentRoot is Element ? contentRoot : null,
    );
    _context.applySessionUpdate(_sessionService.lastUpdate);
  }

  Future<void> waitForProperty(
    final LiveEditPropertyDescriptor property,
  ) async {
    if (!hasDraftForProperty(property)) {
      updateDraft(
        property: property,
        targetValue: property.value,
        surface: property.preferredEditSurface,
      );
    }
    FocusPropertyCommand(
      property: property,
      surface: LiveEditEditSurface.aiBubble,
      defaultPrompt: _defaultAiPrompt(),
    ).execute(_context);
    if (!_hasText(aiComposer)) {
      updateAiComposer(_defaultAiPrompt());
    }
    notifyListeners();
  }

  List<LiveEditSelection> _activeSelectedWidgets() {
    if (hasMultiSelection) {
      return List<LiveEditSelection>.unmodifiable(activeMultiSelection);
    }
    final selection = activeSelection;
    return selection == null
        ? const <LiveEditSelection>[]
        : <LiveEditSelection>[selection];
  }

  void _appendActivity({
    required final LiveEditActivityStep step,
    required final String label,
    required final String summary,
    final List<String> details = const <String>[],
    final bool inProgress = false,
    final String? nodeId,
    final String? errorText,
  }) {
    final bubbleId =
        nodeId ?? activeBubbleId ?? _bubbleResource.value.pendingBubbleId;
    if (!_hasText(bubbleId) || summary.trim().isEmpty) return;
    final bubble = _ensureBubbleState(
      bubbleId!,
      selection:
          _bubbleRecordFor(bubbleId)?.primarySelection ?? activeSelection,
      selectedWidgets: _bubbleRecordFor(bubbleId)?.selectedWidgets,
    );
    final updated = bubble.copyWith(
      activity: <LiveEditActivityEntry>[
        ...bubble.activity,
        LiveEditActivityEntry(
          step: step,
          label: label.trim(),
          summary: summary.trim(),
          details: details
              .where((final item) => item.trim().isNotEmpty)
              .toList(),
          timestamp: DateTime.now().toUtc(),
          nodeId: bubbleId,
          inProgress: inProgress,
          errorText: errorText,
        ),
      ],
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      _bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = updated;
    _bubbleResource.value = _bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  void _appendDebug({
    required final String message,
    final List<String> details = const <String>[],
    final String? nodeId,
  }) {
    final bubbleId =
        nodeId ?? activeBubbleId ?? _bubbleResource.value.pendingBubbleId;
    if (!_hasText(bubbleId) || message.trim().isEmpty) return;
    final bubble = _ensureBubbleState(
      bubbleId!,
      selection:
          _bubbleRecordFor(bubbleId)?.primarySelection ?? activeSelection,
      selectedWidgets: _bubbleRecordFor(bubbleId)?.selectedWidgets,
    );
    final updated = bubble.copyWith(
      debugTimeline: <LiveEditTimelineEntry>[
        ...bubble.debugTimeline,
        LiveEditTimelineEntry(
          role: 'debug',
          message: message.trim(),
          details: details
              .where((final item) => item.trim().isNotEmpty)
              .toList(),
          timestamp: DateTime.now().toUtc(),
          nodeId: bubbleId,
        ),
      ],
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      _bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = updated;
    _bubbleResource.value = _bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  void _appendTimeline({
    required final String role,
    required final String message,
    final List<String> details = const <String>[],
    final String? nodeId,
  }) {
    final bubbleId =
        nodeId ?? activeBubbleId ?? _bubbleResource.value.pendingBubbleId;
    if (!_hasText(bubbleId) || message.trim().isEmpty) return;
    final bubble = _ensureBubbleState(
      bubbleId!,
      selection:
          _bubbleRecordFor(bubbleId)?.primarySelection ?? activeSelection,
      selectedWidgets: _bubbleRecordFor(bubbleId)?.selectedWidgets,
    );
    final updated = bubble.copyWith(
      history: <LiveEditTimelineEntry>[
        ...bubble.history,
        LiveEditTimelineEntry(
          role: role,
          message: message.trim(),
          details: details
              .where((final item) => item.trim().isNotEmpty)
              .toList(),
          timestamp: DateTime.now().toUtc(),
          nodeId: bubbleId,
        ),
      ],
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      _bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = updated;
    _bubbleResource.value = _bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  LiveEditInferenceConfig? _backendEffectiveConfig(
    final LiveEditAgentBackend backend,
  ) {
    final effective = backend.meta['effectiveInferenceConfig'];
    if (effective is Map) {
      return LiveEditCodexOptions.normalizeConfig(
        LiveEditInferenceConfig.fromJson(
          effective.map((final key, final value) => MapEntry('$key', value)),
        ),
      );
    }
    final defaults = backend.meta['defaultInferenceConfig'];
    if (defaults is Map) {
      return LiveEditCodexOptions.normalizeConfig(
        LiveEditInferenceConfig.fromJson(
          defaults.map((final key, final value) => MapEntry('$key', value)),
        ),
      );
    }
    return null;
  }

  String? _bubbleIdForSelection(final LiveEditSelection? selection) {
    if (selection == null) {
      return null;
    }
    final targetKey = _targetKeyForSelection(selection);
    return _hasText(targetKey)
        ? '${selection.targetDomain.wireName}::$targetKey'
        : null;
  }

  LiveEditBubbleRecord? _bubbleRecordFor(final String? bubbleId) {
    final resolved = _resolveBubbleId(bubbleId);
    if (!_hasText(resolved)) return null;
    return _bubbleResource.value.bubbleRecordsById[resolved!];
  }

  void _captureBubbleState({
    required final LiveEditSelection selection,
    required final List<LiveEditSelection> selectedWidgets,
    final String? instructionText,
    final LiveEditBubbleStatus? status,
    final String? lastError,
  }) {
    final bubbleId = _bubbleIdForSelection(selection);
    if (!_hasText(bubbleId)) return;
    final current = _bubbleRecordFor(bubbleId);
    final record =
        _ensureBubbleState(
          bubbleId!,
          selection: selection,
          selectedWidgets: selectedWidgets,
        ).copyWith(
          primarySelection: selection,
          selectedWidgets: selectedWidgets,
          draftChanges: _draftChangesForActiveSelection(),
          instructionText: instructionText ?? aiComposer,
          status: status ?? (current?.status ?? LiveEditBubbleStatus.editing),
          displayState:
              current?.displayState ?? LiveEditBubbleDisplayState.expanded,
          changedFiles: current?.changedFiles ?? const <String>[],
          backendId: backendIdForBubble(bubbleId),
          inferenceConfig: inferenceConfigForBubble(bubbleId),
          executionPlan: current?.executionPlan,
          lastError: lastError ?? current?.lastError,
        );
    final records = Map<String, LiveEditBubbleRecord>.from(
      _bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = record;
    _bubbleResource.value = _bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  void _captureCurrentBubbleState() {
    final bubbleId = activeBubbleId;
    if (!_hasText(bubbleId) || activeSelection == null) return;
    _captureBubbleState(
      selection: activeSelection!,
      selectedWidgets: _activeSelectedWidgets(),
      instructionText: aiComposer,
      status:
          _bubbleRecordFor(bubbleId)?.status ?? LiveEditBubbleStatus.editing,
      lastError: _bubbleResource.value.lastError,
    );
  }

  String _defaultAiPrompt() {
    final selection = activeSelection;
    final buffer = StringBuffer();
    if (hasMultiSelection) {
      buffer.write('Update ${activeMultiSelection.length} selected widgets');
    } else if (selection != null) {
      buffer.write('Update ${selection.widgetType}');
      if (_hasText(selection.source?.file)) {
        buffer.write(' in ${selection.source!.file}');
        if (selection.source?.line != null) {
          buffer.write(':${selection.source!.line}');
        }
      }
      final draftSummary = activeDraftChanges
          .map((final draft) => '${draft.propertyId}=${draft.targetValue}')
          .join(', ');
      if (draftSummary.isNotEmpty) {
        buffer.write(' for $draftSummary');
      }
    }
    if (_hasText(intentText)) {
      if (buffer.isNotEmpty) {
        buffer.write('. ');
      }
      buffer.write(intentText!.trim());
    }
    return buffer.isEmpty
        ? 'Persist the current live-edit changes.'
        : buffer.toString();
  }

  String _describeDraftChange(final LiveEditDraftChange draft) =>
      _describeDraftChangeFor(activeSelection, draft);

  String _describeDraftChangeFor(
    final LiveEditSelection? selection,
    final LiveEditDraftChange draft,
  ) {
    final property = selection?.propertyGroups.firstWhere(
      (final candidate) => candidate.id == draft.propertyId,
      orElse: () => LiveEditPropertyDescriptor(
        id: draft.propertyId,
        label: draft.propertyId,
        group: LiveEditPropertyGroup.diagnostics,
        kind: LiveEditPropertyKind.object,
      ),
    );
    return '${property?.label ?? draft.propertyId}: ${draft.targetValue}';
  }

  String _draftChangeListText() => activeDraftChanges
      .map((final draft) => '- ${_describeDraftChange(draft)}')
      .join('\n');

  List<LiveEditDraftChange> _draftChangesForActiveSelection() {
    final selection = activeSelection;
    if (selection == null) {
      return const <LiveEditDraftChange>[];
    }
    final nodeIds = <String>{
      selection.nodeId,
      ...selection.selectedNodeIds,
      ...activeMultiSelection.map((final item) => item.nodeId),
    };
    return draftsByDomain(_presentationLayer)
        .where((final draft) => nodeIds.contains(draft.nodeId))
        .toList(growable: false);
  }

  void _emitEventForBubble(
    final String? bubbleId,
    final LiveEditRuntimeEvent event,
  ) {
    final resolvedBubbleId =
        bubbleId ?? activeBubbleId ?? _bubbleResource.value.pendingBubbleId;
    final promptText = event.promptText?.trim();
    if (_hasText(resolvedBubbleId) && _hasText(promptText)) {
      final bubble = _ensureBubbleState(
        resolvedBubbleId!,
        selection:
            _bubbleRecordFor(resolvedBubbleId)?.primarySelection ??
            activeSelection,
        selectedWidgets: _bubbleRecordFor(resolvedBubbleId)?.selectedWidgets,
      );
      final records = Map<String, LiveEditBubbleRecord>.from(
        _bubbleResource.value.bubbleRecordsById,
      );
      records[resolvedBubbleId] = bubble.copyWith(debugPromptText: promptText);
      _bubbleResource.value = _bubbleResource.value.copyWith(
        bubbleRecordsById: records,
      );
    }
    if (event.debugOnly || event.kind == LiveEditRuntimeEventKind.debug) {
      _appendDebug(
        message: event.message,
        details: event.details,
        nodeId: resolvedBubbleId,
      );
      return;
    }
    if (event.kind == LiveEditRuntimeEventKind.edit) {
      _appendDebug(
        message: event.message,
        details: event.details,
        nodeId: resolvedBubbleId,
      );
      return;
    }
    final translated = _translateRuntimeEvent(event.message, resolvedBubbleId);
    _appendActivity(
      step: translated.$1,
      label: translated.$2,
      summary: translated.$3,
      details: event.details,
      inProgress: translated.$4,
      nodeId: resolvedBubbleId,
    );
    _appendDebug(
      message: event.message,
      details: event.details,
      nodeId: resolvedBubbleId,
    );
  }

  LiveEditBubbleRecord _ensureBubbleState(
    final String bubbleId, {
    final LiveEditSelection? selection,
    final List<LiveEditSelection>? selectedWidgets,
  }) {
    final existing = _bubbleRecordFor(bubbleId);
    if (existing != null) {
      return existing;
    }
    final bubbleDomain = selection?.targetDomain ?? targetDomain;
    final targetKey = _targetKeyForSelection(selection) ?? bubbleId;
    return LiveEditBubbleRecord(
      bubbleId: bubbleId,
      targetDomain: bubbleDomain,
      targetKey: targetKey,
      primarySelection: selection,
      selectedWidgets: selectedWidgets ?? const <LiveEditSelection>[],
    );
  }

  String _failureSummary(final String error, {final String? bubbleId}) {
    final normalized = error.toLowerCase();
    if (normalized.contains('working directory') ||
        normalized.contains('source file') ||
        normalized.contains('transport') ||
        normalized.contains('source context')) {
      return 'Configuration or source context failed.';
    }
    if (normalized.contains('apply') ||
        normalized.contains('write') ||
        normalized.contains('executionid') ||
        normalized.contains('proposalid')) {
      return 'Applying source changes failed.';
    }
    return '${backendLabelForBubble(bubbleId)} request failed.';
  }

  void _finalizeCurrentBubbleOnBlur({final String? nextNodeId}) {
    final bubbleId = activeBubbleId;
    if (!_hasText(bubbleId) ||
        bubbleId == nextNodeId ||
        activeSelection == null) {
      return;
    }
    _captureBubbleState(
      selection: activeSelection!,
      selectedWidgets: _activeSelectedWidgets(),
      instructionText: aiComposer,
      status:
          _bubbleRecordFor(bubbleId)?.status ?? LiveEditBubbleStatus.editing,
      lastError: _bubbleResource.value.lastError,
    );
    if (_shouldKeepBubblePinned(bubbleId)) {
      final bubble = _bubbleRecordFor(bubbleId);
      if (bubble != null && bubbleId != null) {
        final records = Map<String, LiveEditBubbleRecord>.from(
          _bubbleResource.value.bubbleRecordsById,
        );
        records[bubbleId] = bubble.copyWith(
          displayState: LiveEditBubbleDisplayState.minimized,
        );
        _bubbleResource.value = _bubbleResource.value.copyWith(
          bubbleRecordsById: records,
        );
      }
      return;
    }
    if (bubbleId != null) {
      final records = Map<String, LiveEditBubbleRecord>.from(
        _bubbleResource.value.bubbleRecordsById,
      );
      records.remove(bubbleId);
      _bubbleResource.value = _bubbleResource.value.copyWith(
        bubbleRecordsById: records,
      );
    }
  }

  LiveEditLayerViewState _layerViewStateFor(
    final LiveEditTargetDomain domain,
  ) =>
      _bubbleResource.value.layerViewStateByDomain[domain] ??
      LiveEditLayerViewState();

  Iterable<LiveEditBubbleRecord> _pendingBubbleStates() {
    final data = _bubbleResource.value;
    return data.bubbleRecordsById.values.where(
      (final bubble) =>
          !data.resolvedBubbleIds.contains(bubble.bubbleId) &&
          bubble.hasPendingApply,
    );
  }

  LiveEditBubbleId? _resolveBubbleId(final String? bubbleIdOrNodeId) {
    final normalized = bubbleIdOrNodeId?.trim();
    if (!_hasText(normalized)) return null;
    final records = _bubbleResource.value.bubbleRecordsById;
    if (records.containsKey(normalized)) return normalized;
    for (final bubbleId in records.keys) {
      if (bubbleId.endsWith('::$normalized')) {
        return bubbleId;
      }
    }
    return normalized;
  }

  String _resolveIntentText(final String? message) {
    final prompt = (message?.trim().isNotEmpty == true)
        ? message!.trim()
        : (stagedPromptText ?? '');
    final draftSummary = _draftChangeListText();
    if (prompt.isNotEmpty && draftSummary.isNotEmpty) {
      return '$prompt\n\nStaged fixes:\n$draftSummary';
    }
    if (prompt.isNotEmpty) {
      return prompt;
    }
    if (draftSummary.isNotEmpty) {
      return 'Staged fixes:\n$draftSummary';
    }
    return _defaultAiPrompt();
  }

  void _restoreBubbleState(final String? bubbleId) {
    if (!_hasText(bubbleId)) return;
    final bubble = _bubbleRecordFor(bubbleId);
    if (bubble == null) return;
    final records = Map<String, LiveEditBubbleRecord>.from(
      _bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId!] = bubble.copyWith(
      displayState: LiveEditBubbleDisplayState.expanded,
    );
    _bubbleResource.value = _bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  void _setError(final String error) {
    _setErrorForBubble(
      activeBubbleId ?? _bubbleResource.value.pendingBubbleId,
      error,
    );
  }

  void _setErrorForBubble(final String? bubbleId, final String error) {
    var data = _bubbleResource.value.copyWith(
      applyPhase: LiveEditApplyPhase.failed,
      lastError: error,
    );
    if (_hasText(bubbleId)) {
      final activeBubble = data.bubbleRecordsById[bubbleId];
      if (activeBubble != null) {
        final records = Map<String, LiveEditBubbleRecord>.from(
          data.bubbleRecordsById,
        );
        records[bubbleId!] = activeBubble.copyWith(
          status: LiveEditBubbleStatus.failed,
          displayState: LiveEditBubbleDisplayState.expanded,
          lastError: error,
        );
        data = data.copyWith(bubbleRecordsById: records);
      }
    }
    _bubbleResource.value = data;
    final nodeId = bubbleId ?? activeBubbleId ?? data.pendingBubbleId;
    _appendActivity(
      step: LiveEditActivityStep.failed,
      label: 'Failed',
      summary: _failureSummary(error, bubbleId: bubbleId),
      details: <String>[error],
      nodeId: nodeId,
      errorText: error,
    );
    _appendDebug(
      message: 'Live-edit request failed.',
      details: <String>[error],
      nodeId: nodeId,
    );
    _appendTimeline(role: 'assistant', message: error, nodeId: nodeId);
    notifyListeners();
  }

  bool _shouldKeepBubblePinned(final String? nodeId) {
    if (!_hasText(nodeId)) {
      return false;
    }
    final bubble = _bubbleRecordFor(nodeId);
    final hasMeaningfulDraft =
        bubble?.draftChanges.any(
          (final draft) => '${draft.targetValue}'.trim().isNotEmpty,
        ) ??
        false;
    final hasInstruction = _hasText(bubble?.instructionText);
    final primaryNodeId = bubble?.primarySelection?.nodeId;
    final hasMeaningfulNode =
        _hasText(primaryNodeId) &&
        _sessionService.isMeaningfulNode(
          primaryNodeId!,
          sessionId: activeSessionId,
        );
    final status = bubble?.status;
    final hasPersistentStatus =
        status == LiveEditBubbleStatus.waiting ||
        status == LiveEditBubbleStatus.needsApproval ||
        status == LiveEditBubbleStatus.applied ||
        status == LiveEditBubbleStatus.failed;
    return hasMeaningfulDraft ||
        hasInstruction ||
        hasMeaningfulNode ||
        hasPersistentStatus;
  }

  void _syncSelectionState() {
    final selection = activeSelection;
    final currentBubbleId = _bubbleIdForSelection(selection);
    if (currentBubbleId != _lastSelectionIdentity) {
      _lastSelectionIdentity = currentBubbleId;
      final domain = _presentationLayer;
      final bubble = _hasText(currentBubbleId)
          ? _ensureBubbleState(
              currentBubbleId!,
              selection: selection,
              selectedWidgets: _activeSelectedWidgets(),
            )
          : null;
      final phase = bubble?.status == LiveEditBubbleStatus.waiting
          ? LiveEditApplyPhase.preparing
          : bubble?.status == LiveEditBubbleStatus.applied
          ? LiveEditApplyPhase.success
          : bubble?.status == LiveEditBubbleStatus.failed
          ? LiveEditApplyPhase.failed
          : LiveEditApplyPhase.idle;
      var editMode = selection == null
          ? LiveEditEditMode.inspect
          : (_bubbleResource.value.layerViewStateByDomain[domain]?.editMode ==
                    LiveEditEditMode.ai
                ? LiveEditEditMode.ai
                : LiveEditEditMode.edit);
      var activePropertyId =
          _bubbleResource
              .value
              .layerViewStateByDomain[domain]
              ?.activePropertyId ??
          activeProperty?.id;
      if (selection != null &&
          activeProperty?.requiresAgentForPersistence == true) {
        editMode = LiveEditEditMode.ai;
        activePropertyId = activeProperty?.id ?? activePropertyId;
      }
      final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
        _bubbleResource.value.layerViewStateByDomain,
      );
      layerMap[domain] = (layerMap[domain] ?? LiveEditLayerViewState())
          .copyWith(
            activeBubbleId: currentBubbleId,
            editMode: editMode,
            activePropertyId: activePropertyId,
          );
      _bubbleResource.value = _bubbleResource.value.copyWith(
        layerViewStateByDomain: layerMap,
        applyPhase: phase,
        pendingExecutionPlan: bubble?.executionPlan,
        pendingProposalId: bubble?.executionPlan?.proposalId,
        lastError: bubble?.lastError,
        globalComposerText: bubble?.instructionText ?? '',
      );
      _panelViewResource.value = _panelViewResource.value.copyWith(
        editMode: editMode,
      );
      if (_hasText(currentBubbleId) && selection != null) {
        _captureBubbleState(
          selection: selection,
          selectedWidgets: _activeSelectedWidgets(),
          instructionText: bubble?.instructionText ?? '',
          status: bubble?.status,
          lastError: bubble?.lastError,
        );
      }
      if (selection != null &&
          activeProperty?.requiresAgentForPersistence == true &&
          !_hasText(bubble?.instructionText)) {
        updateAiComposer(_defaultAiPrompt());
      }
      return;
    }

    final active = activeProperty;
    if (active == null && selection != null) {
      final properties = effectiveProperties;
      final propId = properties.isEmpty ? null : properties.first.id;
      final domain = _presentationLayer;
      final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
        _bubbleResource.value.layerViewStateByDomain,
      );
      layerMap[domain] = (layerMap[domain] ?? LiveEditLayerViewState())
          .copyWith(activePropertyId: propId);
      _bubbleResource.value = _bubbleResource.value.copyWith(
        layerViewStateByDomain: layerMap,
      );
    }
  }

  String? _targetKeyForSelection(final LiveEditSelection? selection) {
    if (selection == null) {
      return null;
    }
    if (selection.selectionMode == LiveEditSelectionMode.multi &&
        selection.selectedNodeIds.length > 1) {
      final ordered =
          selection.selectedNodeIds.where(_hasText).toList(growable: false)
            ..sort();
      if (ordered.isNotEmpty) {
        return 'area:${ordered.join('|')}';
      }
    }
    final nodeId = selection.nodeId.trim();
    return _hasText(nodeId) ? nodeId : null;
  }

  (LiveEditActivityStep, String, String, bool) _translateRuntimeEvent(
    final String message,
    final String? bubbleId,
  ) {
    final backendLabel = backendLabelForBubble(bubbleId);
    final normalized = message.toLowerCase();
    if (normalized.contains('preparing') && normalized.contains('workspace')) {
      return (
        LiveEditActivityStep.readingSourceContext,
        'Reading source context',
        'Preparing the workspace and source context.',
        true,
      );
    }
    if (normalized.contains('source context')) {
      return (
        LiveEditActivityStep.readingSourceContext,
        'Reading source context',
        'Reading source context for the selected node.',
        true,
      );
    }
    if (normalized.contains('sending') ||
        normalized.contains('resolve') ||
        normalized.contains('generating proposal') ||
        normalized.contains('direct apply') ||
        normalized.contains('stream started') ||
        normalized.contains('streamed output') ||
        normalized.contains('reported progress') ||
        normalized.contains('running codex exec') ||
        normalized.contains('starting codex exec') ||
        normalized.contains('running cursor-agent') ||
        normalized.contains('starting cursor-agent')) {
      return (
        LiveEditActivityStep.generatingProposal,
        'Applying with agent',
        '$backendLabel is implementing this bubble change.',
        true,
      );
    }
    if (normalized.contains('stream completed')) {
      return (
        LiveEditActivityStep.generatingProposal,
        'Applying with agent',
        '$backendLabel finished streaming the agent response.',
        true,
      );
    }
    if ((normalized.contains('proposal') ||
            normalized.contains('execution result') ||
            normalized.contains('applied this bubble')) &&
        (normalized.contains('returned') ||
            normalized.contains('produced') ||
            normalized.contains('received'))) {
      return (
        LiveEditActivityStep.applyingChanges,
        'Applying',
        '$backendLabel is writing the requested source changes.',
        true,
      );
    }
    if (normalized.contains('applying')) {
      return (
        LiveEditActivityStep.applyingChanges,
        'Applying',
        'Applying source changes for this node.',
        true,
      );
    }
    if (normalized.contains('finished') ||
        normalized.contains('applied the patch') ||
        normalized.contains('finished writing') ||
        normalized.contains('source changes applied')) {
      return (
        LiveEditActivityStep.finished,
        'Applied',
        '$backendLabel finished writing the source changes.',
        false,
      );
    }
    return (
      LiveEditActivityStep.preparingRequest,
      'Preparing request',
      message.trim(),
      true,
    );
  }

  static String? _resolveInitialBackendId({
    required final List<LiveEditAgentBackend> availableBackends,
    required final String? backendId,
  }) {
    final requested = backendId?.trim();
    if (requested != null && requested.isNotEmpty) {
      if (availableBackends.isEmpty ||
          availableBackends.any((final backend) => backend.id == requested)) {
        return requested;
      }
    }
    if (availableBackends.isEmpty) {
      return requested;
    }
    return availableBackends
        .firstWhere(
          (final backend) => backend.isDefault,
          orElse: () => availableBackends.first,
        )
        .id;
  }
}
