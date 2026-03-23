import '../models/models.dart';
import '../types/live_edit_types.dart';

/// Result of [LiveEditApplyService.run]; Command applies this to Resources.
final class LiveEditApplyResult {
  const LiveEditApplyResult({
    required this.applyPhase,
    this.lastError,
    this.bubbleId,
    this.updatedBubbleRecord,
    this.sessionId,
    this.commitNodeIds,
    this.showAppliedPreviewChanges,
    this.pendingExecutionPlan,
    this.pendingProposalId,
    this.resolvedBubbleIdsAdd,
  });

  final LiveEditApplyPhase applyPhase;
  final String? lastError;
  final String? bubbleId;
  final LiveEditBubbleRecord? updatedBubbleRecord;
  final String? sessionId;
  final List<String>? commitNodeIds;
  final List<LiveEditDraftChange>? showAppliedPreviewChanges;
  final LiveEditExecutionPlan? pendingExecutionPlan;
  final String? pendingProposalId;
  final Set<String>? resolvedBubbleIdsAdd;
}
