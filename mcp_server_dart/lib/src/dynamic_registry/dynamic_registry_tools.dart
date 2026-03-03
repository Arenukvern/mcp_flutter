// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';
import 'package:flutter_inspector_mcp_server/src/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_inspector_mcp_server/src/server.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:is_dart_empty_or_not/is_dart_empty_or_not.dart';
import 'package:meta/meta.dart';

/// MCP tools for managing dynamic registry via shared core command surface.
@immutable
final class DynamicRegistryTools {
  const DynamicRegistryTools({required this.registry, required this.server});

  final DynamicRegistry registry;
  final MCPToolkitServer server;

  CoreCommandExecutor get _executor => server.coreCommandExecutor;

  static const _setupWorkflowText =
      'To create new tools/resources: 1) Generate MCPCallEntry.tool() or MCPCallEntry.resource() with handler and definition, '
      '2) Add to Flutter app (in main.dart, widget tree, or state management like provider/riverpod) using addMcpTool(), '
      '3) Use listClientToolsAndResources to verify the tool is registered, '
      '4) Hot reload the app to activate. '
      '5) Use runClientTool to execute the tool. ';

  static const _exactMatchingText =
      'Names/URIs must match exactly what appears in listClientToolsAndResources. ';

  static const _schemaComplianceText =
      "Arguments should conform to the tool's inputSchema requirements. ";

  static const _listClientToolsAndResourcesDescription =
      'Discover all dynamically registered tools and resources from the connected Flutter application. '
      'Use this as your first step to understand what debugging and inspection capabilities are available. '
      'Returns tool definitions with names, descriptions, and input schemas, plus available resources with URIs. '
      "Essential for planning your debugging workflow and understanding the app's current MCP toolkit setup. "
      '\n\n$_setupWorkflowText'
      'See server instructions for detailed examples of creating custom MCPCallEntry definitions.';

  static final listClientToolsAndResources = Tool(
    name: 'listClientToolsAndResources',
    description: _listClientToolsAndResourcesDescription,
    inputSchema: ObjectSchema(properties: {}),
  );

  static final runClientTool = Tool(
    name: 'runClientTool',
    description:
        'Execute a specific dynamically registered tool from the Flutter application. '
        'Use this to run debugging tools, inspect app state, take screenshots, analyze errors, or execute custom tools. '
        '$_exactMatchingText'
        '$_schemaComplianceText'
        'This is your primary way to interact with Flutter app functionality beyond static MCP server tools. '
        '\n\nFor custom tools: $_setupWorkflowText'
        'Example: Create MCPCallEntry.tool() with handler: (params) => MCPCallResult(...), then register and hot reload.',
    inputSchema: ObjectSchema(
      required: ['toolName'],
      properties: {
        'toolName': Schema.string(
          description:
              'Exact name of the tool to execute (from listClientToolsAndResources)',
        ),
        'arguments': Schema.object(
          description:
              'Arguments to pass to the tool, matching its inputSchema requirements',
          additionalProperties: true,
        ),
      },
    ),
  );

  static final runClientResource = Tool(
    name: 'runClientResource',
    description:
        'Read content from a dynamically registered resource in the Flutter application. '
        'Resources provide structured data like app state, view details, or configuration information. '
        "Use this to access read-only information that doesn't require tool execution. "
        '$_exactMatchingText'
        'Typically used for getting current app state snapshots or accessing structured data. '
        '\n\nFor custom resources: $_setupWorkflowText'
        'Example: Create MCPCallEntry.resource() with handler: (uri) => MCPCallResult(...), then register and hot reload.',
    inputSchema: ObjectSchema(
      required: ['resourceUri'],
      properties: {
        'resourceUri': Schema.string(
          description:
              'Exact URI of the resource to read (from listClientToolsAndResources)',
        ),
      },
    ),
  );

  static final getRegistryStats = Tool(
    name: 'getRegistryStats',
    description: 'Get statistics about the dynamic registry',
    inputSchema: ObjectSchema(
      properties: {
        'includeAppDetails': Schema.bool(
          description: 'Include detailed app information (default: true)',
        ),
      },
    ),
  );

