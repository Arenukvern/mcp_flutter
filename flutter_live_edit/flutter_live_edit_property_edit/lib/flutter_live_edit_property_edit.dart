import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

import 'src/property_descriptors.dart';
import 'src/property_panel_section.dart';

/// Installs the direct property editing feature: sets the controller's
/// [LiveEditController.propertyDescriptorProvider] and returns the panel
/// section builder to pass to [FlutterLiveEditHost.buildPropertyPanelSection].
///
/// Usage:
/// ```dart
/// final buildPropertyPanelSection = LiveEditPropertyEditPlugin.install();
/// FlutterLiveEditHost(
///   orchestrator: orchestrator,
///   buildPropertyPanelSection: buildPropertyPanelSection,
///   child: ...,
/// )
/// ```
LiveEditPropertyPanelSectionBuilder install() {
  LiveEditController.instance.propertyDescriptorProvider = buildPropertyDescriptors;
  return buildPropertyPanelSection;
}
