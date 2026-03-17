import 'package:flutter/material.dart';

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
  Widget build(final BuildContext context) => Semantics(
    identifier: semanticsId,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: SizedBox(
        height: 12,
        child: Align(
          alignment: alignment,
          child: Container(
            width: 28,
            height: 3,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF94A3B8),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Bubble resize handle; triggers [onPanUpdate].
class BubbleResizeHandle extends StatelessWidget {
  const BubbleResizeHandle({required this.onPanUpdate, super.key});

  final ValueChanged<DragUpdateDetails> onPanUpdate;

  @override
  Widget build(final BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onPanUpdate: onPanUpdate,
    child: const Padding(
      padding: EdgeInsets.only(top: 6, left: 6),
      child: Icon(Icons.open_in_full, size: 14, color: Color(0xFF64748B)),
    ),
  );
}
