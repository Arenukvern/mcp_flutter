import 'package:agentkit_core/agentkit_core.dart';

/// Phase 3 placeholder — publishes registry intents to WebMCP surfaces.
abstract interface class WebMcpAgentAdapter implements AgentAdapter {
  @override
  String get id => 'webmcp';
}
