// mcp_capability_core/lib/src/tools/semantic_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

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
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        return runCommand(runner, args, const SemanticSnapshotCommand());
      },
    ),
  );
}
