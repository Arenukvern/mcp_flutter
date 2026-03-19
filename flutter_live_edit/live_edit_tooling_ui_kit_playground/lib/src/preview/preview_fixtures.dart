import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';
import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

/// Preview theme: minimal keys and status colors/labels matching toolkit glue.
ToolingThemeData get previewTheme => ToolingThemeData(
  keyForSurface: (final String id) => ValueKey<String>(id),
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

/// Shared bubble summaries for both bubble layer and panel rail (consistent look).
List<BubbleSummaryViewModel> previewBubbleSummaries(final Size viewportSize) {
  const domain = LiveEditTargetDomain.appScene;
  final bounds1 = LiveEditBounds(
    left: 72,
    top: 84,
    right: 312,
    bottom: 132,
    width: 240,
    height: 48,
  );
  final bounds2 = LiveEditBounds(
    left: 72,
    top: 168,
    right: 372,
    bottom: 312,
    width: 300,
    height: 144,
  );
  final bounds3 = LiveEditBounds(
    left: 72,
    top: 352,
    right: 136,
    bottom: 772,
    width: 64,
    height: 420,
  );
  return <BubbleSummaryViewModel>[
    BubbleSummaryViewModel(
      bubbleId: 'preview-1',
      targetDomain: domain,
      targetKey: 'Container',
      nodeId: 'preview-1',
      label: 'Container',
      statusLabel: 'editing',
      active: true,
      displayState: LiveEditBubbleDisplayState.minimized,
      bounds: bounds1,
      sourceLabel: 'lib/main.dart:12',
    ),
    BubbleSummaryViewModel(
      bubbleId: 'preview-2',
      targetDomain: domain,
      targetKey: 'Text',
      nodeId: 'preview-2',
      label: 'Text',
      statusLabel: 'applied',
      active: false,
      displayState: LiveEditBubbleDisplayState.minimized,
      bounds: bounds2,
    ),
    BubbleSummaryViewModel(
      bubbleId: 'preview-3',
      targetDomain: domain,
      targetKey: 'Column',
      nodeId: 'preview-3',
      label: 'Column',
      statusLabel: 'editing',
      active: false,
      displayState: LiveEditBubbleDisplayState.minimized,
      bounds: bounds3,
    ),
  ];
}

/// Fixture [BubbleLayerViewModel] for the dumb surface (no context/commands).
BubbleLayerViewModel buildPreviewBubbleLayerViewModel(final Size viewportSize) {
  final summaries = previewBubbleSummaries(viewportSize);
  return BubbleLayerViewModel(
    viewportSize: viewportSize,
    pinnedSummaries: summaries,
    expandedSummaries: const <BubbleSummaryViewModel>[],
    activeBubbleId: 'preview-1',
    globalComposerText: '',
    applyPhaseLabel: 'idle',
    currentBackendLabel: 'GPT',
    activeBubbleDraftCount: 0,
    activeBubbleStatusLabel: 'editing',
    activeBubbleInstructionText: null,
    activeBubbleLastError: null,
    activeBubbleDragOffset: Offset.zero,
    theme: previewTheme,
  );
}

/// Fixture [PanelViewModel] for the dumb surface (rail only, no context).
PanelViewModel buildPreviewPanelRailViewModel(final Size viewportSize) {
  const panelWidth = 64.0;
  const panelHeight = 420.0;
  return PanelViewModel(
    displayMode: ToolingPanelDisplayMode.rail,
    placement: const Offset(72, 352),
    width: panelWidth,
    height: panelHeight,
    editMode: LiveEditEditMode.inspect,
    theme: previewTheme,
    railBubbleSummaries: previewBubbleSummaries(viewportSize),
    railActiveBubbleId: 'preview-1',
    railHasBackendChoice: false,
    railBackendLabel: 'G',
  );
}

/// Fixture [PanelViewModel] for expanded panel showcase.
PanelViewModel buildPreviewPanelExpandedViewModel(final Size viewportSize) =>
    PanelViewModel(
      displayMode: ToolingPanelDisplayMode.expanded,
      placement: const Offset(164, 352),
      width: 312,
      height: 420,
      editMode: LiveEditEditMode.ai,
      theme: previewTheme,
      railBubbleSummaries: previewBubbleSummaries(viewportSize),
      railActiveBubbleId: 'preview-2',
      railHasBackendChoice: false,
      railBackendLabel: 'G',
    );

/// Stub [BubbleCallbacks] for the dumb surface (no context/commands).
final class PreviewBubbleCallbacks implements BubbleCallbacks {
  @override
  void onSetActiveBubble(final String? bubbleId) {}

  @override
  void onApply(final String? bubbleId) {}

  @override
  void onResolve(final String? bubbleId) {}

  @override
  void onComposerChanged(final String value) {}

  @override
  void onDragBubble(final String bubbleId, final Offset delta) {}

  @override
  void onResizeBubble(final Size size) {}

  @override
  void onSubmitPrompt(final String text) {}

  @override
  void onBackendChanged(final String backendId) {}

  @override
  void onDragBubbleEnd(final String bubbleId) {}
}

/// Stub [PanelCallbacks] for the dumb surface (no context/commands).
final class PreviewPanelCallbacks implements PanelCallbacks {
  @override
  void onExpand() {}

  @override
  void onCollapse() {}

  @override
  void onResize(final double width, final double height) {}

  @override
  void onDrag(final Offset delta) {}
}
