import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import '../models/models.dart';
import '../types/live_edit_types.dart';
import '../ui_selectors/ui_selectors.dart';
import 'live_edit_apply_result.dart';

/// Runs the apply delegate and returns a result for Commands to apply to Resources.
final class LiveEditApplyService {
  LiveEditApplyService({this.applyDraftDelegate});

  final LiveEditApplyDraftDelegate? applyDraftDelegate;

  /// Calls the delegate with [request]. Returns a result describing updates
  /// for [BubbleResource] and any session follow-ups (commit, preview).
  Future<LiveEditApplyResult> run(
    final LiveEditApplyDraftRequest request, {
    final LiveEditBubbleRecord? currentBubbleRecord,
  }) async {
    if (applyDraftDelegate == null) {
      return const LiveEditApplyResult(
        applyPhase: LiveEditApplyPhase.failed,
        lastError: 'Apply transport is not configured for this host app.',
      );
    }
    try {
      final response = await applyDraftDelegate!(request);
      final error = _extractError(response);
      if (hasText(error)) {
        return LiveEditApplyResult(
          applyPhase: LiveEditApplyPhase.failed,
          lastError: error,
          bubbleId: request.effectiveBubbleId,
          updatedBubbleRecord: currentBubbleRecord?.copyWith(
            status: LiveEditBubbleStatus.failed,
            lastError: error,
          ),
        );
      }
      final executionPlan = _decodeExecutionPlan(response['executionPlan']);
      final executionResult = _decodeExecutionResult(
        response['executionResult'] ?? response['result'],
      );
      final proposalId = _extractProposalId(
        response,
        executionPlan: executionPlan,
        executionResult: executionResult,
      );
      if (!request.approve && executionPlan != null && executionResult == null) {
        final previewRecord = currentBubbleRecord?.copyWith(
          status: LiveEditBubbleStatus.needsApproval,
          displayState: LiveEditBubbleDisplayState.expanded,
          executionPlan: executionPlan,
          lastError: null,
        );
        return LiveEditApplyResult(
          applyPhase: LiveEditApplyPhase.awaitingApproval,
          bubbleId: request.effectiveBubbleId,
          updatedBubbleRecord: previewRecord,
          pendingExecutionPlan: executionPlan,
          pendingProposalId:
              proposalId ?? request.effectiveBubbleId ?? request.sessionId,
        );
      }
      final changedFiles =
          executionResult?.changedFiles ??
          executionPlan?.affectedFiles ??
          const <String>[];
      final updatedRecord = currentBubbleRecord?.copyWith(
        draftChanges: const <LiveEditDraftChange>[],
        status: LiveEditBubbleStatus.applied,
        displayState: LiveEditBubbleDisplayState.expanded,
        changedFiles: changedFiles,
        executionPlan: executionPlan,
        lastError: null,
      );
      return LiveEditApplyResult(
        applyPhase: LiveEditApplyPhase.success,
        bubbleId: request.effectiveBubbleId,
        updatedBubbleRecord: updatedRecord,
        sessionId: request.sessionId,
        commitNodeIds: updatedRecord?.nodeIds,
      );
    } on Exception catch (e) {
      return LiveEditApplyResult(
        applyPhase: LiveEditApplyPhase.failed,
        lastError: 'Apply failed: $e',
        bubbleId: request.effectiveBubbleId,
        updatedBubbleRecord: currentBubbleRecord?.copyWith(
          status: LiveEditBubbleStatus.failed,
          lastError: 'Apply failed: $e',
        ),
      );
    }
  }

  String? _extractError(final Map<String, Object?> response) {
    final error = response['error'];
    if (error is String && hasText(error)) return error;
    final message = response['message'];
    if (message is String && hasText(message)) return message;
    return null;
  }

  LiveEditExecutionPlan? _decodeExecutionPlan(final Object? value) {
    if (value is Map) {
      final normalized = value.map(
        (final key, final nested) => MapEntry('$key', nested),
      );
      return LiveEditExecutionPlan.fromJson(normalized);
    }
    return null;
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

  String? _extractProposalId(
    final Map<String, Object?> response, {
    required final LiveEditExecutionPlan? executionPlan,
    required final LiveEditDirectApplyResult? executionResult,
  }) {
    final topLevel = response['proposalId'];
    if (topLevel is String && hasText(topLevel)) {
      return topLevel.trim();
    }
    if (hasText(executionResult?.executionId)) {
      return executionResult!.executionId;
    }
    if (hasText(executionPlan?.proposalId)) {
      return executionPlan!.proposalId;
    }
    return null;
  }
}
