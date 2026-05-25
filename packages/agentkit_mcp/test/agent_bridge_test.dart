import 'package:agentkit_core/agentkit_core.dart';
import 'package:agentkit_mcp/agentkit_mcp.dart';
import 'package:agentkit_schema/agentkit_schema.dart';
import 'package:flutter_mcp_toolkit_capability_kernel/flutter_mcp_toolkit_capability_kernel.dart';
import 'package:test/test.dart';

void main() {
  test('toolRegistrationToRegistration invokes AgentResult handler', () async {
    final registration = ToolRegistration(
      name: 'echo',
      description: 'echo',
      inputSchema: const {'type': 'object', 'properties': <String, Object?>{}},
      handler: (final args) async => AgentResult.success(
        data: <String, Object?>{'text': '{"ok":true}'},
      ),
    );
    final intent = toolRegistrationToRegistration(
      capabilityId: 'fmt',
      registration: registration,
    );
    final result = await intent.execute(
      AgentInvocation(
        descriptor: intent.descriptor,
        arguments: const {},
      ),
    );
    expect(result.ok, isTrue);
    expect(result.data['text'], '{"ok":true}');
  });
}
