import '../authoring/agent_call_entry.dart';
import '../registry/agent_registry.dart';
import 'agent_module.dart';

final class AgentModuleFromEntries implements AgentModule {
  AgentModuleFromEntries({required this.id, required this.buildEntries});

  static AgentModule fromEntries({
    required final String id,
    required final Set<AgentCallEntry> Function() build,
  }) => AgentModuleFromEntries(id: id, buildEntries: build);

  @override
  final String id;
  final Set<AgentCallEntry> Function() buildEntries;

  @override
  Future<void> register(final AgentRegistry registry) async {
    registerAll(registry, buildEntries());
  }

  @override
  Future<void> dispose() async {}
}
