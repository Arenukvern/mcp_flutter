import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:test/test.dart';

void main() {
  test('toRegistration uses qualified name', () {
    final entry = AgentCallEntry.tool(
      namespace: 'app',
      name: 'ping',
      description: 'ping',
      inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
      handler: (_) => AgentResult.success(),
    );
    expect(entry.toRegistration().qualifiedName, 'app_ping');
  });

  test('invokeDirect validates against inputSchema', () async {
    final entry = AgentCallEntry.tool(
      namespace: 'app',
      name: 'needs_ref',
      description: 'needs ref',
      inputSchema: const {
        'type': 'object',
        'required': ['ref'],
        'properties': {
          'ref': {'type': 'string'},
        },
      },
      handler: (_) => AgentResult.success(),
    );

    expect(
      () => entry.invokeDirect(const {}),
      throwsA(isA<AgentValidationException>()),
    );
    final result = await entry.invokeDirect({'ref': 's_0'});
    expect(result.ok, isTrue);
  });
}
