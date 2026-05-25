import 'package:flutter/material.dart';

/// View type shared with macOS native factory and web `registerViewFactory`.
const String kShowcasePlatformViewType = 'showcase.platform.stub';

/// Placeholder when no platform-specific embed is available.
Widget showcasePlatformViewPlaceholder() => const Center(
  child: Text(
    'Platform view demo — macOS / web only',
    style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
  ),
);

/// Fallback panel for targets without a registered platform view implementation.
class ShowcasePlatformViewPanel extends StatelessWidget {
  const ShowcasePlatformViewPanel({super.key});

  static const String viewType = kShowcasePlatformViewType;

  @override
  Widget build(final BuildContext context) {
    return Semantics(
      identifier: 'platform_view_demo_panel',
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: showcasePlatformViewPlaceholder(),
      ),
    );
  }
}
