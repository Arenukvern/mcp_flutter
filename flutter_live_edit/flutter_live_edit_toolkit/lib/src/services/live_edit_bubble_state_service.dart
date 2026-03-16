import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_context.dart';
import '../live_edit_types.dart';

/// Parameters for [LiveEditBubbleStateService.syncSelectionState].
final class SyncSelectionStateParams {
  const SyncSelectionStateParams({
    required this.activeSelection,
    required this.activeSelectedWidgets,
    required this.presentationLayer,
    required this.lastSelectionIdentity,
    required this.effectiveProperties,
    required this.activeProperty,
    required this.draftChanges,
    required this.getBackendIdForBubble,
    required this.getInferenceConfigForBubble,
    required this.defaultAiPrompt,
    required this.updateAiComposer,
  });

  final LiveEditSelection? activeSelection;
  final List<LiveEditSelection> activeSelectedWidgets;
  final LiveEditTargetDomain presentationLayer;
  final String? lastSelectionIdentity;
  final List<LiveEditPropertyDescriptor> effectiveProperties;
  final LiveEditPropertyDescriptor? activeProperty;
  final List<LiveEditDraftChange> draftChanges;
  final String? Function(String?) getBackendIdForBubble;
  final LiveEditInferenceConfig? Function(String?) getInferenceConfigForBubble;
  final String defaultAiPrompt;
  final void Function(String) updateAiComposer;
}

bool _hasText(final String? value) =>
    value != null && value.trim().isNotEmpty;

/// Encapsulates bubble record creation, update, and sync. Used by Commands and orchestrator.
final class LiveEditBubbleStateService {
  LiveEditBubbleStateService();

  /// Resolves bubble id from id or nodeId (domain::nodeId).
  String? resolveBubbleId(
    final LiveEditContext ctx,
    final String? bubbleIdOrNodeId,
  ) {
    final normalized = bubbleIdOrNodeId?.trim();
    if (!_hasText(normalized)) return null;
    final records = ctx.bubbleResource.value.bubbleRecordsById;
    if (records.containsKey(normalized)) return normalized;
    for (final bubbleId in records.keys) {
      if (bubbleId.endsWith('::$normalized')) return bubbleId;
    }
    return normalized;
  }

  LiveEditBubbleRecord? bubbleRecordFor(
    final LiveEditContext ctx,
    final String? bubbleId,
  ) {
    final resolved = resolveBubbleId(ctx, bubbleId);
    if (!_hasText(resolved)) return null;
    return ctx.bubbleResource.value.bubbleRecordsById[resolved!];
  }

  static String? _targetKeyForSelection(final LiveEditSelection? selection) {
    if (selection == null) return null;
    if (selection.selectionMode == LiveEditSelectionMode.multi &&
        selection.selectedNodeIds.length > 1) {
      final ordered = selection.selectedNodeIds
          .where((final id) => _hasText(id))
          .toList(growable: false)
        ..sort();
      if (ordered.isNotEmpty) return 'area:${ordered.join('|')}';
    }
    final nodeId = selection.nodeId.trim();
    return _hasText(nodeId) ? nodeId : null;
  }

  /// Returns bubble id for selection (domain::targetKey) or null.
  String? bubbleIdForSelection(
    final LiveEditContext ctx,
    final LiveEditSelection? selection,
  ) {
    if (selection == null) return null;
    final targetKey = _targetKeyForSelection(selection);
    return _hasText(targetKey)
        ? '${selection.targetDomain.wireName}::$targetKey'
        : null;
  }

