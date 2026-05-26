// packages/server_capability_core/lib/src/tools/log_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

import '_internal/handler_helpers.dart';
import 'codegen/get_recent_logs_tool.dart';

Map<String, Object?> _mergeConnectionSchema(final Map<String, Object?> schema) {
  final merged = <String, Object?>{
    ...schema,
    'additionalProperties': false,
    'properties': <String, Object?>{
      ...(schema['properties'] as Map<String, Object?>),
      'connection': connectionOverrideJsonSchema(),
    },
  };
  final required = merged['required'];
  if (required is List && required.isEmpty) {
    merged.remove('required');
  }
  return merged;
}

/// Registers log tools with the host through [context].
/// Registers: get_recent_logs (via `@AgentTool` codegen).
void registerLogTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    agentCallEntryToToolRegistration(
      getRecentLogsCallEntry,
      mergeInputSchema: _mergeConnectionSchema,
      handler: (final args) async {
        final countRaw = intArgOrNull(args['count']);
        return runCommand(
          runner,
          args,
          GetRecentLogsCommand(count: countRaw ?? 50),
        );
      },
    ),
  );
}
