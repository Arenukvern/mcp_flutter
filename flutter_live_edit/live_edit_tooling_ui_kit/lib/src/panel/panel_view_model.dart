import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

import '../bubble/bubble_view_model.dart';
import '../common/tooling_theme_data.dart';

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
    this.railActiveLabel,
    this.railStatusLabel = '',
    this.railActivityLabel = '',
    this.railHasBackendChoice = false,
    this.railBackendLabel = 'DBG',
    this.railDebugEnabled = false,
    this.railTargetDomain,
  });

  final ToolingPanelDisplayMode displayMode;
  final Offset placement;
  final double width;
  final double height;
  final LiveEditEditMode editMode;
  final ToolingThemeData? theme;
  final List<BubbleSummaryViewModel> railBubbleSummaries;
  final String? railActiveBubbleId;
  final String? railActiveLabel;
  final String railStatusLabel;
  final String railActivityLabel;
  final bool railHasBackendChoice;
  final String railBackendLabel;
  final bool railDebugEnabled;
  final LiveEditTargetDomain? railTargetDomain;
}
