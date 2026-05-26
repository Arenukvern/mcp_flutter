import 'package:agentkit_codegen/agentkit_codegen.dart';
import 'package:agentkit_schema/agentkit_schema.dart';

// Example annotated tool for codegen pilot (see test/agent_tool_generator_test.dart).

@AgentTool(
  namespace: 'app',
  name: 'demo_ping',
  description: 'Returns pong for a message',
)
Future<AgentResult> demoPing(@AgentParam('Message to echo') String message) async {
  return AgentResult.success(data: {'pong': message});
}
