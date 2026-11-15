import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_toolkit/mcp_toolkit.dart';

/// Compiles the README custom-tools snippet (const Map inputSchema).
void main() {
  test('README custom-tools AgentCallEntry.tool snippet type-checks', () {
    final entry = AgentCallEntry.tool(
      namespace: 'demo',
      name: 'ping',
      description: 'Health check',
      inputSchema: const {
        'type': 'object',
        'additionalProperties': false,
        'properties': {},
      },
      handler: (args) async => AgentResult.success(message: 'pong'),
    );
    expect(entry.name, 'ping');
  });
}