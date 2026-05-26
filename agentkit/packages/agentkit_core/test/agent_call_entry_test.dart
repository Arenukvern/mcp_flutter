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
}
