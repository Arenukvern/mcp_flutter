import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import 'live_edit_controller.dart';

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

String? _firstEditablePropertyId(final LiveEditSelection? selection) {
  if (selection == null) {
    return null;
  }
  for (final property in selection.propertyGroups) {
    if (property.editable) {
      return property.id;
    }
  }
  return null;
}

typedef LiveEditApplyDraftDelegate =
    Future<Map<String, Object?>> Function(LiveEditApplyDraftRequest request);

final class LiveEditApplyDraftRequest {
  const LiveEditApplyDraftRequest({
    required this.sessionId,
    this.proposalId,
    this.backendId,
    this.workingDirectory,
    this.intentText,
    this.approve = false,
  });

  final String sessionId;
  final String? proposalId;
  final String? backendId;
  final String? workingDirectory;
  final String? intentText;
  final bool approve;

  Map<String, Object?> toJson() => <String, Object?>{
    'sessionId': sessionId,
    if (_hasText(proposalId)) 'proposalId': proposalId,
    if (_hasText(backendId)) 'backendId': backendId,
    if (_hasText(workingDirectory)) 'workingDirectory': workingDirectory,
    if (_hasText(intentText)) 'intentText': intentText,
    'approve': approve,
  };
}

enum LiveEditApplyPhase {
  idle,
  preparing,
  awaitingApproval,
  applying,
  success,
  failed,
}

final class LiveEditTimelineEntry {
  const LiveEditTimelineEntry({
    required this.role,
    required this.message,
    required this.timestamp,
    this.nodeId,
    this.details = const <String>[],
  });

  final String role;
  final String message;
  final DateTime timestamp;
  final String? nodeId;
  final List<String> details;
}

final class LiveEditOrchestrator extends ChangeNotifier {
  LiveEditOrchestrator({
    final LiveEditController? controller,
    this.applyDraftDelegate,
    this.backendId,
    this.workingDirectory,
    this.intentText,
  }) : controller = controller ?? LiveEditController.instance {
    this.controller.addListener(_onControllerChanged);
  }

  final LiveEditController controller;
  final LiveEditApplyDraftDelegate? applyDraftDelegate;
  final String? backendId;
  final String? workingDirectory;
  final String? intentText;

  LiveEditApplyPhase _applyPhase = LiveEditApplyPhase.idle;
  LiveEditExecutionPlan? _pendingExecutionPlan;
  String? _pendingProposalId;
  String? _lastError;
  String? _activePropertyId;
  String _aiComposer = '';
  bool _disposed = false;
  String? _lastSelectionNodeId;
  LiveEditEditMode _editMode = LiveEditEditMode.inspect;
  final Map<String, List<LiveEditTimelineEntry>> _historyByNode =
      <String, List<LiveEditTimelineEntry>>{};

  List<LiveEditDraftChange> get activeDraftChanges =>
      controller.activeDraftChanges;
  LiveEditSelection? get activeSelection => controller.activeSelection;
  List<LiveEditSelectionCandidate> get activeSelectionCandidates =>
      controller.activeSelectionCandidates;
  String? get activeSessionId => controller.activeSessionId;
  LiveEditApplyPhase get applyPhase => _applyPhase;
  bool get hasDraftChanges => activeDraftChanges.isNotEmpty;
  String? get lastError => _lastError;
  bool get overlayVisible => controller.overlayVisible;
  LiveEditExecutionPlan? get pendingExecutionPlan => _pendingExecutionPlan;
  LiveEditEditMode get editMode => _editMode;
  String? get activePropertyId => _activePropertyId;
  String get aiComposer => _aiComposer;
  bool get aiBubbleVisible =>
      overlayVisible &&
      activeSelection != null &&
      (_editMode == LiveEditEditMode.ai ||
          needsApproval ||
          _applyPhase == LiveEditApplyPhase.success);

  bool get needsApproval =>
      _applyPhase == LiveEditApplyPhase.awaitingApproval &&
      _pendingExecutionPlan != null &&
      _hasText(_pendingProposalId);

  LiveEditPropertyDescriptor? get activeProperty {
    final selection = activeSelection;
    if (selection == null) {
      return null;
    }
    final activeId = _activePropertyId;
    if (_hasText(activeId)) {
      for (final property in selection.propertyGroups) {
        if (property.id == activeId) {
          return property;
        }
      }
    }
    for (final property in selection.propertyGroups) {
      if (property.editable) {
        return property;
      }
    }
    return selection.propertyGroups.isEmpty
        ? null
        : selection.propertyGroups.first;
  }

