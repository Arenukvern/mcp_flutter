import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Compresses a base64 encoded image by resizing and quality optimization
class ImageCompressor {
  ImageCompressor._();

  /// Compresses a [Uint8List] image by resizing and quality optimization
  /// Returns a new base64 string with reduced size
  /// [imageBytes] - The original image bytes
  /// [maxWidth] - Maximum width to scale down to (maintains aspect ratio)
  /// [quality] - JPEG quality (1-100), lower means more compression
  static Future<Uint8List> compressImage({
    required final Image image,
    final int maxWidth = 1024,
    final int quality = 99,
  }) async {
    try {
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

      // Clean up
      scaledImage.dispose();
      image.dispose();

      return uint8List;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('Error compressing image: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Compresses a base64 encoded image by resizing and quality optimization
  /// Returns a new base64 string with reduced size
  /// [base64Image] - The original base64 encoded image string
  /// [maxWidth] - Maximum width to scale down to (maintains aspect ratio)
  /// [quality] - JPEG quality (1-100), lower means more compression
  static Future<Uint8List> compressBase64Image({
    required final String base64Image,
    final int maxWidth = 1024,
    final int quality = 99,
  }) async {
    // Decode base64 to bytes
    final bytes = base64Decode(base64Image);
    return compressImage(image: await getImageFromBytes(imageBytes: bytes));
  }

  /// Returns a new [Image] from a [Uint8List]
  static Future<Image> getImageFromBytes({
    required final Uint8List imageBytes,
  }) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    return frame.image;
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
