import 'package:agentkit_core/agentkit_core.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';

RegisteredAgentIntent toolRegistrationToRegistration({
  required final String capabilityId,
  required final ToolRegistration registration,
}) {
  return RegisteredAgentIntent(
    descriptor: AgentIntentDescriptor(
      namespace: capabilityId,
      name: registration.name,
      description: registration.description,
      kind: AgentIntentKind.tool,
      inputSchema: registration.inputSchema,
    ),
    execute: (final invocation) => registration.handler(invocation.arguments),
  );
}

RegisteredAgentIntent resourceRegistrationToRegistration({
  required final String capabilityId,
  required final ResourceRegistration registration,
}) {
  return RegisteredAgentIntent(
    descriptor: AgentIntentDescriptor(
      namespace: capabilityId,
      name: registration.name,
      description: registration.description,
      kind: AgentIntentKind.resource,
      inputSchema: const <String, Object?>{'type': 'object'},
      resourceUri: registration.uri,
      mimeType: registration.mimeType,
    ),
    execute: (final invocation) {
      final uri = invocation.arguments['uri'];
      return registration.handler(uri is String ? uri : registration.uri);
    },
  );
}
