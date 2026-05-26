import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';

extension AgentCallEntryTest on AgentCallEntry {
  Future<AgentResult> invokeWire(final Map<String, String> wire) =>
      invokeDirect(AgentWireArgs(wire).toAgentArguments());
}
