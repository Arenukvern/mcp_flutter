import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

import 'src/property_descriptors.dart';
import 'src/property_panel_section.dart';

/// Plugin for optional direct property editing. Call [install] to enable
/// the Properties panel and per-widget property descriptors.
abstract final class LiveEditPropertyEditPlugin {
  LiveEditPropertyEditPlugin._();

  /// Sets the orchestrator's property descriptor provider and returns the
  /// panel section builder for [FlutterLiveEditHost.buildPropertyPanelSection].
  /// Call after the host has built (e.g. when [LiveEditOrchestrator.instance]
  /// is set).
  static LiveEditPropertyPanelSectionBuilder install() {
    final o = LiveEditOrchestrator.instance;
    if (o != null) o.propertyDescriptorProvider = buildPropertyDescriptors;
    return buildPropertyPanelSection;
  }
}
