import 'package:agentkit_core/agentkit_core.dart';
import 'package:dart_mcp/server.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';

import 'mcp_result_mapper.dart';

RegisteredAgentIntent toolRegistrationToRegistration({
  required final String capabilityId,
  required final ToolRegistration registration,
}) {
  final qualified = applyPrefix(
    capabilityId: capabilityId,
    name: registration.name,
  );
  return RegisteredAgentIntent(
    descriptor: AgentIntentDescriptor(
      namespace: capabilityId,
      name: registration.name,
      description: registration.description,
      kind: AgentIntentKind.tool,
      inputSchema: registration.inputSchema,
    ),
    execute: (final invocation) async {
      final mcpResult = await registration.handler(
        CallToolRequest(name: qualified, arguments: invocation.arguments),
      );
      return mcpResultToAgentResult(mcpResult);
    },
  );
}
