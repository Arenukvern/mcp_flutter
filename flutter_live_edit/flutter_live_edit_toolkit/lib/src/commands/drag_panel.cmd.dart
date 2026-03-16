import 'package:flutter/material.dart' show Offset;

import '../live_edit_context.dart';

/// Updates panel drag offset.
final class DragPanelCommand {
  DragPanelCommand({required this.delta});

  final Offset delta;

  void execute(final LiveEditContext context) {
    final current = context.panelViewResource.value.panelDragOffset;
    context.panelViewResource.value = context.panelViewResource.value
        .copyWith(panelDragOffset: current + delta);
  }
}
