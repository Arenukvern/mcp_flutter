// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

// ignore_for_file: lines_longer_than_80_chars

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/port_scanner.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/vm_service_support.dart';
import 'package:from_json_to_json/from_json_to_json.dart';
import 'package:vm_service/vm_service.dart';

/// Handles VM-related tools and functionality for the Flutter Inspector.
class VMToolsHandler {
  /// Creates a new [VMToolsHandler] instance.
  VMToolsHandler({required this.server, required this.vmService});
  final BaseMCPToolkitServer server;
  final VMServiceSupport vmService;
  late final _portScanner = PortScanner(server: server);

  static final hotRestartTool = Tool(
    name: 'hot_restart_flutter',
    description: 'Hot restarts the Flutter app.',
    inputSchema: Schema.object(
      properties: {
        'port': Schema.int(
          description:
              'Optional: Custom port number if not using default Flutter debug port 8181',
        ),
      },
    ),
  );

  // Tool definitions
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

  /// Hot restart the Flutter application.
  Future<CallToolResult> hotRestart(final CallToolRequest request) async {
    server.log(
      LoggingLevel.info,
      'Executing hot restart tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Hot restart tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await vmService.hotRestart();
      return CallToolResult(content: [TextContent(text: jsonEncode(result))]);
    } on Exception catch (e, s) {
      server.log(
        LoggingLevel.error,
        'Hot restart tool failed: $e',
        logger: 'FlutterInspector',
      );
      server.log(
        LoggingLevel.debug,
        () => 'Stack trace: $s',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Hot restart failed: $e')],
      );
    }
  }

  /// Hot reload the Flutter application.
  Future<CallToolResult> hotReload(final CallToolRequest request) async {
    server.log(
      LoggingLevel.info,
      'Executing hot reload tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Hot reload tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }
    try {
      final force = jsonDecodeBool(request.arguments?['force']);
      server.log(
        LoggingLevel.debug,
        'Hot reload force parameter: $force',
        logger: 'FlutterInspector',
      );

      final result = await vmService.hotReload(force: force);

      server.log(
        LoggingLevel.info,
        'Hot reload tool completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [
          TextContent(text: 'Hot reload completed'),
          TextContent(text: jsonEncode(result)),
        ],
      );
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Hot reload tool failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Hot reload failed: $e')],
      );
    }
  }

  /// Get VM information.
  Future<CallToolResult> getVm(final CallToolRequest request) async {
    server.log(
      LoggingLevel.info,
      'Executing get VM tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Get VM tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }
    try {
      final vm = await vmService.vmService!.getVM();

      server
        ..log(
          LoggingLevel.info,
          'Get VM tool completed successfully',
          logger: 'FlutterInspector',
        )
        ..log(
          LoggingLevel.debug,
          () => 'VM info: ${vm.name} v${vm.version}',
          logger: 'FlutterInspector',
        );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(vm.toJson()))],
      );
    } on Exception catch (e, s) {
      server.log(
        LoggingLevel.error,
        'Get VM tool failed: $e\nStack trace: $s',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get VM info: $e')],
      );
    }
  }

  /// Get available extension RPCs.
  Future<CallToolResult> getExtensionRpcs(final CallToolRequest request) async {
    server.log(
      LoggingLevel.info,
      'Executing get extension RPCs tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Get extension RPCs tool failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }
    try {
      final vm = await vmService.vmService!.getVM();
      final allExtensions = <String>[];

      server.log(
        LoggingLevel.debug,
        'Scanning ${vm.isolates?.length ?? 0} isolates for extensions',
        logger: 'FlutterInspector',
      );
      for (final isolateRef in vm.isolates ?? <IsolateRef>[]) {
        final isolate = await vmService.vmService!.getIsolate(isolateRef.id!);
        if (isolate.extensionRPCs != null) {
          allExtensions.addAll(isolate.extensionRPCs!);
          server.log(
            LoggingLevel.debug,
            'Found ${isolate.extensionRPCs!.length} extensions in isolate ${isolateRef.id}',
            logger: 'FlutterInspector',
          );
        }
      }

      final uniqueExtensions = allExtensions.toSet().toList();
      server
        ..log(
          LoggingLevel.info,
          'Get extension RPCs tool completed: found ${uniqueExtensions.length} unique extensions',
          logger: 'FlutterInspector',
        )
        ..log(
          LoggingLevel.debug,
          () => 'Extensions: $uniqueExtensions',
          logger: 'FlutterInspector',
        );

      return CallToolResult(
        content: [TextContent(text: jsonEncode(uniqueExtensions))],
      );
    } on Exception catch (e, s) {
      server.log(
        LoggingLevel.error,
        'Get extension RPCs tool failed: $e\nStack trace: $s',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get extension RPCs: $e')],
      );
    }
  }

  /// Get active ports.
  Future<CallToolResult> getActivePorts(final CallToolRequest request) async {
    server.log(
      LoggingLevel.info,
      'Executing get active ports tool',
      logger: 'FlutterInspector',
    );

    try {
      final ports = await _portScanner.scanForFlutterPorts();
      server
        ..log(
          LoggingLevel.info,
          'Get active ports completed: found ${ports.length} ports',
          logger: 'FlutterInspector',
        )
        ..log(
          LoggingLevel.debug,
          () => 'Active ports: $ports',
          logger: 'FlutterInspector',
        );
      return CallToolResult(content: [TextContent(text: jsonEncode(ports))]);
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Get active ports failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Failed to get active ports: $e')],
      );
    }
  }
}
