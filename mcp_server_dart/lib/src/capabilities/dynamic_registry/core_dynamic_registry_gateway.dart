// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/types/error_codes.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/dynamic_registry/dynamic_gateway.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/types/results.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_inspector_mcp_server/src/capabilities/dynamic_registry/registry_discovery_service.dart';

/// Dynamic gateway backed by the live in-process registry used by MCP server.
final class RegistryBackedDynamicGateway implements CoreDynamicGateway {
  RegistryBackedDynamicGateway({
    required this.registry,
    required this.discoveryService,
  });

  final DynamicRegistry registry;
  final RegistryDiscoveryService? Function() discoveryService;

  @override
  Future<CoreResult> listClientToolsAndResources() async {
    await discoveryService()?.registerToolsAndResources();

    final toolEntries = registry.getToolEntries();
    final resourceEntries = registry.getResourceEntries();

    return CoreResult.success(
      data: {
        'tools': toolEntries.map((final e) => e.tool).toList(),
        'resources': resourceEntries.map((final e) => e.resource).toList(),
        'summary': {
          'totalTools': toolEntries.length,
          'totalResources': resourceEntries.length,
        },
      },
    );
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

    final result = await registry.forwardToolCall(toolName, arguments);
    if (result == null) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicToolFailed,
        message: 'Tool not found: $toolName',
        details: {'reason': 'tool_not_found', 'toolName': toolName},
      );
    }

    final textContents = result.content.whereType<TextContent>().toList();
    final message = textContents.isEmpty
        ? 'Tool executed successfully'
        : textContents.first.text;

    Object? parameters = const <String, Object?>{};
    if (textContents.length > 1) {
      try {
        parameters = jsonDecode(textContents[1].text);
      } on Exception {
        parameters = {'raw': textContents[1].text};
      }
    }

    if (result.isError ?? false) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicToolFailed,
        message: message,
        details: parameters,
      );
    }

    return CoreResult.success(
      data: {'message': message, 'parameters': parameters},
    );
  }

  @override
  Future<CoreResult> runClientResource(final String resourceUri) async {
    if (resourceUri.isEmpty) {
      return CoreResult.failure(
        code: CoreErrorCode.missingResourceUri,
        message: 'Missing required parameter: resourceUri',
      );
    }

    final result = await registry.forwardResourceRead(resourceUri);
    if (result == null || result.contents.isEmpty) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicResourceFailed,
        message: 'Resource not found: $resourceUri',
        details: {'reason': 'resource_not_found', 'resourceUri': resourceUri},
      );
    }

    final first = result.contents.first;
    if (first is TextResourceContents) {
      return CoreResult.success(
        data: {
          'uri': resourceUri,
          'content': first.text,
          'mimeType': first.mimeType ?? 'text/plain',
        },
      );
    }

    if (first is BlobResourceContents) {
      return CoreResult.success(
        data: {
          'uri': resourceUri,
          'blob': first.blob,
          'mimeType': first.mimeType ?? 'application/octet-stream',
          'isBlob': true,
        },
      );
    }

    return CoreResult.failure(
      code: CoreErrorCode.dynamicResourceFailed,
      message: 'Unsupported resource content type for $resourceUri',
      details: {
        'reason': 'unsupported_resource_content',
        'resourceUri': resourceUri,
      },
    );
  }

  @override
  Future<CoreResult> dynamicRegistryStats({
    required final bool includeAppDetails,
  }) async {
    final info = registry.appInfo;
    if (info == null) {
      return CoreResult.failure(
        code: CoreErrorCode.dynamicRegistryListFailed,
        message: 'No app info available',
        details: {'reason': 'no_app_info'},
      );
    }

    final result = <String, Object?>{
      'toolCount': info.toolCount,
      'resourceCount': info.resourceCount,
    };

    if (includeAppDetails) {
      result.addAll(info);
    }

    return CoreResult.success(data: result);
  }
}
