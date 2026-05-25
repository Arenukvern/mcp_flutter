import '../registry/agent_registry.dart';

abstract interface class AgentModule {
  String get id;

  Future<void> register(AgentRegistry registry);

  Future<void> dispose();
}
