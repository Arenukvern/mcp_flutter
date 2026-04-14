import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import '../models/models.dart';
import '../types/live_edit_types.dart';
import '../ui_selectors/ui_selectors.dart';
import 'live_edit_apply_result.dart';
import 'live_edit_worktree_service.dart';

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

  /// Worktree-routed variant of [run].
  ///
  /// Allocates (or reuses) a worktree for [request.bubbleId] via
  /// [worktreeService], rewrites the request's `workingDirectory` to the
  /// worktree path, invokes the apply delegate there, then merges the
  /// resulting branch back into [mainWorkingDirectory].
  ///
  /// Decision policy: callers should use [shouldUseWorktree] to decide
  /// whether to route through this method or the plain [run] — single
  /// in-flight bubbles stay on the main tree for instant hot reload.
  ///
  /// Merge conflicts are NOT resolved here. On a conflict the underlying
  /// apply result is still returned (writes succeeded in the worktree),
  /// with [LiveEditApplyResult.lastError] populated so the orchestrator
  /// can surface it. The worktree is NOT abandoned on conflict so a user
  /// can inspect it; callers own cleanup.
  Future<LiveEditApplyResult> applyViaWorktree(
    final LiveEditApplyDraftRequest request, {
    required final LiveEditWorktreeService worktreeService,
    required final String mainWorkingDirectory,
    final LiveEditBubbleRecord? currentBubbleRecord,
  }) async {
    final bubbleId = request.effectiveBubbleId ?? request.sessionId;
    final LiveEditWorktreeHandle handle;
    try {
      handle = await worktreeService.allocate(
        bubbleId: bubbleId,
        mainWorkingDirectory: mainWorkingDirectory,
      );
    } on Exception catch (e) {
      return LiveEditApplyResult(
        applyPhase: LiveEditApplyPhase.failed,
        lastError: 'Worktree allocation failed: $e',
        bubbleId: request.effectiveBubbleId,
        updatedBubbleRecord: currentBubbleRecord?.copyWith(
          status: LiveEditBubbleStatus.failed,
          lastError: 'Worktree allocation failed: $e',
        ),
      );
    }

    final rerouted = _withWorkingDirectory(request, handle.worktreePath);
    final applyResult = await run(
      rerouted,
      currentBubbleRecord: currentBubbleRecord,
    );

    if (applyResult.applyPhase != LiveEditApplyPhase.success) {
      // Preview/approval, failure, etc. — no commits to merge yet.
      return applyResult;
    }

    final merge = await worktreeService.mergeInto(
      handle: handle,
      mainWorkingDirectory: mainWorkingDirectory,
    );
    // Freezed 3.x generates an abstract (non-sealed) base class, so the
    // analyzer can't prove exhaustiveness of a switch expression. Use
    // explicit type checks instead.
    if (merge is LiveEditMergeResultClean) {
      // Clean merge: reclaim the worktree. Swallow abandon errors — the
      // apply itself succeeded and a stale worktree is recoverable.
      try {
        await worktreeService.abandon(handle);
      } on Object {
        // best-effort cleanup
      }
      return applyResult;
    }
    if (merge is LiveEditMergeResultConflict) {
      // Leave worktree in place so the user (or a retry pass) can inspect.
      return _withError(
        applyResult,
        'Merge conflict in ${merge.files.length} file(s): '
        '${merge.files.join(', ')}',
      );
    }
    if (merge is LiveEditMergeResultFailed) {
      return _withError(applyResult, 'Merge failed: ${merge.stderr}');
    }
    return applyResult;
  }

  LiveEditApplyResult _withError(
    final LiveEditApplyResult base,
    final String error,
  ) => LiveEditApplyResult(
    applyPhase: base.applyPhase,
    lastError: error,
    bubbleId: base.bubbleId,
    updatedBubbleRecord: base.updatedBubbleRecord?.copyWith(
      status: LiveEditBubbleStatus.failed,
      lastError: error,
    ),
    sessionId: base.sessionId,
    commitNodeIds: base.commitNodeIds,
    showAppliedPreviewChanges: base.showAppliedPreviewChanges,
    pendingExecutionPlan: base.pendingExecutionPlan,
    pendingProposalId: base.pendingProposalId,
    resolvedBubbleIdsAdd: base.resolvedBubbleIdsAdd,
  );

  /// Returns a copy of [request] with [workingDirectory] swapped in.
  LiveEditApplyDraftRequest _withWorkingDirectory(
    final LiveEditApplyDraftRequest request,
    final String workingDirectory,
  ) => LiveEditApplyDraftRequest(
    sessionId: request.sessionId,
    bubbleId: request.bubbleId,
    instructionText: request.instructionText,
    primarySelection: request.primarySelection,
    selectedWidgets: request.selectedWidgets,
    sourceTargets: request.sourceTargets,
    applyMode: request.applyMode,
    backendId: request.backendId,
    inferenceConfig: request.inferenceConfig,
    workingDirectory: workingDirectory,
    approve: request.approve,
    onEvent: request.onEvent,
  );

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
