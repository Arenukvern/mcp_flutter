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
      final candidates = _resourceExtensionCandidates(
        parsed: parsed,
        fallback: resourceUri,
      );

      Map<String, Object?>? json;
      Object? lastUnknownMethodError;
      for (final candidate in candidates) {
        try {
          final response = await connectionContext.callFlutterExtension(
            '$mcpToolkitExt.$candidate',
            args: {'uri': resourceUri},
          );
          json = jsonDecodeMap(response.json);
          break;
        } catch (e) {
          if (!_isUnknownExtensionMethodError(e)) {
            rethrow;
          }
          lastUnknownMethodError = e;
        }
      }

      if (json == null) {
        throw StateError(
          'No matching dynamic resource extension for $resourceUri. '
          'Last error: $lastUnknownMethodError',
        );
      }

      final mimeType = jsonDecodeString(json['mimeType']).whenEmptyUse(
        jsonDecodeBool(json['isBlob'])
            ? 'application/octet-stream'
            : 'application/json',
      );

      if (jsonDecodeBool(json['isBlob'])) {
        final blob = jsonDecodeString(json['blob']);
        if (blob.isNotEmpty) {
          return CoreResult.success(
            data: {
              'uri': resourceUri,
              'blob': blob,
              'mimeType': mimeType,
              'isBlob': true,
            },
          );
        }
      }

      final content = jsonDecodeString(json['content']);
      if (content.isNotEmpty) {
        return CoreResult.success(
          data: {'uri': resourceUri, 'content': content, 'mimeType': mimeType},
        );
      }

      final payload = <String, Object?>{...json}
        ..remove('content')
        ..remove('mimeType')
        ..remove('blob')
        ..remove('isBlob');
      final message = jsonDecodeString(payload['message']);
      payload.remove('message');
      final normalizedPayload = <String, Object?>{
        if (message.isNotEmpty) 'message': message,
        if (payload.isNotEmpty) 'parameters': payload,
      };

      return CoreResult.success(
        data: {
          'uri': resourceUri,
          'content': jsonEncode(normalizedPayload),
          'mimeType': 'application/json',
          if (message.isNotEmpty) 'message': message,
          if (payload.isNotEmpty) 'payload': payload,
        },
      );
    } catch (e) {
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

  List<String> _resourceExtensionCandidates({
    required final Uri parsed,
    required final String fallback,
  }) {
    final candidates = <String>[];

    void addCandidate(final String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || candidates.contains(normalized)) {
        return;
      }
      candidates.add(normalized);
    }

    final pathSegments = parsed.pathSegments
        .where((final segment) => segment.trim().isNotEmpty)
        .toList();
    if (pathSegments.isNotEmpty) {
      addCandidate(pathSegments.last);
      if (pathSegments.length > 1) {
        addCandidate(pathSegments.join('_'));
      }
    } else {
      addCandidate(fallback);
    }

    return candidates;
  }

  bool _isUnknownExtensionMethodError(final Object error) {
    final text = '$error'.toLowerCase();
    return text.contains('unknown method') ||
        text.contains('not found') ||
        text.contains('extension call returned null') ||
        text.contains('-32601');
  }
}

String encodeDynamicPayload(final Object? payload) {
  try {
    return jsonEncode(payload);
  } on Exception {
    return '$payload';
  }
}
