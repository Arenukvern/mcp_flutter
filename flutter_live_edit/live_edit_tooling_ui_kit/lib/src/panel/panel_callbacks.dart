import 'package:flutter/material.dart';

/// Callbacks for panel UI; host wires these to commands.
abstract interface class PanelCallbacks {
  void onExpand();
  void onCollapse();
  void onResize(final double width, final double height);
  void onDrag(final Offset delta);
}
