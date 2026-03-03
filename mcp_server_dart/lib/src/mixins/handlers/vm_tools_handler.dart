// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/core/command_catalog.dart';
import 'package:flutter_inspector_mcp_server/src/core/commands.dart';
import 'package:flutter_inspector_mcp_server/src/core/executor.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/handlers/connection_override.dart';
import 'package:from_json_to_json/from_json_to_json.dart';

/// Thin MCP adapter for VM-related tools.
class VMToolsHandler {
  VMToolsHandler({required this.server, required this.executor});

  final BaseMCPToolkitServer server;
  final CoreCommandExecutor executor;
  static final _catalog = CommandCatalog.instance;

  static String _description(final String name, final String fallback) =>
      _catalog.specFor(name)?.description ?? fallback;

  static final connectDebugAppTool = Tool(
    name: 'connect_debug_app',
    description:
        'Connect to a Flutter debug VM. Use this to select an app when multiple are running.',
    inputSchema: strictToolInputSchema(),
  );

  static final hotRestartTool = Tool(
    name: 'hot_restart_flutter',
    description: _description(
      'hot_restart_flutter',
      'Hot restarts the Flutter app (full restart; state not preserved).',
    ),
    inputSchema: strictToolInputSchema(),
  );

  static final hotReloadTool = Tool(
    name: 'hot_reload_flutter',
    description: _description(
      'hot_reload_flutter',
      'Hot reloads the Flutter app.',
    ),
    inputSchema: strictToolInputSchema(
      properties: {
        'force': Schema.bool(
          description:
              'If true, forces a hot reload even if there are no source changes',
        ),
      },
    ),
  );

  static final getVmTool = Tool(
    name: 'get_vm',
    description: _description(
      'get_vm',
      'Utility: Get VM information from a Flutter app. This is a VM service method, not a Flutter RPC.',
    ),
    inputSchema: strictToolInputSchema(),
  );

  static final getExtensionRpcsTool = Tool(
    name: 'get_extension_rpcs',
    description: _description(
      'get_extension_rpcs',
      'Utility: List all available extension RPCs in the Flutter app.',
    ),
    inputSchema: strictToolInputSchema(
      properties: {
        'isolateId': Schema.string(
          description:
              'Optional specific isolate ID to inspect. If omitted, checks all isolates.',
        ),
        'isRawResponse': Schema.bool(
          description:
              'If true, returns the raw VM response without post-processing.',
        ),
      },
    ),
  );

  static final getActivePortsTool = Tool(
    name: 'get_active_ports',
    description: _description(
      'get_active_ports',
      'Gets active debug ports for Flutter/Dart processes (useful for selecting an app).',
    ),
    inputSchema: Schema.object(properties: const <String, Schema>{}),
  );

  Future<CallToolResult> connectDebugApp(final CallToolRequest request) async {
    final resolved = buildConnectCommandFromArguments(
      arguments: request.arguments,
      fallbackToAuto: true,
    );
    final parseError = resolved.error;
    if (parseError != null) {
      return toCallToolErrorResult(parseError, prefix: 'Failed to connect');
    }

    final command = resolved.command ?? const ConnectCommand();
    final result = await executor.execute(command);
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to connect');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> hotRestart(final CallToolRequest request) async {
    final overrideError = await _prepareConnectionIfRequested(request);
    if (overrideError != null) {
      return overrideError;
    }

    final result = await executor.execute(const HotRestartFlutterCommand());
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Hot restart failed');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> hotReload(final CallToolRequest request) async {
    final overrideError = await _prepareConnectionIfRequested(request);
    if (overrideError != null) {
      return overrideError;
    }

    final force = jsonDecodeBool(request.arguments?['force']);
    final result = await executor.execute(
      HotReloadFlutterCommand(force: force),
    );

    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Hot reload failed');
    }

    return CallToolResult(
      content: [
        TextContent(text: 'Hot reload completed'),
        TextContent(text: jsonEncode(result.data)),
      ],
    );
  }

  Future<CallToolResult> getVm(final CallToolRequest request) async {
    final overrideError = await _prepareConnectionIfRequested(request);
    if (overrideError != null) {
      return overrideError;
    }

    final result = await executor.execute(const GetVmCommand());
    if (!result.ok) {
      return toCallToolErrorResult(result, prefix: 'Failed to get VM info');
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> getExtensionRpcs(final CallToolRequest request) async {
    final overrideError = await _prepareConnectionIfRequested(request);
    if (overrideError != null) {
      return overrideError;
    }

    final result = await executor.execute(const GetExtensionRpcsCommand());
    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Failed to get extension RPCs',
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult> getActivePorts(final CallToolRequest request) async {
    final result = await executor.execute(const GetActivePortsCommand());
    if (!result.ok) {
      return toCallToolErrorResult(
        result,
        prefix: 'Failed to get active ports',
      );
    }

    return CallToolResult(
      content: [TextContent(text: jsonEncode(result.data))],
    );
  }

  Future<CallToolResult?> _prepareConnectionIfRequested(
    final CallToolRequest request,
  ) async {
    final connectError = await applyConnectionOverride(
      request: request,
      executor: executor,
    );
    if (connectError == null) {
      return null;
    }

    return toCallToolErrorResult(connectError, prefix: 'Failed to connect');
  }
}
