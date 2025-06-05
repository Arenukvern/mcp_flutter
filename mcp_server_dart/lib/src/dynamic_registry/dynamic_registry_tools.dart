// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:async';
import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/dynamic_registry/dynamic_registry.dart';
import 'package:flutter_inspector_mcp_server/src/server.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:meta/meta.dart';

/// MCP tools for managing dynamic registry
/// These tools allow clients to interact with dynamically registered tools and resources
@immutable
final class DynamicRegistryTools {
  const DynamicRegistryTools({required this.registry});

  final DynamicRegistry registry;

  // Reusable text constants for setup instructions
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

  /// Tool to list all client tools and resources
  static final listClientToolsAndResources = Tool(
    name: 'listClientToolsAndResources',
    description: _listClientToolsAndResourcesDescription,
    inputSchema: ObjectSchema(properties: {}),
  );

  /// Tool to run a client tool
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

  /// Tool to read a client resource
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

  /// Tool to get registry statistics
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

  /// Get all management tools
  Map<Tool, FutureOr<CallToolResult> Function(CallToolRequest)> get allTools =>
      {
        listClientToolsAndResources: _handleListClientToolsAndResources,
        runClientTool: _handleRunClientTool,
        runClientResource: _handleRunClientResource,
        if (kDebugMode) getRegistryStats: _handleGetRegistryStats,
      };

  FutureOr<CallToolResult> _handleListClientToolsAndResources(
    final CallToolRequest request,
  ) {
    final toolEntries = registry.getToolEntries();
    final resourceEntries = registry.getResourceEntries();

    final result = <String, dynamic>{
      'tools': toolEntries.map((final entry) => entry.tool).toList(),
      'resources':
          resourceEntries.map((final entry) => entry.resource).toList(),
      'summary': {
        'totalTools': toolEntries.length,
        'totalResources': resourceEntries.length,
      },
    };

    if (resourceEntries.isEmpty) {
      result['resources'] = [];
    }

    return CallToolResult(
      content: [
        TextContent(text: _setupWorkflowText),
        TextContent(text: jsonEncode(result)),
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

    // Forward to the dynamic registry
    final result = await registry.forwardToolCall(toolName, toolArguments);

    if (result == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Tool not found: $toolName. '
                'Use listClientToolsAndResources to see available tools.',
          ),
        ],
        isError: true,
      );
    }

    return result;
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

    // Forward to the dynamic registry
    final content = await registry.forwardResourceRead(resourceUri);

    if (content == null) {
      return CallToolResult(
        content: [
          TextContent(
            text:
                'Resource not found: $resourceUri. '
                'Use listClientToolsAndResources to see available resources.',
          ),
        ],
        isError: true,
      );
    }

    return CallToolResult(
      content: content.contents.map((final c) => c.toContent()).toList(),
      isError: false,
    );
  }

  FutureOr<CallToolResult> _handleGetRegistryStats(
    final CallToolRequest request,
  ) {
    final arguments = request.arguments;
    final includeAppDetails = jsonDecodeBool(arguments?['includeAppDetails']);
    final info = registry.appInfo;
    if (info == null) {
      return CallToolResult(
        content: [TextContent(text: 'No app info available')],
        isError: true,
      );
    }

    final result = <String, dynamic>{
      'toolCount': info.toolCount,
      'resourceCount': info.resourceCount,
      if (includeAppDetails) ...info,
    };

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result))],
      isError: false,
    );
  }
}

extension on ResourceContents {
  Content toContent() {
    final mimeType = this.mimeType;
    if (mimeType == null ||
        mimeType.startsWith('text/') ||
        mimeType.startsWith('application/')) {
      final textContent = this as TextResourceContents;
      return TextContent(text: textContent.text);
    } else if (mimeType.startsWith('image/')) {
      return ImageContent(
        data: (this as BlobResourceContents).blob,
        mimeType: mimeType,
      );
    } else if (mimeType.startsWith('audio/')) {
      return AudioContent(
        data: (this as BlobResourceContents).blob,
        mimeType: mimeType,
      );
    } else {
      return TextContent(text: 'Unsupported resource contents type: $this');
    }
  }
}
