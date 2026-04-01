import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';
import 'package:path/path.dart' as p;

import '../../di_live_edit_context/live_edit_context.dart';
import '../../models/models.dart';
import '../../types/live_edit_types.dart';

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

    final result = await context.applyService.run(
      request,
      currentBubbleRecord: bubble,
    );

    final newData = context.bubbleResource.value;
    var nextData = newData.copyWith(
      applyPhase: result.applyPhase,
      lastError: result.lastError,
      pendingExecutionPlan:
          result.pendingExecutionPlan ?? newData.pendingExecutionPlan,
      pendingProposalId: result.pendingProposalId ?? newData.pendingProposalId,
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
