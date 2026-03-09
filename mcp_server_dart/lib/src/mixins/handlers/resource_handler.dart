// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/core/command_catalog.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/visual_capture.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/handlers/connection_override.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';

/// Thin MCP adapter for resource and resource-like tools.
class ResourceHandler {
  ResourceHandler({required this.server, required this.executor});

  final BaseMCPToolkitServer server;
  final CoreCommandExecutor executor;
  static final _catalog = CommandCatalog.instance;

  static String _description(final String name, final String fallback) =>
      _catalog.specFor(name)?.description ?? fallback;

  static final getAppErrorsTool = Tool(
    name: 'get_app_errors',
    description: _description(
      'get_app_errors',
      'Get the most recent application errors from Dart VM',
    ),
    inputSchema: strictToolInputSchema(
      properties: {
        'count': Schema.int(
          description: 'Number of recent errors to retrieve (default: 4)',
        ),
      },
    ),
  );

  static final getScreenshotsTool = Tool(
    name: 'get_screenshots',
    description: _description(
      'get_screenshots',
      'Get screenshots of all views in the application',
    ),
    inputSchema: strictToolInputSchema(
      properties: {
        'compress': Schema.bool(
          description: 'Whether to compress the images (default: true)',
        ),
        'mode': Schema.string(
          description:
              'Screenshot mode: auto, flutter_layer, or desktop_window '
              '(default: auto)',
        ),
        'permissionPolicy': Schema.string(
          description:
              'Permission policy: check_only, auto_request_once, or request_always '
              '(default: check_only)',
        ),
      },
    ),
  );

  static final getViewDetailsTool = Tool(
    name: 'get_view_details',
    description: _description(
      'get_view_details',
      'Get details for all views in the application',
    ),
    inputSchema: strictToolInputSchema(),
  );

  static final inspectWidgetAtPointTool = Tool(
    name: 'inspect_widget_at_point',
    description: _description(
      'inspect_widget_at_point',
      'Inspect the deepest widget at global logical coordinates (x, y).',
    ),
    inputSchema: strictToolInputSchema(
      required: ['x', 'y'],
      properties: {
        'x': Schema.int(description: 'Global logical X coordinate'),
        'y': Schema.int(description: 'Global logical Y coordinate'),
        'viewId': Schema.int(
          description: 'Optional FlutterView id for multi-view apps',
        ),
      },
    ),
  );

  static final captureUiSnapshotTool = Tool(
    name: 'capture_ui_snapshot',
    description: _description(
      'capture_ui_snapshot',
      'Capture screenshots, view details, and app errors in one response.',
    ),
    inputSchema: strictToolInputSchema(
      properties: {
        'errorsCount': Schema.int(
          description: 'Number of recent errors to include (default: 4)',
        ),
        'compress': Schema.bool(
          description:
              'Whether screenshots should be compressed (default: true)',
        ),
        'includeViewDetails': Schema.bool(
          description: 'Include detailed view/widget data (default: true)',
        ),
        'includeErrors': Schema.bool(
          description: 'Include app errors (default: true)',
        ),
        'screenshotMode': Schema.string(
          description:
              'Screenshot mode: auto, flutter_layer, or desktop_window '
              '(default: auto)',
        ),
        'permissionPolicy': Schema.string(
          description:
              'Permission policy: check_only, auto_request_once, or request_always '
              '(default: check_only)',
        ),
      },
    ),
  );

