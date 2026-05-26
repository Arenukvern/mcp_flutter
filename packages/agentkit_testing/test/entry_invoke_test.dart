import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:agentkit_testing/agentkit_testing.dart';
import 'package:test/test.dart';

void main() {
  test('AgentCallEntry invokeWire returns AgentResult envelope', () async {
    final entry = AgentCallEntry.tool(
      namespace: 'demo',
      name: 'ping',
      description: 'ping',
      inputSchema: const {
        'type': 'object',
        'additionalProperties': false,
        'properties': {},
      },
      handler: (_) async => AgentResult.success(
        message: 'pong',
        data: const {'ok': true},
      ),
    );

    final result = await entry.invokeWire(const {});
    expect(result.ok, isTrue);
    expect(result.message, 'pong');
    expect(result.data?['ok'], true);
  });

  test('entry set byName resolves registration descriptor', () {
    final entries = {
      AgentCallEntry.tool(
        namespace: 'app',
        name: 'a',
        description: 'a',
        inputSchema: const {'type': 'object', 'properties': {}},
        handler: (_) async => AgentResult.success(),
      ),
    };

    expect(entries.byName('a').toRegistration().descriptor.qualifiedName, 'app_a');
  });
}
