import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// macOS-only native panel for platform-view capture routing demos.
class ShowcasePlatformViewPanel extends StatelessWidget {
  const ShowcasePlatformViewPanel({super.key});

  static const String viewType = 'showcase.platform.stub';

  @override
  Widget build(final BuildContext context) {
    return Semantics(
      identifier: 'platform_view_demo_panel',
      child: SizedBox(
        height: 48,
        width: double.infinity,
        child: defaultTargetPlatform == TargetPlatform.macOS
            ? const AppKitView(
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: <String, dynamic>{},
                creationParamsCodec: StandardMessageCodec(),
              )
            : const Center(
                child: Text(
                  'Platform view demo — macOS only',
                  style: TextStyle(fontSize: 13, color: Color(0xFF666666)),
                ),
              ),
      ),
    );
  }
}
