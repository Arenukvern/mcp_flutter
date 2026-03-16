import 'dart:ui' show Offset, Rect, Size;

import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../live_edit_backend_utils.dart';
import '../live_edit_context.dart';
import '../live_edit_controller_adapter.dart';
import '../live_edit_types.dart';
import '../services/live_edit_bubble_state_service.dart';

// --- Pure helpers (no context) ---

bool hasText(final String? value) => value != null && value.trim().isNotEmpty;

double maxDouble(final double left, final double right) =>
    left > right ? left : right;

double minDouble(final double left, final double right) =>
    left < right ? left : right;

List<LiveEditPropertyDescriptor> commonEditableProperties(
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

// --- Selectors (ctx + controller) ---

final _bubbleStateService = LiveEditBubbleStateService();

String? selectActiveSessionId(final LiveEditContext ctx) =>
    ctx.sessionResource.value.activeSessionId;

LiveEditTargetDomain selectTargetDomain(final LiveEditContext ctx) =>
    ctx.sessionResource.value.targetDomain;

LiveEditSelection? selectSelectionForDomain(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain domain,
  final String? sessionId,
}) => controller.selectionForDomain(
  targetDomain: domain,
  sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
);

String? selectBubbleIdForSelection(
  final LiveEditContext ctx,
  final LiveEditSelection? selection,
) => _bubbleStateService.bubbleIdForSelection(ctx, selection);

LiveEditBubbleId? selectActiveBubbleId(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final sessionId_ = sessionId ?? ctx.sessionResource.value.activeSessionId;
  final selection = controller.selectionForDomain(
    targetDomain: presentationDomain,
    sessionId: sessionId_,
  );
  return selectBubbleIdForSelection(ctx, selection);
}

List<LiveEditPropertyDescriptor> selectEffectiveProperties(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain domain,
  final String? sessionId,
}) {
  final multi = controller.multiSelectionForDomain(
    targetDomain: domain,
    sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
  );
  if (multi.length > 1) {
    return commonEditableProperties(multi);
  }
  final selection = controller.selectionForDomain(
    targetDomain: domain,
    sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
  );
  return selection?.propertyGroups ?? const <LiveEditPropertyDescriptor>[];
}

List<LiveEditSelection> selectMultiSelectionForDomain(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain domain,
  final String? sessionId,
}) => controller.multiSelectionForDomain(
  targetDomain: domain,
  sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
);

List<LiveEditDraftChange> selectDraftChangesForDomain(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain domain,
  final String? sessionId,
}) => controller.draftChangesForDomain(
  targetDomain: domain,
  sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
);

bool selectOverlayVisible(final LiveEditContext ctx) =>
    ctx.sessionResource.value.overlayVisible;

LiveEditLayerViewState selectLayerViewState(
  final LiveEditContext ctx, {
  required final LiveEditTargetDomain domain,
}) =>
    ctx.bubbleResource.value.layerViewStateByDomain[domain] ??
    LiveEditLayerViewState();

LiveEditAgentBackend? selectBackendForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final bubbleBackendId = _bubbleStateService
      .bubbleRecordFor(ctx, bubbleId)
      ?.backendId
      ?.trim();
  final globalId = ctx.backendConfigResource.value.globalBackendId?.trim();
  final backendId = hasText(bubbleBackendId) ? bubbleBackendId : globalId;
  if (!hasText(backendId)) return null;
  for (final b in ctx.backendConfigResource.value.availableBackends) {
    if (b.id == backendId) return b;
  }
  return null;
}

LiveEditAgentBackend? selectCurrentBackend(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectBackendForBubble(
  ctx,
  selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  ),
);

String? selectCurrentBackendId(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final bid = _bubbleStateService
      .bubbleRecordFor(ctx, bubbleId)
      ?.backendId
      ?.trim();
  if (hasText(bid)) return bid;
  return ctx.backendConfigResource.value.globalBackendId;
}