  LiveEditBubbleRecord ensureBubbleState(
    final LiveEditContext ctx,
    final String bubbleId, {
    final LiveEditSelection? selection,
    final List<LiveEditSelection>? selectedWidgets,
  }) {
    final existing = bubbleRecordFor(ctx, bubbleId);
    if (existing != null) return existing;
    final domain = selection?.targetDomain ??
        ctx.sessionResource.value.targetDomain;
    final targetKey = _targetKeyForSelection(selection) ?? bubbleId;
    final record = LiveEditBubbleRecord(
      bubbleId: bubbleId,
      targetDomain: domain,
      targetKey: targetKey,
      primarySelection: selection,
      selectedWidgets: selectedWidgets ?? const <LiveEditSelection>[],
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      ctx.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = record;
    ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
    return record;
  }

  void restoreBubbleState(final LiveEditContext ctx, final String? bubbleId) {
    if (!_hasText(bubbleId)) return;
    final bubble = bubbleRecordFor(ctx, bubbleId);
    if (bubble == null) return;
    final records = Map<String, LiveEditBubbleRecord>.from(
      ctx.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId!] = bubble.copyWith(
      displayState: LiveEditBubbleDisplayState.expanded,
    );
    ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  /// Syncs bubble/layer state when selection or identity changes. Returns new
  /// lastSelectionIdentity (caller should store and pass back next time).
  String? syncSelectionState(
    final LiveEditContext ctx,
    final SyncSelectionStateParams params,
  ) {
    final selection = params.activeSelection;
    final currentBubbleId = bubbleIdForSelection(ctx, selection);
    if (currentBubbleId != params.lastSelectionIdentity) {
      final domain = params.presentationLayer;
      final bubble = _hasText(currentBubbleId)
          ? ensureBubbleState(
              ctx,
              currentBubbleId!,
              selection: selection,
              selectedWidgets: params.activeSelectedWidgets,
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
          : (ctx.bubbleResource.value.layerViewStateByDomain[domain]?.editMode ==
                  LiveEditEditMode.ai
              ? LiveEditEditMode.ai
              : LiveEditEditMode.edit);
      var activePropertyId =
          ctx.bubbleResource.value.layerViewStateByDomain[domain]?.activePropertyId ??
              params.activeProperty?.id;
      if (selection != null &&
          params.activeProperty?.requiresAgentForPersistence == true) {
        editMode = LiveEditEditMode.ai;
        activePropertyId = params.activeProperty?.id ?? activePropertyId;
      }
      final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
        ctx.bubbleResource.value.layerViewStateByDomain,
      );
      layerMap[domain] = (layerMap[domain] ?? LiveEditLayerViewState()).copyWith(
        activeBubbleId: currentBubbleId,
        editMode: editMode,
        activePropertyId: activePropertyId,
      );
      ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
        layerViewStateByDomain: layerMap,
        applyPhase: phase,
        pendingExecutionPlan: bubble?.executionPlan,
        pendingProposalId: bubble?.executionPlan?.proposalId,
        lastError: bubble?.lastError,
        globalComposerText: bubble?.instructionText ?? '',
      );
      ctx.panelViewResource.value =
          ctx.panelViewResource.value.copyWith(editMode: editMode);
      if (_hasText(currentBubbleId) && selection != null) {
        captureBubbleState(
          ctx,
          selection,
          params.activeSelectedWidgets,
          instructionText: bubble?.instructionText ?? '',
          status: bubble?.status,
          lastError: bubble?.lastError,
          draftChanges: params.draftChanges,
          backendId: params.getBackendIdForBubble(currentBubbleId),
          inferenceConfig:
              params.getInferenceConfigForBubble(currentBubbleId),
        );
      }
      if (selection != null &&
          params.activeProperty?.requiresAgentForPersistence == true &&
          !_hasText(bubble?.instructionText)) {
        params.updateAiComposer(params.defaultAiPrompt);
      }
      return currentBubbleId;
    }

    final active = params.activeProperty;
    if (active == null && selection != null) {
      final properties = params.effectiveProperties;
      final propId = properties.isEmpty ? null : properties.first.id;
      final domain = params.presentationLayer;
      final layerMap = Map<LiveEditTargetDomain, LiveEditLayerViewState>.from(
        ctx.bubbleResource.value.layerViewStateByDomain,
      );
      layerMap[domain] = (layerMap[domain] ?? LiveEditLayerViewState())
          .copyWith(activePropertyId: propId);
      ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
        layerViewStateByDomain: layerMap,
      );
    }
    return params.lastSelectionIdentity;
  }

