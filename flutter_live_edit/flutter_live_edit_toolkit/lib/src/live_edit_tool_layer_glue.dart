import 'package:flutter/material.dart';
import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import 'commands/commands.dart';
import 'live_edit_context.dart';
import 'live_edit_controller_adapter.dart';
import 'live_edit_overlay_theme.dart';
import 'live_edit_types.dart';
import 'selectors/live_edit_selectors.dart';

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

BubbleSummaryViewModel _summaryToViewModel(
  final LiveEditContext ctx,
  final LiveEditBubbleSummary s,
) => BubbleSummaryViewModel(
  bubbleId: s.bubbleId,
  targetDomain: s.targetDomain,
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
  final activeSelection = selectSelectionForDomain(
    context,
    controller,
    domain: presentationDomain,
    sessionId: sessionId,
  );
  final bubbleStatus = selectBubbleStatusForBubble(context, activeBubbleId);
  final currentActivity = selectCurrentActivity(
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
        .map((final s) => _summaryToViewModel(context, s))
        .toList(),
    railActiveBubbleId: activeBubbleId,
    railActiveLabel: activeSelection?.widgetType,
    railStatusLabel: _bubbleStatusLabel(bubbleStatus),
    railActivityLabel:
        currentActivity?.label ?? _bubbleStatusLabel(bubbleStatus),
    railHasBackendChoice: _hasBackendChoice(context),
    railBackendLabel: _hasBackendChoice(context)
        ? (backendLabel.isNotEmpty
              ? backendLabel.substring(0, 1).toUpperCase()
              : 'DBG')
        : 'DBG',
    railDebugEnabled: selectDebugModeEnabled(context),
    railTargetDomain: selectTargetDomain(context),
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
    SelectTrackedBubbleCommand(
      bubbleId: bubbleId,
      controller: controller,
    ).execute(context);
  }

  @override
  void onApply(final String? bubbleId) =>
      ApplyDraftCommand(bubbleId: bubbleId).execute(context);

  @override
  void onResolve(final String? bubbleId) =>
      ResolveActiveBubbleCommand().execute(context);

  @override
  void onComposerChanged(final String value) => UpdateBubbleComposerCommand(
    bubbleId:
        context
            .bubbleResource
            .value
            .layerViewStateByDomain[context.sessionResource.value.targetDomain]
            ?.activeBubbleId ??
        '',
    value: value,
  ).execute(context);

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

  @override
  void onToggleDebugMode(final bool enabled) =>
      SetDebugModeCommand(enabled: enabled).execute(context);
}