LiveEditInferenceConfig? selectInferenceConfigForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final bubble = _bubbleStateService.bubbleRecordFor(ctx, bubbleId);
  if (bubble?.inferenceConfig != null) return bubble!.inferenceConfig;
  final backend = selectBackendForBubble(ctx, bubbleId);
  if (backend == null) return null;
  return ctx.backendConfigResource.value.inferenceConfigByBackendId[backend
          .id] ??
      backendEffectiveConfig(backend);
}

LiveEditInferenceConfig? selectCurrentInferenceConfig(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectInferenceConfigForBubble(
  ctx,
  selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  ),
);

String? selectCurrentModel(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectCurrentInferenceConfig(
  ctx,
  controller,
  presentationDomain: presentationDomain,
  sessionId: sessionId,
)?.model;

bool selectPanelExpanded(final LiveEditContext ctx) =>
    ctx.panelViewResource.value.panelDisplayMode ==
    LiveEditPanelDisplayMode.expanded;

List<LiveEditBubbleSummary> selectBubbleSummariesByDomain(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final LiveEditTargetDomain domain, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final data = ctx.bubbleResource.value;
  final activeBubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
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
          sourceLabel: !hasText(source?.file)
              ? null
              : '${source!.file}${source.line == null ? '' : ':${source.line}'}',
        );
      })
      .toList(growable: false);
  summaries.sort((final left, final right) {
    final activeScore = (right.active ? 1 : 0) - (left.active ? 1 : 0);
    if (activeScore != 0) return activeScore;
    return left.label.compareTo(right.label);
  });
  return summaries;
}

List<LiveEditBubbleSummary> selectBubbleSummaries(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final domain = ctx.sessionResource.value.targetDomain;
  final inactive = domain == LiveEditTargetDomain.appScene
      ? LiveEditTargetDomain.toolScene
      : LiveEditTargetDomain.appScene;
  return <LiveEditTargetDomain>[domain, inactive]
      .expand(
        (final d) => selectBubbleSummariesByDomain(
          ctx,
          controller,
          d,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        ),
      )
      .toList(growable: false);
}

bool selectNeedsApproval(final LiveEditContext ctx) =>
    ctx.bubbleResource.value.applyPhase ==
        LiveEditApplyPhase.awaitingApproval &&
    ctx.bubbleResource.value.pendingExecutionPlan != null &&
    hasText(ctx.bubbleResource.value.pendingProposalId);

bool selectIsApplyingBusy(final LiveEditContext ctx) {
  final phase = ctx.bubbleResource.value.applyPhase;
  return phase == LiveEditApplyPhase.preparing ||
      phase == LiveEditApplyPhase.applying;
}

LiveEditApplyPhase selectApplyPhase(final LiveEditContext ctx) =>
    ctx.bubbleResource.value.applyPhase;

bool selectActiveBubbleResolved(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  return hasText(bubbleId) &&
      ctx.bubbleResource.value.resolvedBubbleIds.contains(bubbleId);
}

List<LiveEditTimelineEntry> selectHistoryForActiveSelection(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectHistoryForBubble(
  ctx,
  selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  ),
);

List<LiveEditActivityEntry> selectActivityTimelineForActiveSelection(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubble = _bubbleStateService.bubbleRecordFor(
    ctx,
    selectActiveBubbleId(
      ctx,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    ),
  );
  return List<LiveEditActivityEntry>.unmodifiable(
    bubble?.activity ?? const <LiveEditActivityEntry>[],
  );
}

bool selectIsWaitingForAgent(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) =>
    selectBubbleStatusForBubble(
      ctx,
      selectActiveBubbleId(
        ctx,
        controller,
        presentationDomain: presentationDomain,
        sessionId: sessionId,
      ),
    ) ==
    LiveEditBubbleStatus.waiting;

bool selectCanTriggerApply(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final needsApproval = selectNeedsApproval(ctx);
  final draftChanges = selectDraftChangesForDomain(
    ctx,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  );
  final hasDraftChanges = draftChanges.isNotEmpty;
  final selection = selectSelectionForDomain(
    ctx,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  );
  final activeBubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final bubble = _bubbleStateService.bubbleRecordFor(ctx, activeBubbleId);
  final aiComposer =
      bubble?.instructionText ?? ctx.bubbleResource.value.globalComposerText;
  final hasAiPrompt = hasText(aiComposer);
  final canSubmitAiPrompt =
      selection != null &&
      hasAiPrompt &&
      !needsApproval &&
      !selectIsApplyingBusy(ctx);
  return needsApproval || hasDraftChanges || canSubmitAiPrompt;
}

