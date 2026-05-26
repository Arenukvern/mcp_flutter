import '../adapter/agent_adapter.dart';
import '../module/agent_module.dart';
import '../registry/agent_registry.dart';
import '../registry/in_memory_agent_registry.dart';

final class AgentRuntime {
  AgentRuntime({
    final AgentRegistry? registry,
    final List<AgentModule> modules = const [],
    final List<AgentAdapter> adapters = const [],
  }) : registry = registry ?? InMemoryAgentRegistry(),
       _modules = List<AgentModule>.from(modules),
       _adapters = List<AgentAdapter>.from(adapters);

  final AgentRegistry registry;
  final List<AgentModule> _modules;
  final List<AgentAdapter> _adapters;
  var _started = false;

  Future<void> start() async {
    if (_started) {
      return;
    }
    for (final module in _modules) {
      await module.register(registry);
    }
    for (final adapter in _adapters) {
      await adapter.attach(registry);
    }
    _started = true;
  }

  Future<void> stop() async {
    if (!_started) {
      return;
    }
    for (final adapter in _adapters.reversed) {
      await adapter.detach();
    }
    for (final module in _modules.reversed) {
      await module.dispose();
    }
    _started = false;
  }
}
