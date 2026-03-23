import 'package:flutter/material.dart';

import '../common/tooling_theme_data.dart';
import '../models/models.dart';

enum LiveEditBubbleDisplayState {
  expanded('expanded'),
  minimized('minimized');

  const LiveEditBubbleDisplayState(this.wireName);

  final String wireName;

  static LiveEditBubbleDisplayState fromWire(final Object? value) {
    final normalized = '$value'.trim().toLowerCase();
    return LiveEditBubbleDisplayState.values.firstWhere(
      (final state) => state.wireName == normalized,
      orElse: () => LiveEditBubbleDisplayState.expanded,
    );
  }
}

/// Summary for a single bubble (pinned or expanded). UI kit uses primitives
/// and core enums only; host maps from toolkit types.
final class BubbleSummaryViewModel {
  const BubbleSummaryViewModel({
    required this.bubbleId,
    required this.targetKey,
    required this.nodeId,
    required this.label,
    required this.statusLabel,
    required this.active,
    required this.displayState,
    this.bounds,
    this.sourceLabel,
    this.dragOffset = Offset.zero,
  });

  final String bubbleId;
  final String targetKey;
  final String nodeId;
  final String label;
  final String statusLabel;
  final bool active;
  final LiveEditBubbleDisplayState displayState;
  final LiveEditBounds? bounds;
  final String? sourceLabel;
  final Offset dragOffset;
}

/// View model for the full bubble layer (pinned pills + expanded bubbles).
final class BubbleLayerViewModel {
  const BubbleLayerViewModel({
    required this.viewportSize,
    required this.pinnedSummaries,
    required this.expandedSummaries,
    required this.theme,
    this.activeBubbleId,
    this.globalComposerText = '',
    this.applyPhaseLabel = 'idle',
    this.currentBackendLabel,
    this.activeBubbleDraftCount = 0,
    this.activeBubbleStatusLabel = 'editing',
    this.activeBubbleInstructionText,
    this.activeBubbleLastError,
    this.activeBubbleDragOffset = Offset.zero,
  });

  final Size viewportSize;
  final List<BubbleSummaryViewModel> pinnedSummaries;
  final List<BubbleSummaryViewModel> expandedSummaries;
  final String? activeBubbleId;
  final String globalComposerText;
  final String applyPhaseLabel;
  final String? currentBackendLabel;
  final int activeBubbleDraftCount;
  final String activeBubbleStatusLabel;
  final String? activeBubbleInstructionText;
  final String? activeBubbleLastError;
  final Offset activeBubbleDragOffset;
  final ToolingThemeData theme;
}
