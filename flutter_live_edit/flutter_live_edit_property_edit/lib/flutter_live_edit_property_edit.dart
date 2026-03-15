import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

import 'src/property_descriptors.dart';
import 'src/property_panel_section.dart';

/// Plugin for optional direct property editing. Call [install] to enable
/// the Properties panel and per-widget property descriptors.
abstract final class LiveEditPropertyEditPlugin {
  LiveEditPropertyEditPlugin._();

  /// Sets the controller's [LiveEditController.propertyDescriptorProvider]
  /// and returns the panel section builder for
  /// [FlutterLiveEditHost.buildPropertyPanelSection].
  static LiveEditPropertyPanelSectionBuilder install() {
    LiveEditController.instance.propertyDescriptorProvider =
        buildPropertyDescriptors;
    return buildPropertyPanelSection;
  }
}
