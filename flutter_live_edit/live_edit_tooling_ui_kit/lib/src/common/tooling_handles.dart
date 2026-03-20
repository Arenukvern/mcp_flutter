import 'package:flutter/material.dart';

/// Drag-indicator bar (no gestures).
class ToolingDragBar extends StatelessWidget {
  const ToolingDragBar({
    required this.width,
    super.key,
    this.height = 3,
    this.color = const Color(0xFF94A3B8),
    this.borderRadius,
  });

  /// macOS-style lighter slab (used on AI bubble chrome).
  const ToolingDragBar.slab({
    required this.width,
    super.key,
    this.height = 4,
    this.color = const Color(0xFFCBD5E1),
    this.borderRadius = const BorderRadius.all(Radius.circular(2)),
  });

  final double width;
  final double height;
  final Color color;
  final BorderRadius? borderRadius;

  @override
  Widget build(final BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color,
      borderRadius: borderRadius ?? BorderRadius.circular(999),
    ),
  );
}

/// Full-width (or aligned) strip that forwards horizontal drags via [onPanUpdate].
class ToolingPanDragStrip extends StatelessWidget {
  const ToolingPanDragStrip({
    required this.onPanUpdate,
    required this.hitHeight,
    required this.indicator,
    super.key,
    this.semanticsIdentifier,
    this.alignment = Alignment.center,
    this.indicatorMargin = EdgeInsets.zero,
  });

  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final double hitHeight;
  final Widget indicator;
  final String? semanticsIdentifier;
  final Alignment alignment;
  final EdgeInsetsGeometry indicatorMargin;

  @override
  Widget build(final BuildContext context) {
    final strip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: SizedBox(
        height: hitHeight,
        child: Align(
          alignment: alignment,
          child: Padding(padding: indicatorMargin, child: indicator),
        ),
      ),
    );
    if (semanticsIdentifier == null) return strip;
    return Semantics(identifier: semanticsIdentifier, child: strip);
  }
}

/// Corner resize grip: pan updates only (caller applies width/height deltas).
class ToolingPanResizeCorner extends StatelessWidget {
  const ToolingPanResizeCorner({
    required this.onPanUpdate,
    required this.icon,
    super.key,
    this.semanticsIdentifier,
    this.iconSize = 14,
    this.iconColor = const Color(0xFF64748B),
    this.padding = const EdgeInsets.only(top: 6, left: 6),
    this.alignment,
  });

  final ValueChanged<DragUpdateDetails> onPanUpdate;
  final IconData icon;
  final String? semanticsIdentifier;
  final double iconSize;
  final Color iconColor;
  final EdgeInsetsGeometry padding;
  final Alignment? alignment;

  @override
  Widget build(final BuildContext context) {
    Widget grip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanUpdate: onPanUpdate,
      child: Padding(
        padding: padding,
        child: Icon(icon, size: iconSize, color: iconColor),
      ),
    );
    if (semanticsIdentifier != null) {
      grip = Semantics(identifier: semanticsIdentifier, child: grip);
    }
    return alignment != null ? Align(alignment: alignment!, child: grip) : grip;
  }
}
