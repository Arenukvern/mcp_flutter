// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:flutter_inspector_mcp_server/src/core/connection_context.dart';
import 'package:flutter_inspector_mcp_server/src/core/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/mcp_toolkit_consts.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';

/// Dynamic registry behavior adapter used by the shared command executor.
abstract interface class CoreDynamicGateway {
  Future<CoreResult> listClientToolsAndResources();

  Future<CoreResult> runClientTool(
    final String toolName,
    final Map<String, Object?> arguments,
  );

  Future<CoreResult> runClientResource(final String resourceUri);

  Future<CoreResult> dynamicRegistryStats({required bool includeAppDetails});
}

/// Default dynamic gateway implementation based on toolkit VM extensions.
final class VmExtensionDynamicGateway implements CoreDynamicGateway {
  VmExtensionDynamicGateway({required this.connectionContext});

  final ConnectionContext connectionContext;

  String _appId = '';
  List<Map<String, Object?>> _tools = const <Map<String, Object?>>[];
  List<Map<String, Object?>> _resources = const <Map<String, Object?>>[];

  @override
  Future<CoreResult> listClientToolsAndResources() async {
    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) {
      return ensureFailure;
    }

    try {
      final response = await connectionContext.callFlutterExtension(
        '$mcpToolkitExt.${mcpToolkitExtNames.registerDynamics}',
      );
      final json = jsonDecodeMap(response.json);

      final appId = jsonDecodeString(json['appId']);
      final tools = jsonDecodeListAs<Map<String, dynamic>>(
        json['tools'],
      ).map((final e) => e.cast<String, Object?>()).toList();
      final resources = jsonDecodeListAs<Map<String, dynamic>>(
        json['resources'],
      ).map((final e) => e.cast<String, Object?>()).toList();

      _appId = appId;
      _tools = tools;
      _resources = resources;

      return CoreResult.success(
        data: {
          'appId': appId,
          'tools': tools,
          'resources': resources,
          'summary': {
            'totalTools': tools.length,
            'totalResources': resources.length,
          },
        },
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicRegistryListFailed,
        message: 'Failed to list dynamic tools/resources: $e',
      );
    }
  }

  @override
  Future<CoreResult> runClientTool(
    final String toolName,
    final Map<String, Object?> arguments,
  ) async {
    if (toolName.isEmpty) {
      return CoreResult.failure(
        code: CoreErrorCode.missingToolName,
        message: 'Missing required parameter: toolName',
      );
    }

    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) {
      return ensureFailure;
    }

    try {
      final response = await connectionContext.callFlutterExtension(
        '$mcpToolkitExt.$toolName',
        args: arguments.cast<String, dynamic>(),
      );
      final json = jsonDecodeMap(response.json);
      final message = jsonDecodeString(
        json['message'],
      ).whenEmptyUse('Tool executed successfully');

      final parameters = Map<String, Object?>.from(json)..remove('message');

      return CoreResult.success(
        data: {'message': message, 'parameters': parameters},
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicToolFailed,
        message: 'Error forwarding tool call: $e',
      );
    }
  }

  @override
  Future<CoreResult> runClientResource(final String resourceUri) async {
    if (resourceUri.isEmpty) {
      return CoreResult.failure(
        code: CoreErrorCode.missingResourceUri,
        message: 'Missing required parameter: resourceUri',
      );
    }

    final ensureFailure = await _ensureVmConnected();
    if (ensureFailure != null) {
      return ensureFailure;
    }

    try {
      final parsed = Uri.parse(resourceUri);
      final resourceName = parsed.pathSegments.isEmpty
          ? resourceUri
          : parsed.pathSegments.last;

      final response = await connectionContext.callFlutterExtension(
        '$mcpToolkitExt.$resourceName',
        args: {'uri': resourceUri},
      );

      final json = jsonDecodeMap(response.json);
      final content = jsonDecodeString(
        json['content'],
      ).whenEmptyUse('Resource content not available');
      final mimeType = jsonDecodeString(
        json['mimeType'],
      ).whenEmptyUse('text/plain');

      return CoreResult.success(
        data: {'uri': resourceUri, 'content': content, 'mimeType': mimeType},
      );
    } on Exception catch (e) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicResourceFailed,
        message: 'Error forwarding resource read: $e',
      );
    }
  }

  @override
  Future<CoreResult> dynamicRegistryStats({
    required final bool includeAppDetails,
  }) async {
    final result = <String, Object?>{
      'toolCount': _tools.length,
      'resourceCount': _resources.length,
    };

    if (includeAppDetails) {
      result.addAll({
        'id': _appId,
        'toolCount': _tools.length,
        'resourceCount': _resources.length,
      });
    }

    return CoreResult.success(data: result);
  }

  Future<CoreResult?> _ensureVmConnected() async {
    final ensure = await connectionContext.ensureConnectedWithPolicy();
    if (ensure.connected) {
      return null;
    }

    return CoreResult.failure(
      code: ensure.code ?? CoreErrorCode.vmNotConnected,
      message: ensure.message ?? 'VM service not connected',
      details: ensure.details,
    );
  }
}

String encodeDynamicPayload(final Object? payload) {
  try {
    return jsonEncode(payload);
  } on Exception {
    return '$payload';
  }
}
