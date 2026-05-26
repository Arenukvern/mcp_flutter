import '../registry/agent_registry.dart';

abstract interface class AgentModule {
  String get id;

  Future<void> register(final AgentRegistry registry);

  Future<void> dispose();
}
