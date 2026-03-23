import 'package:flutter/material.dart';
import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import '../commands/commands.dart';
import '../di_live_edit_context/live_edit_context.dart';
import '../di_live_edit_context/tools/live_edit_controller_adapter.dart';
import '../types/live_edit_types.dart';
import '../ui_selectors/ui_selectors.dart';
import '../ui_widgets/backend_switcher.dart';
import '../ui_workbench/live_edit_overlay_theme.dart';

String _bubbleStatusLabel(final LiveEditBubbleStatus status) =>
    switch (status) {
      LiveEditBubbleStatus.editing => 'editing',
      LiveEditBubbleStatus.waiting => 'waiting',
      LiveEditBubbleStatus.needsApproval => 'needsApproval',
      LiveEditBubbleStatus.applied => 'applied',
      LiveEditBubbleStatus.failed => 'failed',
    };

String _applyPhaseLabel(final LiveEditApplyPhase phase) => switch (phase) {
  LiveEditApplyPhase.idle => 'idle',
  LiveEditApplyPhase.preparing => 'preparing',
  LiveEditApplyPhase.awaitingApproval => 'awaitingApproval',
  LiveEditApplyPhase.applying => 'applying',
  LiveEditApplyPhase.success => 'success',
  LiveEditApplyPhase.failed => 'failed',
};

const int _kMaxPinnedPills = 32;
const int _kMaxRailBubbles = 64;

BubbleSummaryViewModel _summaryToViewModel(
  final LiveEditContext ctx,
  final LiveEditBubbleSummary s,
) => BubbleSummaryViewModel(
  bubbleId: s.bubbleId,
  targetKey: s.targetKey,
  nodeId: s.nodeId,
  label: s.label,
  statusLabel: _bubbleStatusLabel(s.status),
  active: s.active,
  displayState: s.displayState,
  bounds: s.bounds,
  sourceLabel: s.sourceLabel,
  dragOffset: selectBubbleDragOffset(ctx, s.bubbleId),
);

bool _hasBackendChoice(final LiveEditContext ctx) =>
    ctx.backendConfigResource.value.availableBackends.length > 1;

