// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/core/results.dart';
import 'package:from_json_to_json/from_json_to_json.dart';

/// Thin MCP adapter for VM-related tools.
class VMToolsHandler {
  VMToolsHandler({required this.server, required this.executor});

  final BaseMCPToolkitServer server;
  final CoreCommandExecutor executor;

  static final hotRestartTool = Tool(
    name: 'hot_restart_flutter',
    description:
        'Hot restarts the Flutter app (full restart; state not preserved).',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  static final hotReloadTool = Tool(
    name: 'hot_reload_flutter',
    description: 'Hot reloads the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
        'force': Schema.bool(
          description:
              'If true, forces a hot reload even if there are no changes to the source code',
        ),
      },
    ),
  );

  static final getVmTool = Tool(
    name: 'get_vm',
    description:
        'Utility: Get VM information from a Flutter app. This is a VM service method, not a Flutter RPC.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  static final getExtensionRpcsTool = Tool(
    name: 'get_extension_rpcs',
    description:
        'Utility: List all available extension RPCs in the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
        'isolateId': Schema.string(
          description:
              'Optional specific isolate ID to check. If not provided, checks all isolates',
        ),
        'isRawResponse': Schema.bool(
          description:
              'If true, returns the raw response from the VM service without processing',
        ),
      },
    ),
  );

  static final getActivePortsTool = Tool(
    name: 'get_active_ports',
    description: 'Gets the active ports of the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  Future<CallToolResult> hotRestart(final CallToolRequest request) async {
    final result = await executor.execute(const HotRestartFlutterCommand());
    if (!result.ok) {
      return _errorResult(_errorText(result, prefix: 'Hot restart failed'));
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> hotReload(final CallToolRequest request) async {
    final force = jsonDecodeBool(request.arguments?['force']);
    final result = await executor.execute(
      HotReloadFlutterCommand(force: force),
    );

    if (!result.ok) {
      return _errorResult(_errorText(result, prefix: 'Hot reload failed'));
    }

    return CallToolResult(
      content: [
        TextContent(text: 'Hot reload completed'),
        TextContent(text: jsonEncode(result.data)),
      ],
    );
  }

  Future<CallToolResult> getVm(final CallToolRequest request) async {
    final result = await executor.execute(const GetVmCommand());
    if (!result.ok) {
      return _errorResult(_errorText(result, prefix: 'Failed to get VM info'));
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> getExtensionRpcs(final CallToolRequest request) async {
    final result = await executor.execute(const GetExtensionRpcsCommand());
    if (!result.ok) {
      return _errorResult(
        _errorText(result, prefix: 'Failed to get extension RPCs'),
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> getActivePorts(final CallToolRequest request) async {
    final result = await executor.execute(const GetActivePortsCommand());
    if (!result.ok) {
      return _errorResult(
        _errorText(result, prefix: 'Failed to get active ports'),
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  CallToolResult _errorResult(final String message) =>
      CallToolResult(isError: true, content: [TextContent(text: message)]);

  String _errorText(final CoreResult result, {required final String prefix}) {
    final message = result.error?.message ?? 'Unknown error';
    if (message == 'VM service not connected') {
      return message;
    }
    return '$prefix: $message';
  }
}
