// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';

/// Thin MCP adapter for resource and resource-like tools.
class ResourceHandler {
  ResourceHandler({required this.server, required this.executor});

  final BaseMCPToolkitServer server;
  final CoreCommandExecutor executor;

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

  Future<ReadResourceResult> handleAppErrorsResource(
    final ReadResourceRequest request, {
    final int count = 4,
  }) async {
    final parsedCount = Uri.parse(request.uri).pathSegments.last;
    final requestedCount = jsonDecodeInt(parsedCount).whenZeroUse(count);

    final result = await executor.execute(
      GetAppErrorsCommand(count: requestedCount),
    );
    if (!result.ok) {
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: _errorText(result, prefix: 'Failed to get app errors'),
          ),
        ],
      );
    }

    final data = _map(result.data);
    final message = jsonDecodeString(
      data['message'],
    ).whenEmptyUse('No errors found');
    final errors = jsonDecodeListAs<Map<String, dynamic>>(
      data['errors'],
    ).map((final e) => e.cast<String, Object?>()).toList();

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
  }

  Future<ReadResourceResult> handleScreenshotsResource(
    final ReadResourceRequest request,
  ) async {
    final result = await executor.execute(
      const GetScreenshotsCommand(compress: true),
    );

    if (!result.ok) {
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: _errorText(result, prefix: 'Failed to get screenshots'),
          ),
        ],
      );
    }

    final data = _map(result.data);
    final fileUrls = jsonDecodeListAs<String>(data['fileUrls']);
    if (fileUrls.isNotEmpty) {
      return ReadResourceResult(
        meta: Meta.fromMap({'fileUrls': fileUrls}),
        contents: fileUrls
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

    final images = jsonDecodeListAs<String>(data['images']);
    return ReadResourceResult(
      contents: images
          .map(
            (final image) => BlobResourceContents(
              uri: request.uri,
              blob: image,
              mimeType: 'image/png',
            ),
          )
          .toList(),
    );
  }

  Future<ReadResourceResult> handleViewDetailsResource(
    final ReadResourceRequest request,
  ) async {
    final result = await executor.execute(const GetViewDetailsCommand());

    if (!result.ok) {
      return ReadResourceResult(
        contents: [
          TextResourceContents(
            uri: request.uri,
            text: _errorText(result, prefix: 'Failed to get view details'),
          ),
        ],
      );
    }

    final data = _map(result.data);
    final message = jsonDecodeString(
      data['message'],
    ).whenEmptyUse('View details');
    final details = jsonDecodeListAs<Map<String, dynamic>>(
      data['details'],
    ).map((final e) => e.cast<String, Object?>()).toList();

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
  }

  Future<CallToolResult> getAppErrors(final CallToolRequest request) async {
    final count = jsonDecodeInt(request.arguments?['count']).whenZeroUse(4);
    final result = await executor.execute(GetAppErrorsCommand(count: count));

    if (!result.ok) {
      return CallToolResult(
        isError: true,
        content: [
          TextContent(
            text: _errorText(result, prefix: 'Failed to get app errors'),
          ),
        ],
      );
    }

    final data = _map(result.data);
    final message = jsonDecodeString(
      data['message'],
    ).whenEmptyUse('No errors found');
    final errors = jsonDecodeListAs<Map<String, dynamic>>(
      data['errors'],
    ).map((final e) => e.cast<String, Object?>()).toList();

    return CallToolResult(
      content: [
        TextContent(text: message),
        ...errors.map((final error) => TextContent(text: jsonEncode(error))),
      ],
    );
  }

  Future<CallToolResult> getScreenshots(final CallToolRequest request) async {
    final compress = bool.tryParse('${request.arguments?['compress']}') ?? true;
    final result = await executor.execute(
      GetScreenshotsCommand(compress: compress),
    );

    if (!result.ok) {
      return CallToolResult(
        isError: true,
        content: [
          TextContent(
            text: _errorText(result, prefix: 'Failed to get screenshots'),
          ),
        ],
      );
    }

    final data = _map(result.data);
    final fileUrls = jsonDecodeListAs<String>(data['fileUrls']);
    if (fileUrls.isNotEmpty) {
      return CallToolResult(
        meta: Meta.fromMap({'fileUrls': fileUrls}),
        content: fileUrls
            .map(
              (final fileUrl) => TextContent(
                text: 'Analyse with vision image by URL $fileUrl',
              ),
            )
            .toList(),
      );
    }

    final images = jsonDecodeListAs<String>(data['images']);
    return CallToolResult(
      content: images
          .map(
            (final image) => ImageContent(data: image, mimeType: 'image/png'),
          )
          .toList(),
    );
  }

  Future<CallToolResult> getViewDetails(final CallToolRequest request) async {
    final result = await executor.execute(const GetViewDetailsCommand());

    if (!result.ok) {
      return CallToolResult(
        isError: true,
        content: [
          TextContent(
            text: _errorText(result, prefix: 'Failed to get view details'),
          ),
        ],
      );
    }

    final data = _map(result.data);
    final message = jsonDecodeString(
      data['message'],
    ).whenEmptyUse('View details');
    final details = jsonDecodeListAs<Map<String, dynamic>>(
      data['details'],
    ).map((final e) => e.cast<String, Object?>()).toList();

    return CallToolResult(
      content: [
        TextContent(text: message),
        ...details.map((final detail) => TextContent(text: jsonEncode(detail))),
      ],
    );
  }

  Future<void> dispose() async {}

  Map<String, Object?> _map(final Object? data) {
    if (data is Map<String, Object?>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, Object?>();
    }
    return const <String, Object?>{};
  }

  String _errorText(final CoreResult result, {required final String prefix}) {
    final message = result.error?.message ?? 'Unknown error';
    if (message == 'VM service not connected') {
      return message;
    }
    return '$prefix: $message';
  }
}