  void appendActivity(
    final LiveEditContext ctx, {
    required final LiveEditActivityStep step,
    required final String label,
    required final String summary,
    final List<String> details = const <String>[],
    final bool inProgress = false,
    final String? nodeId,
    final String? errorText,
  }) {
    final data = ctx.bubbleResource.value;
    final bubbleId =
        nodeId ?? data.layerViewStateByDomain[ctx.sessionResource.value.targetDomain]?.activeBubbleId ?? data.pendingBubbleId;
    if (!_hasText(bubbleId) || summary.trim().isEmpty) return;
    final bubble = ensureBubbleState(ctx, bubbleId!);
    final updated = bubble.copyWith(
      activity: <LiveEditActivityEntry>[
        ...bubble.activity,
        LiveEditActivityEntry(
          step: step,
          label: label.trim(),
          summary: summary.trim(),
          details: details.where((final item) => item.trim().isNotEmpty).toList(),
          timestamp: DateTime.now().toUtc(),
          nodeId: bubbleId,
          inProgress: inProgress,
          errorText: errorText,
        ),
      ],
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      ctx.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = updated;
    ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  void appendDebug(
    final LiveEditContext ctx, {
    required final String message,
    final List<String> details = const <String>[],
    final String? nodeId,
  }) {
    final data = ctx.bubbleResource.value;
    final bubbleId =
        nodeId ?? data.layerViewStateByDomain[ctx.sessionResource.value.targetDomain]?.activeBubbleId ?? data.pendingBubbleId;
    if (!_hasText(bubbleId) || message.trim().isEmpty) return;
    final bubble = ensureBubbleState(ctx, bubbleId!);
    final updated = bubble.copyWith(
      debugTimeline: <LiveEditTimelineEntry>[
        ...bubble.debugTimeline,
        LiveEditTimelineEntry(
          role: 'debug',
          message: message.trim(),
          details: details.where((final item) => item.trim().isNotEmpty).toList(),
          timestamp: DateTime.now().toUtc(),
          nodeId: bubbleId,
        ),
      ],
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      ctx.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = updated;
    ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  void appendTimeline(
    final LiveEditContext ctx, {
    required final String role,
    required final String message,
    final List<String> details = const <String>[],
    final String? nodeId,
  }) {
    final data = ctx.bubbleResource.value;
    final bubbleId =
        nodeId ?? data.layerViewStateByDomain[ctx.sessionResource.value.targetDomain]?.activeBubbleId ?? data.pendingBubbleId;
    if (!_hasText(bubbleId) || message.trim().isEmpty) return;
    final bubble = ensureBubbleState(ctx, bubbleId!);
    final updated = bubble.copyWith(
      history: <LiveEditTimelineEntry>[
        ...bubble.history,
        LiveEditTimelineEntry(
          role: role,
          message: message.trim(),
          details: details.where((final item) => item.trim().isNotEmpty).toList(),
          timestamp: DateTime.now().toUtc(),
          nodeId: bubbleId,
        ),
      ],
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      ctx.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = updated;
    ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  void captureBubbleState(
    final LiveEditContext ctx,
    final LiveEditSelection selection,
    final List<LiveEditSelection> selectedWidgets, {
    final String? instructionText,
    final LiveEditBubbleStatus? status,
    final String? lastError,
    final List<LiveEditDraftChange> draftChanges =
        const <LiveEditDraftChange>[],
    final String? backendId,
    final LiveEditInferenceConfig? inferenceConfig,
  }) {
    final bubbleId = bubbleIdForSelection(ctx, selection);
    if (!_hasText(bubbleId)) return;
    final current = bubbleRecordFor(ctx, bubbleId);
    final record = ensureBubbleState(
      ctx,
      bubbleId!,
      selection: selection,
      selectedWidgets: selectedWidgets,
    ).copyWith(
      primarySelection: selection,
      selectedWidgets: selectedWidgets,
      draftChanges: draftChanges,
      instructionText: instructionText ?? '',
      status: status ?? (current?.status ?? LiveEditBubbleStatus.editing),
      displayState:
          current?.displayState ?? LiveEditBubbleDisplayState.expanded,
      changedFiles: current?.changedFiles ?? const <String>[],
      backendId: backendId ?? current?.backendId,
      inferenceConfig: inferenceConfig ?? current?.inferenceConfig,
      executionPlan: current?.executionPlan,
      lastError: lastError ?? current?.lastError,
    );
    final records = Map<String, LiveEditBubbleRecord>.from(
      ctx.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = record;
    ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }

  void finalizeCurrentBubbleOnBlur(
    final LiveEditContext ctx, {
    required final String? bubbleId,
    required final String? nextNodeId,
    required final LiveEditSelection? selection,
    required final List<LiveEditSelection> selectedWidgets,
    required final String instructionText,
    required final String? lastError,
    required final bool keepPinned,
  }) {
    if (!_hasText(bubbleId) ||
        bubbleId == nextNodeId ||
        selection == null) return;
    captureBubbleState(
      ctx,
      selection,
      selectedWidgets,
      instructionText: instructionText,
      status: bubbleRecordFor(ctx, bubbleId)?.status ?? LiveEditBubbleStatus.editing,
      lastError: lastError,
    );
    if (keepPinned) {
      final bubble = bubbleRecordFor(ctx, bubbleId);
      if (bubble != null && bubbleId != null) {
        final records = Map<String, LiveEditBubbleRecord>.from(
          ctx.bubbleResource.value.bubbleRecordsById,
        );
        records[bubbleId] = bubble.copyWith(
          displayState: LiveEditBubbleDisplayState.minimized,
        );
        ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
          bubbleRecordsById: records,
        );
      }
      return;
    }
    if (bubbleId != null) {
      final records = Map<String, LiveEditBubbleRecord>.from(
        ctx.bubbleResource.value.bubbleRecordsById,
      );
      records.remove(bubbleId);
      ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
        bubbleRecordsById: records,
      );
    }
  }

  String failureSummary(
    final String error, {
    final String? bubbleId,
    required final String Function(String?) getBackendLabel,
  }) {
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
    return '${getBackendLabel(bubbleId)} request failed.';
  }

  void setErrorForBubble(
    final LiveEditContext ctx,
    final String? bubbleId,
    final String error, {
    required final String Function(String?) getBackendLabel,
  }) {
    var data = ctx.bubbleResource.value.copyWith(
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
    ctx.bubbleResource.value = data;
    final nodeId = bubbleId ??
        data.layerViewStateByDomain[ctx.sessionResource.value.targetDomain]?.activeBubbleId ??
        data.pendingBubbleId;
    appendActivity(
      ctx,
      step: LiveEditActivityStep.failed,
      label: 'Failed',
      summary: failureSummary(error, bubbleId: bubbleId, getBackendLabel: getBackendLabel),
      details: <String>[error],
      nodeId: nodeId,
      errorText: error,
    );
    appendDebug(
      ctx,
      message: 'Live-edit request failed.',
      details: <String>[error],
      nodeId: nodeId,
    );
    appendTimeline(ctx, role: 'assistant', message: error, nodeId: nodeId);
  }

  /// Translates runtime event message to activity step, label, summary, inProgress.
  (LiveEditActivityStep, String, String, bool) translateRuntimeEvent(
    final String message,
    final String Function(String?) getBackendLabel,
    final String? bubbleId,
  ) {
    final backendLabel = getBackendLabel(bubbleId);
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

  void emitEventForBubble(
    final LiveEditContext ctx,
    final String? bubbleId,
    final LiveEditRuntimeEvent event, {
    required final String Function(String?) getBackendLabel,
  }) {
    final data = ctx.bubbleResource.value;
    final resolvedBubbleId = bubbleId ??
        data.layerViewStateByDomain[ctx.sessionResource.value.targetDomain]?.activeBubbleId ??
        data.pendingBubbleId;
    final promptText = event.promptText?.trim();
    if (_hasText(resolvedBubbleId) && _hasText(promptText)) {
      final bubble = ensureBubbleState(ctx, resolvedBubbleId!);
      final records = Map<String, LiveEditBubbleRecord>.from(
        ctx.bubbleResource.value.bubbleRecordsById,
      );
      records[resolvedBubbleId] = bubble.copyWith(debugPromptText: promptText);
      ctx.bubbleResource.value = ctx.bubbleResource.value.copyWith(
        bubbleRecordsById: records,
      );
    }
    if (event.debugOnly || event.kind == LiveEditRuntimeEventKind.debug) {
      appendDebug(
        ctx,
        message: event.message,
        details: event.details,
        nodeId: resolvedBubbleId,
      );
      return;
    }
    if (event.kind == LiveEditRuntimeEventKind.edit) {
      appendDebug(
        ctx,
        message: event.message,
        details: event.details,
        nodeId: resolvedBubbleId,
      );
      return;
    }
    final translated = translateRuntimeEvent(
      event.message,
      getBackendLabel,
      resolvedBubbleId,
    );
    appendActivity(
      ctx,
      step: translated.$1,
      label: translated.$2,
      summary: translated.$3,
      details: event.details,
      inProgress: translated.$4,
      nodeId: resolvedBubbleId,
    );
    appendDebug(
      ctx,
      message: event.message,
      details: event.details,
      nodeId: resolvedBubbleId,
    );
  }
}
