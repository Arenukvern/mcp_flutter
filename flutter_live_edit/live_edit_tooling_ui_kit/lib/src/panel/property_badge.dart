import 'package:flutter/material.dart';

/// Badge with label and colors. [surfaceKey] wraps in KeyedSubtree when set.
class PropertyBadge extends StatelessWidget {
  const PropertyBadge({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.surfaceKey,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    this.cornerRadius = 6,
    super.key,
  });

  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Key? surfaceKey;
  final EdgeInsets padding;
  final double cornerRadius;

  @override
  Widget build(final BuildContext context) {
    final badge = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(cornerRadius),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
    return surfaceKey != null
        ? KeyedSubtree(key: surfaceKey!, child: badge)
        : badge;
  }
}