  List<LiveEditTimelineEntry> get historyForActiveSelection {
    final nodeId = activeSelection?.nodeId;
    if (!_hasText(nodeId)) {
      return const <LiveEditTimelineEntry>[];
    }
    return List<LiveEditTimelineEntry>.unmodifiable(
      _historyByNode[nodeId] ?? const <LiveEditTimelineEntry>[],
    );
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

  Future<void> applyDraft({
    final bool approve = false,
    final String? message,
  }) async {
    final sessionId = ensureSession();
    if (!hasDraftChanges) {
      _setError('No draft changes to apply.');
      return;
    }
    if (applyDraftDelegate == null) {
      _setError('Apply transport is not configured for this host app.');
      return;
    }

    final resolvedIntent = _resolveIntentText(message);
    _applyPhase = approve
        ? LiveEditApplyPhase.applying
        : LiveEditApplyPhase.preparing;
    _lastError = null;
    if (!approve) {
      _editMode = LiveEditEditMode.ai;
    }
    _appendTimeline(
      role: approve ? 'system' : 'user',
      message: approve
          ? 'Approve and apply live-edit proposal.'
          : resolvedIntent,
    );
    notifyListeners();

    try {
      final response = await applyDraftDelegate!(
        LiveEditApplyDraftRequest(
          sessionId: sessionId,
          proposalId: _pendingProposalId,
          backendId: backendId,
          workingDirectory: workingDirectory,
          intentText: resolvedIntent,
          approve: approve,
        ),
      );

      final responseError = _extractError(response);
      if (_hasText(responseError)) {
        _setError(responseError!);
        return;
      }

      final proposalId = '${response['proposalId'] ?? ''}'.trim();
      if (_hasText(proposalId)) {
        _pendingProposalId = proposalId;
      }

      final executionPlan = _decodeExecutionPlan(response['executionPlan']);
      if (executionPlan != null) {
        _pendingExecutionPlan = executionPlan;
        _appendTimeline(
          role: 'assistant',
          message: executionPlan.summary,
          details: <String>[
            ...executionPlan.requestedChanges,
            ...executionPlan.riskNotes,
          ],
        );
      }

      if (approve) {
        _applyPhase = LiveEditApplyPhase.success;
        _appendTimeline(
          role: 'assistant',
          message: 'Applied live-edit proposal.',
          details: _pendingExecutionPlan?.affectedFiles ?? const <String>[],
        );
        _pendingExecutionPlan = null;
        _pendingProposalId = null;
        controller.discardDraft(sessionId: sessionId);
      } else {
        _applyPhase = executionPlan == null
            ? LiveEditApplyPhase.success
            : LiveEditApplyPhase.awaitingApproval;
      }
      notifyListeners();
    } on Exception catch (error) {
      _setError('Apply failed: $error');
    }
  }

  void beginInlineEdit(
    final LiveEditPropertyDescriptor property, {
    final LiveEditEditSurface? surface,
  }) {
    _activePropertyId = property.id;
    final resolvedSurface = surface ?? property.preferredEditSurface;
    _editMode =
        resolvedSurface == LiveEditEditSurface.aiBubble ||
            property.requiresAgentForPersistence
        ? LiveEditEditMode.ai
        : LiveEditEditMode.edit;
    if (_editMode == LiveEditEditMode.ai && !_hasText(_aiComposer)) {
      _aiComposer = _defaultAiPrompt();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  String ensureSession() {
    final current = activeSessionId;
    if (_hasText(current)) {
      return current!;
    }
    final started = controller.startSession();
    return '${started['sessionId'] ?? ''}';
  }

  void focusProperty(final LiveEditPropertyDescriptor property) {
    beginInlineEdit(property);
  }

  void openAiBubble({final LiveEditPropertyDescriptor? property}) {
    if (property != null) {
      _activePropertyId = property.id;
    }
    _editMode = LiveEditEditMode.ai;
    if (!_hasText(_aiComposer)) {
      _aiComposer = _defaultAiPrompt();
    }
    notifyListeners();
  }

  Future<void> retryApply() async {
    if (_hasText(_pendingProposalId)) {
      await applyDraft(approve: true);
      return;
    }
    await applyDraft(message: _aiComposer);
  }

  void selectCandidateAt(final int index) {
    controller.selectCandidate(sessionId: activeSessionId, index: index);
    _syncSelectionState();
  }

  void selectNode(final Offset globalOffset, {final GlobalKey? contentKey}) {
    final sessionId = ensureSession();
    final contentRoot = contentKey?.currentContext;
    controller.selectAtPoint(
      sessionId: sessionId,
      x: globalOffset.dx.round(),
      y: globalOffset.dy.round(),
      contentRoot: contentRoot is Element ? contentRoot : null,
    );
    _syncSelectionState();
  }

  void selectParentCandidate() {
    controller.selectParent(sessionId: activeSessionId);
    _syncSelectionState();
  }

  void setOverlayEnabled(final bool enabled) {
    final sessionId = ensureSession();
    controller.setOverlay(sessionId: sessionId, enabled: enabled);
    if (!enabled) {
      _editMode = LiveEditEditMode.inspect;
      _aiComposer = '';
      _resetApplyState(clearError: false);
    }
    notifyListeners();
  }

  Future<void> showApprovalSheet(final BuildContext context) async {
    openAiBubble();
    await applyDraft(message: _aiComposer);
  }

  Future<void> submitAiPrompt() async {
    openAiBubble();
    await applyDraft(message: _aiComposer);
  }

  void updateAiComposer(final String value) {
    _aiComposer = value;
    notifyListeners();
  }

  void undoDraft() {
    final sessionId = ensureSession();
    controller.discardDraft(sessionId: sessionId);
    _resetApplyState(clearError: true);
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

    controller.updateDraft(
      sessionId: sessionId,
      change: LiveEditDraftChange(
        nodeId: selection.nodeId,
        propertyId: property.id,
        targetValue: targetValue,
        previewMode: previewMode,
        confidence: property.safeToAutoGroupInApply ? 0.95 : 0.75,
        intentText: _resolveIntentText(null),
        meta: <String, Object?>{
          'requiresAgentForPersistence': property.requiresAgentForPersistence,
          'editSurface': (surface ?? property.preferredEditSurface).wireName,
        },
      ),
    );

    _activePropertyId = property.id;
    _lastError = null;
    _applyPhase = LiveEditApplyPhase.idle;
    _pendingExecutionPlan = null;
    _pendingProposalId = null;
    _editMode =
        property.requiresAgentForPersistence ||
            (surface ?? property.preferredEditSurface) ==
                LiveEditEditSurface.aiBubble
        ? LiveEditEditMode.ai
        : LiveEditEditMode.edit;
    if (_editMode == LiveEditEditMode.ai && !_hasText(_aiComposer)) {
      _aiComposer = _defaultAiPrompt();
    }
    _appendTimeline(
      role: 'system',
      message: 'Set ${property.label} to $targetValue',
    );
    notifyListeners();
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
      title: 'Apply live edit',
      summary: 'Persist current draft changes.',
      selectedNode: selection.widgetType,
      requestedChanges: activeDraftChanges
          .map((final draft) => '${draft.propertyId}: ${draft.targetValue}')
          .toList(growable: false),
      affectedFiles: const <String>[],
      confidence: activeDraftChanges.isEmpty ? 0 : 0.7,
      agentInstruction: 'Apply current live-edit draft changes.',
    );
  }

  String _defaultAiPrompt() {
    final selection = activeSelection;
    final buffer = StringBuffer();
    if (selection != null) {
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

  String? _extractError(final Map<String, Object?> response) {
    if (response['ok'] == false) {
      return '${response['message'] ?? 'Unknown apply failure'}';
    }
    final nestedError = response['error'];
    if (nestedError is Map) {
      final message = '${nestedError['message'] ?? ''}'.trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  void _appendTimeline({
    required final String role,
    required final String message,
    final List<String> details = const <String>[],
  }) {
    final nodeId = activeSelection?.nodeId;
    if (!_hasText(nodeId) || message.trim().isEmpty) {
      return;
    }
    final entries = _historyByNode.putIfAbsent(
      nodeId!,
      () => <LiveEditTimelineEntry>[],
    );
    entries.add(
      LiveEditTimelineEntry(
        role: role,
        message: message.trim(),
        details: details.where((final item) => item.trim().isNotEmpty).toList(),
        timestamp: DateTime.now().toUtc(),
        nodeId: nodeId,
      ),
    );
  }

  void _onControllerChanged() {
    if (_disposed) {
      return;
    }
    _syncSelectionState();
    notifyListeners();
  }

  void _resetApplyState({required final bool clearError}) {
    _applyPhase = LiveEditApplyPhase.idle;
    _pendingExecutionPlan = null;
    _pendingProposalId = null;
    if (clearError) {
      _lastError = null;
    }
  }

  String _resolveIntentText(final String? message) {
    final composed = message?.trim() ?? '';
    if (composed.isNotEmpty) {
      return composed;
    }
    final aiPrompt = _aiComposer.trim();
    if (aiPrompt.isNotEmpty) {
      return aiPrompt;
    }
    return _defaultAiPrompt();
  }

  void _setError(final String error) {
    _applyPhase = LiveEditApplyPhase.failed;
    _lastError = error;
    _appendTimeline(role: 'assistant', message: error);
    notifyListeners();
  }

  void _syncSelectionState() {
    final selection = activeSelection;
    final currentNodeId = selection?.nodeId;
    if (currentNodeId != _lastSelectionNodeId) {
      _lastSelectionNodeId = currentNodeId;
      _pendingExecutionPlan = null;
      _pendingProposalId = null;
      _applyPhase = LiveEditApplyPhase.idle;
      _lastError = null;
      _aiComposer = '';
      _editMode = selection == null
          ? LiveEditEditMode.inspect
          : LiveEditEditMode.edit;
      _activePropertyId = _firstEditablePropertyId(selection);
      if (selection != null &&
          activeProperty?.requiresAgentForPersistence == true) {
        _editMode = LiveEditEditMode.ai;
        _aiComposer = _defaultAiPrompt();
      }
      return;
    }

    final active = activeProperty;
    if (active == null && selection != null) {
      _activePropertyId = _firstEditablePropertyId(selection);
    }
  }
}
