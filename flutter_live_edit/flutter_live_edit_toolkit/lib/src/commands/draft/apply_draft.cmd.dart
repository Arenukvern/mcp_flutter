import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';
import 'package:path/path.dart' as p;

import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';
import '../../services/live_edit_apply_result.dart';
import '../../services/live_edit_worktree_service.dart';
import '../../types/live_edit_types.dart';
import '../in_flight/complete_in_flight_bubble.cmd.dart';
import '../in_flight/register_in_flight_bubble.cmd.dart';
import '../in_flight/unregister_in_flight_bubble.cmd.dart';

bool _hasText(final String? value) => value != null && value.trim().isNotEmpty;

/// Builds request from context, calls ApplyService, applies result to BubbleResource.
final class ApplyDraftCommand {
  ApplyDraftCommand({
    this.bubbleId,
    this.message,
    this.approve = false,
    this.applyMode = LiveEditApplyMode.singleBubble,
    this.workingDirectory,
    this.intentText,
    this.globalBackendId,
  });

  final String? bubbleId;
  final String? message;
  final bool approve;
  final LiveEditApplyMode applyMode;
  final String? workingDirectory;
  final String? intentText;
  final String? globalBackendId;

  Future<void> execute(final LiveEditContext context) async {
    final sessionId = context.sessionResource.value.activeSessionId;
    if (sessionId == null) return;

    final domain = context.sessionResource.value.targetDomain;
    final bubbleData = context.bubbleResource.value;
    final activeId = bubbleData.layerViewStateByDomain[domain]?.activeBubbleId;
    final fallbackSelection = context.sessionService.selectionForDomain(
      targetDomain: domain,
      sessionId: sessionId,
    );
    final fallbackBubbleId = context.bubbleStateService.bubbleIdForSelection(
      context,
      fallbackSelection,
    );
    final bid = bubbleId ?? activeId ?? fallbackBubbleId;
    if (bid == null || bid.isEmpty) return;

    final bubble = bubbleData.bubbleRecordsById[bid];
    final selection = bubble?.primarySelection;
    final selectedWidgets =
        bubble?.selectedWidgets ?? const <LiveEditSelection>[];

    final resolvedIntent = _resolveIntent(
      message: message,
      instructionText: bubble?.instructionText,
      intentText: intentText,
    );
    if (!_hasText(resolvedIntent)) return;

    context.bubbleStateService.appendTimeline(
      context,
      role: 'user',
      message: resolvedIntent,
      nodeId: bid,
    );

    final backendId = bubble?.backendId?.trim().isNotEmpty == true
        ? bubble!.backendId
        : globalBackendId;

    final request = LiveEditApplyDraftRequest(
      sessionId: sessionId,
      bubbleId: bid,
      instructionText: resolvedIntent,
      primarySelection: selection,
      selectedWidgets: List<LiveEditSelection>.unmodifiable(selectedWidgets),
      sourceTargets: _sourceTargets(selectedWidgets, workingDirectory),
      applyMode: applyMode,
      backendId: backendId,
      inferenceConfig: bubble?.inferenceConfig,
      workingDirectory: workingDirectory,
      approve: approve,
      onEvent: context.applyEventSink != null
          ? (final e) => context.applyEventSink!(bid, e)
          : null,
    );

    context.bubbleResource.value = bubbleData.copyWith(
      applyPhase: LiveEditApplyPhase.preparing,
      lastError: null,
      pendingBubbleId: bid,
    );
    if (bubble != null) {
      final records = Map<String, LiveEditBubbleRecord>.from(
        context.bubbleResource.value.bubbleRecordsById,
      );
      records[bid] = bubble.copyWith(
        status: LiveEditBubbleStatus.waiting,
        displayState: LiveEditBubbleDisplayState.minimized,
        lastError: null,
      );
      context.bubbleResource.value = context.bubbleResource.value.copyWith(
        bubbleRecordsById: records,
      );
    }

    RegisterInFlightBubbleCommand(
      bubbleId: bid,
      targetPath: _inFlightTargetPath(selection),
      filePaths: _inFlightFilePaths(selectedWidgets, selection),
    ).execute(context);

    // Read back the just-registered record to see whether overlap was
    // detected; count other `running` bubbles to decide whether to route
    // this bubble through a worktree (isolates parallel writes).
    final inFlightSnapshot = context.inFlightResource.value;
    final selfRecord = inFlightSnapshot.recordsByBubbleId[bid];
    final overlap =
        selfRecord?.status == LiveEditInFlightStatus.blockedOnOverlap;
    final runningCount = inFlightSnapshot.recordsByBubbleId.values
        .where(
          (final r) =>
              r.bubbleId != bid &&
              r.status == LiveEditInFlightStatus.running,
        )
        .length;
    final useWorktree = _canUseWorktree(context) &&
        shouldUseWorktree(
          inFlightCount: runningCount + 1,
          bubbleTargetsOverlap: overlap,
        );

    // If overlap was flagged but worktree isolation is about to carry the
    // bubble, flip status to `running` so the panel chip doesn't say
    // "blocked" while the agent is actively writing in its worktree, and
    // so `CompleteInFlightBubbleCommand`'s re-scan promotes the right
    // bubbles when this one finishes.
    if (useWorktree && overlap && selfRecord != null) {
      final updated = Map<String, LiveEditInFlightRecord>.from(
        inFlightSnapshot.recordsByBubbleId,
      );
      updated[bid] = selfRecord.copyWith(
        status: LiveEditInFlightStatus.running,
        meta: const <String, Object?>{},
      );
      context.inFlightResource.value = inFlightSnapshot.copyWith(
        recordsByBubbleId: Map<String, LiveEditInFlightRecord>.unmodifiable(
          updated,
        ),
      );
    }

    bool applySucceeded = false;
    try {
      final result = useWorktree
          ? await context.applyService.applyViaWorktree(
              request,
              worktreeService: context.worktreeService!,
              mainWorkingDirectory: context.mainWorkingDirectory!,
              currentBubbleRecord: bubble,
            )
          : await context.applyService.run(
              request,
              currentBubbleRecord: bubble,
            );
      applySucceeded = result.applyPhase == LiveEditApplyPhase.success;
      _applyResultToContext(context, result, bid);
    } finally {
      CompleteInFlightBubbleCommand(
        bubbleId: bid,
        success: applySucceeded,
      ).execute(context);
      // Clear completed record so a subsequent bubble targeting the same
      // widget doesn't see this one as a blocker. (Completed records are
      // kept momentarily for telemetry but removed once settled.)
      UnregisterInFlightBubbleCommand(bubbleId: bid).execute(context);
    }
  }

