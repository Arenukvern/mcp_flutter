import 'dart:async';

import 'package:agentkit_schema/agentkit_schema.dart';

import '../intent/agent_intent_descriptor.dart';
import '../intent/agent_intent_kind.dart';
import '../intent/agent_invocation.dart';
import '../intent/registered_agent_intent.dart';
import '../registry/agent_registry.dart';

typedef AgentCallHandler =
    FutureOr<AgentResult> Function(AgentArguments request);

typedef _AgentCallEntryValue = ({
  String namespace,
  String description,
  InputSchema inputSchema,
  AgentIntentKind kind,
  AgentCallHandler handler,
  String? methodName,
  String? resourceUri,
  String? mimeType,
});

extension type const AgentCallEntry._(
  MapEntry<String, _AgentCallEntryValue> _entry
)
    implements MapEntry<String, _AgentCallEntryValue> {
  factory AgentCallEntry.tool({
    required final String namespace,
    required final String name,
    required final String description,
    required final InputSchema inputSchema,
    required final AgentCallHandler handler,
    final String? methodName,
  }) => AgentCallEntry._(
    MapEntry(name, (
      namespace: namespace,
      description: description,
      inputSchema: inputSchema,
      kind: AgentIntentKind.tool,
      handler: handler,
      methodName: methodName,
      resourceUri: null,
      mimeType: null,
    )),
  );

  factory AgentCallEntry.resource({
    required final String namespace,
    required final String name,
    required final String description,
    required final AgentCallHandler handler,
    final InputSchema? inputSchema,
    final String? methodName,
    final String? mimeType,
  }) => AgentCallEntry._(
    MapEntry(name, (
      namespace: namespace,
      description: description,
      inputSchema: inputSchema ?? clientResourceReadInputSchema(),
      kind: AgentIntentKind.resource,
      handler: handler,
      methodName: methodName,
      resourceUri: null,
      mimeType: mimeType ?? 'application/json',
    )),
  );

  String get name => _entry.key;

  RegisteredAgentIntent toRegistration() {
    final value = _entry.value;
    return RegisteredAgentIntent(
      descriptor: AgentIntentDescriptor(
        namespace: value.namespace,
        name: name,
        description: value.description,
        kind: value.kind,
        inputSchema: value.inputSchema,
        methodName: value.methodName,
        resourceUri: value.resourceUri,
        mimeType: value.mimeType,
      ),
      execute: (final invocation) async =>
          await value.handler(invocation.arguments),
    );
  }

  Future<AgentResult> invokeDirect(final AgentArguments arguments) {
    final registration = toRegistration();
    final coerced = coerceArgumentsForSchema(
      registration.descriptor.inputSchema,
      arguments,
    );
    registration.validate(coerced);
    return registration.execute(
      AgentInvocation(
        descriptor: registration.descriptor,
        arguments: coerced,
      ),
    );
  }
}

void registerAll(
  final AgentRegistry registry,
  final Iterable<AgentCallEntry> entries,
) {
  for (final entry in entries) {
    registry.register(entry.toRegistration());
  }
}

extension AgentCallEntrySet on Set<AgentCallEntry> {
  AgentCallEntry byName(final String name) =>
      firstWhere((final entry) => entry.name == name);
}
