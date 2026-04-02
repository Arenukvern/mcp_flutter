import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import '../../ai/backend/live_edit_backend_utils.dart';
import '../../di_live_edit_context/live_edit_context.dart';
import '../../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../../models/models.dart';
import '../../types/live_edit_types.dart';
import '../shared/live_edit_selectors_shared.dart';

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
  final summaries =
      data.bubbleRecordsById.values
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
          .toList(growable: false)
        ..sort((final a, final b) {
          final activeScore = (b.active ? 1 : 0) - (a.active ? 1 : 0);
          if (activeScore != 0) return activeScore;
          return a.label.compareTo(b.label);
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

List<LiveEditBubbleSummary> selectAllNonResolvedBubbleSummariesByDomain(
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

List<LiveEditBubbleSummary> selectAllNonResolvedBubbleSummaries(
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
        (final d) => selectAllNonResolvedBubbleSummariesByDomain(
          ctx,
          controller,
          d,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        ),
      )
      .toList(growable: false);
}

bool selectHasAgentBackedDrafts(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  required final LiveEditTargetDomain presentationDomain,
  final String? sessionId,
}) {
  if (selectSelectionForDomain(
        ctx,
        controller,
        domain: presentationDomain,
        sessionId: sessionId,
      ) ==
      null) {
    return false;
  }
  return false;
}

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

String _failureSummary(final String error) =>
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
  final bubble = selectBubbleRecord(ctx, bubbleId);
  final timeline = bubble?.activity;

  if (applyPhase == LiveEditApplyPhase.rollbackInProgress) {
    return LiveEditActivityEntry(
      step: LiveEditActivityStep.rollbackInProgress,
      label: 'Rolling back',
      summary: 'Rolling back the last applied change.',
      timestamp: now,
      nodeId: bubbleId,
      inProgress: true,
    );
  }
  if (applyPhase == LiveEditApplyPhase.rollbackDone) {
    if (timeline != null && timeline.isNotEmpty) return timeline.last;
    return LiveEditActivityEntry(
      step: LiveEditActivityStep.rollbackDone,
      label: 'Rolled back',
      summary: 'Rollback completed and the bubble is editable again.',
      timestamp: now,
      nodeId: bubbleId,
    );
  }
  if (applyPhase == LiveEditApplyPhase.failed && hasText(lastErr)) {
    return LiveEditActivityEntry(
      step: LiveEditActivityStep.failed,
      label: 'Failed',
      summary: _failureSummary(lastErr!),
      details: <String>[lastErr],
      timestamp: now,
      nodeId: bubbleId,
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
      nodeId: bubbleId,
    );
  }
  if (selectNeedsApproval(ctx)) {
    if (timeline != null && timeline.isNotEmpty) return timeline.last;
    return LiveEditActivityEntry(
      step: LiveEditActivityStep.waitingForApproval,
      label: 'Preview ready',
      summary:
          ctx.bubbleResource.value.pendingExecutionPlan?.summary ??
          'Review the proposed change, then apply or discard.',
      timestamp: now,
      nodeId: bubbleId,
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
      nodeId: bubbleId,
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
        nodeId: bubbleId,
      );
    }
  }
  if (timeline != null && timeline.isNotEmpty) return timeline.last;
  return null;
}
