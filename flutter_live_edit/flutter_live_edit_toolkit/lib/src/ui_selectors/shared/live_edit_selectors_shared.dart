import 'dart:ui' show Offset;

import 'package:from_json_to_json/from_json_to_json.dart';

import '../../di_live_edit_context/live_edit_context.dart';
import '../../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../../models/models.dart';
import '../../services/live_edit_bubble_state_service.dart';
import '../../types/live_edit_types.dart';

final _bubbleStateService = LiveEditBubbleStateService();

bool hasText(final String? value) => jsonDecodeString(value).trim().isNotEmpty;

double maxDouble(final double left, final double right) =>
    left > right ? left : right;

double minDouble(final double left, final double right) =>
    left < right ? left : right;

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

List<Object?> selectEffectiveProperties(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain domain,
  final String? sessionId,
}) => const <Object?>[];

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

LiveEditLayerViewState selectLayerViewState(
  final LiveEditContext ctx, {
  required final LiveEditTargetDomain domain,
}) =>
    ctx.bubbleResource.value.layerViewStateByDomain[domain] ??
    LiveEditLayerViewState();

LiveEditApplyPhase selectApplyPhase(final LiveEditContext ctx) =>
    ctx.bubbleResource.value.applyPhase;

bool selectNeedsApproval(final LiveEditContext ctx) =>
    ctx.bubbleResource.value.applyPhase ==
        LiveEditApplyPhase.awaitingApproval &&
    ctx.bubbleResource.value.pendingExecutionPlan != null &&
    hasText(ctx.bubbleResource.value.pendingProposalId);

bool selectIsApplyingBusy(final LiveEditContext ctx) {
  final phase = ctx.bubbleResource.value.applyPhase;
  return phase == LiveEditApplyPhase.preparing ||
      phase == LiveEditApplyPhase.applying ||
      phase == LiveEditApplyPhase.rollbackInProgress;
}

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
  final bubble = selectBubbleRecord(
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
  final bubble = selectBubbleRecord(ctx, activeBubbleId);
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
  final bubble = selectBubbleRecord(ctx, activeBubbleId);
  final aiComposer =
      bubble?.instructionText ?? ctx.bubbleResource.value.globalComposerText;
  return selection != null &&
      hasText(aiComposer) &&
      !selectNeedsApproval(ctx) &&
      !selectIsApplyingBusy(ctx);
}

LiveEditBubbleStatus selectBubbleStatusForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  if (!hasText(bubbleId)) return LiveEditBubbleStatus.editing;
  final bubble = selectBubbleRecord(ctx, bubbleId);
  return bubble?.status ?? LiveEditBubbleStatus.editing;
}

LiveEditBubbleRecord? selectBubbleRecord(
  final LiveEditContext ctx,
  final String? bubbleId,
) => _bubbleStateService.bubbleRecordFor(ctx, bubbleId);

Offset selectBubbleDragOffset(
  final LiveEditContext ctx,
  final String? bubbleId,
) => selectBubbleRecord(ctx, bubbleId)?.bubbleDragOffset ?? Offset.zero;

List<LiveEditTimelineEntry> selectHistoryForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  if (hasText(bubbleId)) {
    return List<LiveEditTimelineEntry>.unmodifiable(
      selectBubbleRecord(ctx, bubbleId)?.history ??
          const <LiveEditTimelineEntry>[],
    );
  }
  final activeId = ctx
      .bubbleResource
      .value
      .layerViewStateByDomain[ctx.sessionResource.value.targetDomain]
      ?.activeBubbleId;
  return List<LiveEditTimelineEntry>.unmodifiable(
    selectBubbleRecord(ctx, activeId)?.history ??
        const <LiveEditTimelineEntry>[],
  );
}

/// History + debugTimeline merged by timestamp for chat bubble display.
List<LiveEditTimelineEntry> selectMergedTimelineForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final bubble = hasText(bubbleId)
      ? selectBubbleRecord(ctx, bubbleId)
      : selectBubbleRecord(
          ctx,
          ctx
              .bubbleResource
              .value
              .layerViewStateByDomain[ctx.sessionResource.value.targetDomain]
              ?.activeBubbleId,
        );
  if (bubble == null) return const <LiveEditTimelineEntry>[];
  final merged = <LiveEditTimelineEntry>[
    ...bubble.history,
    ...bubble.debugTimeline,
  ]..sort((final a, final b) => a.timestamp.compareTo(b.timestamp));
  return List<LiveEditTimelineEntry>.unmodifiable(merged);
}

String selectInstructionTextForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  if (hasText(bubbleId)) {
    final bubble = selectBubbleRecord(ctx, bubbleId);
    if (bubble != null) {
      return bubble.instructionText;
    }
    return ctx.bubbleResource.value.globalComposerText;
  }
  final activeId = ctx
      .bubbleResource
      .value
      .layerViewStateByDomain[ctx.sessionResource.value.targetDomain]
      ?.activeBubbleId;
  final active = selectBubbleRecord(ctx, activeId);
  return active?.instructionText ?? ctx.bubbleResource.value.globalComposerText;
}

LiveEditExecutionPlan? selectExecutionPlanForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final data = ctx.bubbleResource.value;
  if (hasText(bubbleId) && bubbleId == data.pendingBubbleId) {
    return data.pendingExecutionPlan;
  }
  return selectBubbleRecord(ctx, bubbleId)?.executionPlan;
}

bool selectNeedsApprovalForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) =>
    hasText(bubbleId) &&
    bubbleId == ctx.bubbleResource.value.pendingBubbleId &&
    selectNeedsApproval(ctx);

LiveEditExecutionPlan? selectPendingExecutionPlan(final LiveEditContext ctx) =>
    ctx.bubbleResource.value.pendingExecutionPlan;

String? _stagedDraftSummaryForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  final bubble = selectBubbleRecord(ctx, bubbleId);
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
  final bubble = selectBubbleRecord(ctx, bubbleId);
  final draftSummary = _stagedDraftSummaryForBubble(ctx, bubbleId);
  final prompt = (bubble?.instructionText ?? '').trim();
  final sections = <String>[
    if (hasText(draftSummary)) 'Edits: $draftSummary',
    if (hasText(prompt)) 'Prompt: $prompt',
  ];
  return sections.isEmpty ? null : sections.join('\n');
}

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

String? selectStagedDraftSummaryForBubble(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final String? bubbleId, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => _stagedDraftSummaryForBubble(ctx, bubbleId);

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

bool selectCanTriggerApplyForBubble(
  final LiveEditContext ctx,
  final LiveEditController controller,
  final String? bubbleId, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  if (!hasText(bubbleId)) {
    return selectCanTriggerApply(
      ctx,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
  }

  final bubble = selectBubbleRecord(ctx, bubbleId);
  if (bubble == null) {
    return selectCanTriggerApply(
      ctx,
      controller,
      presentationDomain: presentationDomain,
      sessionId: sessionId,
    );
  }

  final needsApproval = selectNeedsApprovalForBubble(ctx, bubbleId);
  final hasDraftChanges = bubble.draftChanges.isNotEmpty;
  final hasSelection =
      bubble.primarySelection != null || bubble.selectedWidgets.isNotEmpty;
  final aiComposer = bubble.instructionText;
  final hasAiPrompt = hasText(aiComposer);
  final canSubmitAiPrompt =
      hasSelection &&
      hasAiPrompt &&
      !needsApproval &&
      !selectIsApplyingBusy(ctx);
  return needsApproval || hasDraftChanges || canSubmitAiPrompt;
}

bool selectCanRollbackForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  if (!hasText(bubbleId)) return false;
  final bubble = selectBubbleRecord(ctx, bubbleId);
  if (bubble == null) return false;
  final phase = selectApplyPhase(ctx);
  if (phase == LiveEditApplyPhase.rollbackInProgress) return false;
  return bubble.status == LiveEditBubbleStatus.applied &&
      hasText(bubble.executionPlan?.proposalId);
}

bool selectCanRollback(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) => selectCanRollbackForBubble(
  ctx,
  selectActiveBubbleId(
    ctx,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  ),
);

String? selectLastErrorForBubble(
  final LiveEditContext ctx,
  final String? bubbleId,
) {
  if (hasText(bubbleId)) {
    final bubble = selectBubbleRecord(ctx, bubbleId);
    return bubble?.lastError;
  }
  final activeId = ctx
      .bubbleResource
      .value
      .layerViewStateByDomain[ctx.sessionResource.value.targetDomain]
      ?.activeBubbleId;
  final active = selectBubbleRecord(ctx, activeId);
  return active?.lastError ?? ctx.bubbleResource.value.lastError;
}

String? selectLastError(final LiveEditContext ctx) =>
    ctx.bubbleResource.value.lastError;
