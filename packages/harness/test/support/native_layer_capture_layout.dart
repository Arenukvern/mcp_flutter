import 'dart:math' as math;

import 'package:flutter_mcp_harness/flutter_mcp_harness.dart';
import 'package:image/image.dart' as img;
import 'native_layer_evidence.dart';

/// Fixture stripe height in logical pixels (`main.dart` `Container(height: 8)`).
const double kFixtureMarkerStripeLogicalPx = 8;

/// CLI max width matches [ImageCompressor] default.
const int kCliCompressMaxWidthPx = 1024;

/// Layout bridge: semantics logical bounds → physical capture pixels.
class NativeCaptureLayout {
  NativeCaptureLayout({
    required this.imageWidth,
    required this.imageHeight,
    required this.logicalWindowWidth,
    required this.logicalWindowHeight,
    required this.scale,
    required this.markerStripePhysicalPx,
    required this.counterTextPhysicalRoi,
  });

  final int imageWidth;
  final int imageHeight;
  final double logicalWindowWidth;
  final double logicalWindowHeight;
  final double scale;
  final int markerStripePhysicalPx;
  final (int, int, int, int) counterTextPhysicalRoi;

  /// JSON-safe layout snapshot for artifact files ([dart:convert] cannot encode Records).
  Map<String, Object?> toEvidenceJson() {
    final (left, top, width, height) = counterTextPhysicalRoi;
    return {
      'logicalWindowWidth': logicalWindowWidth,
      'logicalWindowHeight': logicalWindowHeight,
      'scale': scale,
      'markerStripePhysicalPx': markerStripePhysicalPx,
      'counterTextPhysicalRoi': {
        'left': left,
        'top': top,
        'width': width,
        'height': height,
      },
    };
  }

  static NativeCaptureLayout? fromSemantics({
    required int imageWidth,
    required int imageHeight,
    AxBounds? marker,
    AxBounds? counter,
  }) {
    if (marker == null || counter == null) return null;
    if (marker.width <= 0) return null;
    final scale = imageWidth / marker.width;
    final logicalH = imageHeight / scale;
    final markerPhysical = (kFixtureMarkerStripeLogicalPx * scale).round().clamp(
      1,
      imageHeight,
    );
    final c = counter;
    final roi = (
      (c.left * scale).round(),
      (c.top * scale).round(),
      math.max(1, (c.width * scale).round()),
      math.max(1, (c.height * scale).round()),
    );
    return NativeCaptureLayout(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      logicalWindowWidth: marker.width,
      logicalWindowHeight: logicalH,
      scale: scale,
      markerStripePhysicalPx: markerPhysical,
      counterTextPhysicalRoi: roi,
    );
  }

  /// 1:1 logical↔physical (desktop unit fixtures).
  static NativeCaptureLayout identityForImage(img.Image image) {
    return NativeCaptureLayout(
      imageWidth: image.width,
      imageHeight: image.height,
      logicalWindowWidth: image.width.toDouble(),
      logicalWindowHeight: image.height.toDouble(),
      scale: 1,
      markerStripePhysicalPx: kMarkerStripeHeightPx,
      counterTextPhysicalRoi: (
        24,
        8 + 24,
        image.width - 48,
        56,
      ),
    );
  }

  NativeCaptureLayout forRescaledImage(int newWidth, int newHeight) {
    final widthScale = newWidth / imageWidth;
    final heightScale = newHeight / imageHeight;
    final (l, t, w, h) = counterTextPhysicalRoi;
    return NativeCaptureLayout(
      imageWidth: newWidth,
      imageHeight: newHeight,
      logicalWindowWidth: logicalWindowWidth,
      logicalWindowHeight: logicalWindowHeight,
      scale: scale * widthScale,
      markerStripePhysicalPx: (markerStripePhysicalPx * heightScale).round().clamp(
        1,
        newHeight,
      ),
      counterTextPhysicalRoi: (
        (l * widthScale).round(),
        (t * heightScale).round(),
        math.max(1, (w * widthScale).round()),
        math.max(1, (h * heightScale).round()),
      ),
    );
  }
}

AxNode? _findByIdentifier(Iterable<AxNode> nodes, String id) {
  for (final node in nodes) {
    if (node.attributes['identifier'] == id) return node;
    final child = _findByIdentifier(node.children, id);
    if (child != null) return child;
  }
  return null;
}

Future<NativeCaptureLayout> resolveNativeCaptureLayout(
  ToolkitDriver driver,
  int imageWidth,
  int imageHeight,
) async {
  final roots = (await driver.snapshot()).nodes;
  final marker = _findByIdentifier(roots, 'native_layer_marker_stripe')?.bounds;
  final counter =
      _findByIdentifier(roots, 'native_layer_counter_value')?.bounds;
  final layout = NativeCaptureLayout.fromSemantics(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
    marker: marker,
    counter: counter,
  );
  if (layout == null) {
    throw StateError(
      'native capture layout: missing semantics bounds for marker/counter '
      '(marker=$marker counter=$counter image=${imageWidth}x$imageHeight)',
    );
  }
  return layout;
}
