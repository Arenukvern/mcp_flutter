import 'package:flutter/material.dart';

import 'panel_callbacks.dart';
import 'panel_rail.dart';
import 'panel_view_model.dart';
import '../bubble/bubble_callbacks.dart';

/// Panel surface: rail or expanded content. Uses [viewModel].displayMode.
/// [expandedChild] shown when expanded; otherwise [PanelRail].
class PanelSurface extends StatelessWidget {
  const PanelSurface({
    required this.viewModel,
    required this.callbacks,
    required this.bubbleCallbacks,
    required this.expandedChild,
    super.key,
  });

  final PanelViewModel viewModel;
  final PanelCallbacks callbacks;
  final BubbleCallbacks bubbleCallbacks;
  final Widget expandedChild;

  @override
  Widget build(final BuildContext context) {
    return viewModel.displayMode == ToolingPanelDisplayMode.expanded
        ? expandedChild
        : PanelRail(
            viewModel: viewModel,
            callbacks: callbacks,
            bubbleCallbacks: bubbleCallbacks,
          );
  }
}
