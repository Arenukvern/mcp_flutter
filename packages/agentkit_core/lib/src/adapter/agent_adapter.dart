import '../registry/agent_registry.dart';

abstract interface class AgentAdapter {
  String get id;

  Future<void> attach(AgentRegistry registry);

  Future<void> detach();

  bool get watchesRegistry => true;
}
