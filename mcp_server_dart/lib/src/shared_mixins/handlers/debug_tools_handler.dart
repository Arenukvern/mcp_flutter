// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/commands/commands_specs.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/commands/commands_catalogue.dart';
import 'package:flutter_inspector_mcp_server/src/shared_core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/shared_mixins/handlers/connection_override.dart';

/// Thin MCP adapter for debug-dump tools.
class DebugToolsHandler {
  DebugToolsHandler({required this.server, required this.executor});

  final BaseMCPToolkitServer server;
  final CoreCommandExecutor executor;
  static final _catalog = CommandCatalog.instance;

  static String _description(final String name, final String fallback) =>
      _catalog.specFor(name)?.description ?? fallback;

  static final debugDumpLayerTreeTool = Tool(
    name: 'debug_dump_layer_tree',
    description: _description(
      'debug_dump_layer_tree',
      'Dumps the layer tree of the Flutter app.',
    ),
    inputSchema: strictToolInputSchema(),
  );

  static final debugDumpSemanticsTreeTool = Tool(
    name: 'debug_dump_semantics_tree',
    description: _description(
      'debug_dump_semantics_tree',
      'Dumps the semantics tree of the Flutter app.',
    ),
    inputSchema: strictToolInputSchema(),
  );

  static final debugDumpRenderTreeTool = Tool(
    name: 'debug_dump_render_tree',
    description: _description(
      'debug_dump_render_tree',
      'Dumps the render tree of the Flutter app.',
    ),
    inputSchema: strictToolInputSchema(),
  );

  static final debugDumpFocusTreeTool = Tool(
    name: 'debug_dump_focus_tree',
    description: _description(
      'debug_dump_focus_tree',
      'Dumps the focus tree of the Flutter app.',
    ),
    inputSchema: strictToolInputSchema(),
  );

  Future<CallToolResult> debugDumpLayerTree(final CallToolRequest request) =>
      _run(
        const DebugDumpLayerTreeCommand(),
        'Debug dump layer tree failed',
        request: request,
      );

  Future<CallToolResult> debugDumpSemanticsTree(
    final CallToolRequest request,
  ) => _run(
    const DebugDumpSemanticsTreeCommand(),
    'Debug dump semantics tree failed',
    request: request,
  );

  Future<CallToolResult> debugDumpRenderTree(final CallToolRequest request) =>
      _run(
        const DebugDumpRenderTreeCommand(),
        'Debug dump render tree failed',
        request: request,
      );

  Future<CallToolResult> debugDumpFocusTree(final CallToolRequest request) =>
      _run(
        const DebugDumpFocusTreeCommand(),
        'Debug dump focus tree failed',
        request: request,
      );

  Future<CallToolResult> _run(
    final CoreCommand command,
    final String errorPrefix, {
    required final CallToolRequest request,
  }) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError != null) {
      return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
    }

    final result = await executor.execute(command);
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: errorPrefix);
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }
}
