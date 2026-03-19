import 'package:flutter/material.dart';

/// Callbacks for panel UI; host wires these to commands.
abstract interface class PanelCallbacks {
  void onExpand();
  void onCollapse();
  void onResize(double width, double height);
  void onDrag(Offset delta);
}
