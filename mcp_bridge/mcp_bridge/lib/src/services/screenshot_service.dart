// ignore_for_file: lines_longer_than_80_chars, avoid_catches_without_on_clauses

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../utils/image_compressor.dart';

/// Service for taking screenshots of the main app view using RenderView layers.
mixin ScreenshotService {
  /// Takes a screenshot of the main RenderView.
  ///
  /// This method attempts to capture the current state of the main view
  /// by rendering its layer tree into an image.
  ///
  /// Returns a base64 encoded PNG image string, or null if capture fails.
  static Future<List<String>> takeScreenshots({
    final bool compress = true,
  }) async {
    // Target the main RenderView and its corresponding FlutterView
    final renderViews = WidgetsBinding.instance.renderViews;
    final imageFutures = <Future<String?>>[]; // Prepare for async calls

    for (final renderView in renderViews) {
      final flutterView = renderView.flutterView;
      // Call takeImage asynchronously for each view
      // Note: Ensure takeImage is marked async and returns Future<String?>
      final imageFuture = takeImage(
        flutterView: flutterView,
        view: renderView,
        compress: compress,
      );
      imageFutures.add(imageFuture);
    }

    // Wait for all screenshots to complete and filter out failures (nulls)
    final images =
        (await Future.wait(imageFutures)).whereType<String>().toList();

    // The function should return this list. Ensure a return statement follows.
    return images; // Added return statement as it's logically required here.
  }

  /// Takes a screenshot of the main RenderView.
  ///
  /// This method attempts to capture the current state of the main view
  /// by rendering its layer tree into an image.
  ///
  /// Returns a base64 encoded PNG image string, or null if capture fails.
  static Future<String?> takeImage({
    required final ui.FlutterView flutterView,
    required final RenderView view,
    required final bool compress,
  }) async {
    // ignore: invalid_use_of_protected_member
    if (view.debugNeedsPaint || view.layer == null) {
      debugPrint(
        'ScreenshotService: Main view needs paint or layer is null. Scheduling frame.',
      );
      // Schedule a frame to ensure the layer tree is built and painted.
      WidgetsBinding.instance.scheduleFrame();
      // Wait for the frame to likely complete.
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // ignore: invalid_use_of_protected_member
    final layer = view.layer;
    if (layer == null) {
      debugPrint(
        'ScreenshotService: Skipping main view: Layer is null after delay.',
      );
      return null;
    }

    // Get physical size for accurate rendering from the corresponding FlutterView.
    final size = flutterView.physicalSize;
    if (size.isEmpty) {
      debugPrint(
        'ScreenshotService: Skipping main view: Physical size is empty.',
      );
      return null;
    }

    // Create a SceneBuilder and add the view's layer tree to it.
    final builder = ui.SceneBuilder();
    ui.Scene? scene;
    try {
      // The offset is zero because we want to capture the entire view from its origin.
      layer.addToScene(builder);

      // Build the scene.
      scene = builder.build();

      // Render the scene to an image.
      // Ensure width and height are integers and positive.
      final width = size.width.ceil();
      final height = size.height.ceil();
      if (width <= 0 || height <= 0) {
        debugPrint(
          'ScreenshotService: Skipping main view: Invalid image dimensions ($width x $height).',
        );
        return null; // scene will be disposed in finally
      }

      final ui.Image image = await scene.toImage(width, height);

      // Convert to PNG byte data.
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      // Dispose image immediately after use.
      image.dispose();

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        debugPrint(
          'ScreenshotService: Successfully captured screenshot for '
          'main view (${pngBytes.lengthInBytes} bytes).',
        );
        final effectiveImage =
            compress
                ? await ImageCompressor.compressImage(image: image)
                : pngBytes;

        return base64Encode(effectiveImage);
      } else {
        debugPrint(
          'ScreenshotService: Failed to get byte data for screenshot of main view.',
        );
        return null;
      }
    } catch (e, stackTrace) {
      debugPrint(
        'ScreenshotService: Error capturing screenshot for main view: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      return null;
    } finally {
      // Ensure scene is always disposed.
      scene?.dispose();
    }
  }
}
