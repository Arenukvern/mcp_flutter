// flutter_mcp_toolkit_capability_core/lib/src/tools/debug_dump_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

import '_internal/handler_helpers.dart';

/// Registers debug dump tools with the host through [context].
///
/// Registers: debug_dump_layer_tree, debug_dump_semantics_tree,
/// debug_dump_render_tree, debug_dump_focus_tree.
///
/// These tools are heavy operations. The [FmtCapability] gates registration
/// on `context.config.getBool('dumps_supported', defaultValue: false)` so they
/// are only exposed when the host has opted in (matching the legacy server's
/// `--dumps` flag behaviour).
void registerDebugDumpTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    ToolRegistration(
      name: 'debug_dump_layer_tree',
      description: 'Dumps the layer tree of the Flutter app.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        return runCommand(runner, args, const DebugDumpLayerTreeCommand());
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'debug_dump_semantics_tree',
      description: 'Dumps the semantics tree of the Flutter app.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        return runCommand(runner, args, const DebugDumpSemanticsTreeCommand());
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'debug_dump_render_tree',
      description: 'Dumps the render tree of the Flutter app.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        return runCommand(runner, args, const DebugDumpRenderTreeCommand());
      },
    ),
  );

  context.registerTool(
    ToolRegistration(
      name: 'debug_dump_focus_tree',
      description: 'Dumps the focus tree of the Flutter app.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        return runCommand(runner, args, const DebugDumpFocusTreeCommand());
      },
    ),
  );
}