bool selectCanSubmitAiPrompt(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final selection = selectSelectionForDomain(
    ctx,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  );
  final activeBubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final bubble = _bubbleStateService.bubbleRecordFor(ctx, activeBubbleId);
  final aiComposer =
      bubble?.instructionText ?? ctx.bubbleResource.value.globalComposerText;
  return selection != null &&
      hasText(aiComposer) &&
      !selectNeedsApproval(ctx) &&
      !selectIsApplyingBusy(ctx);
}

// --- Host/panel selectors ---

String selectCurrentBackendLabel(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final backend = selectCurrentBackend(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  if (backend?.label.trim().isNotEmpty == true) return backend!.label;
  final bid = selectCurrentBackendId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  return hasText(bid) ? fallbackBackendLabel(bid!) : 'AI agent';
}

double selectPanelWidth(final LiveEditContext ctx) {
  final pv = ctx.panelViewResource.value;
  return pv.panelDisplayMode == LiveEditPanelDisplayMode.expanded
      ? pv.panelExpandedWidth
      : pv.panelRailWidth;
}

double selectPanelHeight(final LiveEditContext ctx) {
  final pv = ctx.panelViewResource.value;
  return pv.panelDisplayMode == LiveEditPanelDisplayMode.expanded
      ? pv.panelExpandedHeight
      : pv.panelRailHeight;
}

Offset selectPanelPlacement(final LiveEditContext ctx, final Size viewport) =>
    clampPanelPlacement(
      placement:
          Offset(viewport.width - selectPanelWidth(ctx) - 16, 16) +
          ctx.panelViewResource.value.panelDragOffset,
      viewport: viewport,
      panelWidth: selectPanelWidth(ctx),
      panelHeight: selectPanelHeight(ctx),
    );

List<LiveEditBubbleSummary> selectPinnedBubbleSummaries(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) =>
    selectBubbleSummaries(
          ctx,
          controller,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        )
        .where(
          (final s) => s.displayState == LiveEditBubbleDisplayState.minimized,
        )
        .toList(growable: false);

List<LiveEditBubbleSummary> selectExpandedBubbleSummariesByDomain(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final LiveEditTargetDomain domain, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final data = ctx.bubbleResource.value;
  final activeBubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  return data.bubbleRecordsById.values
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
          sourceLabel: !hasText(source?.file)
              ? null
              : '${source!.file}${source.line == null ? '' : ':${source.line}'}',
        );
      })
      .toList(growable: false)
    ..sort((final a, final b) {
      final activeScore = (b.active ? 1 : 0) - (a.active ? 1 : 0);
      if (activeScore != 0) return activeScore;
      return a.label.compareTo(b.label);
    });
}

List<LiveEditBubbleSummary> selectExpandedBubbleSummaries(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final domain = ctx.sessionResource.value.targetDomain;
  final inactive = domain == LiveEditTargetDomain.appScene
      ? LiveEditTargetDomain.toolScene
      : LiveEditTargetDomain.appScene;
  return <LiveEditTargetDomain>[domain, inactive]
      .expand(
        (final d) => selectExpandedBubbleSummariesByDomain(
          ctx,
          controller,
          d,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        ),
      )
      .toList(growable: false);
}

LiveEditBubbleStatus selectBubbleStatusForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  if (!hasText(bubbleId)) return LiveEditBubbleStatus.editing;
  final bubble = _bubbleStateService.bubbleRecordFor(ctx, bubbleId);
  return bubble?.status ?? LiveEditBubbleStatus.editing;
}

String? _stagedDraftSummaryForBubble(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final String? bubbleId, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubble = _bubbleStateService.bubbleRecordFor(ctx, bubbleId);
  final changes = bubble?.draftChanges ?? const <LiveEditDraftChange>[];
  if (changes.isEmpty) return null;
  return changes
      .map((final d) => '${d.propertyId}: ${d.targetValue}')
      .where(hasText)
      .join(' | ');
}

