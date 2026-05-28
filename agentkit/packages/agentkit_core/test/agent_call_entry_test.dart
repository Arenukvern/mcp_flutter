import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
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

  test('resource defaults to clientResourceReadInputSchema', () {
    final entry = AgentCallEntry.resource(
      namespace: 'app',
      name: 'status',
      description: 'status',
      handler: (_) => AgentResult.success(),
    );

    expect(
      entry.toRegistration().descriptor.inputSchema,
      clientResourceReadInputSchema(),
    );
  });

  test('invokeDirect coerces VM wire strings before validate', () async {
    int? capturedSnapshotId;
    final entry = AgentCallEntry.tool(
      namespace: 'app',
      name: 'tap',
      description: 'tap',
      inputSchema: const {
        'type': 'object',
        'required': ['ref'],
        'properties': {
          'ref': {'type': 'string'},
          'snapshotId': {'type': 'integer'},
        },
      },
      handler: (final args) async {
        capturedSnapshotId = args['snapshotId'] as int?;
        return AgentResult.success();
      },
    );

    await entry.invokeDirect({'ref': 's_0', 'snapshotId': '99'});
    expect(capturedSnapshotId, 99);
  });

  test('invokeDirect on resource rejects missing uri', () {
    final entry = AgentCallEntry.resource(
      namespace: 'app',
      name: 'status',
      description: 'status',
      handler: (_) => AgentResult.success(),
    );

    expect(
      () => entry.invokeDirect(const {}),
      throwsA(isA<AgentValidationException>()),
    );
  });
}
