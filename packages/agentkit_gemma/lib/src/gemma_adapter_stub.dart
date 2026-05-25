import 'package:agentkit_core/agentkit_core.dart';

/// Phase 3 placeholder — maps registry intents to on-device Gemma tools.
abstract interface class GemmaAgentAdapter implements AgentAdapter {
  @override
  String get id => 'gemma';
}
