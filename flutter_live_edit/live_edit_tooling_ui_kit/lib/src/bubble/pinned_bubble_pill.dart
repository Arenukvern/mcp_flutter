import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../common/tooling_theme_data.dart';
import 'bubble_callbacks.dart';
import 'bubble_view_model.dart';

/// Pinned bubble pill; tap selects the bubble. Uses view model + callbacks only.
class PinnedBubblePill extends StatelessWidget {
  const PinnedBubblePill({
    required this.summary,
    required this.viewportSize,
    required this.callbacks,
    required this.theme,
    super.key,
  });

  final BubbleSummaryViewModel summary;
  final Size viewportSize;
  final BubbleCallbacks callbacks;
  final ToolingThemeData theme;

  @override
  Widget build(final BuildContext context) {
    final bounds = summary.bounds;
    if (bounds == null) return const SizedBox.shrink();
    final left = clampDouble(bounds.right + 6, 8, viewportSize.width - 28);
    final top = clampDouble(bounds.top, 8, viewportSize.height - 28);
    final color = theme.statusColor(summary.statusLabel);
    return Positioned(
      left: left,
      top: top,
      child: Semantics(
        identifier: 'live_edit_pinned_bubble_${summary.nodeId}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => callbacks.onSetActiveBubble(summary.bubbleId),
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
