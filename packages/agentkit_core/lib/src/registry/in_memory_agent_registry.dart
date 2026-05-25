import 'dart:async';

import 'package:agentkit_schema/agentkit_schema.dart';

import '../intent/agent_intent_descriptor.dart';
import '../intent/agent_invocation.dart';
import '../intent/registered_agent_intent.dart';
import '../naming/qualified_name.dart';
import 'agent_registry.dart';
import 'agent_registry_errors.dart';
import 'registry_events.dart';

final class InMemoryAgentRegistry implements AgentRegistry {
  InMemoryAgentRegistry();

  final Map<String, RegisteredAgentIntent> _intents =
      <String, RegisteredAgentIntent>{};
  final StreamController<AgentRegistryEvent> _events =
      StreamController<AgentRegistryEvent>.broadcast();

  @override
  Stream<AgentRegistryEvent> get events => _events.stream;

  @override
  String qualify({required final String namespace, required final String name}) =>
      qualifyName(namespace: namespace, name: name);

  @override
  void register(
    final RegisteredAgentIntent intent, {
    final String? qualifiedNameOverride,
  }) {
    final key = qualifiedNameOverride ?? intent.qualifiedName;
    if (_intents.containsKey(key)) {
      throw AgentIntentCollisionError('Intent "$key" registered twice.');
    }
    _intents[key] = intent;
    _events.add(IntentRegistered(timestamp: DateTime.now(), qualifiedName: key));
  }

  @override
  void unregister(final String qualifiedName) {
    if (_intents.remove(qualifiedName) != null) {
      _events.add(
        IntentUnregistered(
          timestamp: DateTime.now(),
          qualifiedName: qualifiedName,
        ),
      );
    }
  }

  @override
  RegisteredAgentIntent? get(final String qualifiedName) => _intents[qualifiedName];

  @override
  Iterable<AgentIntentDescriptor> listDescriptors({final String? namespace}) {
    final values = _intents.values.map((final e) => e.descriptor);
    if (namespace == null) {
      return values;
    }
    return values.where((final d) => d.namespace == namespace);
  }

  @override
  Future<AgentResult> invoke(
    final String qualifiedName,
    final AgentArguments arguments, {
    final String? correlationId,
  }) async {
    final intent = _intents[qualifiedName];
    if (intent == null) {
      return AgentResult.failure(
        code: 'intent_not_found',
        message: 'No intent registered for $qualifiedName',
      );
    }
    intent.validate(arguments);
    return intent.execute(
      AgentInvocation(
        descriptor: intent.descriptor,
        arguments: arguments,
        correlationId: correlationId,
      ),
    );
  }
}
