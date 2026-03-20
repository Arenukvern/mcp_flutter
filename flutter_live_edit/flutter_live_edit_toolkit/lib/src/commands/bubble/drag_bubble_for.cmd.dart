import 'package:flutter/material.dart' show Offset;

import '../../di_live_edit_context/live_edit_context.dart';
import '../../types/live_edit_types.dart';

/// Adds [delta] to the given bubble's drag offset.
final class DragBubbleForCommand {
  DragBubbleForCommand({required this.bubbleId, required this.delta});

  final String bubbleId;
  final Offset delta;

  void execute(final LiveEditContext context) {
    if (delta == Offset.zero || bubbleId.isEmpty) return;
    final bubble = context.bubbleResource.value.bubbleRecordsById[bubbleId];
    if (bubble == null) return;
    final records = Map<String, LiveEditBubbleRecord>.from(
      context.bubbleResource.value.bubbleRecordsById,
    );
    records[bubbleId] = bubble.copyWith(
      bubbleDragOffset: bubble.bubbleDragOffset + delta,
    );
    context.bubbleResource.value = context.bubbleResource.value.copyWith(
      bubbleRecordsById: records,
    );
  }
}
