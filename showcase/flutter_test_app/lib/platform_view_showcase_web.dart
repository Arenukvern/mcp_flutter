import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:test_app/platform_view_showcase_stub.dart';
import 'package:web/web.dart' as web;

/// Web [HtmlElementView] panel (factory registered at startup).
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
        child: HtmlElementView(viewType: viewType),
      ),
    );
  }
}

/// Registers [kShowcasePlatformViewType] for Flutter web embed.
void registerShowcasePlatformView() {
  ui_web.platformViewRegistry.registerViewFactory(kShowcasePlatformViewType, (
    final int viewId,
  ) {
    final box = web.HTMLDivElement()
      ..style.setProperty('width', '100%')
      ..style.setProperty('height', '48px')
      ..style.setProperty('box-sizing', 'border-box')
      ..style.setProperty('background', 'rgba(25, 118, 210, 0.85)')
      ..style.setProperty('border-radius', '4px')
      ..style.setProperty('display', 'flex')
      ..style.setProperty('align-items', 'center')
      ..style.setProperty('justify-content', 'center')
      ..style.setProperty('color', 'white')
      ..style.setProperty('font', '500 11px system-ui, sans-serif')
      ..textContent = 'Native';
    return box;
  });
}
