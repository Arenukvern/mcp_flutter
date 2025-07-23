// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/image_file_saver.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/mcp_toolkit_consts.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/vm_service_support.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';

/// Handles resource-related functionality for the Flutter Inspector.
class ResourceHandler {
  /// Creates a new [ResourceHandler] instance.
  ResourceHandler({required this.server, required this.vmService})
    : _imageFileSaver = ImageFileSaver(server: server);

  final BaseMCPToolkitServer server;
  final VMServiceSupport vmService;
  final ImageFileSaver _imageFileSaver;

  // Tool definitions
  static final getAppErrorsTool = Tool(
    name: 'get_app_errors',
    description: 'Get the most recent application errors from Dart VM',
    inputSchema: Schema.object(
      properties: {
        'count': Schema.int(
          description: 'Number of recent errors to retrieve (default: 4)',
        ),
      },
    ),
  );

  static final getScreenshotsTool = Tool(
    name: 'get_screenshots',
    description: 'Get screenshots of all views in the application',
    inputSchema: Schema.object(
      properties: {
        'compress': Schema.bool(
          description: 'Whether to compress the images (default: true)',
        ),
      },
    ),
  );

  static final getViewDetailsTool = Tool(
    name: 'get_view_details',
    description: 'Get details for all views in the application',
    inputSchema: Schema.object(properties: {}),
  );

