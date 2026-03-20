import 'package:flutter/material.dart';

import '../common/tooling_handles.dart';

/// Panel drag handle; triggers [onPanUpdate].
class PanelDragHandle extends StatelessWidget {
  const PanelDragHandle({required this.onPanUpdate, super.key});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => ToolingPanDragStrip(
    semanticsIdentifier: 'live_edit_panel_drag_handle',
    onPanUpdate: onPanUpdate,
    hitHeight: 18,
    indicator: const ToolingDragBar(width: 34),
  );
}

/// Panel resize handle; triggers [onPanUpdate].
class PanelResizeHandle extends StatelessWidget {
  const PanelResizeHandle({required this.onPanUpdate, super.key});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => ToolingPanResizeCorner(
    semanticsIdentifier: 'live_edit_panel_resize_handle',
    onPanUpdate: onPanUpdate,
    icon: Icons.open_in_full,
  );
}
