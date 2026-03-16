import 'package:flutter_live_edit_toolkit/flutter_live_edit_toolkit.dart';

import 'src/property_descriptors.dart';
import 'src/property_panel_section.dart';

/// Plugin for optional direct property editing. Call [install] to enable
/// the Properties panel and per-widget property descriptors.
abstract final class LiveEditPropertyEditPlugin {
  LiveEditPropertyEditPlugin._();

  /// Registers the property descriptor provider with the live-edit runtime.
  /// When the host or scope builds, [buildPropertyDescriptors] will be set on
  /// the session service. Returns the panel section builder for
  /// [FlutterLiveEditHost.buildPropertyPanelSection].
  static LiveEditPropertyPanelSectionBuilder install() {
    LiveEditRuntime.onSessionServiceCreated = (final service) {
      service.propertyDescriptorProvider = buildPropertyDescriptors;
    };
    return buildPropertyPanelSection;
  }
}
