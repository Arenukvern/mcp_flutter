import 'package:flutter/material.dart' show Offset;

import '../live_edit_context.dart';
import '../live_edit_types.dart';

/// Adds [delta] to the active bubble's drag offset.
final class DragBubbleCommand {
  DragBubbleCommand({required this.delta});

  final Offset delta;

  void execute(final LiveEditContext context) {
    if (delta == Offset.zero) return;
    final domain = context.sessionResource.value.targetDomain;
    final bubbleData = context.bubbleResource.value;
    final activeId =
        bubbleData.layerViewStateByDomain[domain]?.activeBubbleId;
    if (activeId == null) return;
    final bubble = bubbleData.bubbleRecordsById[activeId];
    if (bubble == null) return;
    final records = Map<String, LiveEditBubbleRecord>.from(
      bubbleData.bubbleRecordsById,
    );
    records[activeId] = bubble.copyWith(
      bubbleDragOffset: bubble.bubbleDragOffset + delta,
    );
    context.bubbleResource.value = bubbleData.copyWith(
      bubbleRecordsById: records,
    );
  }
}
