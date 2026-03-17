import 'package:flutter/material.dart';

/// Drag handle bar (visual only).
class HandleBar extends StatelessWidget {
  const HandleBar({required this.width, super.key});

  final double width;

  @override
  Widget build(final BuildContext context) => Container(
    width: width,
    height: 3,
    decoration: BoxDecoration(
      color: const Color(0xFF94A3B8),
      borderRadius: BorderRadius.circular(999),
    ),
  );
}

/// Panel drag handle; triggers [onPanUpdate].
class PanelDragHandle extends StatelessWidget {
  const PanelDragHandle({required this.onPanUpdate, super.key});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => Semantics(
    identifier: 'live_edit_panel_drag_handle',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: const SizedBox(
        height: 18,
        child: Center(child: HandleBar(width: 34)),
      ),
    ),
  );
}

/// Panel resize handle; triggers [onPanUpdate].
class PanelResizeHandle extends StatelessWidget {
  const PanelResizeHandle({required this.onPanUpdate, super.key});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => Semantics(
    identifier: 'live_edit_panel_resize_handle',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: const Padding(
        padding: EdgeInsets.only(top: 6, left: 6),
        child: Icon(Icons.open_in_full, size: 14, color: Color(0xFF64748B)),
      ),
    ),
  );
}
