import 'package:flutter/material.dart';
import 'package:flutter_live_edit_core/flutter_live_edit_core.dart';

/// Callbacks for panel UI; host wires these to commands.
abstract interface class PanelCallbacks {
  void onExpand();
  void onCollapse();
  void onResize(double width, double height);
  void onDrag(Offset delta);
  void onFocusProperty(String? propertyId);
  void onPropertyValueChanged(
    LiveEditPropertyDescriptor property,
    Object? value,
  );
  void onToggleDebugMode(bool enabled);
}
