import 'package:agentkit_schema/agentkit_schema.dart';

import '../intent/agent_intent_descriptor.dart';
import '../intent/registered_agent_intent.dart';
import 'registry_events.dart';

abstract interface class AgentRegistry {
  String qualify({required String namespace, required String name});

  void register(
    RegisteredAgentIntent intent, {
    String? qualifiedNameOverride,
  });

  void unregister(String qualifiedName);

  RegisteredAgentIntent? get(String qualifiedName);

  Iterable<AgentIntentDescriptor> listDescriptors({String? namespace});

  Future<AgentResult> invoke(
    String qualifiedName,
    AgentArguments arguments, {
    String? correlationId,
  });

  Stream<AgentRegistryEvent> get events;
}
