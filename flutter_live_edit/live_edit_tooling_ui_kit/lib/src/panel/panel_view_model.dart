import 'package:flutter/material.dart';

import '../bubble/bubble_view_model.dart';
import '../common/tooling_theme_data.dart';
import '../models/models.dart';

/// Display mode for the tooling panel (rail vs expanded).
enum ToolingPanelDisplayMode { rail, expanded }

/// View model for the tooling panel (rail + expanded surface).
final class PanelViewModel {
  const PanelViewModel({
    required this.displayMode,
    required this.placement,
    required this.width,
    required this.height,
    required this.editMode,
    this.theme,
    this.railBubbleSummaries = const <BubbleSummaryViewModel>[],
    this.railActiveBubbleId,
    this.railHasBackendChoice = false,
    this.railBackendLabel = 'DBG',
    this.railBackendSwitcherChild,
  });

  final ToolingPanelDisplayMode displayMode;
  final Offset placement;
  final double width;
  final double height;
  final LiveEditEditMode editMode;
  final ToolingThemeData? theme;
  final List<BubbleSummaryViewModel> railBubbleSummaries;
  final String? railActiveBubbleId;
  final bool railHasBackendChoice;
  final String railBackendLabel;

  /// Injected by host when multiple backends; replaces read-only label.
  final Widget? railBackendSwitcherChild;
}