  /// Common file saving logic for screenshots.
  /// Returns a record with (fileUrls, error) where error is null on success.
  Future<({List<String>? fileUrls, Exception? error})> _saveScreenshotsToFiles(
    final List<String> images,
  ) async {
    if (!server.configuration.saveImagesToFiles) {
      return (fileUrls: null, error: null);
    }

    try {
      // Clean up old screenshots first
      await _imageFileSaver.cleanupOldScreenshots();

      // Save images to files and return file URLs
      final fileUrls = await _imageFileSaver.saveImagesToFiles(images);
      server.log(
        LoggingLevel.info,
        'Screenshots saved to files: ${fileUrls.length} files created',
        logger: 'FlutterInspector',
      );

      return (fileUrls: fileUrls, error: null);
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Failed to save screenshots to files: $e',
        logger: 'FlutterInspector',
      );
      return (fileUrls: null, error: e);
    }
  }

  /// Handle app errors resource request.
  Future<ReadResourceResult> handleAppErrorsResource(
    final ReadResourceRequest request, {
    final int count = 4,
  }) async {
    server.log(
      LoggingLevel.info,
      'Handling app errors resource request (count: $count)',
      logger: 'FlutterInspector',
    );

    try {
      final parsedCount = Uri.parse(request.uri).pathSegments.last;
      final requestedCount = jsonDecodeInt(parsedCount).whenZeroUse(count);
      server.log(
        LoggingLevel.debug,
        'Requesting $requestedCount app errors',
        logger: 'FlutterInspector',
      );

      final result = await vmService.callFlutterExtension(
        mcpToolkitExtKeys.appErrors,
        args: {'count': requestedCount},
      );
      final json = result.json;
      if (json == null) {
        server.log(
          LoggingLevel.warning,
          'App errors extension returned null',
          logger: 'FlutterInspector',
        );
        return ReadResourceResult(
          contents: [
            TextResourceContents(uri: request.uri, text: 'No errors found'),
          ],
        );
      }
      final errors = jsonDecodeListAs<Map<String, dynamic>>(json['errors']);
      final message = jsonDecodeString(
        json['message'],
      ).whenEmptyUse('No errors found');

      server.log(
        LoggingLevel.info,
        'App errors resource completed: found ${errors.length} errors',
        logger: 'FlutterInspector',
      );

      if (errors.isEmpty) {
        return ReadResourceResult(
          contents: [TextResourceContents(uri: request.uri, text: message)],
        );
      }

      return ReadResourceResult(
        contents: [
          TextResourceContents(uri: request.uri, text: message),
          ...errors.map(
            (final error) => TextResourceContents(
              uri: request.uri,
              text: jsonEncode(error),
              mimeType: 'application/json',
            ),
          ),
        ],
      );
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'App errors resource failed: $e',
        logger: 'FlutterInspector',
      );
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: 'Failed to get app errors: $e',
          ),
        ],
      );
    }
  }

  /// Handle screenshots resource request.
  Future<ReadResourceResult> handleScreenshotsResource(
    final ReadResourceRequest request,
  ) async {
    server.log(
      LoggingLevel.info,
      'Handling screenshots resource request',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Screenshots resource failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: 'VM service not connected',
          ),
        ],
      );
    }

    try {
      final result = await vmService.callFlutterExtension(
        mcpToolkitExtKeys.viewScreenshots,
        args: {'compress': true},
      );

      final images = jsonDecodeListAs<String>(result.json?['images']);
      server.log(
        LoggingLevel.info,
        'Screenshots resource completed: captured ${images.length} screenshots',
        logger: 'FlutterInspector',
      );

      // Use the common file saving helper
      final saveResult = await _saveScreenshotsToFiles(images);

      if (saveResult.fileUrls != null) {
        return ReadResourceResult(
          meta: Meta.fromMap({'fileUrls': saveResult.fileUrls}),
          contents:
              saveResult.fileUrls!
                  .map(
                    (final fileUrl) => TextResourceContents(
                      uri: request.uri,
                      text: 'Analyse with vision image by URL $fileUrl ',
                      mimeType: 'text/plain',
                    ),
                  )
                  .toList(),
        );
      }

      // Default behavior: return base64 images
      return ReadResourceResult(
        contents:
            images
                .map(
                  (final image) => BlobResourceContents(
                    uri: request.uri,
                    blob: image,
                    mimeType: 'image/png',
                  ),
                )
                .toList(),
      );
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Screenshots resource failed: $e',
        logger: 'FlutterInspector',
      );
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: 'Failed to get screenshots: $e',
          ),
        ],
      );
    }
  }

  /// Handle view details resource request.
  Future<ReadResourceResult> handleViewDetailsResource(
    final ReadResourceRequest request,
  ) async {
    server.log(
      LoggingLevel.info,
      'Handling view details resource request',
      logger: 'FlutterInspector',
    );

    try {
      final result = await vmService.callFlutterExtension(
        mcpToolkitExtKeys.viewDetails,
        args: {},
      );

      final details = jsonDecodeListAs<Map<String, dynamic>>(
        result.json?['details'],
      );
      final message = jsonDecodeString(
        result.json?['message'],
      ).whenEmptyUse('View details');

      server.log(
        LoggingLevel.info,
        'View details resource completed: found ${details.length} views',
        logger: 'FlutterInspector',
      );

      return ReadResourceResult(
        contents: [
          TextResourceContents(uri: request.uri, text: message),
          ...details.map(
            (final detail) => TextResourceContents(
              uri: request.uri,
              text: jsonEncode(detail),
              mimeType: 'application/json',
            ),
          ),
        ],
      );
    } on Exception catch (e, s) {
      server.log(
        LoggingLevel.error,
        'View details resource failed: $e\nStack trace: $s',
        logger: 'FlutterInspector',
      );
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: 'Failed to get view details: $e',
          ),
        ],
      );
    }
  }

  /// Get app errors as tool.
  Future<CallToolResult> getAppErrors(final CallToolRequest request) async {
    server.log(
      LoggingLevel.info,
      'Executing get app errors tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Get app errors tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final count = jsonDecodeInt(request.arguments?['count']).whenZeroUse(4);
      server.log(
        LoggingLevel.debug,
        'Requesting $count app errors',
        logger: 'FlutterInspector',
      );

      final result = await vmService.callFlutterExtension(
        mcpToolkitExtKeys.appErrors,
        args: {'count': count},
      );

      final errors = jsonDecodeListAs<Map<String, dynamic>>(
        result.json?['errors'],
      );
      final message = jsonDecodeString(
        result.json?['message'],
      ).whenEmptyUse('No errors found');

      server.log(
        LoggingLevel.info,
        'Get app errors tool completed: found ${errors.length} errors',
        logger: 'FlutterInspector',
      );

      return CallToolResult(
        content: [
          TextContent(text: message),
          ...errors.map((final error) => TextContent(text: jsonEncode(error))),
        ],
      );
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Get app errors tool failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get app errors: $e')],
      );
    }
  }

  /// Get screenshots as tool.
  Future<CallToolResult> getScreenshots(final CallToolRequest request) async {
    server.log(
      LoggingLevel.info,
      'Executing get screenshots tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Get screenshots tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final compress =
          bool.tryParse('${request.arguments?['compress']}') ?? true;
      server.log(
        LoggingLevel.debug,
        'Screenshots compression: $compress',
        logger: 'FlutterInspector',
      );

      final result = await vmService.callFlutterExtension(
        mcpToolkitExtKeys.viewScreenshots,
        args: {'compress': compress},
      );

      final images = jsonDecodeListAs<String>(result.json?['images']);
      server.log(
        LoggingLevel.info,
        'Get screenshots tool completed: captured ${images.length} screenshots',
        logger: 'FlutterInspector',
      );

      // Use the common file saving helper
      final saveResult = await _saveScreenshotsToFiles(images);

      if (saveResult.fileUrls != null) {
        return CallToolResult(
          meta: Meta.fromMap({'fileUrls': saveResult.fileUrls}),
          content:
              saveResult.fileUrls!
                  .map(
                    (final fileUrl) => TextContent(
                      text: 'Analyse with vision image by URL $fileUrl',
                    ),
                  )
                  .toList(),
        );
      }

      // Default behavior: return base64 images
      return CallToolResult(
        content: [
          ...images.map(
            (final image) => ImageContent(data: image, mimeType: 'image/png'),
          ),
        ],
      );
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Get screenshots tool failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get screenshots: $e')],
      );
    }
  }

  /// Get view details as tool.
  Future<CallToolResult> getViewDetails(final CallToolRequest request) async {
    server.log(
      LoggingLevel.info,
      'Executing get view details tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Get view details tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await vmService.callFlutterExtension(
        mcpToolkitExtKeys.viewDetails,
      );
      final details = jsonDecodeListAs<Map<String, dynamic>>(
        result.json?['details'],
      );
      final message = jsonDecodeString(
        result.json?['message'],
      ).whenEmptyUse('View details');

      server.log(
        LoggingLevel.info,
        'Get view details tool completed: found ${details.length} views',
        logger: 'FlutterInspector',
      );

      return CallToolResult(
        content: [
          TextContent(text: message),
          ...details.map(
            (final detail) => TextContent(text: jsonEncode(detail)),
          ),
        ],
      );
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Get view details tool failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get view details: $e')],
      );
    }
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await _imageFileSaver.cleanupOldScreenshots();
  }
}
