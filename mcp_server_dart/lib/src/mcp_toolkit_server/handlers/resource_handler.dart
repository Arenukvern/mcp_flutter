// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/base_server.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/core/to_resources_tools.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/command_executor.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/commands/commands.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/vm_connections/vm_connections.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';

/// Adapter that backs the `visual://localhost/...` MCP resource surface.
///
/// The MCP tool surface (`fmt_get_app_errors`, `fmt_get_screenshots`,
/// `fmt_get_view_details`, `fmt_inspect_widget_at_point`,
/// `fmt_capture_ui_snapshot`) is registered by `flutter_mcp_toolkit_capability_core` and
/// does not pass through this class. This handler exists only to back the
/// `addResource(...)` registrations the kernel does not yet publish.
class ResourceHandler {
  ResourceHandler({required this.server, required this.executor});

  final BaseMCPToolkitServer server;
  final CoreCommandExecutor executor;

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

    final result = await executor.execute(const GetScreenshotsCommand());

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
    final routing = <String, Object?>{
      if (data['captureHints'] != null) 'captureHints': data['captureHints'],
      if (data['warnings'] != null) 'warnings': data['warnings'],
      if (data['suggestedAction'] != null)
        'suggestedAction': data['suggestedAction'],
      if (data['actualMode'] != null) 'actualMode': data['actualMode'],
      if (data['captureMode'] != null) 'captureMode': data['captureMode'],
    };
    return ReadResourceResult(
      meta: routing.isEmpty ? null : Meta.fromMap(routing),
      contents: [
        if (routing.isNotEmpty)
          TextResourceContents(
            uri: request.uri,
            text: jsonEncode(routing),
            mimeType: 'application/json',
          ),
        ...images.map(
          (final image) => BlobResourceContents(
            uri: request.uri,
            blob: image,
            mimeType: 'image/png',
          ),
        ),
      ],
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
