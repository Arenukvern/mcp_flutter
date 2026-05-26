import '../registry/agent_registry.dart';

abstract interface class AgentAdapter {
  String get id;

  Future<void> attach(final AgentRegistry registry);

  Future<void> detach();

  bool get watchesRegistry => true;
}
