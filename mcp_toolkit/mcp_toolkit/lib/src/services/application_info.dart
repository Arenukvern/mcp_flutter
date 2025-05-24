import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:from_json_to_json/from_json_to_json.dart';

/// Extension type to represent display metrics for a Flutter view
extension type ViewMetrics.fromMap(Map<String, Object?> _value) {
  /// Creates view metrics with the given parameters
  factory ViewMetrics({
    required final double devicePixelRatio,
    required final Size physicalSize,
    required final Size logicalSize,
    required final Brightness platformBrightness,
    required final EdgeInsets viewPadding,
    required final EdgeInsets viewInsets,
    required final EdgeInsets systemGestureInsets,
    required final EdgeInsets padding,
  }) => ViewMetrics.fromMap({
    'devicePixelRatio': devicePixelRatio,
    'physicalSize': {
      'width': physicalSize.width,
      'height': physicalSize.height,
    },
    'logicalSize': {'width': logicalSize.width, 'height': logicalSize.height},
    'platformBrightness': platformBrightness.name,
    'viewPadding': {
      'left': viewPadding.left,
      'top': viewPadding.top,
      'right': viewPadding.right,
      'bottom': viewPadding.bottom,
    },
    'viewInsets': {
      'left': viewInsets.left,
      'top': viewInsets.top,
      'right': viewInsets.right,
      'bottom': viewInsets.bottom,
    },
    'systemGestureInsets': {
      'left': systemGestureInsets.left,
      'top': systemGestureInsets.top,
      'right': systemGestureInsets.right,
      'bottom': systemGestureInsets.bottom,
    },
    'padding': {
      'left': padding.left,
      'top': padding.top,
      'right': padding.right,
      'bottom': padding.bottom,
    },
  });

  /// The device pixel ratio for this view
  double get devicePixelRatio => jsonDecodeDouble(_value['devicePixelRatio']);

  /// The physical size of the view in pixels
  Size get physicalSize {
    final size = _value['physicalSize']! as Map<String, Object?>;
    return Size(
      jsonDecodeDouble(size['width']),
      jsonDecodeDouble(size['height']),
    );
  }

  /// The logical size of the view in logical pixels
  Size get logicalSize {
    final size =
        jsonDecodeMap(jsonDecodeString(_value['logicalSize']))
            as Map<String, Object?>;
    return Size(
      jsonDecodeDouble(size['width']),
      jsonDecodeDouble(size['height']),
    );
  }

  /// The platform brightness (light/dark mode)
  Brightness get platformBrightness => Brightness.values.firstWhere(
    (final b) => b.name == jsonDecodeString(_value['platformBrightness']),
    orElse: () => Brightness.light,
  );

  /// The padding that the operating system applies to the view
  EdgeInsets get viewPadding {
    final padding = _value['viewPadding']! as Map<String, Object?>;
    return EdgeInsets.only(
      left: jsonDecodeDouble(padding['left']),
      top: jsonDecodeDouble(padding['top']),
      right: jsonDecodeDouble(padding['right']),
      bottom: jsonDecodeDouble(padding['bottom']),
    );
  }

  /// The insets that the operating system applies to the view
  EdgeInsets get viewInsets {
    final insets = _value['viewInsets']! as Map<String, Object?>;
    return EdgeInsets.only(
      left: jsonDecodeDouble(insets['left']),
      top: jsonDecodeDouble(insets['top']),
      right: jsonDecodeDouble(insets['right']),
      bottom: jsonDecodeDouble(insets['bottom']),
    );
  }

  /// The system gesture insets that the operating system applies to the view
  EdgeInsets get systemGestureInsets {
    final insets = _value['systemGestureInsets']! as Map<String, Object?>;
    return EdgeInsets.only(
      left: jsonDecodeDouble(insets['left']),
      top: jsonDecodeDouble(insets['top']),
      right: jsonDecodeDouble(insets['right']),
      bottom: jsonDecodeDouble(insets['bottom']),
    );
  }

  /// The padding that the operating system applies to the view
  EdgeInsets get padding {
    final padding = _value['padding']! as Map<String, Object?>;
    return EdgeInsets.only(
      left: jsonDecodeDouble(padding['left']),
      top: jsonDecodeDouble(padding['top']),
      right: jsonDecodeDouble(padding['right']),
      bottom: jsonDecodeDouble(padding['bottom']),
    );
  }

  /// Converts the view metrics to a JSON
  Map<String, dynamic> toJson() => _value;
}

/// A mixin that provides information about the application's views.
mixin ApplicationInfo {
  /// Gets information about all Flutter views in the application
  static List<ViewMetrics> getViewsInformation() {
    final views = WidgetsBinding.instance.renderViews;
    return views.map((final view) {
      final flutterView = view.flutterView;

      return ViewMetrics(
        devicePixelRatio: flutterView.devicePixelRatio,
        physicalSize: flutterView.physicalSize,
        logicalSize: Size(
          flutterView.physicalSize.width / flutterView.devicePixelRatio,
          flutterView.physicalSize.height / flutterView.devicePixelRatio,
        ),
        platformBrightness: flutterView.platformDispatcher.platformBrightness,
        viewPadding: EdgeInsets.fromViewPadding(
          flutterView.viewPadding,
          flutterView.devicePixelRatio,
        ),
        viewInsets: EdgeInsets.fromViewPadding(
          flutterView.viewInsets,
          flutterView.devicePixelRatio,
        ),
        systemGestureInsets: EdgeInsets.fromViewPadding(
          flutterView.systemGestureInsets,
          flutterView.devicePixelRatio,
        ),
        padding: EdgeInsets.fromViewPadding(
          flutterView.padding,
          flutterView.devicePixelRatio,
        ),
      );
    }).toList();
  }
}
