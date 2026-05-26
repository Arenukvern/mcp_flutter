import 'package:agentkit_schema/agentkit_schema.dart';

import '../intent/agent_intent_descriptor.dart';
import '../intent/registered_agent_intent.dart';
import 'registry_events.dart';

abstract interface class AgentRegistry {
  String qualify({required final String namespace, required final String name});

  void register(
    final RegisteredAgentIntent intent, {
    final String? qualifiedNameOverride,
  });

  void unregister(final String qualifiedName);

  RegisteredAgentIntent? get(final String qualifiedName);

  Iterable<AgentIntentDescriptor> listDescriptors({final String? namespace});

  Future<AgentResult> invoke(
    final String qualifiedName,
    final AgentArguments arguments, {
    final String? correlationId,
  });

  Stream<AgentRegistryEvent> get events;
}
