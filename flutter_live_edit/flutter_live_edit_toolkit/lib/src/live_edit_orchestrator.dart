import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:path/path.dart' as p;

import 'commands/commands.dart';
import 'live_edit_context.dart';
import 'live_edit_controller_adapter.dart';
import 'live_edit_overlay_theme.dart';
import 'live_edit_types.dart';
import 'resources/resources.dart';
import 'services/services.dart';

const Object _unsetValue = Object();
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

  LiveEditApplyPhase _applyPhase = LiveEditApplyPhase.idle;
  LiveEditExecutionPlan? _pendingExecutionPlan;
  String? _pendingProposalId;
  String? _lastError;
  String? _activePropertyId;
  String _aiComposer = '';
  bool _disposed = false;
  String? _lastSelectionIdentity;
  LiveEditEditMode _editMode = LiveEditEditMode.inspect;
  LiveEditPanelDisplayMode _panelDisplayMode = LiveEditPanelDisplayMode.rail;
  final Map<LiveEditBubbleId, LiveEditBubbleRecord> _bubbleRecordsById =
      <LiveEditBubbleId, LiveEditBubbleRecord>{};
  final Map<LiveEditTargetDomain, LiveEditLayerViewState>
  _layerViewStateByDomain = <LiveEditTargetDomain, LiveEditLayerViewState>{
    LiveEditTargetDomain.appScene: LiveEditLayerViewState(),
    LiveEditTargetDomain.toolScene: LiveEditLayerViewState(),
  };
  String? _pendingBubbleId;
  String? _pendingPropertyId;
  double _bubbleWidth = 300;
  double _bubbleHeight = 340;
  double _panelExpandedWidth = 312;
  double _panelExpandedHeight = 520;
  double _panelRailWidth = 64;
  double _panelRailHeight = 420;
  Offset _panelDragOffset = Offset.zero;
  bool _debugModeEnabled = false;
  bool _deeperPickEnabled = false;
  bool _toolPresentationArmed = false;
  final Set<LiveEditBubbleId> _resolvedBubbleIds = <LiveEditBubbleId>{};

  LiveEditBubbleId? get activeBubbleId =>
      _layerViewStateFor(_presentationLayer).activeBubbleId ??
      _bubbleIdForSelection(activeSelection);
  bool get activeBubbleResolved =>
      _hasText(activeBubbleId) && _resolvedBubbleIds.contains(activeBubbleId);
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
    if (properties.isEmpty) {
      return null;
    }
    final activeId = _activePropertyId;
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
      _layerViewStateFor(_presentationLayer).activePropertyId ??
      _activePropertyId;
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
      (_editMode == LiveEditEditMode.ai ||
          needsApproval ||
          _applyPhase == LiveEditApplyPhase.success);
  String get aiComposer => _activeBubbleState?.instructionText ?? _aiComposer;
  LiveEditApplyPhase get applyPhase => _applyPhase;
  List<LiveEditAgentBackend> get availableBackends => _availableBackends;
  Offset get bubbleDragOffset =>
      _activeBubbleState?.bubbleDragOffset ?? Offset.zero;
  double get bubbleHeight => _bubbleHeight;
  LiveEditBubbleStatus get bubbleStatusForActiveSelection {
    final bubble = _activeBubbleState;
    return bubble?.status ?? LiveEditBubbleStatus.editing;
  }

  List<LiveEditBubbleSummary> get bubbleSummaries {
    final domains = <LiveEditTargetDomain>[targetDomain, inactiveLayer];
    return domains.expand(bubbleSummariesByDomain).toList(growable: false);
  }

  double get bubbleWidth => _bubbleWidth;
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
    if (_applyPhase == LiveEditApplyPhase.failed && _hasText(_lastError)) {
      return LiveEditActivityEntry(
        step: LiveEditActivityStep.failed,
        label: 'Failed',
        summary: _failureSummary(_lastError!, bubbleId: bubbleId),
        details: <String>[_lastError!],
        timestamp: now,
        nodeId: bubbleId,
        errorText: _lastError,
      );
    }
    if (_applyPhase == LiveEditApplyPhase.success) {
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
            _pendingExecutionPlan?.summary ??
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

  bool get debugModeEnabled => _debugModeEnabled;
  String? get debugPromptForActiveSelection {
    final prompt = _activeBubbleState?.debugPromptText?.trim();
    return _hasText(prompt) ? prompt : null;
  }

  List<LiveEditTimelineEntry> get debugTimelineForActiveSelection =>
      List<LiveEditTimelineEntry>.unmodifiable(
        _activeBubbleState?.debugTimeline ?? const <LiveEditTimelineEntry>[],
      );
  bool get deeperPickEnabled => _deeperPickEnabled;

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

  bool get isApplyingBusy =>
      _applyPhase == LiveEditApplyPhase.preparing ||
      _applyPhase == LiveEditApplyPhase.applying;

  bool get isWaitingForAgent =>
      bubbleStatusForActiveSelection == LiveEditBubbleStatus.waiting;
  String? get lastError => _activeBubbleState?.lastError ?? _lastError;
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
      _applyPhase == LiveEditApplyPhase.awaitingApproval &&
      _pendingExecutionPlan != null &&
      _hasText(_pendingProposalId);

  bool get overlayVisible => _sessionResource.value.overlayVisible;

  LiveEditPanelDisplayMode get panelDisplayMode => _panelDisplayMode;
  Offset get panelDragOffset => _panelDragOffset;
  bool get panelExpanded =>
      _panelDisplayMode == LiveEditPanelDisplayMode.expanded;
  double get panelHeight =>
      panelExpanded ? _panelExpandedHeight : _panelRailHeight;
  double get panelWidth =>
      panelExpanded ? _panelExpandedWidth : _panelRailWidth;
  int get pendingBubbleCount => _pendingBubbleStates().length;

  LiveEditExecutionPlan? get pendingExecutionPlan =>
      _activeBubbleState?.executionPlan ?? _pendingExecutionPlan;

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

  LiveEditLayerViewState get _presentedLayerViewState =>
      _layerViewStateByDomain[_presentationLayer]!;

  Future<void> applyAllBubbles() async {
    final bubbleIds = _pendingBubbleStates().map(
      (final bubble) => bubble.bubbleId,
    );
    for (final bubbleId in bubbleIds) {
      await _applyBubble(bubbleId, applyMode: LiveEditApplyMode.applyAll);
    }
  }

  Future<void> applyDraft({
    final bool approve = false,
    final String? message,
  }) async {
    final bubbleId = activeBubbleId;
    if (!_hasText(bubbleId)) {
      _setError('No draft changes to apply.');
      return;
    }
    await _applyBubble(bubbleId!, approve: approve, message: message);
  }

  Future<void> applyDraftForBubble(
    final String bubbleId, {
    final bool approve = false,
    final String? message,
  }) async {
    if (!_hasText(bubbleId)) return;
    await _applyBubble(bubbleId, approve: approve, message: message);
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

    if (rightSpace >= _bubbleWidth) {
      left = bounds.right + gap;
    } else if (leftSpace >= _bubbleWidth) {
      left = bounds.left - _bubbleWidth - gap;
    } else {
      left = _minDouble(
        viewport.width - _bubbleWidth - 16,
        _maxDouble(16, bounds.left),
      );
      top = _minDouble(
        viewport.height - _bubbleHeight - 16,
        bounds.bottom + gap,
      );
    }

    top = _minDouble(top, viewport.height - _bubbleHeight - 16);
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
  }) {
    _activePropertyId = property.id;
    _presentedLayerViewState.activePropertyId = property.id;
    final resolvedSurface = surface ?? property.preferredEditSurface;
    _editMode =
        resolvedSurface == LiveEditEditSurface.aiBubble ||
            property.requiresAgentForPersistence
        ? LiveEditEditMode.ai
        : LiveEditEditMode.edit;
    _presentedLayerViewState.editMode = _editMode;
    if (_editMode == LiveEditEditMode.ai && !_hasText(aiComposer)) {
      updateAiComposer(_defaultAiPrompt());
    }
    notifyListeners();
  }

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
    final summaries = _bubbleRecordsById.values
        .where(
          (final bubble) =>
              bubble.targetDomain == domain &&
              bubble.displayState == LiveEditBubbleDisplayState.minimized &&
              !_resolvedBubbleIds.contains(bubble.bubbleId),
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
    final maxLeft = _maxDouble(16, viewport.width - _bubbleWidth - 16);
    final maxTop = _maxDouble(16, viewport.height - _bubbleHeight - 16);
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

  void collapsePanel() {
    _panelDisplayMode = LiveEditPanelDisplayMode.rail;
    notifyListeners();
  }

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

  void dragBubble(final Offset delta) {
    final bubble = _activeBubbleState;
    if (delta == Offset.zero || bubble == null) {
      return;
    }
    dragBubbleFor(bubble.bubbleId, delta);
  }

  void dragBubbleFor(final String bubbleId, final Offset delta) {
    if (delta == Offset.zero || !_hasText(bubbleId)) {
      return;
    }
    final bubble = _bubbleRecordFor(bubbleId);
    if (bubble == null) {
      return;
    }
    _bubbleRecordsById[bubbleId] = bubble.copyWith(
      bubbleDragOffset: bubble.bubbleDragOffset + delta,
    );
    notifyListeners();
  }

  void dragPanel(final Offset delta) {
    if (delta == Offset.zero) {
      return;
    }
    _panelDragOffset += delta;
    notifyListeners();
  }

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

  LiveEditExecutionPlan? executionPlanForBubble(final String? bubbleId) =>
      _hasText(bubbleId) && bubbleId == _pendingBubbleId
      ? _pendingExecutionPlan
      : _bubbleRecordFor(bubbleId)?.executionPlan;

  List<LiveEditBubbleSummary> expandedBubbleSummariesByDomain(
    final LiveEditTargetDomain domain,
  ) {
    final summaries = _bubbleRecordsById.values
        .where(
          (final bubble) =>
              bubble.targetDomain == domain &&
              bubble.displayState == LiveEditBubbleDisplayState.expanded &&
              !_resolvedBubbleIds.contains(bubble.bubbleId),
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

  void expandPanel() {
    _panelDisplayMode = LiveEditPanelDisplayMode.expanded;
    notifyListeners();
  }

  void focusProperty(final LiveEditPropertyDescriptor property) {
    beginInlineEdit(property);
    _panelDisplayMode = LiveEditPanelDisplayMode.expanded;
  }

  bool hasDraftForProperty(final LiveEditPropertyDescriptor property) =>
      activeDraftChanges.any((final draft) => draft.propertyId == property.id);

  void hideActiveBubble() {
    hideBubble(activeBubbleId);
  }

  void hideBubble(final String? bubbleId) {
    if (!_hasText(bubbleId)) {
      return;
    }
    final bubble = _bubbleRecordFor(bubbleId);
    if (bubble != null) {
      _bubbleRecordsById[bubbleId!] = bubble.copyWith(
        displayState: LiveEditBubbleDisplayState.minimized,
      );
    }
    notifyListeners();
  }

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
      deeperMode: deeperMode || _deeperPickEnabled,
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
    return _activeBubbleState?.instructionText ?? _aiComposer;
  }

  bool isPropertyWaiting(final LiveEditPropertyDescriptor property) =>
      isWaitingForAgent &&
      activeBubbleId == _pendingBubbleId &&
      property.id == _pendingPropertyId;

  String? lastErrorForBubble(final String? bubbleId) => _hasText(bubbleId)
      ? _bubbleRecordFor(bubbleId)?.lastError
      : (_activeBubbleState?.lastError ?? _lastError);

  bool needsApprovalForBubble(final String? bubbleId) =>
      _hasText(bubbleId) && bubbleId == _pendingBubbleId && needsApproval;

  void openAiBubble({final LiveEditPropertyDescriptor? property}) {
    if (property != null) {
      _activePropertyId = property.id;
      _presentedLayerViewState.activePropertyId = property.id;
    }
    _editMode = LiveEditEditMode.ai;
    _presentedLayerViewState.editMode = _editMode;
    _panelDisplayMode = LiveEditPanelDisplayMode.expanded;
    if (!needsApproval &&
        _applyPhase != LiveEditApplyPhase.preparing &&
        _applyPhase != LiveEditApplyPhase.applying) {
      _applyPhase = LiveEditApplyPhase.idle;
      _pendingExecutionPlan = null;
      _pendingProposalId = null;
      _lastError = null;
      final bubble = _activeBubbleState;
      if (bubble != null) {
        _bubbleRecordsById[bubble.bubbleId] = bubble.copyWith(
          status: LiveEditBubbleStatus.editing,
          lastError: null,
        );
      }
    }
    if (!_hasText(aiComposer)) {
      updateAiComposer(_defaultAiPrompt());
    }
    notifyListeners();
  }

  Offset panelPlacement({required final Size viewport}) => clampPanelPlacement(
    placement: Offset(viewport.width - panelWidth - 16, 16) + _panelDragOffset,
    viewport: viewport,
  );

  void resetBubbleDrag() {
    final bubble = _activeBubbleState;
    if (bubble == null || bubble.bubbleDragOffset == Offset.zero) {
      return;
    }
    _bubbleRecordsById[bubble.bubbleId] = bubble.copyWith(
      bubbleDragOffset: Offset.zero,
    );
    notifyListeners();
  }

  void resizeBubble({
    required final double width,
    required final double height,
  }) {
    _bubbleWidth = width.clamp(260, 520);
    _bubbleHeight = height.clamp(300, 520);
    final surfaceId = _editMode == LiveEditEditMode.ai
        ? kLiveEditAiBubbleSurfaceId
        : kLiveEditSelectionBubbleSurfaceId;
    LiveEditOverlayThemeModel.instance.applyDraft(
      LiveEditDraftChange(
        nodeId: surfaceId,
        propertyId: 'width',
        targetValue: _bubbleWidth,
        previewMode: LiveEditPreviewMode.exact,
        meta: <String, Object?>{
          'surfaceId': surfaceId,
          'targetDomain': LiveEditTargetDomain.toolScene.wireName,
        },
      ),
    );
    LiveEditOverlayThemeModel.instance.applyDraft(
      LiveEditDraftChange(
        nodeId: surfaceId,
        propertyId: 'height',
        targetValue: _bubbleHeight,
        previewMode: LiveEditPreviewMode.exact,
        meta: <String, Object?>{
          'surfaceId': surfaceId,
          'targetDomain': LiveEditTargetDomain.toolScene.wireName,
        },
      ),
    );
    notifyListeners();
  }

  void resizePanel({
    required final double width,
    required final double height,
  }) {
    if (panelExpanded) {
      _panelExpandedWidth = width.clamp(240, 640);
      _panelExpandedHeight = height.clamp(320, 760);
    } else {
      _panelRailWidth = width.clamp(56, 160);
      _panelRailHeight = height.clamp(220, 760);
    }
    notifyListeners();
  }

  void resolveActiveBubble() {
    final bubbleId = activeBubbleId;
    if (!_hasText(bubbleId)) {
      return;
    }
    _resolvedBubbleIds.add(bubbleId!);
    _bubbleRecordsById.remove(bubbleId);
    _presentedLayerViewState.activeBubbleId = null;
    _pendingExecutionPlan = null;
    _pendingProposalId = null;
    _pendingBubbleId = null;
    _pendingPropertyId = null;
    _lastError = null;
    _applyPhase = LiveEditApplyPhase.idle;
    _aiComposer = '';
    _panelDisplayMode = LiveEditPanelDisplayMode.rail;
    _editMode = LiveEditEditMode.inspect;
    _presentedLayerViewState.editMode = _editMode;
    notifyListeners();
  }

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
      preferHoverPreview: preferHoverPreview || _deeperPickEnabled,
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
      _resolvedBubbleIds.remove(selectedBubbleId);
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
    final resolvedBubbleId = _bubbleRecordsById.containsKey(nodeId)
        ? nodeId
        : _bubbleRecordsById.keys.firstWhere(
            (final bubbleId) => bubbleId.endsWith('::$nodeId'),
            orElse: () => nodeId,
          );
    _resolvedBubbleIds.remove(resolvedBubbleId);
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
    _layerViewStateFor(bubbleDomain).activeBubbleId = resolvedBubbleId;
    _restoreBubbleState(resolvedBubbleId);
    if (_bubbleRecordFor(resolvedBubbleId) == null) {
      final selection = selectionByDomain(bubbleDomain);
      _bubbleRecordsById[resolvedBubbleId] = _ensureBubbleState(
        resolvedBubbleId,
        selection: selection,
        selectedWidgets: selection != null
            ? <LiveEditSelection>[selection]
            : const <LiveEditSelection>[],
      ).copyWith(displayState: LiveEditBubbleDisplayState.expanded);
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
    if (normalized.isEmpty) {
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
    final bubble = _ensureBubbleState(
      bubbleId,
      selection:
          _bubbleRecordFor(bubbleId)?.primarySelection ?? activeSelection,
      selectedWidgets: _bubbleRecordFor(bubbleId)?.selectedWidgets,
    );
    _bubbleRecordsById[bubbleId] = bubble.copyWith(
      backendId: normalized,
      inferenceConfig:
          _inferenceConfigByBackend[normalized] ??
          _backendEffectiveConfig(backend),
    );
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
    notifyListeners();
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
    _bubbleRecordsById[bubbleId] = bubble.copyWith(
      backendId: backend.id,
      inferenceConfig: nextConfig,
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

  void setDebugModeEnabled(final bool enabled) {
    if (_debugModeEnabled == enabled) {
      return;
    }
    _debugModeEnabled = enabled;
    _appendDebug(
      message: enabled
          ? 'Live edit debug mode enabled.'
          : 'Live edit debug mode disabled.',
      nodeId: activeSelection?.nodeId,
    );
    notifyListeners();
  }

  void setDeeperPickEnabled(final bool enabled) {
    if (_deeperPickEnabled == enabled) {
      return;
    }
    _deeperPickEnabled = enabled;
    notifyListeners();
  }

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
      _editMode = LiveEditEditMode.inspect;
      _presentedLayerViewState.editMode = _editMode;
      _panelDisplayMode = LiveEditPanelDisplayMode.rail;
      _aiComposer = '';
      _resetApplyState(clearError: false);
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
    _panelDisplayMode = LiveEditPanelDisplayMode.expanded;
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

  void togglePanelDisplayMode() {
    _panelDisplayMode = panelExpanded
        ? LiveEditPanelDisplayMode.rail
        : LiveEditPanelDisplayMode.expanded;
    notifyListeners();
  }

  void undoDraft() {
    final sessionId = ensureSession();
    final bubbleId = activeBubbleId;
    final bubble = _activeBubbleState;
    final nodeIds =
        bubble?.nodeIds ??
        _activeSelectedWidgets()
            .map((final item) => item.nodeId)
            .toList(growable: false);
    _sessionService.discardDraftNodes(sessionId: sessionId, nodeIds: nodeIds);
    _context.applySessionUpdate(_sessionService.lastUpdate);
    if (_hasText(bubbleId)) {
      final preservedInstruction =
          _bubbleRecordFor(bubbleId)?.instructionText ?? '';
      _bubbleRecordsById[bubbleId!] =
          _ensureBubbleState(
            bubbleId,
            selection: activeSelection,
            selectedWidgets: _activeSelectedWidgets(),
          ).copyWith(
            draftChanges: const <LiveEditDraftChange>[],
            instructionText: preservedInstruction,
            status: LiveEditBubbleStatus.editing,
            displayState: LiveEditBubbleDisplayState.expanded,
            changedFiles: const <String>[],
            lastError: null,
          );
    }
    _resetApplyState(clearError: true);
  }

  void updateAiComposer(final String value) {
    final bubbleId = activeBubbleId;
    if (_hasText(bubbleId)) {
      updateBubbleComposer(bubbleId!, value);
      return;
    }
    _aiComposer = value;
    notifyListeners();
  }

  void updateBubbleComposer(final String bubbleId, final String value) {
    if (!_hasText(bubbleId)) return;
    if (bubbleId == activeBubbleId) {
      _aiComposer = value;
    }
    if (value.trim().isNotEmpty) {
      _resolvedBubbleIds.remove(bubbleId);
    }
    final bubble = _ensureBubbleState(
      bubbleId,
      selection:
          _bubbleRecordFor(bubbleId)?.primarySelection ?? activeSelection,
      selectedWidgets:
          _bubbleRecordFor(bubbleId)?.selectedWidgets ??
          _activeSelectedWidgets(),
    );
    _bubbleRecordsById[bubbleId] = bubble.copyWith(
      instructionText: value,
      status: LiveEditBubbleStatus.editing,
      displayState: LiveEditBubbleDisplayState.expanded,
      backendId: backendIdForBubble(bubbleId),
      inferenceConfig: inferenceConfigForBubble(bubbleId),
      lastError: null,
    );
    if (!needsApproval &&
        _applyPhase != LiveEditApplyPhase.preparing &&
        _applyPhase != LiveEditApplyPhase.applying) {
      _applyPhase = LiveEditApplyPhase.idle;
      _pendingExecutionPlan = null;
      _pendingProposalId = null;
      _lastError = null;
      final activeBubble = _activeBubbleState;
      if (activeBubble != null) {
        _bubbleRecordsById[activeBubble.bubbleId] = activeBubble.copyWith(
          status: LiveEditBubbleStatus.editing,
          lastError: null,
        );
      }
    }
    notifyListeners();
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

    _activePropertyId = property.id;
    _presentedLayerViewState.activePropertyId = property.id;
    _lastError = null;
    _applyPhase = LiveEditApplyPhase.idle;
    _pendingExecutionPlan = null;
    _pendingProposalId = null;
    _pendingBubbleId = null;
    _pendingPropertyId = null;
    _editMode =
        property.requiresAgentForPersistence ||
            (surface ?? property.preferredEditSurface) ==
                LiveEditEditSurface.aiBubble
        ? LiveEditEditMode.ai
        : LiveEditEditMode.edit;
    _presentedLayerViewState.editMode = _editMode;
    final bubbleId = _bubbleIdForSelection(selection);
    if (_hasText(bubbleId)) {
      _resolvedBubbleIds.remove(bubbleId);
    }
    _captureBubbleState(
      selection: selection,
      selectedWidgets: _activeSelectedWidgets(),
      instructionText: aiComposer,
      status: LiveEditBubbleStatus.editing,
    );
    if (_editMode == LiveEditEditMode.ai && !_hasText(aiComposer)) {
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
    _activePropertyId = property.id;
    _editMode = LiveEditEditMode.ai;
    _presentedLayerViewState.activePropertyId = property.id;
    _presentedLayerViewState.editMode = _editMode;
    _panelDisplayMode = LiveEditPanelDisplayMode.expanded;
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
    final bubbleId = nodeId ?? activeBubbleId ?? _pendingBubbleId;
    if (!_hasText(bubbleId) || summary.trim().isEmpty) {
      return;
    }
    final bubble = _ensureBubbleState(
      bubbleId!,
      selection:
          _bubbleRecordFor(bubbleId)?.primarySelection ?? activeSelection,
      selectedWidgets: _bubbleRecordFor(bubbleId)?.selectedWidgets,
    );
    _bubbleRecordsById[bubbleId] = bubble.copyWith(
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
  }

  void _appendDebug({
    required final String message,
    final List<String> details = const <String>[],
    final String? nodeId,
  }) {
    final bubbleId = nodeId ?? activeBubbleId ?? _pendingBubbleId;
    if (!_hasText(bubbleId) || message.trim().isEmpty) {
      return;
    }
    final bubble = _ensureBubbleState(
      bubbleId!,
      selection:
          _bubbleRecordFor(bubbleId)?.primarySelection ?? activeSelection,
      selectedWidgets: _bubbleRecordFor(bubbleId)?.selectedWidgets,
    );
    _bubbleRecordsById[bubbleId] = bubble.copyWith(
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
  }

  void _appendTimeline({
    required final String role,
    required final String message,
    final List<String> details = const <String>[],
    final String? nodeId,
  }) {
    final bubbleId = nodeId ?? activeBubbleId ?? _pendingBubbleId;
    if (!_hasText(bubbleId) || message.trim().isEmpty) {
      return;
    }
    final bubble = _ensureBubbleState(
      bubbleId!,
      selection:
          _bubbleRecordFor(bubbleId)?.primarySelection ?? activeSelection,
      selectedWidgets: _bubbleRecordFor(bubbleId)?.selectedWidgets,
    );
    _bubbleRecordsById[bubbleId] = bubble.copyWith(
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
  }

  Future<void> _applyBubble(
    final String bubbleId, {
    final bool approve = false,
    final String? message,
    final LiveEditApplyMode applyMode = LiveEditApplyMode.singleBubble,
  }) async {
    final sessionId = ensureSession();
    if (applyDraftDelegate == null) {
      _setError('Apply transport is not configured for this host app.');
      return;
    }
    final bubble = _bubbleRecordFor(bubbleId);
    final selection = bubble?.primarySelection;
    final selectedWidgets =
        bubble?.selectedWidgets ?? const <LiveEditSelection>[];
    final draftChanges = bubble?.draftChanges ?? const <LiveEditDraftChange>[];
    final backendId = backendIdForBubble(bubbleId);
    final backendLabel = backendLabelForBubble(bubbleId);
    final inferenceConfig = inferenceConfigForBubble(bubbleId);
    final resolvedIntent = _resolveBubbleInstruction(
      bubbleId: bubbleId,
      message: message,
      draftChanges: draftChanges,
    );
    if (draftChanges.isEmpty && !_hasText(resolvedIntent)) {
      if (bubbleId == activeBubbleId) {
        _setError('No draft changes to apply.');
      }
      return;
    }

    _applyPhase = LiveEditApplyPhase.preparing;
    _lastError = null;
    _pendingBubbleId = bubbleId;
    _pendingPropertyId = _activePropertyId;
    _resolvedBubbleIds.remove(bubbleId);
    _bubbleRecordsById[bubbleId] =
        _ensureBubbleState(
          bubbleId,
          selection: selection,
          selectedWidgets: selectedWidgets,
        ).copyWith(
          draftChanges: draftChanges,
          instructionText: resolvedIntent,
          status: LiveEditBubbleStatus.waiting,
          backendId: backendId,
          inferenceConfig: inferenceConfig,
          lastError: null,
        );
    _appendActivity(
      step: LiveEditActivityStep.preparingRequest,
      label: 'Preparing request',
      summary: 'Preparing the live-edit request for $backendLabel.',
      inProgress: true,
      details: <String>[
        if (_hasText(selection?.source?.file))
          'Source: ${selection!.source!.file}${selection.source?.line == null ? '' : ':${selection.source!.line}'}',
        if (_hasText(backendId)) 'Backend: $backendLabel',
        if (_hasText(inferenceConfig?.model))
          'Model: ${inferenceConfig!.model}',
        if (_hasText(inferenceConfig?.reasoningEffort))
          'Reasoning: ${inferenceConfig!.reasoningEffort}',
        if (draftChanges.isNotEmpty) 'Drafts: ${draftChanges.length}',
        if (draftChanges.isEmpty && _hasText(resolvedIntent))
          'Prompt-only request',
      ],
      nodeId: bubbleId,
    );
    _appendDebug(
      message: 'Dispatching live-edit request to $backendLabel.',
      details: <String>[
        if (_hasText(selection?.source?.file))
          'Source: ${selection!.source!.file}${selection.source?.line == null ? '' : ':${selection.source!.line}'}',
        if (_hasText(backendId)) 'Backend: $backendLabel',
        if (_hasText(inferenceConfig?.model))
          'Model: ${inferenceConfig!.model}',
        if (_hasText(inferenceConfig?.reasoningEffort))
          'Reasoning: ${inferenceConfig!.reasoningEffort}',
        if (_hasText(workingDirectory)) 'Workspace: $workingDirectory',
        if (draftChanges.isNotEmpty) 'Drafts: ${draftChanges.length}',
        if (draftChanges.isEmpty) 'Mode: prompt-only',
      ],
      nodeId: bubbleId,
    );
    _panelDisplayMode = LiveEditPanelDisplayMode.rail;
    _editMode = LiveEditEditMode.ai;
    _appendTimeline(role: 'user', message: resolvedIntent, nodeId: bubbleId);
    notifyListeners();

    try {
      final response = await applyDraftDelegate!(
        LiveEditApplyDraftRequest(
          sessionId: sessionId,
          bubbleId: bubbleId,
          instructionText: resolvedIntent,
          primarySelection: selection,
          selectedWidgets: List<LiveEditSelection>.unmodifiable(
            selectedWidgets,
          ),
          sourceTargets: _sourceTargetsForSelections(selectedWidgets),
          stagedPropertyChanges: List<LiveEditDraftChange>.unmodifiable(
            draftChanges,
          ),
          applyMode: applyMode,
          draftChanges: List<LiveEditDraftChange>.unmodifiable(draftChanges),
          selection: selection,
          proposalId: _pendingProposalId,
          backendId: backendId,
          inferenceConfig: inferenceConfig,
          workingDirectory: workingDirectory,
          intentText: resolvedIntent,
          approve: approve,
          onEvent: (final event) => _emitEventForBubble(bubbleId, event),
        ),
      );

      final responseError = _extractError(response);
      if (_hasText(responseError)) {
        _setErrorForBubble(bubbleId, responseError!);
        return;
      }

      final executionPlan = _decodeExecutionPlan(response['executionPlan']);
      final executionResult = _decodeExecutionResult(
        response['executionResult'] ?? response['result'],
      );
      if (executionPlan != null) {
        _pendingExecutionPlan = executionPlan;
        _bubbleRecordsById[bubbleId] =
            _ensureBubbleState(
              bubbleId,
              selection: selection,
              selectedWidgets: selectedWidgets,
            ).copyWith(
              draftChanges: draftChanges,
              instructionText: resolvedIntent,
              status: LiveEditBubbleStatus.waiting,
              backendId: backendId,
              inferenceConfig: inferenceConfig,
              executionPlan: executionPlan,
              changedFiles: executionPlan.affectedFiles,
            );
        _appendActivity(
          step: LiveEditActivityStep.applyingChanges,
          label: 'Applying',
          summary: executionPlan.summary,
          details: executionPlan.affectedFiles.take(4).toList(growable: false),
          inProgress: true,
          nodeId: bubbleId,
        );
        _appendTimeline(
          role: 'assistant',
          message: executionPlan.summary,
          details: <String>[
            ...executionPlan.requestedChanges,
            ...executionPlan.riskNotes,
          ],
          nodeId: bubbleId,
        );
      }

      final changedFiles =
          executionResult?.changedFiles ??
          executionPlan?.affectedFiles ??
          const <String>[];
      final runtimeRefresh = executionResult?.runtimeRefresh;
      final appliedDetails = <String>[
        ...changedFiles,
        if (runtimeRefresh?.didRefresh == true)
          'Runtime: ${runtimeRefresh!.action.wireName}',
      ];
      _applyPhase = LiveEditApplyPhase.success;
      _lastError = null;
      _bubbleRecordsById[bubbleId] =
          _ensureBubbleState(
            bubbleId,
            selection: selection,
            selectedWidgets: selectedWidgets,
          ).copyWith(
            draftChanges: const <LiveEditDraftChange>[],
            instructionText: resolvedIntent,
            status: LiveEditBubbleStatus.applied,
            displayState: LiveEditBubbleDisplayState.minimized,
            changedFiles: changedFiles,
            backendId: backendId,
            inferenceConfig: inferenceConfig,
            executionPlan: executionPlan,
            lastError: null,
          );
      _pendingBubbleId = null;
      _pendingPropertyId = null;
      _appendTimeline(
        role: 'assistant',
        message: 'Applied live-edit changes.',
        details: appliedDetails,
        nodeId: bubbleId,
      );
      _appendActivity(
        step: LiveEditActivityStep.finished,
        label: 'Applied',
        summary:
            executionResult?.summary ??
            '$backendLabel applied this bubble change to source.',
        details: appliedDetails,
        nodeId: bubbleId,
      );
      _pendingProposalId = null;
      final committedBubble = _bubbleRecordFor(bubbleId);
      _sessionService.commitDraftNodes(
        sessionId: sessionId,
        nodeIds:
            committedBubble?.nodeIds ??
            selectedWidgets
                .map((final item) => item.nodeId)
                .toList(growable: false),
      );
      _sessionService.showAppliedPreview(
        sessionId: sessionId,
        changes: draftChanges,
      );
      notifyListeners();
    } on Exception catch (error) {
      _setErrorForBubble(bubbleId, 'Apply failed: $error');
    }
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

  LiveEditBubbleRecord? _bubbleRecordFor(final String? bubbleId) =>
      _hasText(_resolveBubbleId(bubbleId))
      ? _bubbleRecordsById[_resolveBubbleId(bubbleId)!]
      : null;

  void _captureBubbleState({
    required final LiveEditSelection selection,
    required final List<LiveEditSelection> selectedWidgets,
    final String? instructionText,
    final LiveEditBubbleStatus? status,
    final String? lastError,
  }) {
    final bubbleId = _bubbleIdForSelection(selection);
    if (!_hasText(bubbleId)) {
      return;
    }
    final current = _bubbleRecordFor(bubbleId);
    _bubbleRecordsById[bubbleId!] =
        _ensureBubbleState(
          bubbleId,
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
  }

  void _captureCurrentBubbleState() {
    final bubbleId = activeBubbleId;
    if (!_hasText(bubbleId) || activeSelection == null) {
      return;
    }
    _captureBubbleState(
      selection: activeSelection!,
      selectedWidgets: _activeSelectedWidgets(),
      instructionText: aiComposer,
      status:
          _bubbleRecordFor(bubbleId)?.status ?? LiveEditBubbleStatus.editing,
      lastError: _lastError,
    );
  }

  String? _debugPromptByKey({
    final LiveEditSelection? selection,
    final String? nodeId,
  }) {
    final resolvedBubbleId =
        nodeId ?? _bubbleIdForSelection(selection) ?? activeBubbleId;
    return _bubbleRecordFor(resolvedBubbleId)?.debugPromptText;
  }

  String? _debugPromptKey({
    final LiveEditSelection? selection,
    final String? nodeId,
  }) {
    final resolvedSelection =
        selection ??
        _bubbleRecordFor(nodeId)?.primarySelection ??
        activeSelection;
    final source = resolvedSelection?.source;
    if (_hasText(source?.file)) {
      return [
        resolvedSelection?.widgetType ?? '',
        source!.file,
        '${source.line ?? ''}',
        '${source.column ?? ''}',
      ].join('|');
    }
    if (_hasText(resolvedSelection?.nodeId)) {
      return resolvedSelection!.nodeId;
    }
    final resolvedNodeId = nodeId?.trim();
    return _hasText(resolvedNodeId) ? resolvedNodeId : null;
  }

  LiveEditExecutionPlan? _decodeExecutionPlan(final Object? value) {
    if (value is Map) {
      final normalized = value.map(
        (final key, final nested) => MapEntry('$key', nested),
      );
      return LiveEditExecutionPlan.fromJson(normalized);
    }

    final selection = activeSelection;
    if (selection == null) {
      return null;
    }
    return LiveEditExecutionPlan(
      proposalId: _pendingProposalId ?? '',
      title: 'Apply this bubble change',
      summary: 'Persist current bubble changes.',
      selectedNode: selection.widgetType,
      requestedChanges: activeDraftChanges
          .map((final draft) => '${draft.propertyId}: ${draft.targetValue}')
          .toList(growable: false),
      affectedFiles: const <String>[],
      confidence: activeDraftChanges.isEmpty ? 0 : 0.7,
      agentInstruction: 'Apply current bubble changes.',
    );
  }

  LiveEditDirectApplyResult? _decodeExecutionResult(final Object? value) {
    if (value is Map) {
      final normalized = value.map(
        (final key, final nested) => MapEntry('$key', nested),
      );
      return LiveEditDirectApplyResult.fromJson(normalized);
    }
    return null;
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
    final resolvedBubbleId = bubbleId ?? activeBubbleId ?? _pendingBubbleId;
    final promptText = event.promptText?.trim();
    if (_hasText(resolvedBubbleId) && _hasText(promptText)) {
      final bubble = _ensureBubbleState(
        resolvedBubbleId!,
        selection:
            _bubbleRecordFor(resolvedBubbleId)?.primarySelection ??
            activeSelection,
        selectedWidgets: _bubbleRecordFor(resolvedBubbleId)?.selectedWidgets,
      );
      _bubbleRecordsById[resolvedBubbleId] = bubble.copyWith(
        debugPromptText: promptText,
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

  String? _extractError(final Map<String, Object?> response) {
    if (response['ok'] == false) {
      return _formatErrorMessage(
        '${response['message'] ?? 'Unknown apply failure'}',
        details: response['details'],
      );
    }
    final nestedError = response['error'];
    if (nestedError is Map) {
      final message = '${nestedError['message'] ?? ''}'.trim();
      if (message.isNotEmpty) {
        return _formatErrorMessage(message, details: nestedError['details']);
      }
    }
    return null;
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
      lastError: _lastError,
    );
    if (_shouldKeepBubblePinned(bubbleId)) {
      final bubble = _bubbleRecordFor(bubbleId);
      if (bubble != null && bubbleId != null) {
        _bubbleRecordsById[bubbleId] = bubble.copyWith(
          displayState: LiveEditBubbleDisplayState.minimized,
        );
      }
      return;
    }
    if (bubbleId != null) {
      _bubbleRecordsById.remove(bubbleId);
    }
  }

  String _formatErrorMessage(final String message, {final Object? details}) {
    final normalizedMessage = message.trim();
    final extra = _salientErrorDetail(details);
    if (!_hasText(extra) || extra == normalizedMessage) {
      return normalizedMessage;
    }
    return '$normalizedMessage\n$extra';
  }

  LiveEditLayerViewState _layerViewStateFor(
    final LiveEditTargetDomain domain,
  ) => _layerViewStateByDomain[domain]!;

  void _onControllerChanged() {
    if (_disposed) {
      return;
    }
    _syncSelectionState();
    notifyListeners();
  }

  Iterable<LiveEditBubbleRecord> _pendingBubbleStates() =>
      _bubbleRecordsById.values.where(
        (final bubble) =>
            !_resolvedBubbleIds.contains(bubble.bubbleId) &&
            bubble.hasPendingApply,
      );

  void _resetApplyState({required final bool clearError}) {
    _applyPhase = LiveEditApplyPhase.idle;
    _pendingExecutionPlan = null;
    _pendingProposalId = null;
    if (clearError) {
      _lastError = null;
    }
  }

  LiveEditBubbleId? _resolveBubbleId(final String? bubbleIdOrNodeId) {
    final normalized = bubbleIdOrNodeId?.trim();
    if (!_hasText(normalized)) {
      return null;
    }
    if (_bubbleRecordsById.containsKey(normalized)) {
      return normalized;
    }
    for (final bubbleId in _bubbleRecordsById.keys) {
      if (bubbleId.endsWith('::$normalized')) {
        return bubbleId;
      }
    }
    return normalized;
  }

  String _resolveBubbleInstruction({
    required final String bubbleId,
    required final List<LiveEditDraftChange> draftChanges,
    final String? message,
  }) {
    final prompt = (message?.trim().isNotEmpty == true)
        ? message!.trim()
        : (_bubbleRecordFor(bubbleId)?.instructionText ??
              stagedPromptText ??
              '');
    final draftSummary = draftChanges
        .map((final draft) => '- ${_describeDraftChange(draft)}')
        .join('\n');
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

  void _restoreBubbleState(final String? nodeId) {
    if (!_hasText(nodeId)) {
      return;
    }
    final bubble = _bubbleRecordFor(nodeId);
    if (bubble != null) {
      _bubbleRecordsById[nodeId!] = bubble.copyWith(
        displayState: LiveEditBubbleDisplayState.expanded,
      );
    }
  }

  String? _salientErrorDetail(final Object? details) {
    if (details is Map) {
      final normalized = details.map(
        (final key, final value) => MapEntry('$key', value),
      );
      for (final key in const <String>['stderr', 'rawDetails', 'message']) {
        final value = '${normalized[key] ?? ''}'.trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
      final requestSummary = normalized['requestSummary'];
      if (requestSummary is Map) {
        final mode = '${requestSummary['requestMode'] ?? ''}'.trim();
        final drafts = '${requestSummary['draftChangeCount'] ?? ''}'.trim();
        final intent = '${requestSummary['intentTextPresent'] ?? ''}'.trim();
        final summary = <String>[
          if (mode.isNotEmpty) 'Mode: $mode',
          if (drafts.isNotEmpty) 'Drafts: $drafts',
          if (intent.isNotEmpty) 'Intent present: $intent',
        ].join(' • ');
        if (summary.isNotEmpty) {
          return summary;
        }
      }
    }
    final value = '$details'.trim();
    if (value.isEmpty || value == 'null') {
      return null;
    }
    return value;
  }

  void _setError(final String error) {
    _setErrorForBubble(activeBubbleId ?? _pendingBubbleId, error);
  }

  void _setErrorForBubble(final String? bubbleId, final String error) {
    _applyPhase = LiveEditApplyPhase.failed;
    _lastError = error;
    if (_hasText(bubbleId)) {
      final activeBubble = _bubbleRecordFor(bubbleId);
      if (activeBubble != null) {
        _bubbleRecordsById[bubbleId!] = activeBubble.copyWith(
          status: LiveEditBubbleStatus.failed,
          displayState: LiveEditBubbleDisplayState.expanded,
          lastError: error,
        );
      }
    }
    _appendActivity(
      step: LiveEditActivityStep.failed,
      label: 'Failed',
      summary: _failureSummary(error, bubbleId: bubbleId),
      details: <String>[error],
      nodeId: bubbleId ?? activeBubbleId ?? _pendingBubbleId,
      errorText: error,
    );
    _appendDebug(
      message: 'Live-edit request failed.',
      details: <String>[error],
      nodeId: bubbleId ?? activeBubbleId ?? _pendingBubbleId,
    );
    _pendingBubbleId = null;
    _pendingPropertyId = null;
    _appendTimeline(
      role: 'assistant',
      message: error,
      nodeId: bubbleId ?? activeBubbleId ?? _pendingBubbleId,
    );
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

  List<LiveEditSourceTarget> _sourceTargetsForSelections(
    final List<LiveEditSelection> selections,
  ) {
    final workspace = workingDirectory;
    final deduped = <String, LiveEditSourceTarget>{};
    for (final selection in selections) {
      final source = selection.source;
      if (!_hasText(source?.file)) {
        continue;
      }
      final absolutePath = source!.file;
      final workspacePath =
          _hasText(workspace) && p.isWithin(workspace!, absolutePath)
          ? p.relative(absolutePath, from: workspace)
          : null;
      deduped[workspacePath ?? absolutePath] = LiveEditSourceTarget(
        nodeId: selection.nodeId,
        widgetType: selection.widgetType,
        absolutePath: absolutePath,
        workspacePath: workspacePath,
        line: source.line,
        column: source.column,
      );
    }
    return deduped.values.toList(growable: false);
  }

  void _syncSelectionState() {
    final selection = activeSelection;
    final currentBubbleId = _bubbleIdForSelection(selection);
    if (currentBubbleId != _lastSelectionIdentity) {
      _lastSelectionIdentity = currentBubbleId;
      final bubble = _hasText(currentBubbleId)
          ? _ensureBubbleState(
              currentBubbleId!,
              selection: selection,
              selectedWidgets: _activeSelectedWidgets(),
            )
          : null;
      _presentedLayerViewState.activeBubbleId = currentBubbleId;
      _pendingExecutionPlan = bubble?.executionPlan;
      _pendingProposalId = bubble?.executionPlan?.proposalId;
      _applyPhase = bubble?.status == LiveEditBubbleStatus.waiting
          ? LiveEditApplyPhase.preparing
          : bubble?.status == LiveEditBubbleStatus.applied
          ? LiveEditApplyPhase.success
          : bubble?.status == LiveEditBubbleStatus.failed
          ? LiveEditApplyPhase.failed
          : LiveEditApplyPhase.idle;
      _lastError = bubble?.lastError;
      _aiComposer = bubble?.instructionText ?? '';
      _editMode = selection == null
          ? LiveEditEditMode.inspect
          : (_presentedLayerViewState.editMode == LiveEditEditMode.ai
                ? LiveEditEditMode.ai
                : LiveEditEditMode.edit);
      _activePropertyId =
          _presentedLayerViewState.activePropertyId ?? activeProperty?.id;
      if (_hasText(currentBubbleId) && selection != null) {
        _captureBubbleState(
          selection: selection,
          selectedWidgets: _activeSelectedWidgets(),
          instructionText: _aiComposer,
          status: bubble?.status,
          lastError: bubble?.lastError,
        );
      }
      if (selection != null &&
          activeProperty?.requiresAgentForPersistence == true) {
        _editMode = LiveEditEditMode.ai;
        _presentedLayerViewState.editMode = _editMode;
        if (!_hasText(_aiComposer)) {
          _aiComposer = _defaultAiPrompt();
          updateAiComposer(_aiComposer);
        }
      }
      return;
    }

    final active = activeProperty;
    if (active == null && selection != null) {
      final properties = effectiveProperties;
      _activePropertyId = properties.isEmpty ? null : properties.first.id;
      _presentedLayerViewState.activePropertyId = _activePropertyId;
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
