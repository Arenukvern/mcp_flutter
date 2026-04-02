import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';
import '../../types/live_edit_types.dart';

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

/// Rolls an applied bubble back to editable state.
final class RollbackAppliedBubbleCommand {
  RollbackAppliedBubbleCommand({this.bubbleId});

  final String? bubbleId;

  void execute(final LiveEditContext context) {
    final domain = context.sessionResource.value.targetDomain;
    final bubbleData = context.bubbleResource.value;
    final activeId = bubbleId ?? bubbleData.layerViewStateByDomain[domain]?.activeBubbleId;
    final resolvedId = context.bubbleStateService.resolveBubbleId(
      context,
      activeId,
    );
    if (!_hasText(resolvedId)) return;

    final current = bubbleData.bubbleRecordsById[resolvedId!];
    if (current == null || current.status != LiveEditBubbleStatus.applied) {
      return;
    }

    final transactionId = current.executionPlan?.proposalId;
    final txLabel = _hasText(transactionId)
        ? 'transaction ${transactionId!.trim()}'
        : 'the last applied change';

    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      applyPhase: LiveEditApplyPhase.rollbackInProgress,
      pendingBubbleId: resolvedId,
      lastError: null,
    );

    context.bubbleStateService.appendActivity(
      context,
      step: LiveEditActivityStep.rollbackInProgress,
      label: 'Rolling back',
      summary: 'Rolling back $txLabel.',
      inProgress: true,
      nodeId: resolvedId,
    );
    context.bubbleStateService.appendTimeline(
      context,
      role: 'assistant',
      message: 'Rollback requested for $txLabel.',
      nodeId: resolvedId,
    );
    context.bubbleStateService.appendDebug(
      context,
      message: 'rollback_triggered',
      details: <String>[
        if (_hasText(transactionId)) 'transactionId=${transactionId!.trim()}',
      ],
      nodeId: resolvedId,
    );

    final records = Map<String, LiveEditBubbleRecord>.from(
      context.bubbleResource.value.bubbleRecordsById,
    );
    records[resolvedId] = current.copyWith(
      status: LiveEditBubbleStatus.editing,
      displayState: LiveEditBubbleDisplayState.expanded,
      changedFiles: const <String>[],
      executionPlan: null,
      lastError: null,
    );
    final resolvedBubbleIds = Set<String>.from(
      context.bubbleResource.value.resolvedBubbleIds,
    )..remove(resolvedId);

    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
      resolvedBubbleIds: resolvedBubbleIds,
      applyPhase: LiveEditApplyPhase.rollbackDone,
      pendingExecutionPlan: null,
      pendingProposalId: null,
      pendingBubbleId: null,
      lastError: null,
    );

    context.bubbleStateService.appendActivity(
      context,
      step: LiveEditActivityStep.rollbackDone,
      label: 'Rolled back',
      summary: 'Rollback completed for $txLabel.',
      inProgress: false,
      nodeId: resolvedId,
    );
    context.bubbleStateService.appendTimeline(
      context,
      role: 'assistant',
      message: 'Rollback completed for $txLabel.',
      nodeId: resolvedId,
    );
    context.bubbleStateService.appendDebug(
      context,
      message: 'rollback_completed',
      details: <String>[
        if (_hasText(transactionId)) 'transactionId=${transactionId!.trim()}',
      ],
      nodeId: resolvedId,
    );
  }
}
