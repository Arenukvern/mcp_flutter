import 'package:flutter/material.dart';

import '../common/tooling_handles.dart';

/// Bubble drag handle; triggers [onPanUpdate]. [alignment] for the bar.
class BubbleDragHandle extends StatelessWidget {
  const BubbleDragHandle({
    required this.alignment,
    required this.onPanUpdate,
    this.semanticsId = 'live_edit_bubble_drag_handle',
    super.key,
  });

  final Alignment alignment;
  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final String semanticsId;

  @override
  Widget build(final BuildContext context) => ToolingPanDragStrip(
    semanticsIdentifier: semanticsId,
    onPanUpdate: onPanUpdate,
    hitHeight: 12,
    alignment: alignment,
    indicatorMargin: const EdgeInsets.only(bottom: 8),
    indicator: const ToolingDragBar(width: 28),
  );
}

/// Bubble resize handle; triggers [onPanUpdate].
class BubbleResizeHandle extends StatelessWidget {
  const BubbleResizeHandle({required this.onPanUpdate, super.key});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => ToolingPanResizeCorner(
    onPanUpdate: onPanUpdate,
    icon: Icons.open_in_full,
  );
}
