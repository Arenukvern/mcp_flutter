// packages/server_capability_core/lib/src/tools/semantic_tools.dart
// Copyright (c) 2025, Flutter Inspector MCP Server authors.
// Licensed under the MIT License.

import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';

import '_internal/handler_helpers.dart';

/// Registers semantic tools with the host through [context].
/// Registers: semantic_snapshot.
void registerSemanticTools(CapabilityContext context) {
  final runner = context.require<CommandRunner>();

  context.registerTool(
    ToolRegistration(
      name: 'semantic_snapshot',
      description: semanticSnapshotToolDescription,
      inputSchema: semanticSnapshotInputSchema(),
      handler: (args) async {
        final rawFields = args['fields'];
        return runCommand(
          runner,
          args,
          SemanticSnapshotCommand(
            identifierPrefix: stringArgOrNull(args['identifierPrefix']),
            labelPrefix: stringArgOrNull(args['labelPrefix']),
            subtreeOf: stringArgOrNull(args['subtreeOf']),
            fields: rawFields is List
                ? rawFields.map((f) => f.toString()).toList()
                : null,
            lens: stringArgOrNull(args['lens']),
            maxNodes: intArgOrNull(args['maxNodes']),
            render: args['render'] == true,
            diff: args['diff'] == true,
          ),
        );
      },
    ),
  );
}