  bool _canUseWorktree(final LiveEditContext context) {
    final service = context.worktreeService;
    final main = context.mainWorkingDirectory?.trim();
    return service != null && main != null && main.isNotEmpty;
  }

  String? _inFlightTargetPath(final LiveEditSelection? selection) {
    final nodeId = selection?.nodeId.trim();
    if (nodeId != null && nodeId.isNotEmpty) return nodeId;
    final file = selection?.source?.file.trim();
    if (file != null && file.isNotEmpty) return file;
    return null;
  }

  List<String> _inFlightFilePaths(
    final List<LiveEditSelection> selectedWidgets,
    final LiveEditSelection? primary,
  ) {
    final files = <String>{};
    for (final s in selectedWidgets) {
      final f = s.source?.file.trim();
      if (f != null && f.isNotEmpty) files.add(f);
    }
    final primaryFile = primary?.source?.file.trim();
    if (primaryFile != null && primaryFile.isNotEmpty) files.add(primaryFile);
    return List<String>.unmodifiable(files);
  }

  void _applyResultToContext(
    final LiveEditContext context,
    final LiveEditApplyResult result,
    final String bid,
  ) {
    final newData = context.bubbleResource.value;
    final shouldKeepPending =
        result.applyPhase == LiveEditApplyPhase.awaitingApproval;
    var nextData = newData.copyWith(
      applyPhase: result.applyPhase,
      lastError: result.lastError,
      pendingExecutionPlan: shouldKeepPending
          ? (result.pendingExecutionPlan ?? newData.pendingExecutionPlan)
          : null,
      pendingProposalId: shouldKeepPending
          ? (result.pendingProposalId ?? newData.pendingProposalId)
          : null,
      pendingBubbleId: shouldKeepPending ? (result.bubbleId ?? bid) : null,
    );

    final targetId = result.bubbleId ?? bid;
    if (targetId.isNotEmpty && result.updatedBubbleRecord != null) {
      final records = Map<String, LiveEditBubbleRecord>.from(
        nextData.bubbleRecordsById,
      );
      records[targetId] = result.updatedBubbleRecord!;
      nextData = nextData.copyWith(bubbleRecordsById: records);
    }

    if (result.resolvedBubbleIdsAdd != null) {
      nextData = nextData.copyWith(
        resolvedBubbleIds: nextData.resolvedBubbleIds.union(
          result.resolvedBubbleIdsAdd!,
        ),
      );
    }

    if (result.applyPhase == LiveEditApplyPhase.success ||
        result.applyPhase == LiveEditApplyPhase.failed) {
      nextData = nextData.copyWith();
    }

    context.bubbleResource.value = nextData;
  }

  String _resolveIntent({
    required final String? message,
    required final String? instructionText,
    required final String? intentText,
  }) => (message?.trim().isNotEmpty == true)
      ? message!.trim()
      : (instructionText?.trim().isNotEmpty == true
            ? instructionText!.trim()
            : (intentText?.trim().isNotEmpty == true
                  ? intentText!.trim()
                  : ''));

  List<LiveEditSourceTarget> _sourceTargets(
    final List<LiveEditSelection> selections,
    final String? workspace,
  ) {
    final deduped = <String, LiveEditSourceTarget>{};
    for (final selection in selections) {
      final source = selection.source;
      if (!_hasText(source?.file)) continue;
      final absolutePath = source!.file;
      final workspacePath =
          _hasText(workspace) && p.isWithin(workspace!, absolutePath)
          ? p.relative(absolutePath, from: workspace)
          : null;
      deduped[workspacePath ?? absolutePath] = LiveEditSourceTarget(
        nodeId: selection.nodeId,
        widgetType: selection.widgetType,
        absolutePath: absolutePath,
        workspacePath: workspacePath,
        line: source.line,
        column: source.column,
      );
    }
    return deduped.values.toList(growable: false);
  }
}
