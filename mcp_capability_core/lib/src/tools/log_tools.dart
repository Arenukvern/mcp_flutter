// mcp_capability_core/lib/src/tools/log_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:mcp_capability_kernel/mcp_capability_kernel.dart';
import 'package:mcp_shared_core/mcp_shared_core.dart';

import '_internal/handler_helpers.dart';

/// Registers log tools with the host through [context].
/// Registers: get_recent_logs.
void registerLogTools(final CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    ToolRegistration(
      name: 'get_recent_logs',
      description:
          'Get recent print() and log output from the running Flutter app.',
      inputSchema: <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'properties': <String, Object?>{
          'count': <String, Object?>{
            'type': 'integer',
            'description': 'Number of recent log entries (default: 50).',
          },
          'connection': connectionOverrideJsonSchema(),
        },
      },
      handler: (final request) async {
        final args = request.arguments ?? const <String, Object?>{};
        final countRaw = intArgOrNull(args['count']);
        final count = countRaw ?? 50;
        return runCommand(runner, args, GetRecentLogsCommand(count: count));
      },
    ),
  );
}
