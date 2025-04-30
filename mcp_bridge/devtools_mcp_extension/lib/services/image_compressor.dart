import 'dart:convert';
import 'dart:ui' as ui;

import 'package:devtools_mcp_extension/common_imports.dart';
import 'package:flutter/foundation.dart';

class ImageCompressor {
  ImageCompressor._();

  /// Compresses a base64 encoded image by resizing and quality optimization
  /// Returns a new base64 string with reduced size
  /// [base64Image] - The original base64 encoded image string
  /// [maxWidth] - Maximum width to scale down to (maintains aspect ratio)
  /// [quality] - JPEG quality (1-100), lower means more compression
  static Future<String> compressBase64Image({
    required final String base64Image,
    final int maxWidth = 1024,
    final int quality = 85,
  }) async {
    try {
      // Decode base64 to bytes
      final bytes = base64Decode(base64Image);

      // Convert bytes to image
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      // Calculate new dimensions maintaining aspect ratio
      final double ratio = image.width / image.height;
      final int newWidth = image.width > maxWidth ? maxWidth : image.width;
      final int newHeight = (newWidth / ratio).round();

      // Create scaled image
      final ui.Image scaledImage = await _resizeImage(
        image,
        newWidth,
        newHeight,
      );

      // Convert to byte data with quality compression
      final ByteData? byteData = await scaledImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Failed to encode image');
      }

      // Convert back to base64
      final Uint8List uint8List = byteData.buffer.asUint8List();
      final String compressedBase64 = base64Encode(uint8List);

      // Clean up
      scaledImage.dispose();
      image.dispose();

      return compressedBase64;
    } catch (e) {
      if (kDebugMode) {
        print('Error compressing image: $e');
      }
      rethrow;
    }
  }

  /// Helper method to resize an image
  static Future<ui.Image> _resizeImage(
    final ui.Image image,
    final int width,
    final int height,
  ) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    Canvas(pictureRecorder).drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image resizedImage = await picture.toImage(width, height);

    return resizedImage;
  }
}
