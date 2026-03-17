import 'package:flutter/material.dart';
import 'package:live_edit_tooling_ui_kit/live_edit_tooling_ui_kit.dart';

import 'preview_fixtures.dart';

/// Dumb tool layer: bubble pills + panel rail built from fixture view models
/// and stub callbacks. No [LiveEditScope], no context, no commands.
/// Layer 1 – main surface for the playground.
class DumbToolLayer extends StatelessWidget {
  const DumbToolLayer({required this.viewportSize, super.key});

  final Size viewportSize;

  @override
  Widget build(final BuildContext context) {
    final bubbleViewModel = buildPreviewBubbleLayerViewModel(viewportSize);
    final panelViewModel = buildPreviewPanelViewModel(viewportSize);
    final bubbleCallbacks = PreviewBubbleCallbacks();
    final panelCallbacks = PreviewPanelCallbacks();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        ...bubbleViewModel.pinnedSummaries.map(
          (final summary) => PinnedBubblePill(
            summary: summary,
            viewportSize: viewportSize,
            callbacks: bubbleCallbacks,
            theme: bubbleViewModel.theme,
          ),
        ),
        Positioned(
          left: panelViewModel.placement.dx,
          top: panelViewModel.placement.dy,
          width: panelViewModel.width,
          height: panelViewModel.height,
          child: PanelRail(
            viewModel: panelViewModel,
            callbacks: panelCallbacks,
            bubbleCallbacks: bubbleCallbacks,
          ),
        ),
      ],
    );
  }
}