/// Builds [BubbleLayerViewModel] from [LiveEditContext] and selectors.
BubbleLayerViewModel buildBubbleLayerViewModel(
  final LiveEditContext context,
  final LiveEditController controller,
  final Size viewportSize,
  final ToolingThemeData theme,
) {
  final presentationDomain = selectPresentedLayer(context);
  final sessionId = context.sessionResource.value.activeSessionId;
  final pinned = selectPinnedBubbleSummaries(
    context,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final expanded = selectExpandedBubbleSummaries(
    context,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final activeBubbleId = selectActiveBubbleId(
    context,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final bubbleData = context.bubbleResource.value;
  final activeRecord = activeBubbleId != null
      ? bubbleData.bubbleRecordsById[activeBubbleId]
      : null;
  final applyPhase = selectApplyPhase(context);
  final backendLabel = selectCurrentBackendLabel(
    context,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  return BubbleLayerViewModel(
    viewportSize: viewportSize,
    pinnedSummaries: pinned
        .take(_kMaxPinnedPills)
        .map((final s) => _summaryToViewModel(context, s))
        .toList(),
    expandedSummaries: expanded
        .map((final s) => _summaryToViewModel(context, s))
        .toList(),
    activeBubbleId: activeBubbleId,
    globalComposerText: bubbleData.globalComposerText,
    applyPhaseLabel: _applyPhaseLabel(applyPhase),
    currentBackendLabel: backendLabel,
    activeBubbleDraftCount: activeRecord?.draftChanges.length ?? 0,
    activeBubbleStatusLabel: activeRecord != null
        ? _bubbleStatusLabel(activeRecord.status)
        : 'editing',
    activeBubbleInstructionText: activeRecord?.instructionText,
    activeBubbleLastError: activeRecord?.lastError ?? bubbleData.lastError,
    activeBubbleDragOffset: selectBubbleDragOffset(context, activeBubbleId),
    theme: theme,
  );
}

/// Builds [PanelViewModel] for the tool layer (rail or expanded) from context.
PanelViewModel buildPanelViewModel(
  final LiveEditContext context,
  final LiveEditController controller,
  final Size viewportSize,
  final ToolingThemeData? theme,
) {
  final panelExpanded = selectPanelExpanded(context);
  final presentationDomain = selectPresentedLayer(context);
  final sessionId = context.sessionResource.value.activeSessionId;
  final railSummaries = selectBubbleSummaries(
    context,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final activeBubbleId = selectActiveBubbleId(
    context,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final backendLabel = selectCurrentBackendLabel(
    context,
    controller,
    presentationDomain: presentationDomain,
    sessionId: sessionId,
  );
  final placement = selectPanelPlacement(context, viewportSize);
  final hasBackendChoice = _hasBackendChoice(context);
  return PanelViewModel(
    displayMode: panelExpanded
        ? ToolingPanelDisplayMode.expanded
        : ToolingPanelDisplayMode.rail,
    placement: placement,
    width: selectPanelWidth(context),
    height: selectPanelHeight(context),
    editMode: context.panelViewResource.value.editMode,
    theme: theme,
    railBubbleSummaries: railSummaries
        .take(_kMaxRailBubbles)
        .map((final s) => _summaryToViewModel(context, s))
        .toList(),
    railActiveBubbleId: activeBubbleId,
    railHasBackendChoice: hasBackendChoice,
    railBackendLabel: hasBackendChoice
        ? (hasText(backendLabel)
              ? backendLabel!.substring(0, 1).toUpperCase()
              : 'DBG')
        : 'DBG',
    railBackendSwitcherChild: hasBackendChoice
        ? BackendSwitcher(context: context, controller: controller, rail: true)
        : null,
  );
}

/// Builds [ToolingThemeData] using toolkit overlay theme.
ToolingThemeData buildToolingThemeData() {
  final overlay = LiveEditOverlayThemeModel.instance;
  return ToolingThemeData(
    keyForSurface: overlay.keyFor,
    statusColors: const <String, Color>{
      'editing': Color(0xFF0F766E),
      'waiting': Color(0xFF1D4ED8),
      'needsApproval': Color(0xFF92400E),
      'applied': Color(0xFF166534),
      'failed': Color(0xFFB91C1C),
    },
    statusLabels: const <String, String>{
      'editing': 'Draft ready',
      'waiting': 'Applying',
      'needsApproval': 'Applying',
      'applied': 'Applied',
      'failed': 'Failed',
    },
  );
}

/// [BubbleCallbacks] that forward to toolkit commands.
final class ToolLayerBubbleCallbacks implements BubbleCallbacks {
  ToolLayerBubbleCallbacks({required this.context, required this.controller});

  final LiveEditContext context;
  final LiveEditController controller;

  @override
  void onSetActiveBubble(final String? bubbleId) {
    if (bubbleId == null || bubbleId.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SelectTrackedBubbleCommand(
        bubbleId: bubbleId,
        controller: controller,
      ).execute(context);
    });
  }

  @override
  void onApply(final String? bubbleId) =>
      ApplyDraftCommand(bubbleId: bubbleId).execute(context);

  @override
  void onResolve(final String? bubbleId) =>
      ResolveActiveBubbleCommand().execute(context);

  @override
  void onComposerChanged(final String value) {
    final activeId = context
        .bubbleResource
        .value
        .layerViewStateByDomain[context.sessionResource.value.targetDomain]
        ?.activeBubbleId;
    if (activeId == null || activeId.isEmpty) return;
    UpdateBubbleComposerCommand(
      bubbleId: activeId,
      value: value,
    ).execute(context);
  }

  @override
  void onDragBubble(final String bubbleId, final Offset delta) =>
      DragBubbleForCommand(bubbleId: bubbleId, delta: delta).execute(context);

  @override
  void onResizeBubble(final Size size) {}

  @override
  void onSubmitPrompt(final String text) => SubmitAiPromptCommand(
    controller: controller,
    intentText: text,
  ).execute(context);

  @override
  void onBackendChanged(final String backendId) =>
      SetBackendCommand(backendId: backendId).execute(context);

  @override
  void onDragBubbleEnd(final String bubbleId) {}
}

// ── Chat bubble glue ────────────────────────────────────────────────────

ChatMessageRole _timelineRoleToChatRole(final String role) => switch (role) {
  'user' => ChatMessageRole.user,
  'debug' => ChatMessageRole.thinking,
  _ => ChatMessageRole.assistant,
};

/// Builds [ChatBubbleViewModel] from toolkit state for a specific bubble.
ChatBubbleViewModel buildChatBubbleViewModel(
  final LiveEditContext ctx,
  final LiveEditController controller, {
  final String? bubbleId,
}) {
  final presentationDomain = selectPresentedLayer(ctx);
  final sessionId = ctx.sessionResource.value.activeSessionId;
  final mergedTimeline = selectMergedTimelineForBubble(ctx, bubbleId);
  final backends = ctx.backendConfigResource.value.availableBackends;
  final activeBackendId =
      (bubbleId != null
          ? selectBackendIdForBubble(ctx, bubbleId)
          : selectCurrentBackendId(
              ctx,
              controller,
              presentationDomain: presentationDomain,
              sessionId: sessionId,
            )) ??
      '';
  final inputText = bubbleId != null
      ? selectInstructionTextForBubble(ctx, bubbleId)
      : ctx.bubbleResource.value.globalComposerText;
  final busy = selectIsApplyingBusy(ctx);
  final canApply = bubbleId != null
      ? (selectCanTriggerApplyForBubble(
              ctx,
              controller,
              bubbleId,
              presentationDomain: presentationDomain,
              sessionId: sessionId,
            ) &&
            !busy)
      : (selectCanTriggerApply(
              ctx,
              controller,
              presentationDomain: presentationDomain,
              sessionId: sessionId,
            ) &&
            !busy);
  final draftCount = bubbleId != null
      ? (selectBubbleRecord(ctx, bubbleId)?.draftChanges.length ?? 0)
      : selectDraftChangesForDomain(
          ctx,
          controller,
          domain: presentationDomain,
          sessionId: sessionId,
        ).length;
  final canApplyAll = selectCanApplyAllBubbles(ctx);
  final applyAllCount = selectPendingBubbleCount(ctx);
  final record = bubbleId != null ? selectBubbleRecord(ctx, bubbleId) : null;
  final activeId =
      bubbleId ??
      selectActiveBubbleId(
        ctx,
        controller,
        presentationDomain: presentationDomain,
        sessionId: sessionId,
      );
  final status = selectBubbleStatusForBubble(ctx, activeId);
  final plan = bubbleId != null
      ? selectExecutionPlanForBubble(ctx, bubbleId)
      : selectPendingExecutionPlan(ctx);
  final summary = bubbleId != null
      ? ((record?.instructionText ?? '').trim().isNotEmpty
            ? 'Applied live-edit changes.'
            : null)
      : selectCurrentActivity(
          ctx,
          controller,
          presentationDomain: presentationDomain,
          sessionId: sessionId,
        )?.summary;
  final filesSuffix = plan != null
      ? plan.affectedFiles.join(', ')
      : 'Source updated.';
  final appliedSummary = status == LiveEditBubbleStatus.applied
      ? '${summary ?? 'Applied live-edit changes.'} $filesSuffix'
      : null;
  return ChatBubbleViewModel(
    messages: mergedTimeline
        .map(
          (final e) => ChatMessage(
            role: _timelineRoleToChatRole(e.role),
            text: e.message,
            timestamp: e.timestamp,
          ),
        )
        .toList(growable: false),
    backends: backends
        .map((final b) => (id: b.id, label: b.label))
        .toList(growable: false),
    activeBackendId: activeBackendId,
    showThinking: selectDebugModeEnabled(ctx),
    inputText: inputText,
    isBusy: busy,
    canDiscard: canApply,
    canApplyAll: canApplyAll,
    applyAllCount: applyAllCount,
    draftCount: draftCount,
    appliedSummary: appliedSummary,
  );
}

/// [ChatBubbleCallbacks] that forward to toolkit commands.
final class ToolLayerChatBubbleCallbacks implements ChatBubbleCallbacks {
  ToolLayerChatBubbleCallbacks({
    required this.context,
    required this.controller,
    this.bubbleId,
  });

  final LiveEditContext context;
  final LiveEditController controller;
  final String? bubbleId;

  @override
  Future<void> onSend(final String text) async {
    if (bubbleId != null) {
      await ApplyDraftForBubbleCommand(
        bubbleId: bubbleId!,
        message: text,
        globalBackendId: context.backendConfigResource.value.globalBackendId,
      ).execute(context);
    } else {
      await SubmitAiPromptCommand(
        controller: controller,
        intentText: text,
      ).execute(context);
    }
  }

  @override
  void onInputChanged(final String value) {
    if (bubbleId != null) {
      UpdateBubbleComposerCommand(
        bubbleId: bubbleId!,
        value: value,
      ).execute(context);
    } else {
      UpdateAiComposerCommand(value: value).execute(context);
    }
  }

  @override
  void onBackendChanged(final String backendId) {
    if (bubbleId != null) {
      SetBubbleBackendCommand(
        bubbleId: bubbleId!,
        backendId: backendId,
      ).execute(context);
    } else {
      SetBackendCommand(backendId: backendId).execute(context);
    }
  }

  @override
  void onToggleThinking(final bool enabled) =>
      SetDebugModeCommand(enabled: enabled).execute(context);

  @override
  void onCollapse() {
    final bid =
        bubbleId ??
        context
            .bubbleResource
            .value
            .layerViewStateByDomain[context.sessionResource.value.targetDomain]
            ?.activeBubbleId;
    if (bid == null || bid.isEmpty) return;
    HideBubbleCommand(bubbleId: bid).execute(context);
  }

  @override
  void onDone() => ResolveActiveBubbleCommand().execute(context);

  @override
  void onDiscard() => UndoDraftCommand().execute(context);

  @override
  void onApplyAll(final int count) => ApplyAllBubblesCommand().execute(context);
}

/// [PanelCallbacks] that forward to toolkit commands.
final class ToolLayerPanelCallbacks implements PanelCallbacks {
  ToolLayerPanelCallbacks({required this.context});

  final LiveEditContext context;

  @override
  void onExpand() => ExpandPanelCommand().execute(context);

  @override
  void onCollapse() => CollapsePanelCommand().execute(context);

  @override
  void onResize(final double width, final double height) =>
      ResizePanelCommand(width: width, height: height).execute(context);

  @override
  void onDrag(final Offset delta) =>
      DragPanelCommand(delta: delta).execute(context);
}
