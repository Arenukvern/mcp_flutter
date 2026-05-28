import 'package:agentkit_core/agentkit_core.dart';
import 'package:flutter_mcp_toolkit_core/flutter_mcp_toolkit_core.dart';
import 'resource_registration.dart';
import 'resource_template_registration.dart';
import 'tool_registration.dart';

/// Builds a [ToolRegistration] from a codegen [AgentCallEntry].
///
/// Use [handler] when the generated handler cannot access host services (e.g.
/// [CommandRunner]) or full wire [AgentArguments] (e.g. `connection` override).
/// Use [mergeInputSchema] to extend the generated JSON Schema.
ToolRegistration agentCallEntryToToolRegistration(
  final AgentCallEntry entry, {
  final ToolHandler? handler,
  final Map<String, Object?> Function(Map<String, Object?> schema)?
  mergeInputSchema,
}) {
  final intent = entry.toRegistration();
  var inputSchema = Map<String, Object?>.from(intent.descriptor.inputSchema);
  if (mergeInputSchema != null) {
    inputSchema = mergeInputSchema(inputSchema);
  }
  final execute =
      handler ??
      (final args) {
        intent.validate(args);
        return intent.execute(
          AgentInvocation(descriptor: intent.descriptor, arguments: args),
        );
      };
  return ToolRegistration(
    name: intent.descriptor.name,
    description: intent.descriptor.description,
    inputSchema: inputSchema,
    handler: execute,
  );
}

RegisteredAgentIntent toolRegistrationToRegistration({
  required final String capabilityId,
  required final ToolRegistration registration,
}) {
  final descriptor = AgentIntentDescriptor(
    namespace: capabilityId,
    name: registration.name,
    description: registration.description,
    kind: AgentIntentKind.tool,
    inputSchema: registration.inputSchema,
  );
  late final RegisteredAgentIntent intent;
  intent = RegisteredAgentIntent(
    descriptor: descriptor,
    execute: (final invocation) {
      intent.validate(invocation.arguments);
      return registration.handler(invocation.arguments);
    },
  );
  return intent;
}

RegisteredAgentIntent resourceRegistrationToRegistration({
  required final String capabilityId,
  required final ResourceRegistration registration,
}) {
  final inputSchema = clientResourceReadInputSchema();
  final descriptor = AgentIntentDescriptor(
    namespace: capabilityId,
    name: registration.name,
    description: registration.description,
    kind: AgentIntentKind.resource,
    inputSchema: inputSchema,
    resourceUri: registration.uri,
    mimeType: registration.mimeType,
  );
  late final RegisteredAgentIntent intent;
  intent = RegisteredAgentIntent(
    descriptor: descriptor,
    execute: (final invocation) {
      intent.validate(invocation.arguments);
      final uri = invocation.arguments['uri'];
      return registration.handler(uri is String ? uri : registration.uri);
    },
  );
  return intent;
}

RegisteredAgentIntent resourceTemplateRegistrationToRegistration({
  required final String capabilityId,
  required final ResourceTemplateRegistration registration,
}) {
  final inputSchema = clientResourceTemplateReadInputSchema();
  final descriptor = AgentIntentDescriptor(
    namespace: capabilityId,
    name: registration.name,
    description: registration.description,
    kind: AgentIntentKind.resource,
    inputSchema: inputSchema,
    resourceUri: registration.uriTemplate,
    mimeType: registration.mimeType,
  );
  late final RegisteredAgentIntent intent;
  intent = RegisteredAgentIntent(
    descriptor: descriptor,
    execute: (final invocation) {
      intent.validate(invocation.arguments);
      final uri = invocation.arguments['uri'];
      return registration.handler(
        uri is String ? uri : registration.uriTemplate,
      );
    },
  );
  return intent;
}
