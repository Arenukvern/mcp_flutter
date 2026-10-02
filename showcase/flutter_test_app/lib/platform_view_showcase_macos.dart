import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:test_app/platform_view_showcase_stub.dart';

/// macOS [AppKitView] panel; other IO platforms use the text placeholder.
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
        child: Platform.isMacOS
            ? const AppKitView(
                viewType: viewType,
                layoutDirection: TextDirection.ltr,
                creationParams: <String, dynamic>{},
                creationParamsCodec: StandardMessageCodec(),
              )
            : showcasePlatformViewPlaceholder(),
      ),
    );
  }
}
