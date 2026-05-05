// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';
import 'dart:io';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/types/core_types.dart';
import 'package:path/path.dart' as path;

/// Save screenshots as files for clients that prefer URL references.
final class CoreImageFileSaver {
  const CoreImageFileSaver({required this.logger, this.baseDirectory});

  static const temporalFolderName = '.mcp_screenshots';

  final CoreLogger logger;
  final String? baseDirectory;

  String get _temporalFolderPath {
    final baseDir = baseDirectory ?? Directory.current.path;
    return path.join(baseDir, temporalFolderName);
  }

  Future<Directory> _ensureTemporalFolder() async {
    final folder = Directory(_temporalFolderPath);
    if (!folder.existsSync()) {
      await folder.create(recursive: true);
      logger(
        LoggingLevel.info,
        'Created temporal folder: ${folder.path}',
        logger: 'ImageFileSaver',
      );
    }
    return folder;
  }

  Future<String> saveImageToFile(final String base64Image) async {
    final folder = await _ensureTemporalFolder();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'screenshot-$timestamp.png';
    final filePath = path.join(folder.path, fileName);

    final bytes = base64Decode(base64Image);
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    final fileUrl = 'file://${file.absolute.path}';
    logger(
      LoggingLevel.info,
      'Saved screenshot to: $filePath (${bytes.length} bytes) - URL: $fileUrl',
      logger: 'ImageFileSaver',
    );
    return fileUrl;
  }

  Future<List<String>> saveImagesToFiles(
    final List<String> base64Images,
  ) async {
    final fileUrls = <String>[];
    for (final image in base64Images) {
      try {
        final fileUrl = await saveImageToFile(image);
        fileUrls.add(fileUrl);
      } on Exception catch (e) {
        logger(
          LoggingLevel.error,
          'Failed to save image to file: $e',
          logger: 'ImageFileSaver',
        );
      }
    }
    return fileUrls;
  }

  Future<void> cleanupOldScreenshots() async {
    try {
      final folder = Directory(_temporalFolderPath);
      if (!folder.existsSync()) return;

      final cutoffTime = DateTime.now().subtract(const Duration(hours: 24));
      final entities = await folder.list().toList();

      for (final entity in entities) {
        if (entity is! File || !entity.path.contains('screenshot-')) {
          continue;
        }
        final stat = entity.statSync();
        if (!stat.modified.isBefore(cutoffTime)) continue;
        entity.deleteSync();
        logger(
          LoggingLevel.debug,
          'Deleted old screenshot: ${entity.path}',
          logger: 'ImageFileSaver',
        );
      }
    } on Exception catch (e) {
      logger(
        LoggingLevel.warning,
        'Failed to cleanup old screenshots: $e',
        logger: 'ImageFileSaver',
      );
    }
  }
}