String? selectStagedRequestSummaryForBubble(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final String? bubbleId, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubble = _bubbleStateService.bubbleRecordFor(ctx, bubbleId);
  final draftSummary = _stagedDraftSummaryForBubble(
    ctx,
    controller,
    bubbleId,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final prompt = (bubble?.instructionText ?? '').trim();
  final sections = <String>[
    if (hasText(draftSummary)) 'Edits: $draftSummary',
    if (hasText(prompt)) 'Prompt: $prompt',
  ];
  return sections.isEmpty ? null : sections.join('\n');
}

String? selectStagedDraftSummaryForBubble(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final String? bubbleId, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => _stagedDraftSummaryForBubble(
  ctx,
  controller,
  bubbleId,
  presentationDomain: presentationDomain,
  sessionId: sessionId,
);

String? selectStagedDraftSummary(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectStagedDraftSummaryForBubble(
  ctx,
  controller,
  selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  ),
  presentationDomain: presentationDomain,
  sessionId: sessionId,
);

String? selectLastErrorForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  if (hasText(bubbleId)) {
    final bubble = _bubbleStateService.bubbleRecordFor(ctx, bubbleId);
    return bubble?.lastError;
  }
  final activeId = ctx
      .bubbleResource
      .value
      .layerViewStateByDomain[ctx.sessionResource.value.targetDomain]
      ?.activeBubbleId;
  final active = _bubbleStateService.bubbleRecordFor(ctx, activeId);
  return active?.lastError ?? ctx.bubbleResource.value.lastError;
}

String? selectLastError(final LiveEditContext ctx) =>
    ctx.bubbleResource.value.lastError;

bool selectDebugModeEnabled(final LiveEditContext ctx) =>
    ctx.panelViewResource.value.debugModeEnabled;

bool selectDeeperPickEnabled(final LiveEditContext ctx) =>
    ctx.panelViewResource.value.deeperPickEnabled;

String? selectStagedRequestSummary(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectStagedRequestSummaryForBubble(
  ctx,
  controller,
  selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  ),
  presentationDomain: presentationDomain,
  sessionId: sessionId,
);

bool selectNeedsApprovalForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) =>
    hasText(bubbleId) &&
    bubbleId == ctx.bubbleResource.value.pendingBubbleId &&
    selectNeedsApproval(ctx);

LiveEditExecutionPlan? selectExecutionPlanForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final data = ctx.bubbleResource.value;
  if (hasText(bubbleId) && bubbleId == data.pendingBubbleId) {
    return data.pendingExecutionPlan;
  }
  return _bubbleStateService.bubbleRecordFor(ctx, bubbleId)?.executionPlan;
}

LiveEditBubbleRecord? selectBubbleRecord(
  final LiveEditContext ctx,
  final String? bubbleId,
) => _bubbleStateService.bubbleRecordFor(ctx, bubbleId);

Offset selectBubbleDragOffset(
  final LiveEditContext ctx,
  final String? bubbleId,
) =>
    _bubbleStateService.bubbleRecordFor(ctx, bubbleId)?.bubbleDragOffset ??
    Offset.zero;

List<LiveEditTimelineEntry> selectHistoryForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  if (hasText(bubbleId)) {
    return List<LiveEditTimelineEntry>.unmodifiable(
      _bubbleStateService.bubbleRecordFor(ctx, bubbleId)?.history ??
          const <LiveEditTimelineEntry>[],
    );
  }
  final activeId = ctx
      .bubbleResource
      .value
      .layerViewStateByDomain[ctx.sessionResource.value.targetDomain]
      ?.activeBubbleId;
  return List<LiveEditTimelineEntry>.unmodifiable(
    _bubbleStateService.bubbleRecordFor(ctx, activeId)?.history ??
        const <LiveEditTimelineEntry>[],
  );
}

String selectInstructionTextForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  if (hasText(bubbleId)) {
    return _bubbleStateService
            .bubbleRecordFor(ctx, bubbleId)
            ?.instructionText ??
        '';
  }
  final activeId = ctx
      .bubbleResource
      .value
      .layerViewStateByDomain[ctx.sessionResource.value.targetDomain]
      ?.activeBubbleId;
  final active = _bubbleStateService.bubbleRecordFor(ctx, activeId);
  return active?.instructionText ?? ctx.bubbleResource.value.globalComposerText;
}

bool selectCanTriggerApplyForBubble(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final String? bubbleId, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) =>
    hasText(bubbleId) &&
    (selectNeedsApprovalForBubble(ctx, bubbleId) ||
        (_bubbleStateService.bubbleRecordFor(ctx, bubbleId)?.hasPendingApply ??
            false));

Object? selectEffectiveValueForProperty(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final LiveEditPropertyDescriptor property, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final draftChanges = selectDraftChangesForDomain(
    ctx,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  );
  final draft = draftChanges
      .where((final c) => c.propertyId == property.id)
      .toList();
  if (draft.isNotEmpty) return draft.last.targetValue;
  final selection = selectSelectionForDomain(
    ctx,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  );
  final groups = selection?.propertyGroups
      .where((final p) => p.id == property.id)
      .toList();
  final group = groups != null && groups.isNotEmpty ? groups.first : null;
  return group?.value ?? property.value;
}

bool selectIsPropertyWaiting(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final LiveEditPropertyDescriptor property, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final data = ctx.bubbleResource.value;
  final isWaiting =
      selectBubbleStatusForBubble(
        ctx,
        selectActiveBubbleId(
          ctx,
          controller,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        ),
      ) ==
      LiveEditBubbleStatus.waiting;
  return isWaiting &&
      selectActiveBubbleId(
            ctx,
            controller,
            presentationDomain: presentationDomain,
            sessionId: sessionId,
          ) ==
          data.pendingBubbleId &&
      property.id == data.pendingPropertyId;
}

