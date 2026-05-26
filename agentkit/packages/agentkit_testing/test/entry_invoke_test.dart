import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:agentkit_testing/agentkit_testing.dart';
import 'package:test/test.dart';

Set<AgentCallEntry> _buildDemoEntries({
  required final Map<String, Object?> Function({String? viewMode}) applyControls,
  required final Map<String, Object?> Function() readSnapshot,
}) => {
    AgentCallEntry.tool(
      namespace: 'demo',
      name: 'set_controls',
      description: 'Apply parity controls',
      inputSchema: const {
        'type': 'object',
        'additionalProperties': false,
        'properties': {
          'viewMode': {'type': 'string'},
        },
      },
      handler: (final args) {
        final wire = AgentWireArgs(
          args.map((final k, final v) => MapEntry(k, v?.toString() ?? '')),
        );
        final snapshot = applyControls(viewMode: wire.string('viewMode'));
        return AgentResultEnvelope.envelope(
          kind: 'demo_set_controls',
          snapshot: snapshot,
        );
      },
    ),
    AgentCallEntry.tool(
      namespace: 'demo',
      name: 'ping',
      description: 'ping',
      inputSchema: const {
        'type': 'object',
        'additionalProperties': false,
        'properties': {},
      },
      handler: (_) => AgentResult.success(
        message: 'pong',
        data: const {'ok': true},
      ),
    ),
  };

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
      handler: (_) => AgentResult.success(
        message: 'pong',
        data: const {'ok': true},
      ),
    );

    final result = await entry.invokeWire(const {});
    expect(result.ok, isTrue);
    expect(result.message, 'pong');
    expect(result.data['ok'], true);
  });

  test('builder → invokeWire → AgentResult.envelope (design § Client DX)', () async {
    final entries = _buildDemoEntries(
      readSnapshot: () => const {'phase': 'playing'},
      applyControls: ({final viewMode}) => {'view_mode': viewMode ?? 'default'},
    );
    final entry = entries.byName('set_controls');
    final result = await entry.invokeWire({'viewMode': 'composite'});
    expect(result.ok, isTrue);
    expect(result.data['schema_version'], 1);
    expect(result.data['kind'], 'demo_set_controls');
    expect(
      (result.data['snapshot']! as Map<String, Object?>)['view_mode'],
      'composite',
    );
  });

  test('entry set byName resolves registration descriptor', () {
    final entries = {
      AgentCallEntry.tool(
        namespace: 'app',
        name: 'a',
        description: 'a',
        inputSchema: const {'type': 'object', 'properties': {}},
        handler: (_) => AgentResult.success(),
      ),
    };

    expect(entries.byName('a').toRegistration().descriptor.qualifiedName, 'app_a');
  });
}
