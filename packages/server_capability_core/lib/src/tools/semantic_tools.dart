// packages/server_capability_core/lib/src/tools/semantic_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

import '_internal/handler_helpers.dart';

/// Registers semantic tools with the host through [context].
/// Registers: semantic_snapshot.
void registerSemanticTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    ToolRegistration(
      name: 'semantic_snapshot',
      description:
          'Get compact semantic tree of interactive widgets with refs usable '
          'by interaction tools (tap_widget, enter_text, etc.)',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final args) async {
        return runCommand(runner, args, const SemanticSnapshotCommand());
      },
    ),
  );
}