bool selectHasDraftForProperty(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final LiveEditPropertyDescriptor property, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectDraftChangesForDomain(
  ctx,
  controller,
  domain: presentationDomain,
  sessionId: sessionId,
).any((final d) => d.propertyId == property.id);

bool selectHasMultiSelection(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) =>
    selectMultiSelectionForDomain(
      ctx,
      controller,
      domain: presentationDomain,
      sessionId: sessionId,
    ).length >
    1;

String? selectCurrentReasoningEffort(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectCurrentInferenceConfig(
  ctx,
  controller,
  presentationDomain: presentationDomain,
  sessionId: sessionId,
)?.reasoningEffort;

bool selectCurrentBackendUsesFreeformModel(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) =>
    selectCurrentBackend(
      ctx,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    )?.id ==
    'cursor_agent';

List<LiveEditCodexModelOption> selectCurrentSupportedModels(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final backend = selectCurrentBackend(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  if (backend == null || backend.id != 'codex_exec') {
    return const <LiveEditCodexModelOption>[];
  }
  final models = backend.meta['supportedModels'];
  if (models is! List) return LiveEditCodexOptions.supportedModels;
  return models
      .whereType<Map>()
      .map(
        (final item) => LiveEditCodexModelOption.fromJson(
          item.map((final key, final value) => MapEntry('$key', value)),
        ),
      )
      .toList(growable: false);
}

List<String> selectCurrentSupportedReasoningEfforts(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final backend = selectCurrentBackend(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  if (backend == null || backend.id != 'codex_exec') {
    return const <String>[];
  }
  final efforts = backend.meta['supportedReasoningEfforts'];
  if (efforts is! List) return LiveEditCodexOptions.supportedReasoningEfforts;
  return efforts.map((final item) => '$item').toList(growable: false);
}

LiveEditExecutionPlan? selectPendingExecutionPlan(final LiveEditContext ctx) =>
    ctx.bubbleResource.value.pendingExecutionPlan;

String? selectBackendIdForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final bid = _bubbleStateService
      .bubbleRecordFor(ctx, bubbleId)
      ?.backendId
      ?.trim();
  if (hasText(bid)) return bid;
  return ctx.backendConfigResource.value.globalBackendId;
}

LiveEditTargetDomain selectPresentedLayer(final LiveEditContext ctx) {
  final domain = ctx.sessionResource.value.targetDomain;
  if (domain == LiveEditTargetDomain.toolScene &&
      !(ctx.panelViewResource.value.toolPresentationArmed)) {
    return LiveEditTargetDomain.appScene;
  }
  return domain;
}

LiveEditEditMode selectEditMode(final LiveEditContext ctx) =>
    selectLayerViewState(ctx, domain: selectPresentedLayer(ctx)).editMode;

Rect? selectMarqueeRect(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => controller.marqueeRectForDomain(
  targetDomain: presentationDomain,
  sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
);

List<LiveEditSelection> selectMarqueePreviewSelections(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => controller.marqueeSelectionsForDomain(
  targetDomain: presentationDomain,
  sessionId: sessionId ?? ctx.sessionResource.value.activeSessionId,
);

bool selectHasMarqueePreview(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final rect = selectMarqueeRect(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final list = selectMarqueePreviewSelections(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  return rect != null && list.isNotEmpty;
}

String? selectDebugPromptForActiveSelection(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final prompt = _bubbleStateService
      .bubbleRecordFor(ctx, bubbleId)
      ?.debugPromptText
      ?.trim();
  return hasText(prompt) ? prompt : null;
}

List<LiveEditTimelineEntry> selectDebugTimelineForActiveSelection(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => List<LiveEditTimelineEntry>.unmodifiable(
  _bubbleStateService
          .bubbleRecordFor(
            ctx,
            selectActiveBubbleId(
              ctx,
              controller,
              presentationDomain: presentationDomain,
              sessionId: sessionId,
            ),
          )
          ?.debugTimeline ??
      const <LiveEditTimelineEntry>[],
);

String? selectActivePropertyId(
  final LiveEditContext ctx, {
  required final LiveEditTargetDomain domain,
}) => ctx.bubbleResource.value.layerViewStateByDomain[domain]?.activePropertyId;

LiveEditPropertyDescriptor? selectActiveProperty(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final properties = selectEffectiveProperties(
    ctx,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  );
  if (properties.isEmpty) return null;
  final domain = selectPresentedLayer(ctx);
  final activeId = selectActivePropertyId(ctx, domain: domain);
  if (hasText(activeId)) {
    for (final p in properties) {
      if (p.id == activeId) return p;
    }
  }
  for (final p in properties) {
    if (p.editable) return p;
  }
  return properties.first;
}

String _failureSummary(final String error, {required final String bubbleId}) =>
    error.length > 80 ? '${error.substring(0, 80)}…' : error;

LiveEditActivityEntry? selectCurrentActivity(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  if (!hasText(bubbleId)) return null;
  final backendLabel = backendLabelFromContext(ctx, bubbleId);
  final now = DateTime.now().toUtc();
  final applyPhase = ctx.bubbleResource.value.applyPhase;
  final lastErr = ctx.bubbleResource.value.lastError;
  final bubble = _bubbleStateService.bubbleRecordFor(ctx, bubbleId);
  final timeline = bubble?.activity;

  if (applyPhase == LiveEditApplyPhase.failed && hasText(lastErr)) {
    return LiveEditActivityEntry(
      step: LiveEditActivityStep.failed,
      label: 'Failed',
      summary: _failureSummary(lastErr!, bubbleId: bubbleId!),
      details: <String>[lastErr!],
      timestamp: now,
      nodeId: bubbleId!,
      errorText: lastErr,
    );
  }
  if (applyPhase == LiveEditApplyPhase.success) {
    if (timeline != null && timeline.isNotEmpty) return timeline.last;
    return LiveEditActivityEntry(
      step: LiveEditActivityStep.finished,
      label: 'Applied',
      summary: 'Live-edit changes are applied for this node.',
      timestamp: now,
      nodeId: bubbleId!,
    );
  }
  if (selectNeedsApproval(ctx)) {
    if (timeline != null && timeline.isNotEmpty) return timeline.last;
    return LiveEditActivityEntry(
      step: LiveEditActivityStep.applyingChanges,
      label: 'Applying',
      summary:
          ctx.bubbleResource.value.pendingExecutionPlan?.summary ??
          '$backendLabel is applying this bubble change.',
      timestamp: now,
      nodeId: bubbleId!,
    );
  }
  if (selectDraftChangesForDomain(
    ctx,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  ).isNotEmpty) {
    return LiveEditActivityEntry(
      step: LiveEditActivityStep.draftReady,
      label: 'Draft ready',
      summary: 'Draft changes are ready to send to $backendLabel.',
      timestamp: now,
      nodeId: bubbleId!,
    );
  }
  if (selectCanTriggerApply(
        ctx,
        controller,
        presentationDomain: presentationDomain,
        sessionId: sessionId,
      ) &&
      !selectNeedsApproval(ctx) &&
      !selectIsApplyingBusy(ctx)) {
    final selection = selectSelectionForDomain(
      ctx,
      controller,
      domain: presentationDomain,
      sessionId: sessionId,
    );
    final aiComposer =
        bubble?.instructionText ?? ctx.bubbleResource.value.globalComposerText;
    if (selection != null && hasText(aiComposer)) {
      return LiveEditActivityEntry(
        step: LiveEditActivityStep.promptReady,
        label: 'Prompt ready',
        summary: 'AI prompt is ready to send to $backendLabel.',
        timestamp: now,
        nodeId: bubbleId!,
      );
    }
  }
  if (timeline != null && timeline.isNotEmpty) return timeline.last;
  return null;
}

int selectPendingBubbleCount(final LiveEditContext ctx) {
  final data = ctx.bubbleResource.value;
  return data.bubbleRecordsById.values
      .where(
        (final b) =>
            !data.resolvedBubbleIds.contains(b.bubbleId) &&
            (b.draftChanges.isNotEmpty || hasText(b.instructionText)),
      )
      .length;
}

bool selectCanApplyAllBubbles(final LiveEditContext ctx) =>
    !selectIsApplyingBusy(ctx) && selectPendingBubbleCount(ctx) > 1;

bool selectCanResolveActiveBubble(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final bubbleId = selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  return hasText(bubbleId) &&
      selectBubbleStatusForBubble(ctx, bubbleId) ==
          LiveEditBubbleStatus.applied;
}

bool selectHasAgentBackedDrafts(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final selection = selectSelectionForDomain(
    ctx,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  );
  if (selection == null) return false;
  final draftChanges = selectDraftChangesForDomain(
    ctx,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  );
  for (final draft in draftChanges) {
    for (final property in selection.propertyGroups) {
      if (property.id == draft.propertyId &&
          property.requiresAgentForPersistence) {
        return true;
      }
    }
  }
  return false;
}

/// Default AI prompt for apply/submit, from selection and optional [intentText].
String selectDefaultAiPrompt(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  final String? intentText,
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  final sessionId_ = sessionId ?? ctx.sessionResource.value.activeSessionId;
  final multi = controller.multiSelectionForDomain(
    targetDomain: presentationDomain,
    sessionId: sessionId_,
  );
  final selection = controller.selectionForDomain(
    targetDomain: presentationDomain,
    sessionId: sessionId_,
  );
  final buffer = StringBuffer();
  if (multi.length > 1) {
    buffer.write('Update ${multi.length} selected widgets');
  } else if (selection != null) {
    buffer.write('Update ${selection.widgetType}');
    if (hasText(selection.source?.file)) {
      buffer.write(' in ${selection.source!.file}');
      if (selection.source?.line != null) {
        buffer.write(':${selection.source!.line}');
      }
    }
    final draftChanges = controller.draftChangesForDomain(
      targetDomain: presentationDomain,
      sessionId: sessionId_,
    );
    final draftSummary = draftChanges
        .map((final d) => '${d.propertyId}=${d.targetValue}')
        .join(', ');
    if (draftSummary.isNotEmpty) {
      buffer.write(' for $draftSummary');
    }
  }
  if (hasText(intentText)) {
    if (buffer.isNotEmpty) buffer.write('. ');
    buffer.write(intentText!.trim());
  }
  return buffer.isEmpty
      ? 'Persist the current live-edit changes.'
      : buffer.toString();
}
