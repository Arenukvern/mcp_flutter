// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'dart:convert';

import 'package:dart_mcp/server.dart';
import 'package:flutter_inspector_mcp_server/src/base_server.dart';
import 'package:flutter_inspector_mcp_server/src/mixins/vm_service_support.dart';

/// Handles debug-related tools and functionality for the Flutter Inspector.
class DebugToolsHandler {
  /// Creates a new [DebugToolsHandler] instance.
  DebugToolsHandler({required this.server, required this.vmService});
  final BaseMCPToolkitServer server;
  final VMServiceSupport vmService;

  // Tool definitions
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

  /// Debug dump layer tree.
  Future<CallToolResult> debugDumpLayerTree(
    final CallToolRequest request,
  ) async {
    server.log(
      LoggingLevel.info,
      'Executing debug dump layer tree tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Debug dump layer tree failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await vmService.callFlutterExtension(
        'ext.flutter.debugDumpLayerTree',
        args: {},
      );
      server.log(
        LoggingLevel.info,
        'Debug dump layer tree completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(result.json))],
      );
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Debug dump layer tree failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Debug dump layer tree failed: $e')],
      );
    }
  }

  /// Debug dump semantics tree.
  Future<CallToolResult> debugDumpSemanticsTree(
    final CallToolRequest request,
  ) async {
    server.log(
      LoggingLevel.info,
      'Executing debug dump semantics tree tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Debug dump semantics tree failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await vmService.callFlutterExtension(
        'ext.flutter.debugDumpSemanticsTreeInTraversalOrder',
      );
      server.log(
        LoggingLevel.info,
        'Debug dump semantics tree completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(result.json))],
      );
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Debug dump semantics tree failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Debug dump semantics tree failed: $e')],
      );
    }
  }

  /// Debug dump render tree.
  Future<CallToolResult> debugDumpRenderTree(
    final CallToolRequest request,
  ) async {
    server.log(
      LoggingLevel.info,
      'Executing debug dump render tree tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Debug dump render tree failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await vmService.callFlutterExtension(
        'ext.flutter.debugDumpRenderTree',
      );
      server.log(
        LoggingLevel.info,
        'Debug dump render tree completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(result.json))],
      );
    } on Exception catch (e, s) {
      server.log(
        LoggingLevel.error,
        'Debug dump render tree failed: $e\nStack trace: $s',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Debug dump render tree failed: $e')],
      );
    }
  }

  /// Debug dump focus tree.
  Future<CallToolResult> debugDumpFocusTree(
    final CallToolRequest request,
  ) async {
    server.log(
      LoggingLevel.info,
      'Executing debug dump focus tree tool',
      logger: 'FlutterInspector',
    );

    final connected = await vmService.ensureVMServiceConnected();
    if (!connected) {
      server.log(
        LoggingLevel.error,
        'Debug dump focus tree failed: VM service not connected',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'VM service not connected')],
      );
    }

    try {
      final result = await vmService.callFlutterExtension(
        'ext.flutter.debugDumpFocusTree',
        args: {},
      );
      server.log(
        LoggingLevel.info,
        'Debug dump focus tree completed successfully',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        content: [TextContent(text: jsonEncode(result.json))],
      );
    } on Exception catch (e) {
      server.log(
        LoggingLevel.error,
        'Debug dump focus tree failed: $e',
        logger: 'FlutterInspector',
      );
      return CallToolResult(
        isError: true,
        content: [TextContent(text: 'Debug dump focus tree failed: $e')],
      );
    }
  }
}
