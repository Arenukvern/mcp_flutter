// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';

/// Thin MCP adapter for debug-dump tools.
class DebugToolsHandler {
  DebugToolsHandler({required this.server, required this.executor});

  final BaseMCPToolkitServer server;
  final CoreCommandExecutor executor;

  static final debugDumpLayerTreeTool = Tool(
    name: 'debug_dump_layer_tree',
    description: 'Dumps the layer tree of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  static final debugDumpSemanticsTreeTool = Tool(
    name: 'debug_dump_semantics_tree',
    description: 'Dumps the semantics tree of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  static final debugDumpRenderTreeTool = Tool(
    name: 'debug_dump_render_tree',
    description: 'Dumps the render tree of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  static final debugDumpFocusTreeTool = Tool(
    name: 'debug_dump_focus_tree',
    description: 'Dumps the focus tree of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  Future<CallToolResult> debugDumpLayerTree(final CallToolRequest request) =>
      _run(const DebugDumpLayerTreeCommand(), 'Debug dump layer tree failed');

  Future<CallToolResult> debugDumpSemanticsTree(
    final CallToolRequest request,
  ) => _run(
    const DebugDumpSemanticsTreeCommand(),
    'Debug dump semantics tree failed',
  );

  Future<CallToolResult> debugDumpRenderTree(final CallToolRequest request) =>
      _run(const DebugDumpRenderTreeCommand(), 'Debug dump render tree failed');

  Future<CallToolResult> debugDumpFocusTree(final CallToolRequest request) =>
      _run(const DebugDumpFocusTreeCommand(), 'Debug dump focus tree failed');

  Future<CallToolResult> _run(
    final CoreCommand command,
    final String errorPrefix,
  ) async {
    final result = await executor.execute(command);
    if (!result.ok) {
      return CallToolResult(
        isError: true,
        content: [TextContent(text: _errorText(result, prefix: errorPrefix))],
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  String _errorText(final CoreResult result, {required final String prefix}) {
    final message = result.error?.message ?? 'Unknown error';
    if (message == 'VM service not connected') {
      return message;
    }
    return '$prefix: $message';
  }
}
