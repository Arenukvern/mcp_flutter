import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:test/test.dart';

void main() {
  test('invoke runs intent handler', () async {
    final registry = InMemoryAgentRegistry();
    registry.register(
      RegisteredAgentIntent(
        descriptor: AgentIntentDescriptor(
          namespace: 'demo',
          name: 'echo',
          description: 'echo',
          kind: AgentIntentKind.tool,
          inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
        ),
        execute: (final inv) async =>
            AgentResult.success(data: {'in': inv.arguments['x']}),
      ),
    );
    final out = await registry.invoke('demo_echo', {'x': 1});
    expect(out.ok, isTrue);
    expect(out.data['in'], 1);
  });

  test('duplicate qualified name throws', () {
    final registry = InMemoryAgentRegistry();
    final intent = RegisteredAgentIntent(
      descriptor: AgentIntentDescriptor(
        namespace: 'demo',
        name: 'echo',
        description: 'echo',
        kind: AgentIntentKind.tool,
        inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
      ),
      execute: (_) async => AgentResult.success(),
    );
    registry.register(intent);
    expect(() => registry.register(intent), throwsA(isA<AgentIntentCollisionError>()));
  });
}