  Future<ReadResourceResult> handleAppErrorsResource(
    final ReadResourceRequest request, {
    final int count = 4,
  }) async {
    final connectError = await applyConnectionOverrideFromResourceUri(
      resourceUri: request.uri,
      executor: executor,
    );
    if (connectError != null) {
      return toReadResourceErrorResult(
        uri: request.uri,
        result: connectError,
        prefix: 'Failed to connect',
      );
    }

    final parsedCount = Uri.parse(request.uri).pathSegments.last;
    final requestedCount = jsonDecodeInt(parsedCount).whenZeroUse(count);

    final result = await executor.execute(
      GetAppErrorsCommand(count: requestedCount),
    );
    if (!result.ok) {
      return toReadResourceErrorResult(
        uri: request.uri,
        result: result,
        prefix: 'Failed to get app errors',
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
    final connectError = await applyConnectionOverrideFromResourceUri(
      resourceUri: request.uri,
      executor: executor,
    );
    if (connectError != null) {
      return toReadResourceErrorResult(
        uri: request.uri,
        result: connectError,
        prefix: 'Failed to connect',
      );
    }

    final result = await executor.execute(
      const GetScreenshotsCommand(compress: true),
    );

    if (!result.ok) {
      return toReadResourceErrorResult(
        uri: request.uri,
        result: result,
        prefix: 'Failed to get screenshots',
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
    final connectError = await applyConnectionOverrideFromResourceUri(
      resourceUri: request.uri,
      executor: executor,
    );
    if (connectError != null) {
      return toReadResourceErrorResult(
        uri: request.uri,
        result: connectError,
        prefix: 'Failed to connect',
      );
    }

    final result = await executor.execute(const GetViewDetailsCommand());

    if (!result.ok) {
      return toReadResourceErrorResult(
        uri: request.uri,
        result: result,
        prefix: 'Failed to get view details',
      );
    }

    final data = _map(result.data);
    return ReadResourceResult(
      contents: [
        TextResourceContents(
          uri: request.uri,
          text: jsonEncode(data),
          mimeType: 'application/json',
        ),
      ],
    );
  }

  Future<CallToolResult> getAppErrors(final CallToolRequest request) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final count = jsonDecodeInt(request.arguments?['count']).whenZeroUse(4);
    final result = await executor.execute(GetAppErrorsCommand(count: count));

    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to get app errors');
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
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final compress = bool.tryParse('${request.arguments?['compress']}') ?? true;
    final result = await executor.execute(
      GetScreenshotsCommand(
        compress: compress,
        mode: parseScreenshotMode(request.arguments?['mode']),
        permissionPolicy: parsePermissionPolicy(
          request.arguments?['permissionPolicy'],
        ),
      ),
    );

    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to get screenshots');
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
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final result = await executor.execute(const GetViewDetailsCommand());

    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Failed to get view details',
      );
    }

    final data = _map(result.data);
    return CallToolResult(content: [TextContent(text: jsonEncode(data))]);
  }

  Future<CallToolResult> inspectWidgetAtPoint(
    final CallToolRequest request,
  ) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final x = jsonDecodeInt(request.arguments?['x']).whenZeroUse(0);
    final y = jsonDecodeInt(request.arguments?['y']).whenZeroUse(0);
    final rawViewId = request.arguments?['viewId'];
    final viewId = switch (rawViewId) {
      final int v => v,
      final String v when int.tryParse(v) != null => int.parse(v),
      _ => null,
    };

    final result = await executor.execute(
      InspectWidgetAtPointCommand(x: x, y: y, viewId: viewId),
    );

    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Failed to inspect widget at point',
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> captureUiSnapshot(
    final CallToolRequest request,
  ) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final errorsCount = jsonDecodeInt(
      request.arguments?['errorsCount'],
    ).whenZeroUse(4);
    final compress = switch (request.arguments?['compress']) {
      final bool value => value,
      final String value => value.toLowerCase() != 'false',
      _ => true,
    };
    final includeViewDetails =
        switch (request.arguments?['includeViewDetails']) {
          final bool value => value,
          final String value => value.toLowerCase() != 'false',
          _ => true,
        };
    final includeErrors = switch (request.arguments?['includeErrors']) {
      final bool value => value,
      final String value => value.toLowerCase() != 'false',
      _ => true,
    };

    final result = await executor.execute(
      CaptureUiSnapshotCommand(
        errorsCount: errorsCount,
        compress: compress,
        includeViewDetails: includeViewDetails,
        includeErrors: includeErrors,
        screenshotMode: parseScreenshotMode(
          request.arguments?['screenshotMode'],
        ),
        permissionPolicy: parsePermissionPolicy(
          request.arguments?['permissionPolicy'],
        ),
      ),
    );

    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Failed to capture UI snapshot',
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
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
}
