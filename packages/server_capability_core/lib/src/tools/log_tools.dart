// packages/server_capability_core/lib/src/tools/log_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:intentcall_mcp/intentcall_mcp.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

import '_internal/handler_helpers.dart';
import 'codegen/get_recent_logs_tool.dart';

/// Registers log tools with the host through [context].
///
/// [get_recent_logs] uses `@AgentTool` codegen for the call entry; host
/// registration applies [getRecentLogsInputSchema] via [mergeInputSchema] so
/// discovery matches dynamic tools even if `.g.dart` is regenerated without
/// connection / `additionalProperties: false`.
void registerLogTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    agentCallEntryToToolRegistration(
      getRecentLogsCallEntry,
      mergeInputSchema: (_) => getRecentLogsInputSchema(),
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
