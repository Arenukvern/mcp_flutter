import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:meta/meta.dart';

import 'agent_intent_descriptor.dart';

@immutable
final class AgentInvocation {
  const AgentInvocation({
    required this.descriptor,
    required this.arguments,
    this.correlationId,
  });

  final AgentIntentDescriptor descriptor;
  final AgentArguments arguments;
  final String? correlationId;
}
