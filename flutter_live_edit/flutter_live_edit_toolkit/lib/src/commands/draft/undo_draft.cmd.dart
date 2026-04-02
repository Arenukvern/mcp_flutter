import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';
import '../../types/live_edit_types.dart';

/// Discards draft nodes via session service and clears draft on active bubble.
final class UndoDraftCommand {
  UndoDraftCommand({this.sessionId});

  final String? sessionId;

  void execute(final LiveEditContext context) {
    final sid = sessionId ?? context.sessionResource.value.activeSessionId;
    if (sid == null) return;

    final domain = context.sessionResource.value.targetDomain;
    final bubbleData = context.bubbleResource.value;
    final activeId = bubbleData.layerViewStateByDomain[domain]?.activeBubbleId;
    final bubble = activeId != null
        ? bubbleData.bubbleRecordsById[activeId]
        : null;
    final nodeIds = bubble?.nodeIds ?? const <String>[];

    context.sessionService.discardDraftNodes(sessionId: sid, nodeIds: nodeIds);
    context.applySessionUpdate(context.sessionService.lastUpdate);

    var newBubbleData = bubbleData.copyWith(
      applyPhase: LiveEditApplyPhase.idle,
      pendingExecutionPlan: null,
      pendingProposalId: null,
      pendingBubbleId: null,
      lastError: null,
    );

    if (activeId != null && bubble != null) {
      final records = Map<String, LiveEditBubbleRecord>.from(
        newBubbleData.bubbleRecordsById,
      );
      records[activeId] = bubble.copyWith(
        draftChanges: const <LiveEditDraftChange>[],
        status: LiveEditBubbleStatus.editing,
        changedFiles: const <String>[],
        executionPlan: null,
        lastError: null,
      );
      final resolvedBubbleIds = Set<String>.from(
        newBubbleData.resolvedBubbleIds,
      )..remove(activeId);
      newBubbleData = newBubbleData.copyWith(
        bubbleRecordsById: records,
        resolvedBubbleIds: resolvedBubbleIds,
      );
    }

    context.bubbleResource.value = newBubbleData;
  }
}