  Map<Tool, FutureOr<CallToolResult> Function(CallToolRequest)> get allTools =>
      {
        listClientToolsAndResources: _handleListClientToolsAndResources,
        runClientTool: _handleRunClientTool,
        runClientResource: _handleRunClientResource,
        if (kDebugMode) getRegistryStats: _handleGetRegistryStats,
      };

  FutureOr<CallToolResult> _handleListClientToolsAndResources(
    final CallToolRequest request,
  ) async {
    final result = await _executor.execute(
      const ListClientToolsAndResourcesCommand(),
    );
    if (!result.ok) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: _errorText(result))],
      );
    }

    final data = _map(result.data);
    if (jsonDecodeList(data['resources']).isEmpty) {
      data['resources'] = [];
    }

    return CallToolResult(
      content: [
        TextContent(text: _setupWorkflowText),
        TextContent(text: jsonEncode(data)),
      ],
      isError: false,
    );
  }

  FutureOr<CallToolResult> _handleRunClientTool(
    final CallToolRequest request,
  ) async {
    final arguments = request.arguments;
    final toolName = jsonDecodeString(arguments?['toolName']);
    if (toolName.isEmpty) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required parameter: toolName')],
        isError: true,
      );
    }

    final toolArguments = jsonDecodeMapAs<String, Object?>(
      arguments?['arguments'],
    );

    final result = await _executor.execute(
      RunClientToolCommand(toolName: toolName, arguments: toolArguments),
    );

    if (!result.ok) {
      return CallToolResult(
        content: [TextContent(text: _errorText(result))],
        isError: true,
      );
    }

    final data = _map(result.data);
    final message = jsonDecodeString(
      data['message'],
    ).whenEmptyUse('Tool executed successfully');

    final parameters = data['parameters'] ?? const <String, Object?>{};

    return CallToolResult(
      content: [
        TextContent(text: message),
        TextContent(text: jsonEncode(parameters)),
      ],
      isError: false,
    );
  }

  FutureOr<CallToolResult> _handleRunClientResource(
    final CallToolRequest request,
  ) async {
    final arguments = request.arguments;
    final resourceUri = jsonDecodeString(arguments?['resourceUri']);
    if (resourceUri.isEmpty) {
      return CallToolResult(
        content: [TextContent(text: 'Missing required parameter: resourceUri')],
        isError: true,
      );
    }

    final result = await _executor.execute(
      RunClientResourceCommand(resourceUri: resourceUri),
    );

    if (!result.ok) {
      return CallToolResult(
        content: [TextContent(text: _errorText(result))],
        isError: true,
      );
    }

    final data = _map(result.data);
    final mimeType = jsonDecodeString(
      data['mimeType'],
    ).whenEmptyUse('text/plain');
    if (jsonDecodeBool(data['isBlob'])) {
      final blob = jsonDecodeString(data['blob']);
      if (mimeType.startsWith('image/')) {
        return CallToolResult(
          content: [ImageContent(data: blob, mimeType: mimeType)],
          isError: false,
        );
      }
      if (mimeType.startsWith('audio/')) {
        return CallToolResult(
          content: [AudioContent(data: blob, mimeType: mimeType)],
          isError: false,
        );
      }
      return CallToolResult(content: [TextContent(text: blob)], isError: false);
    }

    final content = jsonDecodeString(data['content']);
    return CallToolResult(
      content: [TextContent(text: content)],
      isError: false,
    );
  }

  FutureOr<CallToolResult> _handleGetRegistryStats(
    final CallToolRequest request,
  ) async {
    final arguments = request.arguments;
    final includeAppDetails = jsonDecodeBool(arguments?['includeAppDetails']);

    final result = await _executor.execute(
      DynamicRegistryStatsCommand(includeAppDetails: includeAppDetails),
    );

    if (!result.ok) {
      return CallToolResult(
        content: [TextContent(text: _errorText(result))],
        isError: true,
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
      isError: false,
    );
  }

  String _errorText(final CoreResult result) =>
      result.error?.message ?? 'Unknown dynamic registry error';

  Map<String, Object?> _map(final Object? data) {
    if (data is Map<String, Object?>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, Object?>();
    }
    return <String, Object?>{};
  }
}
