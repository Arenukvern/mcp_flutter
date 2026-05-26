// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_server/src/capabilities/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/core/core.dart';
import 'package:flutter_mcp_toolkit_server/src/mcp_toolkit_server/server.dart';
import 'package:flutter_mcp_toolkit_server/src/shared_core/shared_core.dart';
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
      'To create new tools/resources: 1) Define AgentCallEntry.tool() or AgentCallEntry.resource() '
      '(namespace, name, description, inputSchema, handler returning AgentResult), '
      '2) Register in the Flutter app (main.dart or bootstrap) via MCPToolkitBinding.addEntries() or addMcpTool(), '
      '3) Use fmt_list_client_tools_and_resources to verify registration, '
      '4) Hot restart the app to activate. '
      '5) Use fmt_client_tool or fmt_client_resource to execute. ';

  static const _exactMatchingText =
      'Names/URIs must match exactly what appears in fmt_list_client_tools_and_resources. ';

  static const _schemaComplianceText =
      "Arguments should conform to the tool's inputSchema requirements. ";

  static const _listClientToolsAndResourcesDescription =
      'Discover all dynamically registered tools and resources from the connected Flutter application. '
      'Use this as your first step to understand what debugging and inspection capabilities are available. '
      'Returns tool definitions with names, descriptions, and input schemas, plus available resources with URIs. '
      "Essential for planning your debugging workflow and understanding the app's current MCP toolkit setup. "
      '\n\n$_setupWorkflowText'
      'See flutter-mcp-toolkit-custom-tools skill for AgentCallEntry examples.';

  static final listClientToolsAndResources = Tool(
    name: 'fmt_list_client_tools_and_resources',
    description: _listClientToolsAndResourcesDescription,
    inputSchema: strictToolInputSchema(),
  );

  static final runClientTool = Tool(
    name: 'fmt_client_tool',
    description:
        'Execute a specific dynamically registered tool from the Flutter application. '
        'Use this to run debugging tools, inspect app state, take screenshots, analyze errors, or execute custom tools. '
        '$_exactMatchingText'
        '$_schemaComplianceText'
        'This is your primary way to interact with Flutter app functionality beyond static MCP server tools. '
        '\n\nFor custom tools: $_setupWorkflowText'
        'Example: AgentCallEntry.tool(namespace: "app", name: "my_tool", ...) then addEntries; hot restart.',
    inputSchema: strictToolInputSchema(
      required: ['toolName'],
      properties: {
        'toolName': Schema.string(
          description:
              'Exact name of the tool to execute (from fmt_list_client_tools_and_resources)',
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
    name: 'fmt_client_resource',
    description:
        'Read content from a dynamically registered resource in the Flutter application. '
        'Resources provide structured data like app state, view details, or configuration information. '
        "Use this to access read-only information that doesn't require tool execution. "
        '$_exactMatchingText'
        'Typically used for getting current app state snapshots or accessing structured data. '
        '\n\nFor custom resources: $_setupWorkflowText'
        'Example: AgentCallEntry.resource(namespace: "app", name: "my_resource", ...) then addEntries; hot restart.',
    inputSchema: strictToolInputSchema(
      required: ['resourceUri'],
      properties: {
        'resourceUri': Schema.string(
          description:
              'Exact URI of the resource to read (from fmt_list_client_tools_and_resources)',
        ),
      },
    ),
  );

  Map<Tool, FutureOr<CallToolResult> Function(CallToolRequest)> get allTools =>
      {
        listClientToolsAndResources: _handleListClientToolsAndResources,
        runClientTool: _handleRunClientTool,
        runClientResource: _handleRunClientResource,
      };

  FutureOr<CallToolResult> _handleListClientToolsAndResources(
    final CallToolRequest request,
  ) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: _executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final result = await _executor.execute(
      const ListClientToolsAndResourcesCommand(),
    );
    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Failed to list dynamic tools/resources',
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
    final connectError = await applyConnectionOverride(
      request: request,
      executor: _executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final arguments = request.arguments;
    final toolName = jsonDecodeString(arguments?['toolName']);
    if (toolName.isEmpty) {
      return toCallToolErrorResult(
        CoreResult.failure(
          code: CoreErrorCode.missingToolName,
          message: 'Missing required parameter: toolName',
        ),
        prefix: 'Dynamic tool execution failed',
      );
    }

    final toolArguments = jsonDecodeMapAs<String, Object?>(
      arguments?['arguments'],
    );

    final result = await _executor.execute(
      RunClientToolCommand(toolName: toolName, arguments: toolArguments),
    );

    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Dynamic tool execution failed',
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
    final connectError = await applyConnectionOverride(
      request: request,
      executor: _executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final arguments = request.arguments;
    final resourceUri = jsonDecodeString(arguments?['resourceUri']);
    if (resourceUri.isEmpty) {
      return toCallToolErrorResult(
        CoreResult.failure(
          code: CoreErrorCode.missingResourceUri,
          message: 'Missing required parameter: resourceUri',
        ),
        prefix: 'Dynamic resource read failed',
      );
    }

    final result = await _executor.execute(
      RunClientResourceCommand(resourceUri: resourceUri),
    );

    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Dynamic resource read failed',
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
