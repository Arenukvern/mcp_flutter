// packages/server_capability_core/lib/src/tools/flutter_inspector_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

import '_internal/handler_helpers.dart';

/// Registers Flutter inspector tools with the host through [context].
///
/// Registers: hot_reload_flutter, hot_restart_flutter, connect_debug_app,
/// discover_debug_apps, get_vm, get_extension_rpcs.
void registerFlutterInspectorTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  // ─────────────────────────────────────────────────────────────────────────
  // hot_reload_flutter
  // ─────────────────────────────────────────────────────────────────────────
  context.registerTool(
    ToolRegistration(
      name: 'hot_reload_flutter',
      description: 'Hot reloads the Flutter app.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'force': <String, Object?>{
            'type': 'boolean',
            'description':
                'If true, forces a hot reload even if there are no source changes',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final force = boolArgOrFalse(args['force']);
        return runCommand(
          runner,
          args,
          HotReloadFlutterCommand(force: force),
          onSuccess: (final data) => CallToolResult(
            content: [
              TextContent(text: 'Hot reload completed'),
              TextContent(text: jsonEncode(data)),
            ],
          ),
        );
      },
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // hot_restart_flutter
  //
  // Full-restart equivalent of hot_reload_flutter; app state is NOT preserved.
  // ─────────────────────────────────────────────────────────────────────────
  context.registerTool(
    ToolRegistration(
      name: 'hot_restart_flutter',
      description:
          'Hot restarts the Flutter app (full restart; state not preserved).',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        return runCommand(runner, args, const HotRestartFlutterCommand());
      },
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // connect_debug_app
  //
  // Special case: the legacy handler calls buildConnectCommandFromArguments
  // with fallbackToAuto: true and executes the ConnectCommand directly —
  // it does NOT use the applyConnectionOverride path. We replicate that here
  // by parsing args ourselves and dispatching directly via runner.execute.
  // ─────────────────────────────────────────────────────────────────────────
  context.registerTool(
    ToolRegistration(
      name: 'connect_debug_app',
      description:
          'Connect to a Flutter debug VM. Use this to select an app when multiple are running.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final parsed = parseConnectionOverrideArguments(
          arguments: args,
          fallbackToAuto: true,
        );
        final parseError = parsed.error;
        if (parseError != null) return toErrorResult(parseError);
        final command = parsed.preconnectCommand ?? const ConnectCommand();
        final result = await runner.execute(command);
        if (!result.ok) return toErrorResult(result);
        return CallToolResult(
          content: [TextContent(text: jsonEncode(result.data))],
        );
      },
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // discover_debug_apps
  //
  // No connection override applied — legacy handler skips it.
  // Schema includes `connection` for fidelity but it is never used.
  // ─────────────────────────────────────────────────────────────────────────
  context.registerTool(
    ToolRegistration(
      name: 'discover_debug_apps',
      description:
          'Discover Flutter debug targets with canonical ws target URIs.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final result = await runner.execute(const DiscoverDebugAppsCommand());
        if (!result.ok) return toErrorResult(result);
        return CallToolResult(
          content: [TextContent(text: jsonEncode(result.data))],
        );
      },
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // get_vm
  // ─────────────────────────────────────────────────────────────────────────
  context.registerTool(
    ToolRegistration(
      name: 'get_vm',
      description:
          'Utility: Get VM information from a Flutter app. This is a VM service method, not a Flutter RPC.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        return runCommand(runner, args, const GetVmCommand());
      },
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // get_extension_rpcs
  //
  // `GetExtensionRpcsCommand` is parameterless; the legacy schema declares
  // `isolateId` and `isRawResponse` as no-op properties — the executor never
  // reads them. They are preserved here for schema fidelity so any existing
  // client passing these fields is not rejected by additionalProperties: false.
  // ─────────────────────────────────────────────────────────────────────────
  context.registerTool(
    ToolRegistration(
      name: 'get_extension_rpcs',
      description:
          'Utility: List all available extension RPCs in the Flutter app.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'isolateId': <String, Object?>{
            'type': 'string',
            'description':
                'Optional specific isolate ID to inspect. If omitted, checks all isolates.',
          },
          'isRawResponse': <String, Object?>{
            'type': 'boolean',
            'description':
                'If true, returns the raw VM response without post-processing.',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        return runCommand(runner, args, const GetExtensionRpcsCommand());
      },
    ),
  );
}
