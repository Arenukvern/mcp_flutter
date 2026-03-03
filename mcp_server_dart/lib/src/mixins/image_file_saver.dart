// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/core/services/core_image_file_saver.dart';

/// Compatibility wrapper around the shared core image file saver.
class ImageFileSaver {
  const ImageFileSaver({required this.server});

  final BaseMCPToolkitServer server;

  CoreImageFileSaver get _core => CoreImageFileSaver(
    logger: (final level, final message, {final logger = 'ImageFileSaver'}) =>
        server.log(level, message, logger: logger),
  );

  Future<String> saveImageToFile(final String base64Image) =>
      _core.saveImageToFile(base64Image);

  Future<List<String>> saveImagesToFiles(final List<String> base64Images) =>
      _core.saveImagesToFiles(base64Images);

  Future<void> cleanupOldScreenshots() => _core.cleanupOldScreenshots();
}
